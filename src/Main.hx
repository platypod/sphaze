import entities.Player;
import game.Collision;
import maze.Maze;
import maze.Maze.MazeData;
import maze.MazeGeometry;
import maze.MazeMesh;

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

	/** Fixed spawn spherical coordinates — valid in any maze, since only which edges are open varies, never the grid's own shape. **/
	static inline final SPAWN_THETA:Float = 1.3;

	static inline final SPAWN_PHI:Float = 0.6;
	static inline final SPAWN_FACING:Float = 0.4;

	var accumulator:Float = 0;
	var player:Player;
	var maze:MazeData;
	var mazeGroup:h3d.scene.Object;
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
		loadMaze(Maze.generate());

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
		(Re)builds the maze's floor/wall meshes under `mazeGroup` and
		respawns the player, for `data` — used both at startup (a fresh
		random maze) and when importing a previously exported one (see
		`exportMaze`/`onMazeFileChosen`). Always respawns at the same fixed
		spherical coordinates: the grid's own shape never changes between
		mazes, only which edges are open, so that spawn point is valid
		regardless of which maze this is.
		@param data the maze to load.
	**/
	function loadMaze(data:MazeData):Void {
		maze = data;
		mazeGroup.removeChildren();
		MazeMesh.build(maze, mazeGroup);
		player = Player.spawnAt(SPAWN_THETA, SPAWN_PHI, SPAWN_FACING, MazeGeometry.RADIUS);
		player.applyToCamera(s3d.camera, MazeGeometry.RADIUS);
	}

	/**
		Downloads the current maze as a JSON file (E) — pairs with L
		(`promptImportMaze`) to make a maze a specific bug showed up in
		something that can actually be saved and handed back, instead of
		lost the moment the page reloads (see `Maze.serialize`'s own doc).
	**/
	function exportMaze():Void {
		var json = Maze.serialize(maze);
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

	/** `mazeFileInput`'s change handler: reads the chosen file and loads it as a maze. **/
	function onMazeFileChosen(e:js.html.Event):Void {
		var file = mazeFileInput.files[0];
		if (file == null) {
			return;
		}

		var reader = new js.html.FileReader();
		reader.onload = (_) -> loadMaze(Maze.deserialize(reader.result));
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
			Collision.tryMoveForward(player, speed * dt, MazeGeometry.RADIUS, maze);
		}
		if (hxd.Key.isDown(hxd.Key.DOWN) || hxd.Key.isDown(hxd.Key.S)) {
			Collision.tryMoveForward(player, -speed * dt, MazeGeometry.RADIUS, maze);
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
			Collision.tryMove(player, player.rightVector(), speed * dt, MazeGeometry.RADIUS, maze);
		}
		if (hxd.Key.isDown(hxd.Key.D)) {
			Collision.tryMove(player, player.rightVector(), -speed * dt, MazeGeometry.RADIUS, maze);
		}

		updateSpaceTilt(dt);

		player.applyToCamera(s3d.camera, MazeGeometry.RADIUS);

		if (hxd.Key.isPressed(hxd.Key.F3)) {
			debugOverlayVisible = !debugOverlayVisible;
			debugOverlay.visible = debugOverlayVisible;
		}
		if (debugOverlayVisible) {
			updateDebugOverlay();
		}

		if (hxd.Key.isPressed(hxd.Key.E)) {
			exportMaze();
		}
		if (hxd.Key.isPressed(hxd.Key.L)) {
			promptImportMaze();
		}
	}

	/**
		Refreshes the F3 overlay's text — only called while it's visible, so
		the string-building cost disappears entirely once it's toggled off.
		Block 1: maze position (node, theta, phi) — the readout used to track
		down wall-mesh bug reports. Block 2: camera angle (facing around the
		local "up" axis, relative to `thetaTangentAt`'s own zero, same
		convention `Player.spawnAt`'s `facing` parameter uses; pitch as
		stored). Block 3: whatever perf info this target can actually offer
		— `hxd.Timer.fps()` always; heap size only where the browser exposes
		the non-standard `performance.memory` (kept out of the layout
		entirely, not shown as "n/a", when it isn't available).
	**/
	function updateDebugOverlay():Void {
		var theta = game.SphereMath.thetaOf(player.pos);
		var phi = game.SphereMath.phiOf(player.pos);
		var node = Maze.nodeAt(theta, phi);

		var thetaTangent = game.SphereMath.thetaTangentAt(theta, phi);
		var phiTangent = game.SphereMath.phiTangentAt(phi);
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
