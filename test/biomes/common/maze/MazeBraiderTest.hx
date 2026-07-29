package biomes.common.maze;

import biomes.common.grid.GridTopology;
import biomes.common.maze.MazeTopology.MazeLayout;
import biomes.maze.MazeGeneratorTest.SeededRandom;
import utest.Assert;
import utest.Test;

/** Braiding's two promises: it removes dead ends, and it only ever *adds* passages. **/
class MazeBraiderTest extends Test {
	function testBraidingRemovesDeadEnds():Void {
		var layout = carveDfs(1);
		var before = MazeBraider.deadEndsOf(layout, GridTopology.INSTANCE).length;
		MazeBraider.braid(layout, GridTopology.INSTANCE, 1, new SeededRandom(2).next);
		var after = MazeBraider.deadEndsOf(layout, GridTopology.INSTANCE).length;

		Assert.isTrue(before > 0, "the unbraided maze should have dead ends to remove in the first place");
		Assert.isTrue(after < before, 'braiding at fraction 1 should leave fewer dead ends (got $after, was $before)');
	}

	function testBraidingOnlyOpensPassages():Void {
		var layout = carveDfs(3);
		var before = openEdgesOf(layout);
		MazeBraider.braid(layout, GridTopology.INSTANCE, 0.5, new SeededRandom(4).next);

		for (key in before) {
			Assert.isTrue(layout.openEdges.exists(key), 'braiding closed the passage "$key", which it must never do');
		}
		Assert.isTrue(openEdgesOf(layout).length > before.length, "braiding at fraction 0.5 should have opened something");
	}

	/** A perfect maze has exactly `nodes - 1` passages, so a braided one must have more — the property braiding deliberately breaks. **/
	function testBraidedMazeIsNoLongerPerfect():Void {
		var layout = MazeCarver.carve(GridTopology.INSTANCE, RandomizedDfs, 0.4, new SeededRandom(5).next);

		Assert.isTrue(openEdgesOf(layout).length > GridTopology.INSTANCE.nodeKeys().length - 1);
	}

	function testBraidingAtZeroChangesNothing():Void {
		var layout = carveDfs(6);
		var before = openEdgesOf(layout).length;
		MazeBraider.braid(layout, GridTopology.INSTANCE, 0, new SeededRandom(7).next);

		Assert.equals(before, openEdgesOf(layout).length);
	}

	static function carveDfs(seed:Int):MazeLayout {
		return MazeCarver.carve(GridTopology.INSTANCE, RandomizedDfs, 0, new SeededRandom(seed).next);
	}

	static function openEdgesOf(layout:MazeLayout):Array<String> {
		return [for (key in layout.openEdges.keys()) key];
	}
}
