package biomes.conway;

import biomes.common.maze.MazeTopology;
import biomes.common.maze.MazeTopology.EdgeAxis;
import biomes.common.maze.MazeTopology.GridCoords;
import biomes.common.maze.MazeTopology.RectangularTopology;
import biomes.conway.ConwayMaze.ConwayNode;

/**
	Presents the Conway biome's own denser lat/long grid as a
	`MazeTopology` — the counterpart to
	`biomes.common.grid.GridTopology`, and the reason `ConwayMaze` no longer
	carries its own copy of the randomized-DFS carve.

	Simpler than `GridTopology` in two ways: this grid's ring rows are already
	numbered from 0, and its column count is uniform
	(`ConwayGrid.COLS` everywhere) rather than banded by latitude — so there's
	no row offset to translate and no resolution changes for
	`biomes.common.maze.RecursiveDivision` to work around.
**/
class ConwayTopology implements RectangularTopology {
	/** The single shared instance — `ConwayGrid`/`ConwayMaze` are entirely static, so there's nothing per-instance to hold. **/
	public static final INSTANCE:ConwayTopology = new ConwayTopology();

	function new() {}

	public function nodeKeys():Array<String> {
		return [for (node in ConwayMaze.allNodes()) ConwayMaze.nodeKey(node)];
	}

	public function neighborsOf(nodeKey:String):Array<String> {
		return [for (neighbor in ConwayMaze.neighborsOf(nodeFor(nodeKey))) ConwayMaze.nodeKey(neighbor)];
	}

	/** Same rule as `GridTopology.axisOf` — see `EdgeAxis`'s own doc for why pole edges are `Irregular`. **/
	public function axisOf(a:String, b:String):EdgeAxis {
		var coordsA = coordsOf(a);
		var coordsB = coordsOf(b);
		if (coordsA == null || coordsB == null) {
			return Irregular;
		}
		return coordsA.row == coordsB.row ? AlongRow : AcrossRow;
	}

	public function rowCount():Int {
		return ConwayGrid.RING_ROWS;
	}

	public function colsInRow(row:Int):Int {
		return ConwayGrid.COLS;
	}

	public function keyOf(row:Int, col:Int):String {
		return ConwayMaze.nodeKey(RingNode(row, col));
	}

	public function coordsOf(nodeKey:String):Null<GridCoords> {
		return switch nodeFor(nodeKey) {
			case PoleNode(_): null;
			case RingNode(row, col): {row: row, col: col};
		}
	}

	public function nonRectangularNodes():Array<String> {
		return [ConwayMaze.nodeKey(PoleNode(North)), ConwayMaze.nodeKey(PoleNode(South))];
	}

	/** Inverse of `ConwayMaze.nodeKey` — same reasoning as `GridTopology.nodeFor`'s own doc for why it lives in the adapter. **/
	static function nodeFor(nodeKey:String):ConwayNode {
		if (nodeKey == ConwayMaze.nodeKey(PoleNode(North))) {
			return PoleNode(North);
		}
		if (nodeKey == ConwayMaze.nodeKey(PoleNode(South))) {
			return PoleNode(South);
		}

		var parts = nodeKey.split(":");
		var row = parts.length == 3 ? Std.parseInt(parts[1]) : null;
		var col = parts.length == 3 ? Std.parseInt(parts[2]) : null;
		if (parts[0] != "ring" || row == null || col == null) {
			throw 'not a ConwayMaze node key: "$nodeKey"';
		}
		return RingNode(row, col);
	}
}
