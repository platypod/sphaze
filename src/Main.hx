import biomes.common.grid.GridModel;
import biomes.common.space.sphere.SphereMath;
import biomes.hub.HubBiome;
import biomes.maze.MazeBiome;
import biomes.maze.MazeGenerator;
import entities.Player;
import game.Biome;
import world.BiomeRegistry;
import world.Painting;

/**
	Entry point. Owns the fixed-timestep accumulator (CLAUDE.md "Architecture")
	so gameplay simulation never depends on render frame rate.
**/
class Main extends hxd.App {
	static inline final FIXED_DT:Float = 1.0 / 60;
	static inline final BACKGROUND_COLOR:Int = 0x202020;
	static inline final CAMERA_FOV_Y:Float = 70;
	static inline final WALK_SPEED:Float = 15;
	static inline final SPRINT_MULTIPLIER:Float = 1.8;
	static inline final TURN_SPEED:Float = 2.5;
	static inline final PITCH_SPEED:Float = 1.5;
	static inline final MOUSE_SENSITIVITY:Float = 0.0025;

	/**
		How long holding SPACE tilts the camera up before it's released back
		to level — but only if the player is also moving (see
		`updateSpaceTilt`); held while standing still, it isn't forced back,
		so a stationary player can linger on the far side view as long as
		they like.
	**/
	static inline final SPACE_TILT_RELEASE_AFTER:Float = 1;

	var accumulator:Float = 0;
	var player:Player;

	/** Every biome that exists, plus which ones the player has discovered so far — see `game.Biome`'s own class doc for why the hub is one of these too, not a special case. **/
	var biomeRegistry:BiomeRegistry;

	/** Whichever biome the player is currently in. **/
	var currentBiome:Biome;

	var mazeGroup:h3d.scene.Object;

	/** The current biome's own exit painting — checked each tick against `player.pos`. **/
	var activePainting:Painting;

	var spaceHoldTime:Float = 0;
	var spaceTiltReleased:Bool = false;
	var debugOverlay:h2d.Text;
	var debugOverlayVisible:Bool = false;
	var mazeFileInput:js.html.InputElement;

	static function main():Void {
		new Main();
	}

	override function init():Void {
		hxd.Res.initEmbed();
		engine.backgroundColor = BACKGROUND_COLOR;
		s3d.camera.fovY = CAMERA_FOV_Y;

		mazeGroup = new h3d.scene.Object(s3d);
		biomeRegistry = new BiomeRegistry();
		biomeRegistry.register(new HubBiome(), true); // always known - it's home, not something to stumble into
		biomeRegistry.register(new MazeBiome(MazeGenerator.generate()));
		enterBiome(MazeBiome.ID, false);

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
		biomeRegistry.markDiscovered(id);

		currentBiome = biome;
		mazeGroup.removeChildren();
		biome.build(mazeGroup);
		activePainting = biome.exitPainting();

		player = biome.spawnPlayer(returning);
		player.applyToCamera(s3d.camera, biome.radius());
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
		Walking into `activePainting` warps to wherever it leads — no
		interact-key confirmation, on purpose (see `world.Painting`'s own class
		doc). Uniform for every biome, hub included: there's no "which kind
		of destination is this" branch, just "enter whichever biome id this
		painting names."
	**/
	function checkPaintingTrigger():Void {
		if (!activePainting.triggeredBy(player.pos)) {
			return;
		}

		enterBiome(activePainting.destinationBiomeId, true);
	}

	/**
		Downloads the current maze biome's data as a JSON file (E) — pairs
		with L (`promptImportMaze`) to make a maze a specific bug showed up
		in something that can actually be saved and handed back, instead of
		lost the moment the page reloads (see `MazeGenerator.serialize`'s own doc).
		No-ops outside a `MazeBiome` (e.g. while in the hub) — there's
		nothing to export there.
	**/
	function exportMaze():Void {
		var mazeBiome = Std.downcast(currentBiome, MazeBiome);
		if (mazeBiome == null) {
			return;
		}

		var json = MazeGenerator.serialize(mazeBiome.data());
		var blob = new js.html.Blob([json], {type: "application/json"});
		var url:String = js.Syntax.code("URL.createObjectURL({0})", blob);
		var anchor:js.html.AnchorElement = cast js.Browser.document.createElement("a");
		anchor.href = url;
		anchor.download = "sphaze-maze.json";
		anchor.click();
		js.Syntax.code("URL.revokeObjectURL({0})", url);
	}

	/** Opens the browser's file picker (L) for `onMazeFileChosen` to load from. **/
	function promptImportMaze():Void {
		mazeFileInput.value = "";
		mazeFileInput.click();
	}

	/**
		`mazeFileInput`'s change handler: reads the chosen file and loads it
		into the maze biome, re-entering it fresh (not `returning`, same as a
		newly generated maze — there's no meaningful "where they left off"
		for an imported maze either). No-ops outside a `MazeBiome`, same as
		`exportMaze`.
	**/
	function onMazeFileChosen(e:js.html.Event):Void {
		var file = mazeFileInput.files[0];
		if (file == null) {
			return;
		}

		var reader = new js.html.FileReader();
		reader.onload = (_) -> {
			var mazeBiome = Std.downcast(currentBiome, MazeBiome);
			if (mazeBiome == null) {
				return;
			}
			mazeBiome.reload(MazeGenerator.deserialize(reader.result));
			enterBiome(MazeBiome.ID, false);
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

	override function update(dt:Float):Void {
		accumulator += dt;
		while (accumulator >= FIXED_DT) {
			fixedUpdate(FIXED_DT);
			accumulator -= FIXED_DT;
		}
	}

	function fixedUpdate(dt:Float):Void {
		// Reading keys and calling Player methods directly here is a
		// placeholder — fine for one input source and one entity, but a
		// dedicated input/controller system is the right home for this once
		// there's more than a single player to drive.
		if (hxd.Key.isDown(hxd.Key.LEFT)) {
			player.turn(-TURN_SPEED * dt);
		}
		if (hxd.Key.isDown(hxd.Key.RIGHT)) {
			player.turn(TURN_SPEED * dt);
		}
		var speed = hxd.Key.isDown(hxd.Key.SHIFT) ? WALK_SPEED * SPRINT_MULTIPLIER : WALK_SPEED;
		if (hxd.Key.isDown(hxd.Key.UP) || hxd.Key.isDown(hxd.Key.Z)) {
			tryMove(player.forward, speed * dt);
		}
		if (hxd.Key.isDown(hxd.Key.DOWN) || hxd.Key.isDown(hxd.Key.S)) {
			tryMove(player.forward, -speed * dt);
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
		if (hxd.Key.isDown(hxd.Key.Q)) {
			tryMove(player.rightVector(), speed * dt);
		}
		if (hxd.Key.isDown(hxd.Key.D)) {
			tryMove(player.rightVector(), -speed * dt);
		}

		checkPaintingTrigger();
		updateSpaceTilt(dt);

		player.applyToCamera(s3d.camera, currentBiome.radius());

		if (hxd.Key.isPressed(hxd.Key.F3)) {
			debugOverlayVisible = !debugOverlayVisible;
			debugOverlay.visible = debugOverlayVisible;
		}
		if (debugOverlayVisible) {
			updateDebugOverlay();
		}

		// Export/import only make sense against a maze biome — no-ops
		// elsewhere (see exportMaze/onMazeFileChosen's own docs).
		if (Std.downcast(currentBiome, MazeBiome) != null) {
			if (hxd.Key.isPressed(hxd.Key.E)) {
				exportMaze();
			}
			if (hxd.Key.isPressed(hxd.Key.L)) {
				promptImportMaze();
			}
		}
	}

	/**
		Refreshes the F3 overlay's text — only called while it's visible, so
		the string-building cost disappears entirely once it's toggled off.
		Block 1: maze position (node, theta, phi) — the readout used to track
		down wall-mesh bug reports (meaningless while in the hub, since it
		isn't on the maze grid at all, but harmless there too). Block 2:
		camera angle (facing around the local "up" axis, relative to
		`thetaTangentAt`'s own zero, same convention `Player.spawnAt`'s
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

	function isMoveKeyDown():Bool {
		return hxd.Key.isDown(hxd.Key.UP) || hxd.Key.isDown(hxd.Key.Z) || hxd.Key.isDown(hxd.Key.DOWN) || hxd.Key.isDown(hxd.Key.S)
			|| hxd.Key.isDown(hxd.Key.Q) || hxd.Key.isDown(hxd.Key.D);
	}

	/**
		Raise your view toward the sphere's center — the "see the far side"
		mechanic. Holding SPACE tilts up continuously, same as the old
		PGUP; the twist is the auto-release once held a full second while
		still moving, snapping back to level so walking blind doesn't
		linger — checked once, at the moment the hold crosses that mark,
		not re-armed until SPACE is released and pressed again.
	**/
	function updateSpaceTilt(dt:Float):Void {
		if (!hxd.Key.isDown(hxd.Key.SPACE)) {
			spaceHoldTime = 0;
			spaceTiltReleased = false;
			return;
		}

		spaceHoldTime += dt;
		if (spaceTiltReleased) {
			return;
		}

		player.lookUp(PITCH_SPEED * dt);
		if (spaceHoldTime >= SPACE_TILT_RELEASE_AFTER && isMoveKeyDown()) {
			player.pitch = 0;
			spaceTiltReleased = true;
		}
	}
}
