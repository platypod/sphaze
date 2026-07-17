import utest.Test;
import utest.Assert;
import maze.Maze;
import maze.Maze.MazeData;
import maze.Maze.MazeNode;
import maze.MazeMesh;
import hub.BiomePainting;
import hub.Painting;

/** Covers BiomePainting's placement scan — a deterministic, hand-built MazeData, not a random generated one. **/
class BiomePaintingTest extends Test {
	function testFindsRow1Col0sWestWallWhenNothingIsOpenAnywhere():Void {
		var maze:MazeData = {openEdges: new haxe.ds.StringMap()}; // nothing open -> row 1 col 0's west edge is the first closed one found

		var painting = BiomePainting.findReturnPainting(maze);

		var inner = MazeMesh.innerCornersOf(1, 0);
		var expected = Painting.midpointOf(inner.nw, inner.sw);
		assertVectorEquals(expected, painting.position);
		Assert.equals(ToHub, painting.destination);
	}

	function testSkipsOpenEdgesUntilItFindsAClosedOne():Void {
		var maze:MazeData = {openEdges: new haxe.ds.StringMap()};
		// Open row 1's whole ring (every west/east edge in it) so the scan
		// has to move on to row 2 entirely before finding a closed one.
		var cols = Maze.colsForRow(1);
		for (col in 0...cols) {
			var here = RingNode(1, col);
			var east = RingNode(1, (col + 1) % cols);
			maze.openEdges.set(edgeKeyForTest(here, east), true);
		}

		var painting = BiomePainting.findReturnPainting(maze);

		var inner = MazeMesh.innerCornersOf(2, 0);
		var expected = Painting.midpointOf(inner.nw, inner.sw);
		assertVectorEquals(expected, painting.position);
	}

	function testUsesTheEastWallWhenWestIsOpenButEastIsClosed():Void {
		var maze:MazeData = {openEdges: new haxe.ds.StringMap()};
		var cols = Maze.colsForRow(1);
		// Row 1 col 0's west edge open, so the scan must check its east
		// side (also closed, since nothing else is open) before moving on.
		maze.openEdges.set(edgeKeyForTest(RingNode(1, 0), RingNode(1, cols - 1)), true);

		var painting = BiomePainting.findReturnPainting(maze);

		var inner = MazeMesh.innerCornersOf(1, 0);
		var expected = Painting.midpointOf(inner.ne, inner.se);
		assertVectorEquals(expected, painting.position);
	}

	function assertVectorEquals(expected:h3d.Vector, actual:h3d.Vector):Void {
		Assert.floatEquals(expected.x, actual.x, 1e-9);
		Assert.floatEquals(expected.y, actual.y, 1e-9);
		Assert.floatEquals(expected.z, actual.z, 1e-9);
	}

	/** Test-only stand-in for Maze's private edgeKey — same sort-then-join format (see CollisionTest's own copy of this). **/
	function edgeKeyForTest(a:MazeNode, b:MazeNode):String {
		var keyA = Maze.nodeKey(a);
		var keyB = Maze.nodeKey(b);
		return keyA < keyB ? '$keyA|$keyB' : '$keyB|$keyA';
	}
}
