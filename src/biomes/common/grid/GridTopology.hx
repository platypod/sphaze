package biomes.common.grid;

import biomes.common.grid.GridModel.GridNode;
import biomes.common.maze.MazeTopology;
import biomes.common.maze.MazeTopology.EdgeAxis;
import biomes.common.maze.MazeTopology.GridCoords;
import biomes.common.maze.MazeTopology.RectangularTopology;

/**
	Presents `GridModel`'s lat/long sphere grid as a `MazeTopology`, so every
	generation style in `biomes.common.maze` applies to it — the adapter that
	replaced this grid's own copy of the randomized-DFS carve.

	Stateless, one shared `INSTANCE`, same shape as
	`biomes.common.space.sphere.SphereSpace`: `GridModel` is entirely static,
	so there's nothing per-instance to hold.

	**Row numbering differs on purpose.** `GridModel` numbers its ring rows
	`1...ROWS - 1`, with rows 0 and `ROWS - 1` standing in for the merged
	poles; `RectangularTopology` numbers the rectangle's own rows
	`0...rowCount()` and keeps the poles out of it entirely (they're
	`nonRectangularNodes`). This class is the only place that translation
	lives, which is the point of an adapter — nothing in
	`biomes.common.maze` should know that a pole is a row index somewhere
	else.
**/
class GridTopology implements RectangularTopology {
	/** The single shared instance — see class doc. **/
	public static final INSTANCE:GridTopology = new GridTopology();

	/** Offset between a rectangle row and its `GridModel` row — see class doc. **/
	static inline final FIRST_RING_ROW:Int = 1;

	function new() {}

	public function nodeKeys():Array<String> {
		return [for (node in GridModel.allNodes()) GridModel.nodeKey(node)];
	}

	public function neighborsOf(nodeKey:String):Array<String> {
		return [
			for (neighbor in GridModel.neighborsOf(nodeFor(nodeKey)))
				GridModel.nodeKey(neighbor)
		];
	}

	/** Two ring cells in the same row run east-west; in different rows, north-south. Anything involving a merged pole is `Irregular` — see `EdgeAxis`'s own doc. **/
	public function axisOf(a:String, b:String):EdgeAxis {
		var coordsA = coordsOf(a);
		var coordsB = coordsOf(b);
		if (coordsA == null || coordsB == null) {
			return Irregular;
		}
		return coordsA.row == coordsB.row ? AlongRow : AcrossRow;
	}

	public function rowCount():Int {
		return GridModel.ROWS - 2;
	}

	public function colsInRow(row:Int):Int {
		return GridModel.colsForRow(row + FIRST_RING_ROW);
	}

	public function keyOf(row:Int, col:Int):String {
		return GridModel.nodeKey(RingNode(row + FIRST_RING_ROW, col));
	}

	public function coordsOf(nodeKey:String):Null<GridCoords> {
		return switch nodeFor(nodeKey) {
			case PoleNode(_): null;
			case RingNode(row, col): {row: row - FIRST_RING_ROW, col: col};
		}
	}

	public function nonRectangularNodes():Array<String> {
		return [GridModel.nodeKey(PoleNode(North)), GridModel.nodeKey(PoleNode(South))];
	}

	/**
		Parses a key back into the node it names — the inverse of
		`GridModel.nodeKey`, which lives here rather than next to it because
		this adapter is the only thing in the project that ever needs to go
		that direction (everything else holds the `GridNode` and derives the
		key when it needs one).
		@param nodeKey a key produced by `GridModel.nodeKey`.
		@return the node it names.
	**/
	static function nodeFor(nodeKey:String):GridNode {
		if (nodeKey == GridModel.nodeKey(PoleNode(North))) {
			return PoleNode(North);
		}
		if (nodeKey == GridModel.nodeKey(PoleNode(South))) {
			return PoleNode(South);
		}

		var parts = nodeKey.split(":");
		var row = parts.length == 3 ? Std.parseInt(parts[1]) : null;
		var col = parts.length == 3 ? Std.parseInt(parts[2]) : null;
		if (parts[0] != "ring" || row == null || col == null) {
			throw 'not a GridModel node key: "$nodeKey"';
		}
		return RingNode(row, col);
	}
}
