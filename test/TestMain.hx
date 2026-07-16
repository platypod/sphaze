import utest.Runner;
import utest.ui.Report;

/**
	utest entry point — runs every test case registered below.
	Add new `Test` subclasses to the runner here as they're written.
**/
class TestMain {
	static function main():Void {
		var runner = new Runner();
		runner.addCase(new SphereMathTest());
		runner.addCase(new MazeTest());
		runner.addCase(new PlayerTest());
		runner.addCase(new MazeMeshTest());
		runner.addCase(new CollisionTest());
		Report.create(runner);
		runner.run();
	}
}
