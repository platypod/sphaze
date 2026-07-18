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
		runner.addCase(new GridModelTest());
		runner.addCase(new MazeGeneratorTest());
		runner.addCase(new PlayerModelTest());
		runner.addCase(new CameraTest());
		runner.addCase(new GridMeshTest());
		runner.addCase(new GridCollisionTest());
		runner.addCase(new PaintingModelTest());
		runner.addCase(new MazeExitWallTest());
		runner.addCase(new BiomesRegistryTest());
		runner.addCase(new ProcessTest());
		runner.addCase(new CreatureSpawnTableTest());
		runner.addCase(new NpcsRegistryTest());
		runner.addCase(new CreaturesRegistryTest());
		Report.create(runner);
		runner.run();
	}
}
