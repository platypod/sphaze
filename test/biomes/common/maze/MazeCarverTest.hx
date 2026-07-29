package biomes.common.maze;

import biomes.common.grid.GridModel;
import biomes.common.grid.GridModel.GridNode;
import biomes.common.grid.GridTopology;
import biomes.common.maze.MazeTopology.EdgeAxis;
import biomes.common.maze.MazeTopology.GridCoords;
import biomes.common.maze.MazeTopology.MazeLayout;
import biomes.maze.MazeGeneratorTest.SeededRandom;
import utest.Assert;
import utest.Test;

/**
	Every style, checked against the one property they all promise: a perfect
	maze over the whole topology — every node reachable, and exactly
	`nodes - 1` open edges, which together mean "connected with no loops"
	without having to hunt for cycles directly.

	Runs against the real `GridTopology` rather than a toy grid on purpose:
	that grid's varying column count (`GridModel.colsForRow`) and merged poles
	are exactly the awkward cases a carver can get wrong, and
	`RecursiveDivision` in particular exists in its current shape *because* of
	them (see its own class doc).
**/
class MazeCarverTest extends Test {
	function testRandomizedDfsCarvesAPerfectMaze():Void {
		assertPerfect(carve(RandomizedDfs, 1));
	}

	function testRandomizedPrimCarvesAPerfectMaze():Void {
		assertPerfect(carve(RandomizedPrim, 2));
	}

	function testRandomizedKruskalCarvesAPerfectMaze():Void {
		assertPerfect(carve(RandomizedKruskal, 3));
	}

	function testAxisBiasedCarvesAPerfectMaze():Void {
		assertPerfect(carve(AxisBiased(4), 4));
	}

	function testRecursiveDivisionCarvesAPerfectMaze():Void {
		assertPerfect(carve(RecursiveDivision, 5));
	}

	/** The bias has to actually bias something, not just be accepted as a parameter. **/
	function testAxisBiasedFavorsTheAxisItIsPointedAt():Void {
		var eastWest = countEdgesOnAxis(carve(AxisBiased(12), 7), AlongRow);
		var northSouth = countEdgesOnAxis(carve(AxisBiased(1 / 12), 7), AlongRow);

		Assert.isTrue(eastWest > northSouth, 'expected a high alongRowWeight to open more east-west edges than a low one (got $eastWest vs $northSouth)');
	}

	function testAxisBiasedRejectsANonPositiveWeight():Void {
		Assert.raises(() -> carve(AxisBiased(0), 8), String);
	}

	/**
		The styles differ in dead-end density — that's most of what makes them
		feel different in play (see `MazeStyle`), so it's worth pinning that
		they aren't quietly producing the same maze shape.
	**/
	function testPrimLeavesMoreDeadEndsThanDfs():Void {
		var prim = MazeBraider.deadEndsOf(carve(RandomizedPrim, 9), GridTopology.INSTANCE).length;
		var dfs = MazeBraider.deadEndsOf(carve(RandomizedDfs, 9), GridTopology.INSTANCE).length;

		Assert.isTrue(prim > dfs, 'expected Prim to leave more dead ends than DFS (got $prim vs $dfs)');
	}

	function testRecursiveDivisionNeedsARectangularTopology():Void {
		Assert.raises(() -> MazeCarver.carve(new PathTopology(), RecursiveDivision, 0, new SeededRandom(10).next), String);
	}

	/** Every other style works on a plain, non-rectangular `MazeTopology`. **/
	function testStylesOtherThanRecursiveDivisionWorkOnAnyTopology():Void {
		var topology = new PathTopology();
		var layout = MazeCarver.carve(topology, RandomizedDfs, 0, new SeededRandom(11).next);

		Assert.equals(topology.nodeKeys().length - 1, countOpenEdges(layout));
	}

	/**
		The carvers' key format has to stay byte-identical to
		`GridModel.edgeKey`'s, or every maze JSON exported before this package
		existed stops deserializing into something the mesh can read.
	**/
	function testEdgeKeysMatchTheGridsOwnFormat():Void {
		var north = GridModel.nodeKey(PoleNode(North));
		var cell = GridModel.nodeKey(RingNode(1, 0));

		Assert.equals(GridModel.edgeKey(PoleNode(North), RingNode(1, 0)), MazeEdges.edgeKey(north, cell));
	}

	static function carve(style:MazeStyle, seed:Int):MazeLayout {
		return MazeCarver.carve(GridTopology.INSTANCE, style, 0, new SeededRandom(seed).next);
	}

	/** Asserts `layout` is connected across every node and has no loops. **/
	static function assertPerfect(layout:MazeLayout):Void {
		var topology = GridTopology.INSTANCE;
		var nodes = topology.nodeKeys();

		Assert.equals(nodes.length - 1, countOpenEdges(layout), "open-edge count should be exactly nodes - 1 (connected, no loops)");
		Assert.equals(nodes.length, countReachable(layout), "every node should be reachable");
	}

	static function countReachable(layout:MazeLayout):Int {
		var topology = GridTopology.INSTANCE;
		var start = topology.nodeKeys()[0];
		if (start == null) {
			return 0;
		}

		var visited = new haxe.ds.StringMap<Bool>();
		visited.set(start, true);
		var stack = [start];
		while (stack.length > 0) {
			var current = stack.pop();
			if (current == null) {
				continue;
			}
			for (neighbor in MazeEdges.openNeighborsOf(layout, topology, current)) {
				if (!visited.exists(neighbor)) {
					visited.set(neighbor, true);
					stack.push(neighbor);
				}
			}
		}
		return countKeys(visited);
	}

	static function countEdgesOnAxis(layout:MazeLayout, axis:EdgeAxis):Int {
		var count = 0;
		for (edge in MazeEdges.allEdges(GridTopology.INSTANCE)) {
			if (MazeEdges.isOpen(layout, edge.a, edge.b) && GridTopology.INSTANCE.axisOf(edge.a, edge.b) == axis) {
				count++;
			}
		}
		return count;
	}

	static function countOpenEdges(layout:MazeLayout):Int {
		return countKeys(layout.openEdges);
	}

	static function countKeys<T>(map:haxe.ds.StringMap<T>):Int {
		var count = 0;
		for (_ in map.keys()) {
			count++;
		}
		return count;
	}
}

/**
	A deliberately non-rectangular topology: a plain open chain of nodes, no
	rows, no columns, no wrap. Exists to check the two halves of the
	`RectangularTopology` contract — that `RecursiveDivision` refuses it
	loudly, and that every other style doesn't care.
**/
class PathTopology implements MazeTopology {
	static inline final LENGTH:Int = 8;

	public function new() {}

	public function nodeKeys():Array<String> {
		return [for (i in 0...LENGTH) 'node:$i'];
	}

	public function neighborsOf(nodeKey:String):Array<String> {
		var index = Std.parseInt(nodeKey.split(":")[1]);
		if (index == null) {
			return [];
		}
		var neighbors:Array<String> = [];
		if (index > 0) {
			neighbors.push('node:${index - 1}');
		}
		if (index < LENGTH - 1) {
			neighbors.push('node:${index + 1}');
		}
		return neighbors;
	}

	/** Nothing here has an axis — see `EdgeAxis.Irregular`'s own doc. **/
	public function axisOf(a:String, b:String):EdgeAxis {
		return Irregular;
	}
}
