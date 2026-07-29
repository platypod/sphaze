package biomes.common.maze;
import biomes.common.maze.MazeTopology.MazeLayout;

/** One edge of a topology, as the pair of node keys it joins. **/
typedef MazeEdge = {a:String, b:String};

/**
	Edge bookkeeping shared by every carver and post-pass in this package:
	the key format, enumerating a topology's edges once without duplicates,
	and the open/closed queries the algorithms need while carving.

	The key format is deliberately identical to
	`biomes.common.grid.GridModel.edgeKey`'s (sorted pair joined by `|`) —
	that's what makes a layout carved here readable by every existing
	consumer and by every maze JSON exported before this package existed.
	`GridModel.edgeKey` stays where it is rather than delegating here: it's
	the query path the mesh and collision code call per frame, and it has no
	business depending on the generation package.
**/
class MazeEdges {
	/**
		Stable key for the edge between two nodes, independent of the order
		they're given in.
		@param a one endpoint's key.
		@param b the other endpoint's key.
		@return the edge's stable key.
	**/
	public static function edgeKey(a:String, b:String):String {
		return a < b ? '$a|$b' : '$b|$a';
	}

	/**
		Every edge of `topology`, each appearing once — `neighborsOf` reports
		adjacency from both ends, so this deduplicates by `edgeKey`.
		@param topology the topology to enumerate.
		@return every edge, in a deterministic order derived from `nodeKeys`/`neighborsOf`.
	**/
	public static function allEdges(topology:MazeTopology):Array<MazeEdge> {
		var seen = new haxe.ds.StringMap<Bool>();
		var edges:Array<MazeEdge> = [];
		for (node in topology.nodeKeys()) {
			for (neighbor in topology.neighborsOf(node)) {
				var key = edgeKey(node, neighbor);
				if (seen.exists(key)) {
					continue;
				}
				seen.set(key, true);
				edges.push({a: node, b: neighbor});
			}
		}
		return edges;
	}

	/**
		Whether `layout` has an open passage between two adjacent nodes.
		@param layout the layout to query.
		@param a one endpoint's key.
		@param b the other endpoint's key.
		@return true if that edge is open.
	**/
	public static function isOpen(layout:MazeLayout, a:String, b:String):Bool {
		return layout.openEdges.exists(edgeKey(a, b));
	}

	/**
		Opens the edge between two adjacent nodes.
		@param layout the layout to modify.
		@param a one endpoint's key.
		@param b the other endpoint's key.
	**/
	public static function open(layout:MazeLayout, a:String, b:String):Void {
		layout.openEdges.set(edgeKey(a, b), true);
	}

	/**
		Closes the edge between two adjacent nodes — needed by
		`RecursiveDivision`, which starts from a fully open field and adds
		walls, unlike every other style here.
		@param layout the layout to modify.
		@param a one endpoint's key.
		@param b the other endpoint's key.
	**/
	public static function close(layout:MazeLayout, a:String, b:String):Void {
		layout.openEdges.remove(edgeKey(a, b));
	}

	/**
		Which of `node`'s neighbors it currently has an open passage to.
		@param layout the layout to query.
		@param topology the topology `node` belongs to.
		@param node the node to inspect.
		@return the neighbors reachable from `node` right now.
	**/
	public static function openNeighborsOf(layout:MazeLayout, topology:MazeTopology, node:String):Array<String> {
		return topology.neighborsOf(node).filter((neighbor) -> isOpen(layout, node, neighbor));
	}

	/** @return an empty layout — nothing open, i.e. every edge a wall. **/
	public static function emptyLayout():MazeLayout {
		return {openEdges: new haxe.ds.StringMap<Bool>()};
	}

	/**
		Fisher-Yates, in place, on a caller-supplied randomness source —
		`RandomizedKruskal` needs a shuffled edge list, and `Array.sort` with
		a random comparator is not a shuffle (it's a biased mess that can
		also break the sort's own invariants).
		@param items the array to shuffle in place.
		@param rng source of randomness in [0, 1).
	**/
	public static function shuffle<T>(items:Array<T>, rng:Void->Float):Void {
		var i = items.length;
		while (i > 1) {
			i--;
			var j = Math.floor(rng() * (i + 1));
			var swap = items[i];
			var other = items[j];
			if (swap == null || other == null) {
				continue;
			}
			items[i] = other;
			items[j] = swap;
		}
	}
}
