import entities.Player;
import maze.MazeGeometry;

/**
	Entry point. Owns the fixed-timestep accumulator (CLAUDE.md "Architecture")
	so gameplay simulation never depends on render frame rate.
**/
class Main extends hxd.App {
	static inline final FIXED_DT:Float = 1.0 / 60;
	static inline final BACKGROUND_COLOR:Int = 0x202020;
	static inline final CAMERA_FOV_Y:Float = 70;

	var accumulator:Float = 0;
	var player:Player;

	static function main():Void {
		new Main();
	}

	override function init():Void {
		engine.backgroundColor = BACKGROUND_COLOR;
		s3d.camera.fovY = CAMERA_FOV_Y;

		// Debug-only: three great circles marking the maze sphere's shell,
		// so the camera's position/orientation is visible before the real
		// maze mesh (next up) replaces it.
		new h3d.scene.Sphere(0xFF3388FF, MazeGeometry.RADIUS, true, s3d);

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
		player.applyToCamera(s3d.camera, MazeGeometry.RADIUS);
	}
}
