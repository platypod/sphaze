package game;

import biomes.common.Biome;
import biomes.common.grid.GridModel;
import biomes.common.space.sphere.SphereMath;
import biomes.hub.HubBiome;
import biomes.maze.MazeBiome;
import biomes.maze.MazeGenerator;
import biomes.mobius.MobiusBiome;
import biomes.tower.TowerBiome;
import biomes.tower.TowerGenerator;
import entities.hourglass.HourglassModel;
import entities.player.Camera;
import entities.player.PlayerModel;
import entities.registries.BiomesRegistry;

/**
	Everything about actually playing the game: biome setup/switching, input
	handling, the debug overlay, save/load — everything `Main` used to do
	except the bare `hxd.App` lifecycle and the fixed-timestep accumulator,
	which stay on `Main` itself (see its own class doc for why those two
	specifically don't move here).
**/
class GameLoop {
	static inline final BACKGROUND_COLOR:Int = 0x202020;
	static inline final CAMERA_FOV_Y:Float = 70;
	static inline final WALK_SPEED:Float = 15;
	static inline final SPRINT_MULTIPLIER:Float = 1.8;
	static inline final TURN_SPEED:Float = 2.5;
	static inline final MOUSE_SENSITIVITY:Float = 0.0025;

	/**
		Initial upward speed a jump launches the player at — one shared
		constant rather than a per-biome one (unlike `Biome.gravity()`): a
		lighter-gravity biome naturally jumps higher and longer off the same
		launch speed, no separate knob needed. First-pass value — tuned by
		feel for "a small hop," not high up, same as `GridGeometry`'s own
		constants were tuned iteratively against playtesting.
	**/
	static inline final JUMP_IMPULSE:Float = 18;

	final s3d:h3d.scene.Scene;

	var player:PlayerModel;

	/** Every biome that exists, plus which ones the player has discovered so far — see `biomes.common.Biome`'s own class doc for why the hub is one of these too, not a special case. **/
	var biomeRegistry:BiomesRegistry;

	/** Whichever biome the player is currently in. **/
	var currentBiome:Biome;

	var mazeGroup:h3d.scene.Object;

	var debugOverlay:h2d.Text;
	var debugOverlayVisible:Bool = false;
	var mazeFileInput:js.html.InputElement;

	/**
		@param s3d the 3D scene to build biomes and place the camera into.
		@param s2d the 2D scene to build the debug overlay into.
		@param engine the render engine, for the background color.
	**/
	public function new(s3d:h3d.scene.Scene, s2d:h2d.Scene, engine:h3d.Engine) {
		this.s3d = s3d;

		engine.backgroundColor = BACKGROUND_COLOR;
		s3d.camera.fovY = CAMERA_FOV_Y;

		mazeGroup = new h3d.scene.Object(s3d);
		biomeRegistry = new BiomesRegistry();
		// One shared instance, not one per biome - the hub ticks it, the
		// tower only reads its own unlocked flag (see TowerBiome's own class
		// doc for why that's a shared model rather than a lookup).
		var hourglassModel = new HourglassModel();
		biomeRegistry.register(new HubBiome(hourglassModel), true); // always known - it's home, not something to stumble into
		biomeRegistry.register(new MazeBiome(MazeGenerator.generate()));
		biomeRegistry.register(new TowerBiome(TowerGenerator.generate(), hourglassModel));
		biomeRegistry.register(new MobiusBiome());
		enterBiome(HubBiome.ID, false);

		// F3 debug overlay (Minecraft-style): player position, camera angle,
		// perf stats. Hidden by default; toggled in fixedUpdate.
		debugOverlay = new h2d.Text(hxd.res.DefaultFont.get(), s2d);
		debugOverlay.x = 10;
		debugOverlay.y = 10;
		debugOverlay.textColor = 0xFFFF00;
		debugOverlay.visible = debugOverlayVisible;

		// Hidden file input backing L's "load a maze" — browsers won't let a
		// page read an arbitrary local file without the user driving a
		// picker, so this has to exist even though nothing ever shows it.
		mazeFileInput = cast js.Browser.document.createElement("input");
		mazeFileInput.type = "file";
		mazeFileInput.accept = ".json";
		mazeFileInput.style.display = "none";
		mazeFileInput.onchange = onMazeFileChosen;
		js.Browser.document.body.appendChild(mazeFileInput);

		// Relative mode hides the cursor and reports movement deltas instead
		// of a position — the standard FPS mouse-look. Per hxd.Window's own
		// doc, this only engages on the player's first click on the canvas
		// (a browser requirement for pointer lock); nothing else to wire up.
		var window = hxd.Window.getInstance();
		window.mouseMode = Relative(onMouseMove, true);
		window.onMouseModeChange = keepWantingRelativeMouse;
	}

	/**
		(Re)builds `id`'s meshes under `mazeGroup`, places its exit painting,
		and spawns the player at its entry point — used at startup, when
		importing a previously exported maze (see `exportMaze`/
		`onMazeFileChosen`), and whenever a painting warps the player into
		another biome (see `checkPaintingTrigger`).
		@param id the `Biome.id()` to enter.
		@param returning whether the player is coming back into a biome they already visited rather than a fresh arrival — see `Biome.spawnPlayer`.
	**/
	function enterBiome(id:String, returning:Bool):Void {
		var biome = biomeRegistry.get(id);
		if (biome == null) {
			throw 'unreachable: no biome registered for id "$id"';
		}
		var fromBiomeId = currentBiome != null ? currentBiome.id() : null;
		biomeRegistry.markDiscovered(id);

		currentBiome = biome;
		mazeGroup.removeChildren();
		biome.build(mazeGroup);

		player = biome.spawnPlayer(returning, fromBiomeId);
		Camera.applyTo(s3d.camera, player);
	}

	/**
		Attempts to move `player` by `distance` along `direction`, through
		whichever biome's own collision currently applies (see `Biome.tryMove`).
		@param direction unit tangent at `player.pos` to move along.
		@param distance arc length to move; negative moves the opposite way.
	**/
	function tryMove(direction:h3d.Vector, distance:Float):Void {
		currentBiome.tryMove(player, direction, distance);
	}

	/**
		Walking into any of the current biome's own exit paintings warps to
		wherever it leads — no interact-key confirmation, on purpose (see
		`entities.painting.PaintingModel`'s own class doc). Uniform for every
		biome, hub included: there's no "which kind of destination is this"
		branch, just "enter whichever biome id this painting names." Reads
		`Biome.exitPaintings` fresh every tick rather than caching it at
		entry — see that method's own doc for why (a biome's own set can
		change mid-visit).
	**/
	function checkPaintingTrigger():Void {
		for (painting in currentBiome.exitPaintings()) {
			if (painting.triggeredBy(player.pos)) {
				enterBiome(painting.destinationBiomeId, true);
				return;
			}
		}
	}

	/**
		Downloads the current biome's own state as a JSON file (E) — pairs
		with L (`promptImportMaze`) to make a maze a specific bug showed up
		in something that can actually be saved and handed back, instead of
		lost the moment the page reloads. Works uniformly for whichever biome
		is current (see `Biome.serialize`) — no biome-specific special case;
		a stateless biome like the hub just downloads a trivial `"{}"`.
	**/
	function exportMaze():Void {
		var json = currentBiome.serialize();
		var blob = new js.html.Blob([json], {type: "application/json"});
		var url:String = js.Syntax.code("URL.createObjectURL({0})", blob);
		var anchor:js.html.AnchorElement = cast js.Browser.document.createElement("a");
		anchor.href = url;
		anchor.download = 'sphaze-${currentBiome.id()}.json';
		anchor.click();
		js.Syntax.code("URL.revokeObjectURL({0})", url);
	}

	/** Opens the browser's file picker (L) for `onMazeFileChosen` to load from. **/
	function promptImportMaze():Void {
		mazeFileInput.value = "";
		mazeFileInput.click();
	}

	/**
		`mazeFileInput`'s change handler: restores the chosen file into
		whichever biome is current (see `Biome.restore`), re-entering it
		fresh (not `returning` — there's no meaningful "where they left off"
		for an imported state).
	**/
	function onMazeFileChosen(e:js.html.Event):Void {
		var file = mazeFileInput.files[0];
		if (file == null) {
			return;
		}

		var reader = new js.html.FileReader();
		reader.onload = (_) -> {
			currentBiome.restore(reader.result);
			enterBiome(currentBiome.id(), false);
		};
		reader.readAsText(file);
	}

	/**
		Pressing Escape (or switching tabs) exits the browser's pointer lock,
		which `hxd.Window` reports by force-changing `mouseMode` to
		`Absolute` — without this override, the game would just stay there,
		since nothing else ever re-requests `Relative`, leaving mouse-look
		permanently dead until a page reload. Forcing the change right back
		to `Relative` here doesn't re-acquire the lock immediately (the
		caller guards against that itself right after an Escape, per
		`hxd.impl.MouseMode`'s own doc), it just keeps the *mode* — not the
		lock — set to `Relative`, which is what makes the documented
		"first click on the canvas re-captures the mouse" behavior kick in
		again on the very next click.
		@param from the mouse mode being changed away from.
		@param to the mouse mode being forced to.
		@return the mouse mode to actually use instead of `to`, or null to accept it as-is.
	**/
	function keepWantingRelativeMouse(from:hxd.impl.MouseMode, to:hxd.impl.MouseMode):Null<hxd.impl.MouseMode> {
		return switch to {
			case Absolute: Relative(onMouseMove, true);
			case other: null;
		}
	}

	function onMouseMove(e:hxd.Event):Void {
		player.turn(e.relX * MOUSE_SENSITIVITY);
		player.lookUp(-e.relY * MOUSE_SENSITIVITY);
	}

	public function fixedUpdate(dt:Float):Void {
		// currentBiome.tick runs on the real, unscaled dt - it's what
		// actually advances the hub's own hourglass (see biomes.common.Biome.tick's
		// own doc) - before timeScale() is read for this same tick, so a
		// tilt change this tick already applies to this tick's own movement.
		// The multiplier itself is read globally (biomeRegistry.globalTimeScale,
		// not currentBiome.timeScale) - the hourglass's own effect on game
		// speed applies everywhere, per direct ask, not only while standing
		// in the hub; only the hourglass's own tilt/trigger detection stays
		// scoped to actually being there (currentBiome.tick, above).
		currentBiome.tick(player, dt);
		var scaledDt = dt * biomeRegistry.globalTimeScale();

		// Reading keys and calling PlayerModel methods directly here is a
		// placeholder — fine for one input source and one entity, but a
		// dedicated input/controller system is the right home for this once
		// there's more than a single player to drive.
		if (hxd.Key.isDown(Keybinds.TURN_LEFT)) {
			player.turn(-TURN_SPEED * scaledDt);
		}
		if (hxd.Key.isDown(Keybinds.TURN_RIGHT)) {
			player.turn(TURN_SPEED * scaledDt);
		}
		var speed = hxd.Key.isDown(Keybinds.SPRINT) ? WALK_SPEED * SPRINT_MULTIPLIER : WALK_SPEED;
		if (hxd.Key.isDown(Keybinds.MOVE_FORWARD) || PhysicalKeys.isDown(Keybinds.MOVE_FORWARD_ALT)) {
			tryMove(player.forward, speed * scaledDt);
		}
		if (hxd.Key.isDown(Keybinds.MOVE_BACKWARD) || PhysicalKeys.isDown(Keybinds.MOVE_BACKWARD_ALT)) {
			tryMove(player.forward, -speed * scaledDt);
		}
		// Q/D strafe sideways rather than turn — the player's body moves
		// without them choosing to face that way, same as forward/backward.
		// rightVector() (forward.cross(up)) is the standard right-handed
		// "right", but Heaps' camera is left-handed (s3d.camera.rightHanded
		// == false) — its actual on-screen right is the *opposite* of that,
		// confirmed via camera.getRight(). So +rightVector() is screen
		// *left* and -rightVector() is screen *right* here. rightVector()
		// itself stays as-is since applyToCamera's pitch axis needs it
		// (flipping it there would flip which way lookUp tilts); the
		// correction lives here instead.
		if (PhysicalKeys.isDown(Keybinds.STRAFE_LEFT)) {
			tryMove(player.rightVector(), speed * scaledDt);
		}
		if (PhysicalKeys.isDown(Keybinds.STRAFE_RIGHT)) {
			tryMove(player.rightVector(), -speed * scaledDt);
		}
		if (hxd.Key.isPressed(Keybinds.JUMP)) {
			// Not scaled: an impulse is a rate, not a distance - its effect
			// over subsequent ticks already scales via scaledDt through
			// applyGravity's own integration below.
			player.jump(JUMP_IMPULSE);
		}
		currentBiome.applyGravity(player, scaledDt);

		checkPaintingTrigger();

		Camera.applyTo(s3d.camera, player);

		if (hxd.Key.isPressed(Keybinds.TOGGLE_DEBUG_OVERLAY)) {
			debugOverlayVisible = !debugOverlayVisible;
			debugOverlay.visible = debugOverlayVisible;
		}
		if (debugOverlayVisible) {
			updateDebugOverlay();
		}

		// E/L now work uniformly for whichever biome is current (see
		// exportMaze/onMazeFileChosen's own docs) — no biome-specific gate.
		if (hxd.Key.isPressed(Keybinds.EXPORT_MAZE)) {
			exportMaze();
		}
		if (hxd.Key.isPressed(Keybinds.IMPORT_MAZE)) {
			promptImportMaze();
		}
	}

	/**
		Refreshes the F3 overlay's text — only called while it's visible, so
		the string-building cost disappears entirely once it's toggled off.
		Block 1: maze position (node, theta, phi) — the readout used to track
		down wall-mesh bug reports (meaningless while in the hub, since it
		isn't on the maze grid at all, but harmless there too). Block 2:
		camera angle (facing around the local "up" axis, relative to
		`thetaTangentAt`'s own zero, same convention `PlayerModel.spawnAt`'s
		`facing` parameter uses; pitch as stored). Block 3: whatever perf
		info this target can actually offer — `hxd.Timer.fps()` always; heap
		size only where the browser exposes the non-standard
		`performance.memory` (kept out of the layout entirely, not shown as
		"n/a", when it isn't available).
	**/
	function updateDebugOverlay():Void {
		var theta = SphereMath.thetaOf(player.pos);
		var phi = SphereMath.phiOf(player.pos);
		var node = GridModel.nodeAt(theta, phi);

		var thetaTangent = SphereMath.thetaTangentAt(theta, phi);
		var phiTangent = SphereMath.phiTangentAt(phi);
		var facing = Math.atan2(player.forward.dot(phiTangent), player.forward.dot(thetaTangent));

		var lines = [
			Std.string(node),
			'theta=' + hxd.Math.fmt(theta),
			'phi=' + hxd.Math.fmt(phi),
			'',
			'facing=' + hxd.Math.fmt(radToDeg(facing)) + ' deg',
			'pitch=' + hxd.Math.fmt(radToDeg(player.pitch)) + ' deg',
			'',
			'fps=' + hxd.Math.fmt(hxd.Timer.fps()),
		];

		// performance.memory is a non-standard, Chromium-only API — absent
		// (Firefox/Safari, or newer Chrome with the feature restricted)
		// this reads as null, and the line is simply omitted.
		var heapBytes:Null<Float> = js.Syntax.code("(typeof performance !== 'undefined' && performance.memory) ? performance.memory.usedJSHeapSize : null");
		if (heapBytes != null) {
			lines.push('heap=' + hxd.Math.fmt(heapBytes / 1024 / 1024) + ' MB');
		}

		debugOverlay.text = lines.join('\n');
	}

	static inline function radToDeg(radians:Float):Float {
		return radians * 180 / Math.PI;
	}
}
