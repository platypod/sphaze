import utest.Test;
import utest.Assert;
import biomes.common.grid.GridModel;
import biomes.common.grid.GridModel.GridNode;
import biomes.common.grid.GridModel.GridData;
import biomes.maze.MazeGenerator;

/**
	Mirrors old/src/maze/mazeGenerator.test.ts, for behavioral parity with the
	ported prototype. Doesn't need to match old/'s mulberry32 sequence bit for
	bit — any deterministic seeded source works for exercising the algorithm.
**/
class MazeGeneratorTest extends Test {
	function testGenerateProducesASpanningTree():Void {
		var maze = MazeGenerator.generate(new SeededRandom(1).next);
		var nodes = GridModel.allNodes();

		Assert.equals(nodes.length - 1, countOpenEdges(maze));
	}

	function testGenerateConnectsEveryNodeToEveryOther():Void {
		var maze = MazeGenerator.generate(new SeededRandom(42).next);
		var nodes = GridModel.allNodes();
		var start = nodes[0];
		if (start == null) {
			Assert.fail("allNodes() returned no nodes");
			return;
		}

		var visited = new haxe.ds.StringMap<Bool>();
		visited.set(GridModel.nodeKey(start), true);

		var stack:Array<GridNode> = [start];
		while (stack.length > 0) {
			var current = stack.pop();
			if (current == null) {
				continue;
			}
			for (neighbor in GridModel.neighborsOf(current)) {
				var key = GridModel.nodeKey(neighbor);
				if (GridModel.isOpen(maze, current, neighbor) && !visited.exists(key)) {
					visited.set(key, true);
					stack.push(neighbor);
				}
			}
		}

		Assert.equals(nodes.length, countKeys(visited));
	}

	function countOpenEdges(maze:GridData):Int {
		var count = 0;
		for (_ in maze.openEdges.keys()) {
			count++;
		}
		return count;
	}

	function countKeys(map:haxe.ds.StringMap<Bool>):Int {
		var count = 0;
		for (_ in map.keys()) {
			count++;
		}
		return count;
	}
}

/**
	xorshift32, seeded — deterministic so the spanning-tree checks above
	aren't at the mercy of Math.random flakiness. Test-only; no need for
	statistical rigor beyond "deterministic and well-mixed".
**/
class SeededRandom {
	var state:Int;

	public function new(seed:Int) {
		state = seed == 0 ? 1 : seed;
	}

	/** @return the next value in the sequence, in [0, 1). **/
	public function next():Float {
		state ^= state << 13;
		state ^= state >>> 17;
		state ^= state << 5;
		var unsigned:Float = state >>> 0;
		return unsigned / 4294967296.0;
	}
}
