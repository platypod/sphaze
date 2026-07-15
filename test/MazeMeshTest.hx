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

	function assertSamePoint(a:h3d.Vector, b:h3d.Vector):Void {
		Assert.floatEquals(a.x, b.x, 1e-9);
		Assert.floatEquals(a.y, b.y, 1e-9);
		Assert.floatEquals(a.z, b.z, 1e-9);
	}
}
