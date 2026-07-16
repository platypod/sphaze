import utest.Test;
import utest.Assert;
import maze.MazeMesh;

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

	function assertSamePoint(a:h3d.Vector, b:h3d.Vector):Void {
		Assert.floatEquals(a.x, b.x, 1e-9);
		Assert.floatEquals(a.y, b.y, 1e-9);
		Assert.floatEquals(a.z, b.z, 1e-9);
	}
}
