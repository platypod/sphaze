package biomes.conway;

import biomes.conway.ConwayMaze.ConwayMazeData;
import biomes.conway.ConwayMaze.ConwayNode;
import biomes.maze.MazeGeneratorTest.SeededRandom;
import utest.Assert;
import utest.Test;

class ConwayMazeTest extends Test {
	function testGenerateCapturesTheCarvedEdgesAsCore():Void {
		var maze = ConwayMaze.generateWith(RandomizedDfs, 0, new SeededRandom(1).next);

		for (key in maze.openEdges.keys()) {
			Assert.isTrue(maze.coreEdges.exists(key), 'expected every freshly carved open edge to be core: $key');
		}
		Assert.equals(countKeys(maze.openEdges), countKeys(maze.coreEdges));
	}

	function testSerializeRoundTripsCoreAndOpenEdgesSeparately():Void {
		var maze = ConwayMaze.generateWith(RandomizedDfs, 0, new SeededRandom(2).next);
		// Simulate ConwayMazeReactivity having opened a shortcut on top of the core.
		var extraEdge = firstNonCoreEdge(maze);
		maze.openEdges.set(ConwayMaze.edgeKey(extraEdge.a, extraEdge.b), true);

		var restored = ConwayMaze.deserialize(ConwayMaze.serialize(maze));

		Assert.equals(countKeys(maze.openEdges), countKeys(restored.openEdges));
		Assert.equals(countKeys(maze.coreEdges), countKeys(restored.coreEdges));
		Assert.isTrue(ConwayMaze.isOpen(restored, extraEdge.a, extraEdge.b));
		Assert.isFalse(ConwayMaze.isCore(restored, extraEdge.a, extraEdge.b));
	}

	/**
		Saves from before `coreEdges` existed had a maze that was static in
		its entirety — the correct reading of that is "every open edge was
		core", not "nothing is protected".
	**/
	function testDeserializeWithoutCoreEdgesTreatsEveryOpenEdgeAsCore():Void {
		var maze = ConwayMaze.generateWith(RandomizedDfs, 0, new SeededRandom(3).next);
		var legacyJson = haxe.Json.stringify({openEdges: [for (key in maze.openEdges.keys()) key]});

		var restored = ConwayMaze.deserialize(legacyJson);

		Assert.equals(countKeys(restored.openEdges), countKeys(restored.coreEdges));
	}

	function testAllEdgesEnumeratesEachEdgeOnce():Void {
		var edges = ConwayMaze.allEdges();
		var seen = new haxe.ds.StringMap<Bool>();
		for (edge in edges) {
			var key = ConwayMaze.edgeKey(edge.a, edge.b);
			Assert.isFalse(seen.exists(key), 'edge $key appeared twice');
			seen.set(key, true);
		}
		Assert.isTrue(edges.length > 0);
	}

	static function firstNonCoreEdge(maze:ConwayMazeData):{a:ConwayNode, b:ConwayNode} {
		for (edge in ConwayMaze.allEdges()) {
			if (!ConwayMaze.isCore(maze, edge.a, edge.b)) {
				return edge;
			}
		}
		throw "expected at least one non-core edge in a perfect maze over more than one node";
	}

	static function countKeys<T>(map:haxe.ds.StringMap<T>):Int {
		var count = 0;
		for (_ in map.keys()) {
			count++;
		}
		return count;
	}
}
