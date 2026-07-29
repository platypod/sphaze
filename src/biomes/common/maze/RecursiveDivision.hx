package biomes.common.maze;
import biomes.common.maze.MazeTopology.MazeLayout;
import biomes.common.maze.MazeTopology.RectangularTopology;

/**
	Recursive division, adapted to a cylindrical row/column grid whose rows
	may not all have the same column count (see
	`biomes.common.grid.GridModel.colsForRow`).

	Unlike every other style in this package it works *backwards*: start from
	a completely open field and add walls, each with exactly one gap,
	recursing into the two halves until a region is a single row or a single
	column — a corridor, which by definition has no internal loops. That's
	what keeps the result a perfect maze despite starting from a field full of
	them, and it's also where the style's own character comes from: rooms and
	halls with long straight walls, rather than the wandering one-cell
	corridors a carving algorithm produces.

	Three adaptations this topology forces, none of them cosmetic:

	1. **The cylinder is cut once at phi = 0** before anything else, turning
	   a surface with no left or right edge into an ordinary rectangle the
	   recursion can divide. That seam is the one wall here with **no door**,
	   which is not an oversight: it *is* the cut. A door in it would join the
	   rectangle's own left and right edges back together, and since a
	   full-width single-row region is a corridor the recursion stops at, that
	   corridor would be a ring — one guaranteed loop, which is exactly how
	   this showed up (every style's perfect-maze test passed except this one,
	   off by precisely one edge). Everything stays reachable without it: the
	   rectangle is fully connected internally. Visually it reads as one long
	   pole-to-pole wall, a signature of this style *here* specifically.
	2. **Vertical cuts only land on column boundaries that exist in every row
	   of the region.** A region whose rows disagree on column count is
	   therefore split *horizontally* first, at a boundary where the count
	   changes, until every region is uniform. Without that, the finest row in
	   a region would keep sub-boundaries no cut ever reaches, leaving loops
	   behind and quietly breaking the perfect-maze property.
	3. **The merged poles aren't cells**, so they're not part of the
	   rectangle at all: each gets exactly one open edge into its adjacent
	   row, chosen up front. Opening all of them (a pole neighbors an entire
	   row) would carve a wide-open cap instead of a passage.
**/
class RecursiveDivision {
	/**
		Widest region, in rows or columns, that still gets divided — at 1 the
		region is a corridor and the recursion stops. Not a tuning knob: it's
		what makes the output a perfect maze (see class doc).
	**/
	static inline final MIN_DIVISIBLE_SPAN:Int = 2;

	/** Guards float comparisons on fraction-of-the-circle boundaries against accumulated division error. **/
	static inline final EPSILON:Float = 1e-9;

	/** `addVerticalWall`'s "no row gets a door" marker — no real row index can be negative. Only the seam wall uses it (see class doc, adaptation 1). **/
	static inline final NO_DOOR:Int = -1;

	/**
		@param topology the rectangular surface to divide.
		@param rng source of randomness in [0, 1).
		@return the divided layout.
	**/
	public static function carve(topology:RectangularTopology, rng:Void->Float):MazeLayout {
		var layout = openField(topology);
		var rows = topology.rowCount();
		if (rows <= 0) {
			return layout;
		}

		attachNonRectangularNodes(layout, topology, rng);
		// The seam wall (see class doc, adaptation 1): a vertical wall at
		// fraction 0 with no door at all, which is what turns the cylinder
		// into a rectangle the recursion below can treat as [0, 1].
		addVerticalWall(layout, topology, 0, 0, rows, NO_DOOR);
		divide(layout, topology, 0, rows, 0, 1, rng);
		return layout;
	}

	/**
		Every edge between two ring cells, open — the field the walls then get
		added to. Deliberately excludes edges onto non-rectangular nodes (the
		poles), which `attachNonRectangularNodes` handles instead.
		@param topology the topology to build the field over.
		@return a layout with every ring-to-ring edge open.
	**/
	static function openField(topology:RectangularTopology):MazeLayout {
		var layout = MazeEdges.emptyLayout();
		for (edge in MazeEdges.allEdges(topology)) {
			if (topology.coordsOf(edge.a) == null || topology.coordsOf(edge.b) == null) {
				continue;
			}
			MazeEdges.open(layout, edge.a, edge.b);
		}
		return layout;
	}

	/**
		Connects each pole (or any other node outside the rectangle) by
		exactly one randomly chosen edge — see class doc, adaptation 3.
		@param layout the layout to modify.
		@param topology the topology being divided.
		@param rng source of randomness in [0, 1).
	**/
	static function attachNonRectangularNodes(layout:MazeLayout, topology:RectangularTopology, rng:Void->Float):Void {
		for (node in topology.nonRectangularNodes()) {
			var candidates = topology.neighborsOf(node).filter((neighbor) -> topology.coordsOf(neighbor) != null);
			var chosen = candidates[Math.floor(rng() * candidates.length)];
			if (chosen == null) {
				continue;
			}
			MazeEdges.open(layout, node, chosen);
		}
	}

	/**
		Divides the region spanning rows `[rowStart, rowEnd)` and fractions
		`[fracStart, fracEnd)` of the circle, recursing into both halves.
		@param layout the layout to modify.
		@param topology the topology being divided.
		@param rowStart first row of the region, inclusive.
		@param rowEnd last row of the region, exclusive.
		@param fracStart start of the region's own fraction of the full circle, in [0, 1].
		@param fracEnd end of the region's own fraction of the full circle, in [0, 1].
		@param rng source of randomness in [0, 1).
	**/
	static function divide(layout:MazeLayout, topology:RectangularTopology, rowStart:Int, rowEnd:Int, fracStart:Float, fracEnd:Float,
			rng:Void->Float):Void {
		var rowSpan = rowEnd - rowStart;
		if (rowSpan >= MIN_DIVISIBLE_SPAN) {
			// Adaptation 2: a region whose rows disagree on resolution gets
			// split there first, so every vertical cut below lands on a
			// boundary that exists in all of the region's rows.
			var mismatch = firstResolutionChange(topology, rowStart, rowEnd);
			if (mismatch != null) {
				divideHorizontally(layout, topology, rowStart, rowEnd, fracStart, fracEnd, mismatch, rng);
				return;
			}
		}

		var cols = topology.colsInRow(rowStart);
		var colSpan = Math.round((fracEnd - fracStart) * cols);
		var canCutRows = rowSpan >= MIN_DIVISIBLE_SPAN;
		var canCutCols = colSpan >= MIN_DIVISIBLE_SPAN;
		if (!canCutRows && !canCutCols) {
			return;
		}

		var cutRows = canCutRows && (!canCutCols || rowSpan >= colSpan);
		if (cutRows) {
			var boundary = rowStart + 1 + Math.floor(rng() * (rowSpan - 1));
			divideHorizontally(layout, topology, rowStart, rowEnd, fracStart, fracEnd, boundary, rng);
			return;
		}

		// Cut on one of the column boundaries strictly inside the region —
		// integer column indices, converted back to a fraction, so the cut is
		// exactly a boundary in every row of the region.
		var firstBoundary = Math.round(fracStart * cols) + 1;
		var cutColumn = firstBoundary + Math.floor(rng() * (colSpan - 1));
		var cutFraction = cutColumn / cols;
		addVerticalWall(layout, topology, cutFraction, rowStart, rowEnd, rowStart + Math.floor(rng() * (rowEnd - rowStart)));
		divide(layout, topology, rowStart, rowEnd, fracStart, cutFraction, rng);
		divide(layout, topology, rowStart, rowEnd, cutFraction, fracEnd, rng);
	}

	/**
		Walls off the boundary between rows `boundary - 1` and `boundary`
		across the region's fraction range, leaving one gap, then recurses
		into the two halves.
		@param layout the layout to modify.
		@param topology the topology being divided.
		@param rowStart first row of the region, inclusive.
		@param rowEnd last row of the region, exclusive.
		@param fracStart start of the region's own fraction of the full circle.
		@param fracEnd end of the region's own fraction of the full circle.
		@param boundary the row whose northern boundary becomes the wall; strictly inside the region.
		@param rng source of randomness in [0, 1).
	**/
	static function divideHorizontally(layout:MazeLayout, topology:RectangularTopology, rowStart:Int, rowEnd:Int, fracStart:Float, fracEnd:Float,
			boundary:Int, rng:Void->Float):Void {
		addHorizontalWall(layout, topology, boundary, fracStart, fracEnd, rng);
		divide(layout, topology, rowStart, boundary, fracStart, fracEnd, rng);
		divide(layout, topology, boundary, rowEnd, fracStart, fracEnd, rng);
	}

	/**
		The first row boundary inside `[rowStart, rowEnd)` where the column
		count changes, or null if every row in the region agrees.
		@param topology the topology being divided.
		@param rowStart first row of the region, inclusive.
		@param rowEnd last row of the region, exclusive.
		@return the row whose count differs from its northern neighbor's, or null.
	**/
	static function firstResolutionChange(topology:RectangularTopology, rowStart:Int, rowEnd:Int):Null<Int> {
		for (row in (rowStart + 1)...rowEnd) {
			if (topology.colsInRow(row) != topology.colsInRow(row - 1)) {
				return row;
			}
		}
		return null;
	}

	/**
		Closes every edge crossing `fraction` in rows `[rowStart, rowEnd)`,
		except in `doorRow` — the wall's door.
		@param layout the layout to modify.
		@param topology the topology being divided.
		@param fraction where around the circle the wall stands, in [0, 1).
		@param rowStart first row the wall spans, inclusive.
		@param rowEnd last row the wall spans, exclusive.
		@param doorRow which row keeps its passage through the wall, or `NO_DOOR` for a solid one (the seam only — see class doc).
	**/
	static function addVerticalWall(layout:MazeLayout, topology:RectangularTopology, fraction:Float, rowStart:Int, rowEnd:Int, doorRow:Int):Void {
		for (row in rowStart...rowEnd) {
			if (row == doorRow) {
				continue;
			}
			var cols = topology.colsInRow(row);
			var east = Math.round(fraction * cols) % cols;
			var west = (east - 1 + cols) % cols;
			MazeEdges.close(layout, topology.keyOf(row, west), topology.keyOf(row, east));
		}
	}

	/**
		Closes every edge between rows `boundary - 1` and `boundary` within
		`[fracStart, fracEnd)`, except one — the wall's door. Iterates from
		the northern row and closes each of its southern neighbors, which
		covers the boundary in both directions whether the two rows share a
		column count or one is a doubling of the other.
		@param layout the layout to modify.
		@param topology the topology being divided.
		@param boundary the row whose northern boundary becomes the wall.
		@param fracStart start of the wall's own fraction of the full circle.
		@param fracEnd end of the wall's own fraction of the full circle.
		@param rng source of randomness in [0, 1).
	**/
	static function addHorizontalWall(layout:MazeLayout, topology:RectangularTopology, boundary:Int, fracStart:Float, fracEnd:Float, rng:Void->Float):Void {
		var northRow = boundary - 1;
		var cols = topology.colsInRow(northRow);
		var spanning:Array<String> = [];
		for (col in 0...cols) {
			var center = (col + 0.5) / cols;
			if (center > fracStart - EPSILON && center < fracEnd + EPSILON) {
				spanning.push(topology.keyOf(northRow, col));
			}
		}

		var doorCell = spanning[Math.floor(rng() * spanning.length)];
		for (cell in spanning) {
			var southNeighbors = topology.neighborsOf(cell).filter((neighbor) -> {
				var coords = topology.coordsOf(neighbor);
				return coords != null && coords.row == boundary;
			});
			var doorNeighbor = cell != doorCell ? null : southNeighbors[Math.floor(rng() * southNeighbors.length)];
			for (neighbor in southNeighbors) {
				if (neighbor == doorNeighbor) {
					continue;
				}
				MazeEdges.close(layout, cell, neighbor);
			}
		}
	}
}
