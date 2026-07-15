import entities.Player;
import maze.Maze;
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

	var accumulator:Float = 0;
	var player:Player;

	static function main():Void {
		new Main();
	}

	override function init():Void {
		engine.backgroundColor = BACKGROUND_COLOR;
		s3d.camera.fovY = CAMERA_FOV_Y;

		MazeMesh.build(Maze.generate(), s3d);

		player = new Player(1.3, 0.6, 0.4);
		player.applyToCamera(s3d.camera, MazeGeometry.RADIUS);
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
		if (hxd.Key.isDown(hxd.Key.LEFT) || hxd.Key.isDown(hxd.Key.A)) {
			player.turn(-TURN_SPEED * dt);
		}
		if (hxd.Key.isDown(hxd.Key.RIGHT) || hxd.Key.isDown(hxd.Key.D)) {
			player.turn(TURN_SPEED * dt);
		}
		if (hxd.Key.isDown(hxd.Key.UP) || hxd.Key.isDown(hxd.Key.W)) {
			player.moveForward(WALK_SPEED * dt, MazeGeometry.RADIUS);
		}
		if (hxd.Key.isDown(hxd.Key.DOWN) || hxd.Key.isDown(hxd.Key.S)) {
			player.moveForward(-WALK_SPEED * dt, MazeGeometry.RADIUS);
		}

		player.applyToCamera(s3d.camera, MazeGeometry.RADIUS);
	}
}
