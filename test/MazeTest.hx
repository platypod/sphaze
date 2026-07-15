import utest.Test;
import utest.Assert;
import maze.Maze;
import maze.Maze.MazeNode;
import maze.Maze.MazeData;

/**
	Mirrors old/src/maze/mazeGenerator.test.ts, for behavioral parity with the
	ported prototype. Doesn't need to match old/'s mulberry32 sequence bit for
	bit — any deterministic seeded source works for exercising the algorithm.
**/
class MazeTest extends Test {
	function testGenerateProducesASpanningTree():Void {
		var maze = Maze.generate(new SeededRandom(1).next);
		var nodes = Maze.allNodes();

		Assert.equals(nodes.length - 1, countOpenEdges(maze));
	}

	function testGenerateConnectsEveryNodeToEveryOther():Void {
		var maze = Maze.generate(new SeededRandom(42).next);
		var nodes = Maze.allNodes();
		var start = nodes[0];
		if (start == null) {
			Assert.fail("allNodes() returned no nodes");
			return;
		}

		var visited = new haxe.ds.StringMap<Bool>();
		visited.set(Maze.nodeKey(start), true);

		var stack:Array<MazeNode> = [start];
		while (stack.length > 0) {
			var current = stack.pop();
			if (current == null) {
				continue;
			}
			for (neighbor in Maze.neighborsOf(current)) {
				var key = Maze.nodeKey(neighbor);
				if (Maze.isOpen(maze, current, neighbor) && !visited.exists(key)) {
					visited.set(key, true);
					stack.push(neighbor);
				}
			}
		}

		Assert.equals(nodes.length, countKeys(visited));
	}

	function testColumnsWrapAround():Void {
		var ringNeighbors = Maze.neighborsOf(RingNode(3, 0));
		var expected = RingNode(3, Maze.COLS - 1);

		// Array.contains/indexOf use `==`, which is reference equality for
		// enum constructors with arguments — Type.enumEq does the intended
		// structural comparison.
		Assert.isTrue(Lambda.exists(ringNeighbors, node -> Type.enumEq(node, expected)));
	}

	function countOpenEdges(maze:MazeData):Int {
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
