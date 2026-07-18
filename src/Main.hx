import game.GameLoop;

/**
	Entry point. Owns only the bare `hxd.App` lifecycle and the fixed-timestep
	accumulator (CLAUDE.md "Architecture") so gameplay simulation never
	depends on render frame rate — everything about actually playing the
	game lives on `GameLoop` instead (see its own class doc).
**/
class Main extends hxd.App {
	static inline final FIXED_DT:Float = 1.0 / 60;

	var accumulator:Float = 0;
	var gameLoop:GameLoop;

	static function main():Void {
		new Main();
	}

	override function init():Void {
		hxd.Res.initEmbed();
		gameLoop = new GameLoop(s3d, s2d, engine);
	}

	override function update(dt:Float):Void {
		accumulator += dt;
		while (accumulator >= FIXED_DT) {
			gameLoop.fixedUpdate(FIXED_DT);
			accumulator -= FIXED_DT;
		}
	}
}
