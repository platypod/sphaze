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
	static var initialized = false;

	public static function isDown(code:String):Bool {
		init();
		return down.get(code) == true;
	}

	static function init():Void {
		if (initialized)
			return;
		initialized = true;
		#if js
		js.Browser.window.addEventListener("keydown", (e:js.html.KeyboardEvent) -> down.set(e.code, true), true);
		js.Browser.window.addEventListener("keyup", (e:js.html.KeyboardEvent) -> down.set(e.code, false), true);
		#end
	}
}
