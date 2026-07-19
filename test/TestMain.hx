import utest.Runner;
import utest.ui.Report;
import biomes.common.GravityTest;
import biomes.common.grid.GridCollisionTest;
import biomes.common.grid.GridMeshTest;
import biomes.common.grid.GridModelTest;
import biomes.common.space.flat.FlatSpaceTest;
import biomes.common.space.mobius.MobiusMathTest;
import biomes.common.space.mobius.MobiusSpaceTest;
import biomes.common.space.sphere.SphereMathTest;
import biomes.hub.HubStructureTest;
import biomes.hub.MazeShrineTest;
import biomes.hub.TowerReplicaTest;
import biomes.maze.MazeExitWallTest;
import biomes.maze.MazeGeneratorTest;
import biomes.tower.TowerCollisionTest;
import biomes.tower.TowerGeneratorTest;
import biomes.tower.TowerModelTest;
import entities.CreatureSpawnTableTest;
import entities.hourglass.HourglassModelTest;
import entities.hourglass.HourglassTest;
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
		runner.addCase(new HubStructureTest());
		runner.addCase(new MazeShrineTest());
		runner.addCase(new TowerReplicaTest());
		runner.addCase(new HourglassTest());
		runner.addCase(new HourglassModelTest());
		runner.addCase(new BiomesRegistryTest());
		runner.addCase(new ProcessTest());
		runner.addCase(new CreatureSpawnTableTest());
		runner.addCase(new NpcsRegistryTest());
		runner.addCase(new CreaturesRegistryTest());
		runner.addCase(new GravityTest());
		runner.addCase(new FlatSpaceTest());
		runner.addCase(new MobiusMathTest());
		runner.addCase(new MobiusSpaceTest());
		runner.addCase(new TowerModelTest());
		runner.addCase(new TowerGeneratorTest());
		runner.addCase(new TowerCollisionTest());
		Report.create(runner);
		runner.run();
	}
}
