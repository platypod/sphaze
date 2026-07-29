package biomes.conway;

import biomes.common.maze.MazeCarver;
import biomes.common.maze.MazeStyle;
import biomes.conway.ConwayGrid.Pole;

enum ConwayNode {
	PoleNode(pole:Pole);
	RingNode(row:Int, col:Int);
}

typedef ConwayMazeData = {
	var openEdges:haxe.ds.StringMap<Bool>;
}

/**
	Conway biome's own maze layout over ConwayGrid's topology: which style
	it's generated in, its (de)serialization, and the node/edge key vocabulary
	the rest of the biome queries it through (`ConwayGrid.liveNeighborCount`,
	`ConwayMesh`).

	The carve itself lives in `biomes.common.maze`, reached through
	`ConwayTopology` — this class used to hold its own verbatim copy of
	`biomes.maze.MazeGenerator`'s randomized DFS, which is exactly the
	duplication that made adding a second generation style a per-biome job.
**/
class ConwayMaze {
	/**
		Generates this biome's own maze in its default style — randomized DFS,
		unchanged from the copy this class used to carry itself.
		@param random source of randomness in [0, 1); defaults to Math.random.
		@return the generated maze's open edges.
	**/
	public static function generate(?random:Void->Float):ConwayMazeData {
		return generateWith(RandomizedDfs, 0, random);
	}

	/**
		Generates this biome's own maze in any style, optionally braided — see
		`biomes.maze.MazeGenerator.generateWith`, of which this is the exact
		counterpart over this biome's own denser grid.
		@param style which algorithm to carve with.
		@param braidFraction what fraction of dead ends to open into loops, in [0, 1] — 0 leaves a perfect maze.
		@param random source of randomness in [0, 1); defaults to Math.random.
		@return the generated maze's open edges.
	**/
	public static function generateWith(style:MazeStyle, braidFraction:Float = 0, ?random:Void->Float):ConwayMazeData {
		return MazeCarver.carve(ConwayTopology.INSTANCE, style, braidFraction, random);
	}

	public static function serialize(maze:ConwayMazeData):String {
		var edges = [for (key in maze.openEdges.keys()) key];
		return haxe.Json.stringify({openEdges: edges});
	}

	public static function deserialize(json:String):ConwayMazeData {
		var parsed:{openEdges:Array<String>} = haxe.Json.parse(json);
		var openEdges = new haxe.ds.StringMap<Bool>();
		if (parsed.openEdges != null) {
			for (key in parsed.openEdges) {
				openEdges.set(key, true);
			}
		}
		return {openEdges: openEdges};
	}

	public static function isOpen(maze:ConwayMazeData, a:ConwayNode, b:ConwayNode):Bool {
		return maze.openEdges.exists(edgeKey(a, b));
	}

	public static function nodeKey(node:ConwayNode):String {
		return switch node {
			case PoleNode(North): "pole:north";
			case PoleNode(South): "pole:south";
			case RingNode(row, col): 'ring:$row:$col';
		}
	}

	public static function edgeKey(a:ConwayNode, b:ConwayNode):String {
		var keyA = nodeKey(a);
		var keyB = nodeKey(b);
		return keyA < keyB ? '$keyA|$keyB' : '$keyB|$keyA';
	}

	public static function allNodes():Array<ConwayNode> {
		var nodes:Array<ConwayNode> = [PoleNode(North), PoleNode(South)];
		ConwayGrid.eachRingCell((row, col) -> nodes.push(RingNode(row, col)));
		return nodes;
	}

	public static function neighborsOf(node:ConwayNode):Array<ConwayNode> {
		return switch node {
			case PoleNode(North):
				[for (col in 0...ConwayGrid.COLS) RingNode(0, col)];
			case PoleNode(South):
				[for (col in 0...ConwayGrid.COLS) RingNode(ConwayGrid.RING_ROWS - 1, col)];
			case RingNode(row, col):
				var neighbors:Array<ConwayNode> = [RingNode(row, wrapCol(col - 1)), RingNode(row, wrapCol(col + 1))];
				if (row == 0) {
					neighbors.push(PoleNode(North));
				} else {
					neighbors.push(RingNode(row - 1, col));
				}
				if (row == ConwayGrid.RING_ROWS - 1) {
					neighbors.push(PoleNode(South));
				} else {
					neighbors.push(RingNode(row + 1, col));
				}
				neighbors;
		}
	}

	static function wrapCol(col:Int):Int {
		var wrapped = col % ConwayGrid.COLS;
		return wrapped < 0 ? wrapped + ConwayGrid.COLS : wrapped;
	}
}
