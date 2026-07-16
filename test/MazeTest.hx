import utest.Test;
import utest.Assert;
import maze.Maze;
import maze.Maze.MazeNode;
import maze.Maze.MazeData;

/**
	Mirrors old/src/maze/mazeGenerator.test.ts, for behavioral parity with the
	ported prototype. Doesn't need to match old/'s mulberry32 sequence bit for
	bit — any deterministic seeded source works for exercising the algorithm.
**/
class MazeTest extends Test {
	function testGenerateProducesASpanningTree():Void {
		var maze = Maze.generate(new SeededRandom(1).next);
		var nodes = Maze.allNodes();

		Assert.equals(nodes.length - 1, countOpenEdges(maze));
	}

	function testGenerateConnectsEveryNodeToEveryOther():Void {
		var maze = Maze.generate(new SeededRandom(42).next);
		var nodes = Maze.allNodes();
		var start = nodes[0];
		if (start == null) {
			Assert.fail("allNodes() returned no nodes");
			return;
		}

		var visited = new haxe.ds.StringMap<Bool>();
		visited.set(Maze.nodeKey(start), true);

		var stack:Array<MazeNode> = [start];
		while (stack.length > 0) {
			var current = stack.pop();
			if (current == null) {
				continue;
			}
			for (neighbor in Maze.neighborsOf(current)) {
				var key = Maze.nodeKey(neighbor);
				if (Maze.isOpen(maze, current, neighbor) && !visited.exists(key)) {
					visited.set(key, true);
					stack.push(neighbor);
				}
			}
		}

		Assert.equals(nodes.length, countKeys(visited));
	}

	function testColumnsWrapAround():Void {
		var ringNeighbors = Maze.neighborsOf(RingNode(3, 0));
		var expected = RingNode(3, Maze.COLS - 1);

		// Array.contains/indexOf use `==`, which is reference equality for
		// enum constructors with arguments — Type.enumEq does the intended
		// structural comparison.
		Assert.isTrue(Lambda.exists(ringNeighbors, node -> Type.enumEq(node, expected)));
	}

	function testNodeAtRingCellCenterReturnsThatCell():Void {
		var row = 5;
		var col = 12;
		var theta = Math.PI * row / (Maze.ROWS - 1);
		// Column phi is boundary-anchored (see Maze.centerOf's doc) — the
		// cell's actual center is at col+0.5, not col itself.
		var phi = 2 * Math.PI * (col + 0.5) / Maze.COLS;

		var node = Maze.nodeAt(theta, phi);

		Assert.isTrue(Type.enumEq(node, RingNode(row, col)));
	}

	function testNodeAtNearNorthPoleReturnsPoleNodeRegardlessOfPhi():Void {
		Assert.isTrue(Type.enumEq(Maze.nodeAt(0.0001, 0), PoleNode(North)));
		Assert.isTrue(Type.enumEq(Maze.nodeAt(0.0001, 5.5), PoleNode(North)));
	}

	function testNodeAtNearSouthPoleReturnsPoleNodeRegardlessOfPhi():Void {
		Assert.isTrue(Type.enumEq(Maze.nodeAt(Math.PI - 0.0001, 0), PoleNode(South)));
		Assert.isTrue(Type.enumEq(Maze.nodeAt(Math.PI - 0.0001, 5.5), PoleNode(South)));
	}

	function testNodeAtNearFullTurnReturnsLastColumn():Void {
		// Boundary-anchored columns (see Maze.centerOf's doc) floor cleanly:
		// just short of a full turn belongs to the *last* column's own
		// range, not the nearest center — unlike the old round-to-nearest-
		// center convention, there's no rounding-driven wraparound to the
		// first column here at all.
		var row = 5;
		var theta = Math.PI * row / (Maze.ROWS - 1);
		var phi = 2 * Math.PI - 0.0001;

		var node = Maze.nodeAt(theta, phi);

		Assert.isTrue(Type.enumEq(node, RingNode(row, Maze.COLS - 1)));
	}

	function testNodeAtPastAFullTurnWrapsToFirstColumn():Void {
		// A genuine wraparound case instead: phi at (not past) a full turn
		// floors to col == COLS, which needs the explicit modulo to land
		// back on column 0 — defensive against a caller passing an
		// unnormalized phi (SphereMath.phiOf itself never produces one).
		var row = 5;
		var theta = Math.PI * row / (Maze.ROWS - 1);
		var phi = 2 * Math.PI;

		var node = Maze.nodeAt(theta, phi);

		Assert.isTrue(Type.enumEq(node, RingNode(row, 0)));
	}

	function testColsForRowMatchesExpectedBandsForEveryRow():Void {
		// The band scheme: d<=1 (rows touching a pole) -> COLS/4, d<=3 ->
		// COLS/2, else the full COLS — see colsForRow's own doc for why.
		var expected = [7, 14, 14, 28, 28, 28, 28, 28, 28, 14, 14, 7];
		for (row in 1...(Maze.ROWS - 1)) {
			Assert.equals(expected[row - 1], Maze.colsForRow(row), 'row $row');
		}
	}

	// The specific regression case for the bug a Plan-agent review caught in
	// the original design: under a center-anchored phi convention, a
	// doubling boundary's children don't nest evenly inside the parent's own
	// range at all (each parent col overlaps three children, not two).
	// Checked two ways: the entries must exactly partition the parent's own
	// range (no gap, no overlap, no drift) *and* each entry's phi range must
	// equal the child column's own boundary-anchored range computed fresh
	// from otherCols (not by re-invoking rowBoundaryNeighbors on the child).
	// (MazeMesh.cornersOf isn't row-aware yet at this point in the reduced-
	// grid work — that comparison belongs in MazeMeshTest once it is.)
	function testRowBoundaryNeighborsDoublingEntriesPartitionParentRangeExactly():Void {
		// Every doubling boundary in the grid: (row, otherRow) pairs where
		// otherRow has more columns than row.
		var boundaries = [{row: 1, otherRow: 2}, {row: 3, otherRow: 4}, {row: 10, otherRow: 9}, {row: 12, otherRow: 11}];
		for (boundary in boundaries) {
			var myCols = Maze.colsForRow(boundary.row);
			var otherCols = Maze.colsForRow(boundary.otherRow);
			var ratio = Std.int(otherCols / myCols);
			Assert.isTrue(ratio > 1, 'expected a doubling at row ${boundary.row} -> ${boundary.otherRow}');

			// Exercise every column of the coarser row, not just column 0 —
			// the bug this guards against was a *systematic* misalignment,
			// not a one-off at the seam.
			for (col in 0...myCols) {
				var parentPhiStart = 2 * Math.PI * col / myCols;
				var parentPhiEnd = 2 * Math.PI * (col + 1) / myCols;
				var entries = Maze.rowBoundaryNeighbors(boundary.row, col, boundary.otherRow);
				Assert.equals(ratio, entries.length, 'row ${boundary.row} col $col -> ${boundary.otherRow}');

				Assert.floatEquals(parentPhiStart, entries[0].phiStart, 1e-9);
				Assert.floatEquals(parentPhiEnd, entries[entries.length - 1].phiEnd, 1e-9);
				for (i in 0...entries.length) {
					var childCol = switch entries[i].node {
						case RingNode(_, c): c;
						case PoleNode(_): -1;
					}
					Assert.equals(col * ratio + i, childCol, 'row ${boundary.row} col $col entry $i');
					Assert.floatEquals(2 * Math.PI * childCol / otherCols, entries[i].phiStart, 1e-9);
					Assert.floatEquals(2 * Math.PI * (childCol + 1) / otherCols, entries[i].phiEnd, 1e-9);
					if (i > 0) {
						Assert.floatEquals(entries[i - 1].phiEnd, entries[i].phiStart, 1e-9); // no gap, no overlap
					}
				}
			}
		}
	}

	function testRowBoundaryNeighborsAtColumnExtremesStayInRange():Void {
		var boundaries = [{row: 1, otherRow: 2}, {row: 3, otherRow: 4}, {row: 10, otherRow: 9}, {row: 12, otherRow: 11}];
		for (boundary in boundaries) {
			var myCols = Maze.colsForRow(boundary.row);

			var first = Maze.rowBoundaryNeighbors(boundary.row, 0, boundary.otherRow);
			Assert.floatEquals(0, first[0].phiStart, 1e-9);

			var last = Maze.rowBoundaryNeighbors(boundary.row, myCols - 1, boundary.otherRow);
			Assert.floatEquals(2 * Math.PI, last[last.length - 1].phiEnd, 1e-9);
		}
	}

	function countOpenEdges(maze:MazeData):Int {
		var count = 0;
		for (_ in maze.openEdges.keys()) {
			count++;
		}
		return count;
	}

	function countKeys(map:haxe.ds.StringMap<Bool>):Int {
		var count = 0;
		for (_ in map.keys()) {
			count++;
		}
		return count;
	}
}

/**
	xorshift32, seeded — deterministic so the spanning-tree checks above
	aren't at the mercy of Math.random flakiness. Test-only; no need for
	statistical rigor beyond "deterministic and well-mixed".
**/
class SeededRandom {
	var state:Int;

	public function new(seed:Int) {
		state = seed == 0 ? 1 : seed;
	}

	/** @return the next value in the sequence, in [0, 1). **/
	public function next():Float {
		state ^= state << 13;
		state ^= state >>> 17;
		state ^= state << 5;
		var unsigned:Float = state >>> 0;
		return unsigned / 4294967296.0;
	}
}
