import entities.Player;
import game.Collision;
import hub.Painting;
import maze.Maze;
import maze.Maze.MazeData;
import maze.MazeGeometry;
import maze.MazeMesh;

/** Which space the player is currently walking around in — a biome maze, or the diegetic hub (see docs/PROJECT_LOG.md's 2026-07-17 entry). **/
enum SceneKind {
	Biome;
	Hub;
}

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

	/**
		Fixed spawn spherical coordinates — chosen to sit well clear of
		row 5's own boundaries (its cell's center theta), not just
		"somewhere in the maze": the old `SPAWN_THETA` (1.3) landed only
		~2.53 units from the row 5/6 boundary, just barely outside the
		`MazeGeometry.WALL_THICKNESS + MazeGeometry.COLLISION_CLEARANCE`
		(2.5) zone `Maze.wallZoneNeighbor` otherwise guarantees a player can
		never get closer than — a margin of about 0.03 units, i.e. nothing.
		Whenever a generated maze happened to close that specific edge
		(about half the time, since it's an ordinary edge with no special
		bias), the player spawned with the camera almost flush against —
		sometimes clipped just past — that wall's actual face, reading as
		"missing texture, see through it" (reported directly, with
		screenshots, since normal movement never lets the collision-enforced
		clearance get this thin). This only ever bit spawning specifically:
		`Player.spawnAt` places the player directly, without going through
		`Collision`'s own clearance check the way every other move does.
		Centering on row 5 instead gives every direction a comfortable
		margin (smallest is ~5.95 units, still well over double what's
		required) rather than relying on which edges a maze happens to open.
		`Math.PI * 5 / (Maze.ROWS - 1)` — row 5's own center theta — spelled
		out as a literal since a `static inline final` can't initialize from
		another class's constant.
	**/
	static inline final SPAWN_THETA:Float = 1.2083048667653051;

	static inline final SPAWN_PHI:Float = 0.6;
	static inline final SPAWN_FACING:Float = 0.4;

	var accumulator:Float = 0;
	var player:Player;
	var maze:MazeData;
	var mazeGroup:h3d.scene.Object;
	var sceneKind:SceneKind = Biome;

	/** Whichever painting this scene has — the biome's to the hub, or the hub's to the biome — checked each tick against `player.pos`. **/
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
		enterBiome(Maze.generate());

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
		How far in front of the return-to-hub painting the player reappears
		when coming back out of the hub — must clear `Painting.TRIGGER_DISTANCE`
		(4), or they'd step right back into the painting's trigger radius and
		immediately bounce back into the hub. Well short of any cell's own
		half-width (the reduced grid's narrowest is ~8 units, per
		`docs/PROJECT_LOG.md`'s reduced-grid entry), so this never overshoots
		into the cell's far wall.
	**/
	static inline final RETURN_SPAWN_OFFSET:Float = 6;

	/**
		(Re)builds `data`'s floor/wall meshes under `mazeGroup` and places
		its return-to-hub painting (see `hub.BiomePainting`) — used at
		startup (a fresh random maze), when importing a previously exported
		one (see `exportMaze`/`onMazeFileChosen`), and when coming back out
		of the hub into the *same* biome the player just left.

		`resumeAtReturnWall` picks how the player spawns: at the fixed
		`SPAWN_THETA`/`SPAWN_PHI`/`SPAWN_FACING` (a fresh maze, or an
		imported one — there's no meaningful "where they left off" for
		either), or a few units in front of the return-to-hub painting,
		facing into the room, coming back out of the hub into the maze they
		were already in. `data` is `maze` itself in that second case — the
		hub visit never touches `maze`, so it's still exactly the biome the
		player left — not a fresh `Maze.generate()`, which is what silently
		sent them back to the maze's fixed start point instead of where
		they'd actually been standing.
		@param data the maze to enter.
		@param resumeAtReturnWall spawn in front of the return-to-hub painting instead of the fixed start point.
	**/
	function enterBiome(data:MazeData, resumeAtReturnWall:Bool = false):Void {
		sceneKind = Biome;
		maze = data;
		mazeGroup.removeChildren();
		MazeMesh.build(maze, mazeGroup);

		var wall = hub.BiomePainting.findReturnWall(maze);
		Painting.buildQuad(mazeGroup, wall.a, wall.b, wall.cellCenter, Painting.TO_HUB_COLOR);
		activePainting = new Painting(Painting.midpointOf(wall.a, wall.b), ToHub);

		if (resumeAtReturnWall) {
			player = playerInFrontOfWall(wall);
		} else {
			player = Player.spawnAt(SPAWN_THETA, SPAWN_PHI, SPAWN_FACING, MazeGeometry.RADIUS);
		}
		player.applyToCamera(s3d.camera, MazeGeometry.RADIUS);
	}

	/**
		A `Player` standing `RETURN_SPAWN_OFFSET` units in front of `wall`'s
		midpoint, facing into the room — where the player reappears coming
		back out of the hub. `wall.cellCenter.sub(mid)` isn't exactly tangent
		to the sphere at `mid` (two points on a curved surface never are,
		strictly), so `forward` gets re-projected onto the tangent plane at
		the final spawn position — the same approximation `Painting`'s own
		wall-mounting math already relies on, just also re-tangented here
		since `Player` depends on `forward` actually being one.
		@param wall the return-to-hub wall to spawn in front of.
		@return the spawned player.
	**/
	function playerInFrontOfWall(wall:hub.BiomePainting.FoundWall):Player {
		var mid = Painting.midpointOf(wall.a, wall.b);
		var intoRoom = wall.cellCenter.sub(mid).normalized();
		var pos = mid.add(intoRoom.scaled(RETURN_SPAWN_OFFSET)).normalized().scaled(MazeGeometry.RADIUS);

		var posDir = pos.normalized();
		var forward = intoRoom.sub(posDir.scaled(intoRoom.dot(posDir))).normalized();
		return new Player(pos, forward);
	}

	/**
		(Re)builds the hub's room + its one painting under `mazeGroup` and
		spawns the player at its equator — the diegetic menu space (see
		`hub.Hub`'s own class doc and `docs/PROJECT_LOG.md`'s 2026-07-17
		entry, and its later entry for the bigger sphere-plus-column
		redesign). Reached by walking into a biome's return-to-hub painting;
		see `checkPaintingTrigger`. Its own sphere is a different size than
		a biome's, so every call touching it uses `hub.Hub.RADIUS`, not
		`MazeGeometry.RADIUS`.
	**/
	function enterHub():Void {
		sceneKind = Hub;
		mazeGroup.removeChildren();
		hub.Hub.build(mazeGroup);
		activePainting = hub.Hub.toBiomePainting();

		player = Player.spawnAt(hub.Hub.SPAWN_THETA, hub.Hub.SPAWN_PHI, 0, hub.Hub.RADIUS);
		player.applyToCamera(s3d.camera, hub.Hub.RADIUS);
	}

	/**
		Attempts to move `player` by `distance` along `direction`, through
		whichever scene's own collision currently applies — `game.Collision`
		against the maze graph in a biome, `hub.HubCollision`'s simpler
		convex-hexagon check in the hub.
		@param direction unit tangent at `player.pos` to move along.
		@param distance arc length to move; negative moves the opposite way.
	**/
	function tryMove(direction:h3d.Vector, distance:Float):Void {
		switch sceneKind {
			case Biome:
				Collision.tryMove(player, direction, distance, MazeGeometry.RADIUS, maze);
			case Hub:
				hub.HubCollision.tryMove(player, direction, distance);
		}
	}

	/**
		Walking into `activePainting` warps to wherever it leads — no
		interact-key confirmation, on purpose (see `hub.Painting`'s own
		class doc). A biome's painting always leads to the hub; the hub's
		always leads back into the *same* biome the player left (the hub
		visit never touches `maze`), resuming in front of its own
		return-to-hub painting rather than the maze's fixed start point —
		this pass still doesn't track "discovered biomes" (see
		`docs/PROJECT_LOG.md`'s 2026-07-17 entry), so there's only ever the
		one biome to send it back to.
	**/
	function checkPaintingTrigger():Void {
		if (!activePainting.triggeredBy(player.pos)) {
			return;
		}

		switch activePainting.destination {
			case ToHub:
				enterHub();
			case ToBiome:
				enterBiome(maze, true);
		}
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
		reader.onload = (_) -> enterBiome(Maze.deserialize(reader.result));
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

		player.applyToCamera(s3d.camera, MazeGeometry.RADIUS);

		if (hxd.Key.isPressed(hxd.Key.F3)) {
			debugOverlayVisible = !debugOverlayVisible;
			debugOverlay.visible = debugOverlayVisible;
		}
		if (debugOverlayVisible) {
			updateDebugOverlay();
		}

		// Export/import only make sense against a biome maze — the hub
		// isn't a Maze/MazeData at all (see hub.Hub's own class doc).
		if (sceneKind == Biome) {
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
