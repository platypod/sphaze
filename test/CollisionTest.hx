import utest.Test;
import utest.Assert;
import entities.Player;
import game.Collision;
import game.SphereMath;
import maze.Maze;
import maze.Maze.MazeNode;
import maze.Maze.MazeData;
import maze.MazeGeometry;
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

	function testMoveIntoWallThicknessIsBlockedShortOfTheOldNodeBoundary():Void {
		// A hand-picked same-row pair rather than a generated maze's first
		// match, so the wall-zone boundary is a plain single-axis (phi)
		// computation to reconstruct independently.
		var row = 5;
		var col = 10;
		var here = RingNode(row, col);
		var maze:MazeData = {openEdges: new haxe.ds.StringMap()}; // nothing open -> the east edge is closed

		var centerTheta = Math.PI * row / (Maze.ROWS - 1);
		var centerPhi = 2 * Math.PI * col / Maze.COLS;
		var halfPhi = Math.PI / Maze.COLS;
		var insetPhi = Math.min(halfPhi, MazeGeometry.WALL_THICKNESS / (RADIUS * Math.sin(centerTheta)));

		// Just inside the wall-zone: past (halfPhi - insetPhi), short of
		// halfPhi. Maze.nodeAt still classifies this as `here` (confirmed
		// below) — the pre-thickness model would have allowed walking
		// further still, right up to halfPhi, since it had no concept of the
		// wall occupying part of the cell.
		var phi = centerPhi + (halfPhi - insetPhi / 2);
		var pos0 = SphereMath.sphericalToCartesian(RADIUS, centerTheta, phi);
		var forward = SphereMath.phiTangentAt(phi); // due east, straight at the wall

		Assert.isTrue(Maze.nodeKey(Maze.nodeAt(centerTheta, phi)) == Maze.nodeKey(here));

		var player = new Player(pos0, forward);
		var moved = Collision.tryMoveForward(player, 0.1, RADIUS, maze); // tiny step, nowhere near nodeAt's own boundary

		Assert.isFalse(moved);
	}

	function testTryMoveAlongAnArbitraryDirectionRespectsWallThickness():Void {
		// Exercises tryMove's general form directly — moving along a
		// direction that isn't player.forward at all, same shape as Main's
		// Q/D strafing via Player.rightVector(). Same wall-zone setup as
		// testMoveIntoWallThicknessIsBlockedShortOfTheOldNodeBoundary
		// (placed just inside the zone, a small step rather than a large
		// one — a large single step drifts off constant theta away from the
		// equator, the same great-circle curvature testMoveAtAnAngle...
		// relies on elsewhere), but forward deliberately points north-south
		// here to prove the block doesn't depend on it.
		var row = 5;
		var col = 10;
		var maze:MazeData = {openEdges: new haxe.ds.StringMap()}; // nothing open -> the east edge is closed

		var centerTheta = Math.PI * row / (Maze.ROWS - 1);
		var centerPhi = 2 * Math.PI * col / Maze.COLS;
		var halfPhi = Math.PI / Maze.COLS;
		var insetPhi = Math.min(halfPhi, MazeGeometry.WALL_THICKNESS / (RADIUS * Math.sin(centerTheta)));

		var phi = centerPhi + (halfPhi - insetPhi / 2);
		var pos0 = SphereMath.sphericalToCartesian(RADIUS, centerTheta, phi);
		var forward = SphereMath.thetaTangentAt(centerTheta, phi); // not the strafe direction
		var player = new Player(pos0, forward);
		var strafeDirection = SphereMath.phiTangentAt(phi); // due east, straight at the wall

		var moved = Collision.tryMove(player, strafeDirection, 0.1, RADIUS, maze);

		Assert.isFalse(moved);
	}

	function testSlidingAlongTheSameWallForManyTicksDoesNotStall():Void {
		// The exact reported bug: sliding at a shallow angle against a single
		// wall for long enough (many fixed-timestep ticks in a row, not just
		// one) used to grind to a permanent halt. Root cause was slideAlong
		// deriving the wall's tangent from the blocked node's fixed nominal
		// center — accurate only near that center, so it rotated away from
		// the true wall direction as the player's position kept advancing
		// along it, until the projected slide distance decayed to zero. Off
		// the equator specifically, since that drift doesn't happen along a
		// meridian (see wallTangentAlong's doc comment).
		// A hand-built maze with nothing open at all would make this a
		// sealed corner (its south side closed too) rather than a
		// free-standing wall — sliding into a genuine corner is *supposed*
		// to stop, so this needs a real generated maze and a cell whose
		// east edge is closed but whose own north/south (the direction the
		// slide travels) stay open for a few rows, same as searching for a
		// reproduction case directly in the running game.
		var maze = Maze.generate(new SeededRandom(3).next);
		var wall = findFreeStandingEastWall(maze);
		if (wall == null) {
			Assert.fail("no free-standing east wall found for this seed — pick another");
			return;
		}

		var centerTheta = Math.PI * wall.row / (Maze.ROWS - 1);
		var centerPhi = 2 * Math.PI * wall.col / Maze.COLS;
		var halfPhi = Math.PI / Maze.COLS;
		var insetPhi = Math.min(halfPhi, MazeGeometry.WALL_THICKNESS / (RADIUS * Math.sin(centerTheta)));

		// Starts short of the wall zone (unlike the other tests here, which
		// place pos0 right at its edge) — this needs room to slide toward
		// the wall and then travel *along* it for many ticks, not just poke
		// at the boundary once. Half the zone's own threshold rather than a
		// fixed fraction of the cell width — the threshold shrinks toward
		// the poles (see wallZoneNeighbor's insetPhi), so a fixed offset
		// safe at one row can already be inside the zone at another.
		var phi = centerPhi + (halfPhi - insetPhi) * 0.5;
		var pos0 = SphereMath.sphericalToCartesian(RADIUS, centerTheta, phi);
		// Mostly along the wall (theta-tangent), tilted slightly toward it
		// (phi-tangent) — a shallow-angle hit, the case that should slide
		// smoothly rather than stop dead.
		var thetaTangent = SphereMath.thetaTangentAt(centerTheta, phi);
		var phiTangent = SphereMath.phiTangentAt(phi);
		var angle = 15 * Math.PI / 180;
		var forward = thetaTangent.scaled(Math.cos(angle)).add(phiTangent.scaled(Math.sin(angle))).normalized();
		var player = new Player(pos0, forward);

		var stepDistance = 0.1;
		var ticks = 80;
		var totalMoved = 0.0;
		for (_ in 0...ticks) {
			var before = player.pos;
			Collision.tryMoveForward(player, stepDistance, RADIUS, maze);
			totalMoved += player.pos.sub(before).length();
		}

		// A permanent stall would leave the player barely past where a
		// handful of ticks alone would land it; sliding freely covers most
		// of the nominal distance across all of them.
		Assert.isTrue(totalMoved > stepDistance * ticks * 0.9);
	}

	/**
		First `RingNode` (in row-major order) whose east edge is closed while
		its own north/south and the next two rows south stay open — a
		free-standing wall with room to slide along, not a corner where
		another closed edge would legitimately stop the player short.
		@param maze the maze to search.
		@return the cell's row/col, or null if this seed has none.
	**/
	function findFreeStandingEastWall(maze:MazeData):Null<{row:Int, col:Int}> {
		for (row in 2...(Maze.ROWS - 4)) {
			for (col in 0...Maze.COLS) {
				var here = RingNode(row, col);
				var east = RingNode(row, (col + 1) % Maze.COLS);
				var north = RingNode(row - 1, col);
				var south = RingNode(row + 1, col);
				var south2 = RingNode(row + 2, col);
				var south3 = RingNode(row + 3, col);
				if (!Maze.isOpen(maze, here, east) && Maze.isOpen(maze, here, north) && Maze.isOpen(maze, here, south) && Maze.isOpen(maze, south, south2)
					&& Maze.isOpen(maze, south2, south3)) {
					return {row: row, col: col};
				}
			}
		}
		return null;
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
		// forward is parallel-transported along with pos during a slide (see
		// Player.moveAlong) rather than left untouched, so it stays a valid
		// tangent at the new position instead of drifting — not "unchanged".
		Assert.floatEquals(1, player.forward.length(), 1e-6);
		Assert.floatEquals(0, player.pos.normalized().dot(player.forward), 1e-6);

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
