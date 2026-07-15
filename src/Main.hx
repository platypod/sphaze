/**
	Entry point. Owns the fixed-timestep accumulator (CLAUDE.md "Architecture")
	so gameplay simulation never depends on render frame rate. No gameplay
	lives here yet — `fixedUpdate` is a placeholder for the Process tree.
**/
class Main extends hxd.App {
	static inline final FIXED_DT:Float = 1.0 / 60;
	static inline final BACKGROUND_COLOR:Int = 0x202020;

	var accumulator:Float = 0;

	static function main():Void {
		new Main();
	}

	override function init():Void {
		engine.backgroundColor = BACKGROUND_COLOR;
	}

	override function update(dt:Float):Void {
		accumulator += dt;
		while (accumulator >= FIXED_DT) {
			fixedUpdate(FIXED_DT);
			accumulator -= FIXED_DT;
		}
	}

	function fixedUpdate(dt:Float):Void {}
}
