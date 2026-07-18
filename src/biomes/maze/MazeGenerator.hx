package biomes.maze;

import biomes.common.grid.GridModel;
import biomes.common.grid.GridModel.GridData;
import biomes.common.grid.GridModel.GridNode;

/**
	Generates and (de)serializes the maze biome's own layout — the spanning-
	tree puzzle-generation algorithm that's specifically what makes this
	biome a *maze*, as opposed to `GridModel`'s topology/query logic, which
	any grid-based biome shares.

	Ported from old/src/maze/mazeGenerator.ts — the algorithm is engine-
	agnostic, so it carries over unchanged; only language/API details differ
	(a Haxe enum instead of a tagged union, a StringMap-backed set instead of
	Set<string>).
**/
class MazeGenerator {
	/**
		Generates a perfect maze (spanning tree — exactly one path between any
		two cells) over the grid via randomized depth-first search.
		@param random source of randomness in [0, 1); defaults to Math.random.
		@return the generated maze's open edges.
	**/
	public static function generate(?random:Void->Float):GridData {
		var rng = random != null ? random : Math.random;
		var visited = new haxe.ds.StringMap<Bool>();
		var openEdges = new haxe.ds.StringMap<Bool>();

		var start = GridModel.allNodes()[0];
		if (start == null) {
			return {openEdges: openEdges};
		}

		var stack:Array<GridNode> = [start];
		visited.set(GridModel.nodeKey(start), true);

		while (stack.length > 0) {
			var current = stack[stack.length - 1];
			if (current == null) {
				break;
			}

			var unvisited = GridModel.neighborsOf(current).filter(neighbor -> !visited.exists(GridModel.nodeKey(neighbor)));
			if (unvisited.length == 0) {
				stack.pop();
				continue;
			}

			var next = unvisited[Math.floor(rng() * unvisited.length)];
			if (next == null) {
				continue;
			}
			openEdges.set(GridModel.edgeKey(current, next), true);
			visited.set(GridModel.nodeKey(next), true);
			stack.push(next);
		}

		return {openEdges: openEdges};
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
