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
	var maze:MazeData;
	var spaceHoldTime:Float = 0;
	var spaceTiltReleased:Bool = false;

	static function main():Void {
		new Main();
	}

	override function init():Void {
		hxd.Res.initEmbed();
		engine.backgroundColor = BACKGROUND_COLOR;
		s3d.camera.fovY = CAMERA_FOV_Y;

		maze = Maze.generate();
		MazeMesh.build(maze, s3d);

		player = Player.spawnAt(1.3, 0.6, 0.4, MazeGeometry.RADIUS);
		player.applyToCamera(s3d.camera, MazeGeometry.RADIUS);

		// Relative mode hides the cursor and reports movement deltas instead
		// of a position — the standard FPS mouse-look. Per hxd.Window's own
		// doc, this only engages on the player's first click on the canvas
		// (a browser requirement for pointer lock); nothing else to wire up.
		hxd.Window.getInstance().mouseMode = Relative(onMouseMove, true);
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
		if (hxd.Key.isDown(hxd.Key.UP) || hxd.Key.isDown(hxd.Key.Z)) {
			Collision.tryMoveForward(player, WALK_SPEED * dt, MazeGeometry.RADIUS, maze);
		}
		if (hxd.Key.isDown(hxd.Key.DOWN) || hxd.Key.isDown(hxd.Key.S)) {
			Collision.tryMoveForward(player, -WALK_SPEED * dt, MazeGeometry.RADIUS, maze);
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
			Collision.tryMove(player, player.rightVector(), WALK_SPEED * dt, MazeGeometry.RADIUS, maze);
		}
		if (hxd.Key.isDown(hxd.Key.D)) {
			Collision.tryMove(player, player.rightVector(), -WALK_SPEED * dt, MazeGeometry.RADIUS, maze);
		}

		updateSpaceTilt(dt);

		player.applyToCamera(s3d.camera, MazeGeometry.RADIUS);
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
