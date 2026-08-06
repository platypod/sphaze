package biomes.conway;

import biomes.conway.ConwayMaze.ConwayMazeData;
import biomes.conway.ConwayMaze.ConwayNode;
import utest.Assert;
import utest.Test;

/**
	Exercises `ConwayMazeReactivity.step` against hand-built maze/state
	fixtures rather than a generated maze plus simulated generations — what's
	under test is the edge-toggling rule itself, not the carve or the Life
	simulation that feeds it.
**/
class ConwayMazeReactivityTest extends Test {
	static inline final ROW:Int = 5;
	static inline final COL:Int = 10;

	function testCoreEdgeNeverClosesEvenAtZeroActivity():Void {
		var here = RingNode(ROW, COL);
		var there = RingNode(ROW, COL + 1);
		var maze = mazeWith([here, there], [here, there]); // open, and core

		ConwayMazeReactivity.step(maze, stateWithActivity([]), RingNode(0, 0));

		Assert.isTrue(ConwayMaze.isOpen(maze, here, there));
	}

	function testNonCoreEdgeOpensWhenEitherEndpointIsActive():Void {
		var here = RingNode(ROW, COL);
		var there = RingNode(ROW, COL + 1);
		var maze = mazeWith([], []); // nothing open, nothing core

		ConwayMazeReactivity.step(maze, stateWithActivity([{node: here, value: 0.9}]), RingNode(0, 0));

		Assert.isTrue(ConwayMaze.isOpen(maze, here, there));
	}

	function testNonCoreEdgeClosesBackOnceBothEndpointsGoQuiet():Void {
		var here = RingNode(ROW, COL);
		var there = RingNode(ROW, COL + 1);
		var maze = mazeWith([here, there], []); // open, not core

		ConwayMazeReactivity.step(maze, stateWithActivity([]), RingNode(0, 0));

		Assert.isFalse(ConwayMaze.isOpen(maze, here, there));
	}

	/** The gap between the two thresholds is the hysteresis band — without it an edge could flip open/closed every single generation. **/
	function testNonCoreEdgeStaysOpenWhileActivityIsBetweenTheTwoThresholds():Void {
		var here = RingNode(ROW, COL);
		var there = RingNode(ROW, COL + 1);
		var maze = mazeWith([here, there], []); // open, not core

		ConwayMazeReactivity.step(maze, stateWithActivity([{node: here, value: 0.3}]), RingNode(0, 0));

		Assert.isTrue(ConwayMaze.isOpen(maze, here, there), "activity above the close threshold should not close the edge yet");
	}

	function testNonCoreEdgeNeverClosesOnTheCellThePlayerOccupies():Void {
		var here = RingNode(ROW, COL);
		var there = RingNode(ROW, COL + 1);
		var maze = mazeWith([here, there], []); // open, not core, would otherwise close

		ConwayMazeReactivity.step(maze, stateWithActivity([]), here);

		Assert.isTrue(ConwayMaze.isOpen(maze, here, there));
	}

	static function mazeWith(open:Array<ConwayNode>, core:Array<ConwayNode>):ConwayMazeData {
		var openEdges = new haxe.ds.StringMap<Bool>();
		if (open.length == 2) {
			openEdges.set(ConwayMaze.edgeKey(open[0], open[1]), true);
		}
		var coreEdges = new haxe.ds.StringMap<Bool>();
		if (core.length == 2) {
			coreEdges.set(ConwayMaze.edgeKey(core[0], core[1]), true);
		}
		return {openEdges: openEdges, coreEdges: coreEdges};
	}

	static function stateWithActivity(entries:Array<{node:ConwayNode, value:Float}>):ConwayState {
		var activity = [for (entry in entries) {k: nodeKeyForActivity(entry.node), v: entry.value}];
		return ConwayState.deserialize(haxe.Json.stringify({live: [], activity: activity}));
	}

	static function nodeKeyForActivity(node:ConwayNode):String {
		return switch node {
			case PoleNode(pole): ConwayGrid.keyOfPole(pole);
			case RingNode(row, col): ConwayGrid.keyOf(row, col);
		}
	}
}
