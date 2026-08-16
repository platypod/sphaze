package game;

/**
	Tracks held keys by physical `KeyboardEvent.code` (e.g. `"KeyW"`) rather
	than `hxd.Key`'s layout-labeled codes. `code` always names the hardware
	key position after its US-QWERTY label regardless of the OS layout, so
	binding movement to `"KeyW"/"KeyA"/"KeyS"/"KeyD"` hits AZERTY's ZQSD keys
	(and any other layout's equivalent) without detecting the layout at all
	— see `Keybinds.MOVE_FORWARD_ALT` and friends.

	`hxd.Event`/`hxd.Key` never carry `.code` (checked against the installed
	Heaps 2.1.0 source: `hxd.Window.js.hx` only forwards the legacy
	`e.keyCode`), so this listens on the DOM directly instead of going
	through Heaps' input pipeline. Listeners are registered on the capture
	phase so they still fire even though Heaps' own canvas-level handler
	calls `stopPropagation()` on every key event by default.
**/
class PhysicalKeys {
	static var down:Map<String, Bool> = new Map();

	/** Codes that have gone down since `isPressed` last consumed them. **/
	static var pending:Map<String, Bool> = new Map();

	/** Per code, the frame `isPressed` last answered on, and what it answered — see `isPressed`'s own doc for why both are kept. **/
	static var answeredFrame:Map<String, Int> = new Map();

	static var answer:Map<String, Bool> = new Map();
	static var initialized = false;

	public static function isDown(code:String):Bool {
		init();
		return down.get(code) == true;
	}

	/**
		True on the frame a key first goes down — the physical-code
		counterpart to `hxd.Key.isPressed`, for the same AZERTY/QWERTY reason
		`isDown` exists.

		**Idempotent within a frame, deliberately.** The obvious
		implementation (return the pending flag and clear it) would make the
		*first* caller in a frame see the press and every later caller miss
		it — a trap that stays invisible until someone adds a second reader
		of the same key. Keying the answer to `hxd.Timer.frameCount` instead
		means every caller in a frame gets the same result, matching what
		`hxd.Key.isPressed` already does.

		Frame-stamping the *answer* rather than the keydown is what makes it
		reliable: a DOM keydown fires between frames, so the frame number at
		press time is ambiguous, whereas the frame at read time never is.
		@param code a `KeyboardEvent.code`, e.g. `"KeyW"` or `"Digit1"`.
		@return whether this key began being held since the last frame that asked.
	**/
	public static function isPressed(code:String):Bool {
		init();
		var frame = hxd.Timer.frameCount;
		if (answeredFrame.get(code) == frame) {
			return answer.get(code) == true;
		}
		var fired = pending.get(code) == true;
		pending.set(code, false);
		answeredFrame.set(code, frame);
		answer.set(code, fired);
		return fired;
	}

	static function init():Void {
		if (initialized)
			return;
		initialized = true;
		#if js
		js.Browser.window.addEventListener("keydown", (e:js.html.KeyboardEvent) -> {
			// auto-repeat re-fires keydown while held; only a genuine
			// transition counts as a press
			if (down.get(e.code) != true) {
				pending.set(e.code, true);
			}
			down.set(e.code, true);
		}, true);
		js.Browser.window.addEventListener("keyup", (e:js.html.KeyboardEvent) -> down.set(e.code, false), true);
		#end
	}
}
