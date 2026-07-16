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

	function testMoveAtAnAngleIntoAClosedEdgeSlidesAlongTheWallInstead():Void {
		var maze = Maze.generate(new SeededRandom(3).next);
		var pair = findPair(maze, false);
		if (pair == null) {
			Assert.fail("no closed edge found for this seed — pick another");
			return;
		}

		var fromCenter = Maze.centerOf(pair.from);
		var toCenter = Maze.centerOf(pair.to);
		var fromDir = SphereMath.sphericalToCartesian(1, fromCenter.theta, fromCenter.phi);
		var toDir = SphereMath.sphericalToCartesian(1, toCenter.theta, toCenter.phi);
		var axis = fromDir.cross(toDir).normalized();
		var fullAngle = Math.acos(hxd.Math.clamp(fromDir.dot(toDir), -1, 1));

		// The wall sits exactly halfway between the two centers (a regular
		// grid, both cells the same size) — placed just short of it, still
		// clearly within `pair.from`, rather than at the middle of the cell.
		var gap = 0.1;
		var pos0Dir = SphereMath.rotateAroundAxis(fromDir, axis, fullAngle / 2 - gap / RADIUS);
		var pos0 = pos0Dir.scaled(RADIUS);

		// intoWall: continuing straight on toward the neighbor from here.
		// wallTangent: perpendicular to that, in the tangent plane — exactly
		// what Collision.slideAlong itself derives from the blocked node.
		var intoWall = axis.cross(pos0Dir).normalized();
		var wallTangent = pos0Dir.cross(toDir).normalized();
		// Squarely between "straight at the wall" and "along the wall" —
		// enough of an angle that a real wall should redirect it, not stop it.
		var forward = intoWall.add(wallTangent).normalized();
		var distance = 0.5; // comfortably covers the small remaining gap even split diagonally

		var player = new Player(pos0, forward);
		var moved = Collision.tryMoveForward(player, distance, RADIUS, maze);

		Assert.isTrue(moved);
		Assert.isTrue(player.pos.sub(pos0).length() > 0.01); // actually slid, not just stopped
		Assert.floatEquals(RADIUS, player.pos.length(), 1e-6); // stayed on the sphere
		// Sliding redirects movement, not where the player is looking.
		Assert.floatEquals(forward.x, player.forward.x, 1e-9);
		Assert.floatEquals(forward.y, player.forward.y, 1e-9);
		Assert.floatEquals(forward.z, player.forward.z, 1e-9);

		var landedNode = Maze.nodeAt(SphereMath.thetaOf(player.pos), SphereMath.phiOf(player.pos));
		Assert.isTrue(Maze.nodeKey(landedNode) == Maze.nodeKey(pair.from) || Maze.isOpen(maze, pair.from, landedNode));
	}

	function assertMoveAcrossEdge(wantOpen:Bool):Void {
		var maze = Maze.generate(new SeededRandom(3).next);
		var pair = findPair(maze, wantOpen);
		if (pair == null) {
			Assert.fail('no ${wantOpen ? "open" : "closed"} edge found for this seed — pick another');
			return;
		}

		var fromCenter = Maze.centerOf(pair.from);
		var toCenter = Maze.centerOf(pair.to);
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
}
