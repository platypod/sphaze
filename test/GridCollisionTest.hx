import utest.Test;
import utest.Assert;
import biomes.common.grid.GridCollision;
import biomes.common.grid.GridGeometry;
import biomes.common.grid.GridModel;
import biomes.common.grid.GridModel.GridData;
import biomes.common.grid.GridModel.GridNode;
import biomes.common.grid.GridModel.RowBoundaryNeighbor;
import biomes.common.space.sphere.SphereMath;
import biomes.maze.MazeGenerator;
import entities.Player;
import MazeGeneratorTest.SeededRandom;

/**
	Exercises GridCollision.tryMoveForward against a real generated maze (see
	MazeGeneratorTest's SeededRandom) rather than a hand-built edge map — that
	way these tests go through the same `GridModel.nodeAt`/`isOpen` machinery the
	game itself does, instead of duplicating its edge-key format.
**/
class GridCollisionTest extends Test {
	static inline final RADIUS:Float = 50;

	function testMoveWithinTheSameNodeIsAlwaysAllowed():Void {
		var maze:GridData = {openEdges: new haxe.ds.StringMap()}; // nothing open anywhere
		// A cell *center* rather than theta=pi/2: ROWS-1 is odd, so no row
		// center actually sits on the equator — pi/2 is exactly the boundary
		// between row 7 and row 8, which made this flaky (a tiny step could
		// round to either side).
		var theta = Math.PI * 5 / (GridModel.ROWS - 1);
		var phi = 2 * Math.PI * 10.5 / GridModel.COLS; // column phi is boundary-anchored — the center is at col+0.5
		var player = Player.spawnAt(theta, phi, 0, RADIUS);

		var moved = GridCollision.tryMoveForward(player, 0.01, RADIUS, maze); // far short of a cell boundary

		Assert.isTrue(moved);
	}

	function testMoveIntoWallThicknessIsBlockedShortOfTheOldNodeBoundary():Void {
		// A hand-picked same-row pair rather than a generated maze's first
		// match, so the wall-zone boundary is a plain single-axis (phi)
		// computation to reconstruct independently.
		var row = 5;
		var col = 10;
		var here = RingNode(row, col);
		var maze:GridData = {openEdges: new haxe.ds.StringMap()}; // nothing open -> the east edge is closed

		var centerTheta = Math.PI * row / (GridModel.ROWS - 1);
		var centerPhi = 2 * Math.PI * (col + 0.5) / GridModel.COLS; // column phi is boundary-anchored
		var halfPhi = Math.PI / GridModel.COLS;
		var insetPhi = Math.min(halfPhi, GridGeometry.WALL_THICKNESS / (RADIUS * Math.sin(centerTheta)));

		// Just inside the wall-zone: past (halfPhi - insetPhi), short of
		// halfPhi. GridModel.nodeAt still classifies this as `here` (confirmed
		// below) — the pre-thickness model would have allowed walking
		// further still, right up to halfPhi, since it had no concept of the
		// wall occupying part of the cell.
		var phi = centerPhi + (halfPhi - insetPhi / 2);
		var pos0 = SphereMath.sphericalToCartesian(RADIUS, centerTheta, phi);
		var forward = SphereMath.phiTangentAt(phi); // due east, straight at the wall

		Assert.isTrue(GridModel.nodeKey(GridModel.nodeAt(centerTheta, phi)) == GridModel.nodeKey(here));

		var player = new Player(pos0, forward);
		var moved = GridCollision.tryMoveForward(player, 0.1, RADIUS, maze); // tiny step, nowhere near nodeAt's own boundary

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
		var maze:GridData = {openEdges: new haxe.ds.StringMap()}; // nothing open -> the east edge is closed

		var centerTheta = Math.PI * row / (GridModel.ROWS - 1);
		var centerPhi = 2 * Math.PI * (col + 0.5) / GridModel.COLS; // column phi is boundary-anchored
		var halfPhi = Math.PI / GridModel.COLS;
		var insetPhi = Math.min(halfPhi, GridGeometry.WALL_THICKNESS / (RADIUS * Math.sin(centerTheta)));

		var phi = centerPhi + (halfPhi - insetPhi / 2);
		var pos0 = SphereMath.sphericalToCartesian(RADIUS, centerTheta, phi);
		var forward = SphereMath.thetaTangentAt(centerTheta, phi); // not the strafe direction
		var player = new Player(pos0, forward);
		var strafeDirection = SphereMath.phiTangentAt(phi); // due east, straight at the wall

		var moved = GridCollision.tryMove(player, strafeDirection, 0.1, RADIUS, maze);

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
		// Seed 3 (used by the other tests in this file) has no match once
		// findFreeStandingEastWall is restricted to rows 4-6 (see its own
		// doc for why) — seed 1 does.
		var maze = MazeGenerator.generate(new SeededRandom(1).next);
		var wall = findFreeStandingEastWall(maze);
		if (wall == null) {
			Assert.fail("no free-standing east wall found for this seed — pick another");
			return;
		}

		var wallCols = GridModel.colsForRow(wall.row);
		var centerTheta = Math.PI * wall.row / (GridModel.ROWS - 1);
		var centerPhi = 2 * Math.PI * (wall.col + 0.5) / wallCols; // column phi is boundary-anchored
		var halfPhi = Math.PI / wallCols;
		// Matches GridModel.wallZoneNeighbor's own blocking distance exactly —
		// COLLISION_CLEARANCE on top of WALL_THICKNESS, not the rendered
		// wall's thickness alone — so this offset is actually outside the
		// zone the real code blocks at, not just outside the render.
		var insetPhi = Math.min(halfPhi, (GridGeometry.WALL_THICKNESS + GridGeometry.COLLISION_CLEARANCE) / (RADIUS * Math.sin(centerTheta)));

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
			GridCollision.tryMoveForward(player, stepDistance, RADIUS, maze);
			totalMoved += player.pos.sub(before).length();
		}

		// A permanent stall would leave the player barely past where a
		// handful of ticks alone would land it; sliding freely covers most
		// of the nominal distance across all of them.
		Assert.isTrue(totalMoved > stepDistance * ticks * 0.9);
	}

	function testSlidingAlongANorthSouthWallAtADoublingBoundaryRowDoesNotStall():Void {
		// Same shape as testSlidingAlongTheSameWallForManyTicksDoesNotStall,
		// but sliding along a *north/south* wall (a theta-boundary, using
		// wallTangentAlong's different-row branch) specifically at row 1 —
		// row 1 -> row 2 is a doubling boundary, so this is what actually
		// exercises using the matching rowBoundaryNeighbors entry's own
		// (half-width) phi range for the chord instead of row 1's full
		// width, which is the fix this task made.
		//
		// Starts centered within a single *sub-entry* (one of the two
		// children a doubling boundary splits the parent cell's south wall
		// into), not the parent cell's own center — at a doubling boundary
		// those aren't the same point. The parent's center sits exactly on
		// the seam between the two children's sub-segments, which is the
		// worst possible spot for the chord-tangent approximation (see
		// wallTangentAlong's doc): the true wall there is two flat quads
		// meeting at a seam, each on its own slightly different great
		// circle, and starting exactly at that seam immediately drifts
		// toward whichever child's corner is nearest, tripping the wall
		// zone on the very first slide step (confirmed by tracing it: an
		// instant, not gradual, stall, unlike the reported bug this whole
		// mechanism fixes). A cell's own natural center is *never* a sub-
		// entry seam away from a doubling boundary, so this is the correct
		// stand-in for how a normal, uniform-width slide gets positioned.
		var row = 1;
		var maze = MazeGenerator.generate(new SeededRandom(1).next);
		var wall = findFreeStandingSouthWall(maze, row);
		if (wall == null) {
			Assert.fail('no free-standing south wall found in row $row for this seed — pick another');
			return;
		}

		var centerTheta = Math.PI * row / (GridModel.ROWS - 1);
		var centerPhi = (wall.entry.phiStart + wall.entry.phiEnd) / 2;
		var halfTheta = Math.PI / (GridModel.ROWS - 1) / 2;
		var insetTheta = Math.min(halfTheta, (GridGeometry.WALL_THICKNESS + GridGeometry.COLLISION_CLEARANCE) / RADIUS);

		var theta = centerTheta + (halfTheta - insetTheta) * 0.5;
		var pos0 = SphereMath.sphericalToCartesian(RADIUS, theta, centerPhi);
		var thetaTangent = SphereMath.thetaTangentAt(theta, centerPhi);
		var phiTangent = SphereMath.phiTangentAt(centerPhi);
		var angle = 15 * Math.PI / 180;
		var forward = phiTangent.scaled(Math.cos(angle)).add(thetaTangent.scaled(Math.sin(angle))).normalized();
		var player = new Player(pos0, forward);

		// Fewer ticks/smaller step than the same-row analog: this sub-entry
		// is half the width of a full boundary segment, so there's less
		// room before running past its own far edge into the sibling
		// sub-entry's territory — this test's job is the half-width chord
		// itself, not the (separate, harder) sub-entry-to-sub-entry seam
		// crossing.
		var stepDistance = 0.05;
		var ticks = 40;
		var totalMoved = 0.0;
		for (_ in 0...ticks) {
			var before = player.pos;
			GridCollision.tryMoveForward(player, stepDistance, RADIUS, maze);
			totalMoved += player.pos.sub(before).length();
		}

		Assert.isTrue(totalMoved > stepDistance * ticks * 0.9);
	}

	/**
		First parent column (in order) of `row` whose full south boundary is
		closed (every `GridModel.rowBoundaryNeighbors` entry toward `row + 1`)
		while its own west/east stay open for a couple of columns — a free-
		standing north/south wall with room to slide along.
		@param maze the maze to search.
		@param row the row to search within.
		@return the cell's column and its first south-boundary sub-entry, or null if this seed has none.
	**/
	function findFreeStandingSouthWall(maze:GridData, row:Int):Null<{col:Int, entry:RowBoundaryNeighbor}> {
		var cols = GridModel.colsForRow(row);
		for (col in 0...cols) {
			var here = RingNode(row, col);
			var west = RingNode(row, (col - 1 + cols) % cols);
			var east = RingNode(row, (col + 1) % cols);
			var east2 = RingNode(row, (col + 2) % cols);
			var entries = GridModel.rowBoundaryNeighbors(row, col, row + 1);
			var allClosed = true;
			for (entry in entries) {
				if (GridModel.isOpen(maze, here, entry.node)) {
					allClosed = false;
					break;
				}
			}
			if (allClosed && GridModel.isOpen(maze, here, west) && GridModel.isOpen(maze, here, east) && GridModel.isOpen(maze, east, east2)) {
				return {col: col, entry: entries[0]};
			}
		}
		return null;
	}

	function testRetreatingFromASquareOnWallHitAlwaysMakesProgress():Void {
		// The exact reported bug: walking straight (square-on, not at an
		// angle) into a wall until pressed right up against its face, then
		// trying to back away, left the player permanently frozen — not
		// just slowed, completely stuck, every direction, forever. Root
		// cause was GridModel.wallZoneNeighbor treating "candidate position is
		// still nominally within the wall's thickness zone" as blocked,
		// full stop — with no notion of whether the candidate was deeper
		// into the zone than where the step started. The zone is thicker
		// than one tick's step distance, so a player already pressed
		// against the wall can't fully retreat out of it in a single tick;
		// every subsequent tick saw "still inside the zone", rolled all the
		// way back to the exact starting position, and a square hit has
		// nothing to slide with either (see slideAlong) — so nothing ever
		// happened, ever again.
		//
		// Checks that retreating actually gets back near the starting
		// point, rather than asserting a fixed minimum on every single
		// tick: row 5 isn't exactly on the equator (no row center is,
		// ROWS-1 being odd — see GridMeshTest's own note on this), so "due
		// east" isn't quite a geodesic there, and `forward` drifts a little
		// off being exactly wall-perpendicular over the approach — a real
		// but harmless side effect of the sphere's curvature (unrelated to
		// this bug), which throttles a handful of ticks on both legs
		// symmetrically rather than at a fixed per-tick rate.
		var row = 5;
		var col = 10;
		var maze:GridData = {openEdges: new haxe.ds.StringMap()}; // nothing open -> the east edge is closed

		var centerTheta = Math.PI * row / (GridModel.ROWS - 1);
		var centerPhi = 2 * Math.PI * (col + 0.5) / GridModel.COLS; // column phi is boundary-anchored
		var pos0 = SphereMath.sphericalToCartesian(RADIUS, centerTheta, centerPhi);
		var forward = SphereMath.phiTangentAt(centerPhi); // due east, straight at the wall, square-on
		var player = new Player(pos0, forward);

		var step = 15.0 / 60; // Main.WALK_SPEED * FIXED_DT, the real per-tick distance
		for (_ in 0...20) {
			GridCollision.tryMoveForward(player, step, RADIUS, maze); // walk into the wall until pressed against it
		}
		var pressedPhi = SphereMath.phiOf(player.pos);

		for (_ in 0...20) {
			GridCollision.tryMoveForward(player, -step, RADIUS, maze); // retreat
		}

		// A permanent lockup would leave phi exactly where it was pressed
		// against the wall; real retreat moves it substantially back west,
		// toward (or past) centerPhi — checked as a signed westward change
		// rather than distance from the start, since retreating far enough
		// to overshoot past centerPhi would otherwise read as "no closer".
		// No angle-wrapping needed: both offsets stay well within a
		// fraction of a radian here, nowhere near wrapping past +-pi.
		var finalPhi = SphereMath.phiOf(player.pos);
		var pressedOffset = pressedPhi - centerPhi;
		var finalOffset = finalPhi - centerPhi;
		Assert.isTrue(finalOffset < pressedOffset * 0.1);
	}

	function testRetreatingFromASquareOnWallHitWorksAtEveryReducedColumnRow():Void {
		// The same square-on-retreat check as the test above, repeated at
		// each row whose column count differs from the equatorial band
		// (rows 1, 3, 10, 12 — see GridModel.colsForRow) — this is what actually
		// exercises wallZoneNeighbor's colsForRow-based halfPhi/west/east,
		// rather than the flat GridModel.COLS it used before.
		for (row in [1, 3, 10, 12]) {
			var col = 0;
			var cols = GridModel.colsForRow(row);
			var maze:GridData = {openEdges: new haxe.ds.StringMap()}; // nothing open -> the east edge is closed

			var centerTheta = Math.PI * row / (GridModel.ROWS - 1);
			var centerPhi = 2 * Math.PI * (col + 0.5) / cols;
			var pos0 = SphereMath.sphericalToCartesian(RADIUS, centerTheta, centerPhi);
			var forward = SphereMath.phiTangentAt(centerPhi); // due east, straight at the wall, square-on
			var player = new Player(pos0, forward);

			var step = 15.0 / 60;
			for (_ in 0...20) {
				GridCollision.tryMoveForward(player, step, RADIUS, maze);
			}
			var pressedPhi = SphereMath.phiOf(player.pos);

			for (_ in 0...20) {
				GridCollision.tryMoveForward(player, -step, RADIUS, maze);
			}

			var finalPhi = SphereMath.phiOf(player.pos);
			var pressedOffset = pressedPhi - centerPhi;
			var finalOffset = finalPhi - centerPhi;
			Assert.isTrue(finalOffset < pressedOffset * 0.1, 'row $row');
		}
	}

	function testWallZonePicksTheCorrectSubNeighborAtADoublingBoundary():Void {
		// The specific case rowBoundaryNeighbors/neighborAcrossRowBoundaryAt
		// exist for: at a doubling boundary (row 1's south side, splitting
		// into two of row 2's cells), one sub-neighbor closed and the other
		// open must be treated independently — approaching square-on into
		// the closed one's own phi range blocks, approaching into the open
		// one's doesn't, even though both are "row 1 col 0's south side".
		var maze:GridData = {openEdges: new haxe.ds.StringMap()};
		var row = 1;
		var col = 0;
		var otherRow = 2;
		var entries = GridModel.rowBoundaryNeighbors(row, col, otherRow);
		Assert.equals(2, entries.length); // row 1 -> row 2 is a doubling boundary

		var closedChild = entries[0];
		var openChild = entries[1];
		if (closedChild == null || openChild == null) {
			Assert.fail("rowBoundaryNeighbors returned fewer than 2 entries");
			return;
		}
		maze.openEdges.set(nodeKeyPairForTest(RingNode(row, col), openChild.node), true);

		var centerTheta = Math.PI * row / (GridModel.ROWS - 1);
		var step = 15.0 / 60;

		// Toward the closed child's own phi range: should press against it
		// and then retreat fully, same as any other square-on wall hit.
		var closedPhi = (closedChild.phiStart + closedChild.phiEnd) / 2;
		var pos0 = SphereMath.sphericalToCartesian(RADIUS, centerTheta, closedPhi);
		var player = new Player(pos0, SphereMath.thetaTangentAt(centerTheta, closedPhi));
		for (_ in 0...20) {
			GridCollision.tryMoveForward(player, step, RADIUS, maze);
		}
		Assert.isTrue(SphereMath.thetaOf(player.pos) < centerTheta + Math.PI / (GridModel.ROWS - 1) / 2, "blocked short of the row boundary");

		// Toward the open child's own phi range: nothing should stop it at
		// all — it should cross cleanly into row 2.
		var openPhi = (openChild.phiStart + openChild.phiEnd) / 2;
		var pos1 = SphereMath.sphericalToCartesian(RADIUS, centerTheta, openPhi);
		var player2 = new Player(pos1, SphereMath.thetaTangentAt(centerTheta, openPhi));
		for (_ in 0...40) {
			GridCollision.tryMoveForward(player2, step, RADIUS, maze);
		}
		var landedRow = switch GridModel.nodeAt(SphereMath.thetaOf(player2.pos), SphereMath.phiOf(player2.pos)) {
			case RingNode(r, _): r;
			case PoleNode(_): -1;
		}
		Assert.equals(otherRow, landedRow);
	}

	/** Test-only stand-in for GridModel's private edgeKey — same sort-then-join format. **/
	function nodeKeyPairForTest(a:GridNode, b:GridNode):String {
		var keyA = GridModel.nodeKey(a);
		var keyB = GridModel.nodeKey(b);
		return keyA < keyB ? '$keyA|$keyB' : '$keyB|$keyA';
	}

	/**
		First `RingNode` (in row-major order) whose east edge is closed while
		its own north/south and the next two rows south stay open — a
		free-standing wall with room to slide along, not a corner where
		another closed edge would legitimately stop the player short.

		Restricted to rows 4-6 (not the full 2-9 range this used before
		column count varied by row): north/south/south2/south3 all reusing
		the *same* column index only means the same node when every row
		involved shares the same column count — true for any 4 consecutive
		rows fully inside the equatorial band (4-9), false the moment a
		doubling/halving boundary is crossed. Finding a boundary-adjacent
		free-standing wall specifically is a different, dedicated test
		elsewhere, not this one.
		@param maze the maze to search.
		@return the cell's row/col, or null if this seed has none.
	**/
	function findFreeStandingEastWall(maze:GridData):Null<{row:Int, col:Int}> {
		for (row in 4...7) {
			var cols = GridModel.colsForRow(row);
			for (col in 0...cols) {
				var here = RingNode(row, col);
				var east = RingNode(row, (col + 1) % cols);
				var north = RingNode(row - 1, col);
				var south = RingNode(row + 1, col);
				var south2 = RingNode(row + 2, col);
				var south3 = RingNode(row + 3, col);
				if (!GridModel.isOpen(maze, here, east)
					&& GridModel.isOpen(maze, here, north)
					&& GridModel.isOpen(maze, here, south)
					&& GridModel.isOpen(maze, south, south2)
					&& GridModel.isOpen(maze, south2, south3)) {
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
		var maze = MazeGenerator.generate(new SeededRandom(3).next);
		var pair = findPair(maze, false);
		if (pair == null) {
			Assert.fail("no closed edge found for this seed — pick another");
			return;
		}

		var fromCenter = GridModel.centerOf(pair.from);
		var toCenter = GridModel.centerOf(pair.to);
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
		// what GridCollision.slideAlong itself derives from the blocked node.
		var intoWall = axis.cross(pos0Dir).normalized();
		var wallTangent = pos0Dir.cross(toDir).normalized();
		// Squarely between "straight at the wall" and "along the wall" —
		// enough of an angle that a real wall should redirect it, not stop it.
		var forward = intoWall.add(wallTangent).normalized();
		var distance = 0.5; // comfortably covers the small remaining gap even split diagonally

		var player = new Player(pos0, forward);
		var moved = GridCollision.tryMoveForward(player, distance, RADIUS, maze);

		Assert.isTrue(moved);
		Assert.isTrue(player.pos.sub(pos0).length() > 0.01); // actually slid, not just stopped
		Assert.floatEquals(RADIUS, player.pos.length(), 1e-6); // stayed on the sphere
		// forward is parallel-transported along with pos during a slide (see
		// Player.moveAlong) rather than left untouched, so it stays a valid
		// tangent at the new position instead of drifting — not "unchanged".
		Assert.floatEquals(1, player.forward.length(), 1e-6);
		Assert.floatEquals(0, player.pos.normalized().dot(player.forward), 1e-6);

		var landedNode = GridModel.nodeAt(SphereMath.thetaOf(player.pos), SphereMath.phiOf(player.pos));
		Assert.isTrue(GridModel.nodeKey(landedNode) == GridModel.nodeKey(pair.from) || GridModel.isOpen(maze, pair.from, landedNode));
	}

	function assertMoveAcrossEdge(wantOpen:Bool):Void {
		var maze = MazeGenerator.generate(new SeededRandom(3).next);
		var pair = findPair(maze, wantOpen);
		if (pair == null) {
			Assert.fail('no ${wantOpen ? "open" : "closed"} edge found for this seed — pick another');
			return;
		}

		var fromCenter = GridModel.centerOf(pair.from);
		var toCenter = GridModel.centerOf(pair.to);
		var pos0 = SphereMath.sphericalToCartesian(RADIUS, fromCenter.theta, fromCenter.phi);
		var posTarget = SphereMath.sphericalToCartesian(RADIUS, toCenter.theta, toCenter.phi);

		// The exact great-circle direction/distance from pos0 to posTarget —
		// see GridCollision's class doc: a step landing exactly on the
		// neighboring cell's center is the clearest case to assert against.
		var axis = pos0.cross(posTarget).normalized();
		var forward = axis.cross(pos0.normalized()).normalized();
		var distance = Math.acos(hxd.Math.clamp(pos0.normalized().dot(posTarget.normalized()), -1, 1)) * RADIUS;

		var player = new Player(pos0, forward);
		var moved = GridCollision.tryMoveForward(player, distance, RADIUS, maze);

		Assert.equals(wantOpen, moved);
		var expected = wantOpen ? posTarget : pos0;
		Assert.floatEquals(expected.x, player.pos.x, 1e-6);
		Assert.floatEquals(expected.y, player.pos.y, 1e-6);
		Assert.floatEquals(expected.z, player.pos.z, 1e-6);
	}

	/** First node pair (in `GridModel.allNodes()`/`neighborsOf` order) whose edge's open-ness matches `wantOpen`. **/
	function findPair(maze:GridData, wantOpen:Bool):Null<{from:GridNode, to:GridNode}> {
		for (node in GridModel.allNodes()) {
			for (neighbor in GridModel.neighborsOf(node)) {
				if (GridModel.isOpen(maze, node, neighbor) == wantOpen) {
					return {from: node, to: neighbor};
				}
			}
		}
		return null;
	}
}
