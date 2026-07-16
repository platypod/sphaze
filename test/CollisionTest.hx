import utest.Test;
import utest.Assert;
import entities.Player;
import game.Collision;
import game.SphereMath;
import maze.Maze;
import maze.Maze.MazeNode;
import maze.Maze.MazeData;
import MazeTest.SeededRandom;

/**
	Exercises Collision.tryMoveForward against a real generated maze (see
	MazeTest's SeededRandom) rather than a hand-built edge map — that way
	these tests go through the same `Maze.nodeAt`/`isOpen` machinery the game
	itself does, instead of duplicating its edge-key format.
**/
class CollisionTest extends Test {
	static inline final RADIUS:Float = 50;

	function testMoveWithinTheSameNodeIsAlwaysAllowed():Void {
		var maze:MazeData = {openEdges: new haxe.ds.StringMap()}; // nothing open anywhere
		// A cell *center* rather than theta=pi/2: ROWS-1 is odd, so no row
		// center actually sits on the equator — pi/2 is exactly the boundary
		// between row 7 and row 8, which made this flaky (a tiny step could
		// round to either side).
		var theta = Math.PI * 5 / (Maze.ROWS - 1);
		var phi = 2 * Math.PI * 10 / Maze.COLS;
		var player = Player.spawnAt(theta, phi, 0, RADIUS);

		var moved = Collision.tryMoveForward(player, 0.01, RADIUS, maze); // far short of a cell boundary

		Assert.isTrue(moved);
	}

	function testMoveAcrossAnOpenEdgeSucceedsAndLandsOnTheNeighbor():Void {
		assertMoveAcrossEdge(true);
	}

	function testMoveAcrossAClosedEdgeIsBlockedAndLeavesPositionUnchanged():Void {
		assertMoveAcrossEdge(false);
	}

	function assertMoveAcrossEdge(wantOpen:Bool):Void {
		var maze = Maze.generate(new SeededRandom(3).next);
		var pair = findPair(maze, wantOpen);
		if (pair == null) {
			Assert.fail('no ${wantOpen ? "open" : "closed"} edge found for this seed — pick another');
			return;
		}

		var fromCenter = centerOf(pair.from);
		var toCenter = centerOf(pair.to);
		var pos0 = SphereMath.sphericalToCartesian(RADIUS, fromCenter.theta, fromCenter.phi);
		var posTarget = SphereMath.sphericalToCartesian(RADIUS, toCenter.theta, toCenter.phi);

		// The exact great-circle direction/distance from pos0 to posTarget —
		// see Collision's class doc: a step landing exactly on the
		// neighboring cell's center is the clearest case to assert against.
		var axis = pos0.cross(posTarget).normalized();
		var forward = axis.cross(pos0.normalized()).normalized();
		var distance = Math.acos(hxd.Math.clamp(pos0.normalized().dot(posTarget.normalized()), -1, 1)) * RADIUS;

		var player = new Player(pos0, forward);
		var moved = Collision.tryMoveForward(player, distance, RADIUS, maze);

		Assert.equals(wantOpen, moved);
		var expected = wantOpen ? posTarget : pos0;
		Assert.floatEquals(expected.x, player.pos.x, 1e-6);
		Assert.floatEquals(expected.y, player.pos.y, 1e-6);
		Assert.floatEquals(expected.z, player.pos.z, 1e-6);
	}

	/** First node pair (in `Maze.allNodes()`/`neighborsOf` order) whose edge's open-ness matches `wantOpen`. **/
	function findPair(maze:MazeData, wantOpen:Bool):Null<{from:MazeNode, to:MazeNode}> {
		for (node in Maze.allNodes()) {
			for (neighbor in Maze.neighborsOf(node)) {
				if (Maze.isOpen(maze, node, neighbor) == wantOpen) {
					return {from: node, to: neighbor};
				}
			}
		}
		return null;
	}

	/** A node's center in spherical coordinates — mirrors MazeMesh.cornersOf's own theta/phi formula. **/
	function centerOf(node:MazeNode):{theta:Float, phi:Float} {
		return switch node {
			case PoleNode(North): {theta: 0.0, phi: 0.0};
			case PoleNode(South): {theta: Math.PI, phi: 0.0};
			case RingNode(row, col): {theta: Math.PI * row / (Maze.ROWS - 1), phi: 2 * Math.PI * col / Maze.COLS};
		}
	}
}
