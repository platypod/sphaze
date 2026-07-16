import utest.Test;
import utest.Assert;
import maze.MazeMesh;
import maze.Maze.MazeNode;

/**
	Covers exactly the property that broke: neighboring cells must compute
	identical points for their shared edge, or walls (each extruded from its
	own cell's corners) visibly seam apart on the sphere instead of
	connecting to their neighbors and to the floor.
**/
class MazeMeshTest extends Test {
	function testEastCornersMatchWestNeighborsCorners():Void {
		var row = 5;
		var col = 3;
		var here = MazeMesh.cornersOf(row, col);
		var east = MazeMesh.cornersOf(row, col + 1);

		assertSamePoint(here.ne, east.nw);
		assertSamePoint(here.se, east.sw);
	}

	function testColumnsWrapAroundSeamlessly():Void {
		var row = 5;
		var lastCol = maze.Maze.COLS - 1;
		var here = MazeMesh.cornersOf(row, lastCol);
		var wrapped = MazeMesh.cornersOf(row, 0);

		assertSamePoint(here.ne, wrapped.nw);
		assertSamePoint(here.se, wrapped.sw);
	}

	function testSouthCornersMatchNorthNeighborsCorners():Void {
		var row = 5;
		var col = 3;
		var here = MazeMesh.cornersOf(row, col);
		var south = MazeMesh.cornersOf(row + 1, col);

		assertSamePoint(here.sw, south.nw);
		assertSamePoint(here.se, south.ne);
	}

	function testInnerCornersAreInsetFromOuterCornersByWallThickness():Void {
		// innerCornersOf moves each corner toward the cell's own center by
		// WALL_THICKNESS along theta and phi independently — checked here as
		// actual linear (not angular) distance, since the phi axis needs a
		// sin(theta) correction for the sphere's curvature to stay a
		// consistent linear thickness at any latitude. Uses the *cell
		// center's* theta for that correction (matching innerCornersOf's own
		// approximation, documented on its class doc) rather than each
		// corner's own theta — the two differ slightly since a corner's own
		// theta is offset from center by half the cell's height, which is
		// exactly why this is an approximation and not exact at every corner.
		var row = 5;
		var col = 10;
		var radius = maze.MazeGeometry.RADIUS;
		var centerTheta = Math.PI * row / (maze.Maze.ROWS - 1);
		var outer = MazeMesh.cornersOf(row, col);
		var inner = MazeMesh.innerCornersOf(row, col);

		var thetaOuter = game.SphereMath.thetaOf(outer.nw);
		var thetaInner = game.SphereMath.thetaOf(inner.nw);
		Assert.floatEquals(maze.MazeGeometry.WALL_THICKNESS, (thetaInner - thetaOuter) * radius, 1e-6);

		var phiOuter = game.SphereMath.phiOf(outer.nw);
		var phiInner = game.SphereMath.phiOf(inner.nw);
		Assert.floatEquals(maze.MazeGeometry.WALL_THICKNESS, (phiInner - phiOuter) * radius * Math.sin(centerTheta), 1e-6);
	}

	// The specific property MazeMesh's split boundary pieces need at a
	// doubling boundary (see WallBuilder.addRowBoundaryPieces): each split
	// piece's own outer corners must land exactly on the corresponding
	// child cell's own corners, computed completely independently via
	// cornersOf on the child's row — otherwise the coarser row's wall
	// pieces don't actually line up with the floor/walls the finer row
	// itself builds, a visible seam right at the boundary.
	function testSplitBoundaryPiecesOuterCornersMatchEachChildsOwnCorners():Void {
		var boundaries = [
			{row: 1, otherRow: 2},
			{row: 3, otherRow: 4},
			{row: 10, otherRow: 9},
			{row: 12, otherRow: 11}
		];
		for (boundary in boundaries) {
			var myCols = maze.Maze.colsForRow(boundary.row);
			var otherCols = maze.Maze.colsForRow(boundary.otherRow);
			Assert.isTrue(otherCols > myCols, 'expected a doubling at row ${boundary.row} -> ${boundary.otherRow}');

			// Whichever row is further south (larger theta) has its own
			// north edge (nw/ne) on this boundary; the other has its south
			// edge (sw/se) on it instead.
			var childIsSouthOfParent = boundary.otherRow > boundary.row;
			var parentOuterTheta = Math.PI * boundary.row / (maze.Maze.ROWS - 1) + (childIsSouthOfParent ? 1 : -1) * Math.PI / (maze.Maze.ROWS - 1) / 2;

			for (col in 0...myCols) {
				for (entry in maze.Maze.rowBoundaryNeighbors(boundary.row, col, boundary.otherRow)) {
					var childCol = switch entry.node {
						case RingNode(_, c): c;
						case PoleNode(_): -1;
					}
					var childCorners = MazeMesh.cornersOf(boundary.otherRow, childCol);
					var childWest = childIsSouthOfParent ? childCorners.nw : childCorners.sw;
					var childEast = childIsSouthOfParent ? childCorners.ne : childCorners.se;

					var splitWest = MazeMesh.cornerAt(parentOuterTheta, entry.phiStart);
					var splitEast = MazeMesh.cornerAt(parentOuterTheta, entry.phiEnd);

					assertSamePoint(splitWest, childWest);
					assertSamePoint(splitEast, childEast);
				}
			}
		}
	}

	function assertSamePoint(a:h3d.Vector, b:h3d.Vector):Void {
		Assert.floatEquals(a.x, b.x, 1e-9);
		Assert.floatEquals(a.y, b.y, 1e-9);
		Assert.floatEquals(a.z, b.z, 1e-9);
	}
}
