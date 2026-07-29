package biomes.common.maze;

import biomes.common.maze.MazeTopology.MazeLayout;
import biomes.common.maze.MazeTopology.RectangularTopology;

/**
	Carves a maze into any `MazeTopology`, in whichever `MazeStyle` is asked
	for, optionally braided afterward (see `MazeBraider`).

	This exists because the randomized-DFS carve used to be copy-pasted per
	topology — `biomes.maze.MazeGenerator` and `biomes.conway.ConwayMaze` held
	the same loop, over the same string keys, twice — which meant a second
	generation *style* would have had to be written once per topology too. The
	algorithms here only ever touch node keys, adjacency, and (for
	`AxisBiased`) an edge's axis, so every style lands on every present and
	future topology at once. Which style suits which biome is a design
	question, parked in `docs/game-design/ideas-backlog.md`, not decided here.

	Every style produces a **perfect** maze — a spanning tree, exactly one
	path between any two nodes — except where braiding is asked for on top,
	which is the one thing that deliberately breaks that property (and is why
	it's a separate parameter rather than a style of its own).
**/
class MazeCarver {
	/**
		@param topology the surface to carve into.
		@param style which algorithm to carve with.
		@param braidFraction what fraction of dead ends to open up afterward, in [0, 1] — 0 (the default) leaves a perfect maze. See `MazeBraider.braid`.
		@param random source of randomness in [0, 1); defaults to Math.random.
		@return the carved layout.
	**/
	public static function carve(topology:MazeTopology, style:MazeStyle, braidFraction:Float = 0, ?random:Void->Float):MazeLayout {
		var rng = random != null ? random : Math.random;
		var layout = switch style {
			case RandomizedDfs: carveDfs(topology, 1, rng);
			case AxisBiased(alongRowWeight): carveDfs(topology, alongRowWeight, rng);
			case RandomizedPrim: carvePrim(topology, rng);
			case RandomizedKruskal: carveKruskal(topology, rng);
			case RecursiveDivision: RecursiveDivision.carve(asRectangular(topology), rng);
		}
		if (braidFraction > 0) {
			MazeBraider.braid(layout, topology, braidFraction, rng);
		}
		return layout;
	}

	/**
		Randomized depth-first search: walk to a random unvisited neighbor,
		carving as you go, backtracking at a dead end. Long corridors, few
		branches — see `MazeStyle`.

		`alongRowWeight` makes this `AxisBiased` as well as `RandomizedDfs`:
		it multiplies the selection weight of `EdgeAxis.AlongRow` candidates
		against `AcrossRow`/`Irregular` ones at weight 1. At exactly 1 every
		candidate weighs the same, which is a plain uniform pick — the
		original algorithm, preserved loop-for-loop so an existing maze
		generated from a given seed still comes out the same.
		@param topology the surface to carve into.
		@param alongRowWeight relative weight of east-west candidates; must be positive.
		@param rng source of randomness in [0, 1).
		@return the carved layout.
	**/
	static function carveDfs(topology:MazeTopology, alongRowWeight:Float, rng:Void->Float):MazeLayout {
		if (alongRowWeight <= 0) {
			throw 'AxisBiased needs a positive alongRowWeight (got $alongRowWeight)';
		}

		var layout = MazeEdges.emptyLayout();
		var visited = new haxe.ds.StringMap<Bool>();
		var start = topology.nodeKeys()[0];
		if (start == null) {
			return layout;
		}

		var stack:Array<String> = [start];
		visited.set(start, true);

		while (stack.length > 0) {
			var current = stack[stack.length - 1];
			if (current == null) {
				break;
			}

			var unvisited = topology.neighborsOf(current).filter((neighbor) -> !visited.exists(neighbor));
			if (unvisited.length == 0) {
				stack.pop();
				continue;
			}

			var next = alongRowWeight == 1 ? unvisited[Math.floor(rng() * unvisited.length)] : pickWeightedByAxis(topology, current, unvisited,
				alongRowWeight, rng);
			if (next == null) {
				continue;
			}
			MazeEdges.open(layout, current, next);
			visited.set(next, true);
			stack.push(next);
		}

		return layout;
	}

	/**
		Picks one of `candidates` with `EdgeAxis.AlongRow` ones weighted
		`alongRowWeight` times as likely as the rest — plain roulette-wheel
		selection over the running weight total.
		@param topology the topology the candidates belong to.
		@param from the node the candidates are neighbors of.
		@param candidates the neighbors to choose between; must be non-empty.
		@param alongRowWeight relative weight of east-west candidates.
		@param rng source of randomness in [0, 1).
		@return the chosen neighbor.
	**/
	static function pickWeightedByAxis(topology:MazeTopology, from:String, candidates:Array<String>, alongRowWeight:Float, rng:Void->Float):Null<String> {
		var total = 0.0;
		for (candidate in candidates) {
			total += weightOf(topology, from, candidate, alongRowWeight);
		}

		var draw = rng() * total;
		for (candidate in candidates) {
			draw -= weightOf(topology, from, candidate, alongRowWeight);
			if (draw <= 0) {
				return candidate;
			}
		}
		// Floating-point residue only — the loop above consumes the whole
		// total in exact arithmetic. Falling back to the last candidate is
		// the same choice `draw <= 0` would have made one iteration later.
		return candidates[candidates.length - 1];
	}

	static function weightOf(topology:MazeTopology, from:String, to:String, alongRowWeight:Float):Float {
		return switch topology.axisOf(from, to) {
			case AlongRow: alongRowWeight;
			case AcrossRow: 1;
			case Irregular: 1;
		}
	}

	/**
		Randomized Prim: keep a frontier of edges from the carved region to
		everything outside it, and repeatedly carve a random one. Grows
		outward from a single seed in every direction at once, which is what
		gives it many short dead-ends instead of DFS's long corridors.
		@param topology the surface to carve into.
		@param rng source of randomness in [0, 1).
		@return the carved layout.
	**/
	static function carvePrim(topology:MazeTopology, rng:Void->Float):MazeLayout {
		var layout = MazeEdges.emptyLayout();
		var visited = new haxe.ds.StringMap<Bool>();
		var start = topology.nodeKeys()[0];
		if (start == null) {
			return layout;
		}

		visited.set(start, true);
		var frontier:Array<MazeEdges.MazeEdge> = [for (neighbor in topology.neighborsOf(start)) {a: start, b: neighbor}];

		while (frontier.length > 0) {
			var pick = Math.floor(rng() * frontier.length);
			var edge = frontier[pick];
			// Swap-remove rather than splice: order in the frontier carries
			// no meaning (the pick is uniform), so there's no reason to pay
			// for shifting the tail every step.
			var last = frontier.pop();
			if (edge != null && last != null && pick < frontier.length) {
				frontier[pick] = last;
			}
			if (edge == null || visited.exists(edge.b)) {
				continue;
			}

			MazeEdges.open(layout, edge.a, edge.b);
			visited.set(edge.b, true);
			for (neighbor in topology.neighborsOf(edge.b)) {
				if (!visited.exists(neighbor)) {
					frontier.push({a: edge.b, b: neighbor});
				}
			}
		}

		return layout;
	}

	/**
		Randomized Kruskal: shuffle every edge and carve each one whose two
		ends aren't already connected, tracked with a union-find. No growth
		bias at all — it carves all over the topology at once, so unlike Prim
		there's no seed the maze visibly radiates from.
		@param topology the surface to carve into.
		@param rng source of randomness in [0, 1).
		@return the carved layout.
	**/
	static function carveKruskal(topology:MazeTopology, rng:Void->Float):MazeLayout {
		var layout = MazeEdges.emptyLayout();
		var edges = MazeEdges.allEdges(topology);
		MazeEdges.shuffle(edges, rng);

		var parent = new haxe.ds.StringMap<String>();
		for (edge in edges) {
			var rootA = findRoot(parent, edge.a);
			var rootB = findRoot(parent, edge.b);
			if (rootA == rootB) {
				continue;
			}
			parent.set(rootA, rootB);
			MazeEdges.open(layout, edge.a, edge.b);
		}

		return layout;
	}

	/**
		Union-find root of `node`, with path compression. Absent keys are
		their own root, so the forest needs no initialization pass over every
		node.
		@param parent the forest, as child -> parent links.
		@param node the node to find the root of.
		@return `node`'s root.
	**/
	static function findRoot(parent:haxe.ds.StringMap<String>, node:String):String {
		var current = node;
		while (true) {
			var next = parent.get(current);
			if (next == null || next == current) {
				break;
			}
			current = next;
		}
		// Second pass to point everything on the path straight at the root —
		// the compression half of union-find, without which repeated finds on
		// a long chain degrade to linear.
		var walk = node;
		while (walk != current) {
			var next = parent.get(walk);
			parent.set(walk, current);
			if (next == null) {
				break;
			}
			walk = next;
		}
		return current;
	}

	/**
		Narrows `topology` to a `RectangularTopology`, for the one style that
		can't work without one.
		@param topology the topology to narrow.
		@return the same topology, typed as rectangular.
	**/
	static function asRectangular(topology:MazeTopology):RectangularTopology {
		if (!Std.isOfType(topology, RectangularTopology)) {
			throw 'MazeStyle.RecursiveDivision needs a RectangularTopology; ${Type.getClassName(Type.getClass(topology))} is not one';
		}
		return cast topology;
	}
}
