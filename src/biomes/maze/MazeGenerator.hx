package biomes.maze;

import biomes.common.grid.GridModel.GridData;
import biomes.common.grid.GridTopology;
import biomes.common.maze.MazeCarver;
import biomes.common.maze.MazeStyle;

/**
	The maze biome's own layout: which style it's generated in, and how a
	specific one is saved and reloaded.

	The generation *algorithms* aren't here any more — they're in
	`biomes.common.maze`, working through `GridTopology` — because they were
	never specific to this biome, only to this grid: the randomized-DFS carve
	that used to live here was copy-pasted verbatim into
	`biomes.conway.ConwayMaze` the moment a second grid-based biome existed.
	What stays here is the part that genuinely is this biome's own: which
	recipe it uses, and its serialization format (see `serialize`'s own doc
	for why the format is tied to the grid rather than to an RNG seed).

	Originally ported from old/src/maze/mazeGenerator.ts; the algorithm
	survives unchanged inside `MazeCarver.carve`'s own `RandomizedDfs`
	branch, loop for loop.
**/
class MazeGenerator {
	/**
		Generates this biome's own maze in its default style — a perfect maze
		(spanning tree, exactly one path between any two cells) carved by
		randomized depth-first search, same as every maze in the game so far.
		@param random source of randomness in [0, 1); defaults to Math.random.
		@return the generated maze's open edges.
	**/
	public static function generate(?random:Void->Float):GridData {
		return generateWith(RandomizedDfs, 0, random);
	}

	/**
		Generates this biome's own maze in any style, optionally braided —
		the seam a differently-generated grid biome hangs off, and how a
		design question ("what should this biome's corridors feel like")
		reaches the algorithms without every biome writing its own carve.
		Which biome should use which recipe is still open (see
		`docs/open/ideas-backlog.md`).
		@param style which algorithm to carve with.
		@param braidFraction what fraction of dead ends to open into loops, in [0, 1] — 0 leaves a perfect maze.
		@param random source of randomness in [0, 1); defaults to Math.random.
		@return the generated maze's open edges.
	**/
	public static function generateWith(style:MazeStyle, braidFraction:Float = 0, ?random:Void->Float):GridData {
		return MazeCarver.carve(GridTopology.INSTANCE, style, braidFraction, random);
	}

	/**
		Serializes a generated maze to a JSON string, so a specific maze can
		be saved to a file and reloaded later — instead of only ever having
		whatever fresh random one the last page load produced, which made a
		maze that a bug showed up in impossible to hand off or come back to.

		Encodes the open edges only (as `GridModel.nodeKey`-pair strings, same as
		`openEdges`'s own keys) rather than the RNG seed that produced them:
		this ties a saved maze to the *grid* (`GridModel.ROWS`/`colsForRow`), which
		only changes with a deliberate design change, not to `generate`'s
		own algorithm, which could evolve — and it's what every other query
		reads the maze through, so a deserialized maze is exactly as valid as
		a freshly generated one, not a special case.
		@param maze the maze to serialize.
		@return a JSON string.
	**/
	public static function serialize(maze:GridData):String {
		var edges = [for (key in maze.openEdges.keys()) key];
		return haxe.Json.stringify({openEdges: edges});
	}

	/**
		Inverse of `serialize`.
		@param json a JSON string produced by `serialize`.
		@return the maze it encodes.
	**/
	public static function deserialize(json:String):GridData {
		var parsed:{openEdges:Array<String>} = haxe.Json.parse(json);
		var openEdges = new haxe.ds.StringMap<Bool>();
		for (key in parsed.openEdges) {
			openEdges.set(key, true);
		}
		return {openEdges: openEdges};
	}
}
