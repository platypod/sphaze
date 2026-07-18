import utest.Test;
import utest.Assert;
import grid.GridMesh;
import grid.Grid.GridNode;

/**
	Covers exactly the property that broke: neighboring cells must compute
	identical points for their shared edge, or walls (each extruded from its
	own cell's corners) visibly seam apart on the sphere instead of
	connecting to their neighbors and to the floor.
**/
class GridMeshTest extends Test {
	function testEastCornersMatchWestNeighborsCorners():Void {
		var row = 5;
		var col = 3;
		var here = GridMesh.cornersOf(row, col);
		var east = GridMesh.cornersOf(row, col + 1);

		assertSamePoint(here.ne, east.nw);
		assertSamePoint(here.se, east.sw);
	}

	function testColumnsWrapAroundSeamlessly():Void {
		var row = 5;
		var lastCol = grid.Grid.COLS - 1;
		var here = GridMesh.cornersOf(row, lastCol);
		var wrapped = GridMesh.cornersOf(row, 0);

		assertSamePoint(here.ne, wrapped.nw);
		assertSamePoint(here.se, wrapped.sw);
	}

	function testSouthCornersMatchNorthNeighborsCorners():Void {
		var row = 5;
		var col = 3;
		var here = GridMesh.cornersOf(row, col);
		var south = GridMesh.cornersOf(row + 1, col);

		assertSamePoint(here.sw, south.nw);
		assertSamePoint(here.se, south.ne);
	}

	function testInnerCornersAreInsetFromOuterCornersByWallThickness():Void {
		// innerCornersOf moves each corner toward the cell's own center by
		// WALL_THICKNESS along theta and phi independently — checked here as
		// actual linear (not angular) distance, since the phi axis needs a
		// sin(theta) correction for the sphere's curvature to stay a
		// consistent linear thickness at any latitude. Uses *that corner's
		// own* theta for the correction (the north pair's own north-edge
		// theta, the south pair's own south-edge theta) — not the cell
		// center's — which is exactly what testInnerCornersMatchAcrossRowBoundary
		// depends on to make adjacent rows agree; checked on both a north
		// corner (nw) and a south corner (se) here since they now use
		// different thetas for that correction.
		var row = 5;
		var col = 10;
		var radius = grid.GridGeometry.RADIUS;
		var halfTheta = Math.PI / (grid.Grid.ROWS - 1) / 2;
		var centerTheta = Math.PI * row / (grid.Grid.ROWS - 1);
		var outer = GridMesh.cornersOf(row, col);
		var inner = GridMesh.innerCornersOf(row, col);

		var thetaOuterNw = game.SphereMath.thetaOf(outer.nw);
		var thetaInnerNw = game.SphereMath.thetaOf(inner.nw);
		Assert.floatEquals(grid.GridGeometry.WALL_THICKNESS, (thetaInnerNw - thetaOuterNw) * radius, 1e-6);

		var phiOuterNw = game.SphereMath.phiOf(outer.nw);
		var phiInnerNw = game.SphereMath.phiOf(inner.nw);
		Assert.floatEquals(grid.GridGeometry.WALL_THICKNESS, (phiInnerNw - phiOuterNw) * radius * Math.sin(centerTheta - halfTheta), 1e-6);

		var thetaOuterSe = game.SphereMath.thetaOf(outer.se);
		var thetaInnerSe = game.SphereMath.thetaOf(inner.se);
		Assert.floatEquals(grid.GridGeometry.WALL_THICKNESS, (thetaOuterSe - thetaInnerSe) * radius, 1e-6);

		var phiOuterSe = game.SphereMath.phiOf(outer.se);
		var phiInnerSe = game.SphereMath.phiOf(inner.se);
		Assert.floatEquals(grid.GridGeometry.WALL_THICKNESS, (phiOuterSe - phiInnerSe) * radius * Math.sin(centerTheta + halfTheta), 1e-6);
	}

	// The bug this session's fix targets: a west/east wall's inner corner
	// used the *cell's own center* theta for its curvature correction, but
	// that wall's north/south ends actually sit at the row's boundary theta
	// — so row R's own south-end inner corner and row R+1's own north-end
	// inner corner, despite being the same physical latitude, each computed
	// the correction from a different center and landed at different phi.
	//
	// Their theta still legitimately differs by design — each corner insets
	// *toward its own cell*, i.e. row R's south-inner corner sits just
	// north of the boundary and row R+1's north-inner corner sits just
	// south of it, on opposite sides of the shared outer edge, same as
	// every other pair of facing inner corners on this grid (that's what
	// gives a wall its thickness). What must match is the *phi* the
	// curvature correction lands on: with both sides now correcting from
	// the same true boundary theta (row R's own south theta is bit-
	// identical to row R+1's own north theta — same latitude, same
	// formula), a west/east wall no longer zigzags sideways in phi as it
	// crosses from one row into the next.
	function testInnerCornersMatchAcrossRowBoundary():Void {
		// Same column count on both sides (no doubling in between) — the
		// common case, most of the grid.
		var row = 5;
		var col = 10;
		var here = GridMesh.innerCornersOf(row, col);
		var south = GridMesh.innerCornersOf(row + 1, col);
		Assert.floatEquals(game.SphereMath.phiOf(here.sw), game.SphereMath.phiOf(south.nw), 1e-9);
		Assert.floatEquals(game.SphereMath.phiOf(here.se), game.SphereMath.phiOf(south.ne), 1e-9);

		// Across a doubling boundary too: row 1's own south-west/south-east
		// inner corners' phi must match row 2's leftmost/rightmost child's
		// own north-west/north-east inner corners' phi (ratio 2, so child
		// columns 0 and 1 for parent column 0).
		var parentCol = 0;
		var parent = GridMesh.innerCornersOf(1, parentCol);
		var childWest = GridMesh.innerCornersOf(2, parentCol * 2);
		var childEast = GridMesh.innerCornersOf(2, parentCol * 2 + 1);
		Assert.floatEquals(game.SphereMath.phiOf(parent.sw), game.SphereMath.phiOf(childWest.nw), 1e-9);
		Assert.floatEquals(game.SphereMath.phiOf(parent.se), game.SphereMath.phiOf(childEast.ne), 1e-9);
	}

	// The pinch bug this session's second fix targets: a west/east wall
	// running straight through several rows (nothing perpendicular at any
	// boundary it crosses) used to retreat by WALL_THICKNESS at *every* row
	// boundary regardless of whether anything needed that room — pinching
	// into a wedge that only touched its neighbor along the outer edge, no
	// matter how well the previous fix aligned that seam's phi.
	// WallBuilder.continuesAcrossRowBoundary (private, so exercised here
	// only through innerCornersOf's own retreat flags) is what decides a
	// west/east wall's end shouldn't retreat at all when the same wall
	// continues flush into the next row. This test checks the underlying
	// primitive that decision relies on: passing retreatNorth/retreatSouth
	// = false must land the inner corner exactly on the outer boundary
	// theta, and doing that on both sides of a row boundary must produce
	// the exact same point — a flush rectangular connection, not a wedge.
	function testNotRetreatingLandsExactlyOnTheOuterBoundaryAndMatchesTheNextRow():Void {
		var row = 5;
		var col = 10;
		var outer = GridMesh.cornersOf(row, col);
		var southNotRetreated = GridMesh.innerCornersOf(row, col, true, false);
		var northNotRetreatedNextRow = GridMesh.innerCornersOf(row + 1, col, false, true);

		Assert.floatEquals(game.SphereMath.thetaOf(outer.sw), game.SphereMath.thetaOf(southNotRetreated.sw), 1e-9);
		Assert.floatEquals(game.SphereMath.thetaOf(outer.se), game.SphereMath.thetaOf(southNotRetreated.se), 1e-9);
		assertSamePoint(southNotRetreated.sw, northNotRetreatedNextRow.nw);
		assertSamePoint(southNotRetreated.se, northNotRetreatedNextRow.ne);
	}

	// The specific property GridMesh's split boundary pieces need at a
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
			var myCols = grid.Grid.colsForRow(boundary.row);
			var otherCols = grid.Grid.colsForRow(boundary.otherRow);
			Assert.isTrue(otherCols > myCols, 'expected a doubling at row ${boundary.row} -> ${boundary.otherRow}');

			// Whichever row is further south (larger theta) has its own
			// north edge (nw/ne) on this boundary; the other has its south
			// edge (sw/se) on it instead.
			var childIsSouthOfParent = boundary.otherRow > boundary.row;
			var parentOuterTheta = Math.PI * boundary.row / (grid.Grid.ROWS - 1) + (childIsSouthOfParent ? 1 : -1) * Math.PI / (grid.Grid.ROWS - 1) / 2;

			for (col in 0...myCols) {
				for (entry in grid.Grid.rowBoundaryNeighbors(boundary.row, col, boundary.otherRow)) {
					var childCol = switch entry.node {
						case RingNode(_, c): c;
						case PoleNode(_): -1;
					}
					var childCorners = GridMesh.cornersOf(boundary.otherRow, childCol);
					var childWest = childIsSouthOfParent ? childCorners.nw : childCorners.sw;
					var childEast = childIsSouthOfParent ? childCorners.ne : childCorners.se;

					var splitWest = GridMesh.cornerAt(parentOuterTheta, entry.phiStart);
					var splitEast = GridMesh.cornerAt(parentOuterTheta, entry.phiEnd);

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
