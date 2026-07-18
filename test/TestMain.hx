import utest.Runner;
import utest.ui.Report;
import biomes.common.GravityTest;
import biomes.common.grid.GridCollisionTest;
import biomes.common.grid.GridMeshTest;
import biomes.common.grid.GridModelTest;
import biomes.common.space.sphere.SphereMathTest;
import biomes.hub.HubModelTest;
import biomes.maze.MazeExitWallTest;
import biomes.maze.MazeGeneratorTest;
import entities.CreatureSpawnTableTest;
import entities.painting.PaintingModelTest;
import entities.player.CameraTest;
import entities.player.PlayerModelTest;
import entities.registries.BiomesRegistryTest;
import entities.registries.CreaturesRegistryTest;
import entities.registries.NpcsRegistryTest;
import game.ProcessTest;

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
		runner.addCase(new HubModelTest());
		runner.addCase(new BiomesRegistryTest());
		runner.addCase(new ProcessTest());
		runner.addCase(new CreatureSpawnTableTest());
		runner.addCase(new NpcsRegistryTest());
		runner.addCase(new CreaturesRegistryTest());
		runner.addCase(new GravityTest());
		Report.create(runner);
		runner.run();
	}
}
