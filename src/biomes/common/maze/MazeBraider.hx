package biomes.common.maze;

import biomes.common.maze.MazeTopology.MazeLayout;

/**
	Braids a carved maze: opens extra passages at dead ends, turning some of
	them into loops. A post-pass rather than a `MazeStyle` because it applies
	to the output of any of them (and, unlike all of them, deliberately breaks
	the perfect-maze property they each guarantee).

	The design reason it's worth having, per
	`docs/game-design/inspirations.md`: in a perfect maze a dead end *proves*
	a wrong branch, so the maze can be solved by elimination from inside it.
	Braid it and that stops working — the player has to actually read the
	layout from across the sphere instead of exhausting it up close, which is
	the mechanic this game is built on.
**/
class MazeBraider {
	/**
		Opens a `fraction` of this layout's dead ends, in place.

		Prefers connecting a dead end to *another* dead end where one is
		adjacent — that removes two dead ends per opened passage and tends to
		produce a longer loop than joining onto a through-corridor, which
		otherwise just grows a short stub off the main route.
		@param layout the layout to braid, modified in place.
		@param topology the topology `layout` was carved into.
		@param fraction what proportion of dead ends to open up, in [0, 1] — clamped, so a caller can pass 1 for "no dead ends at all".
		@param random source of randomness in [0, 1); defaults to Math.random.
	**/
	public static function braid(layout:MazeLayout, topology:MazeTopology, fraction:Float, ?random:Void->Float):Void {
		var rng = random != null ? random : Math.random;
		var chance = hxd.Math.clamp(fraction, 0, 1);
		var deadEnds = deadEndsOf(layout, topology);
		var isDeadEnd = new haxe.ds.StringMap<Bool>();
		for (node in deadEnds) {
			isDeadEnd.set(node, true);
		}

		for (node in deadEnds) {
			// Re-checked rather than trusted from the snapshot: an earlier
			// iteration may already have opened this one up as some other
			// dead end's preferred partner, and opening a second passage
			// there would carve a junction nobody asked for.
			if (!isDeadEnd.exists(node) || rng() >= chance) {
				continue;
			}

			var closed = topology.neighborsOf(node).filter((neighbor) -> !MazeEdges.isOpen(layout, node, neighbor));
			if (closed.length == 0) {
				continue;
			}

			var partner = preferDeadEnd(closed, isDeadEnd, rng);
			if (partner == null) {
				continue;
			}
			MazeEdges.open(layout, node, partner);
			isDeadEnd.remove(node);
			isDeadEnd.remove(partner);
		}
	}

	/**
		Every node with exactly one open passage — a dead end. A node with
		*no* open passage isn't one: that's an isolated node, which no style
		in this package produces, and opening a single edge there would
		connect it in a way braiding isn't meant to be responsible for.
		@param layout the layout to inspect.
		@param topology the topology `layout` was carved into.
		@return the dead-end nodes' keys.
	**/
	public static function deadEndsOf(layout:MazeLayout, topology:MazeTopology):Array<String> {
		return topology.nodeKeys().filter((node) -> MazeEdges.openNeighborsOf(layout, topology, node).length == 1);
	}

	/**
		Picks a dead end among `candidates` if there is one, otherwise any
		candidate — see `braid`'s doc for why the preference is worth having.
		@param candidates the neighbors available to open onto; must be non-empty.
		@param isDeadEnd which nodes are still dead ends.
		@param rng source of randomness in [0, 1).
		@return the chosen neighbor.
	**/
	static function preferDeadEnd(candidates:Array<String>, isDeadEnd:haxe.ds.StringMap<Bool>, rng:Void->Float):Null<String> {
		var preferred = candidates.filter((candidate) -> isDeadEnd.exists(candidate));
		var pool = preferred.length > 0 ? preferred : candidates;
		return pool[Math.floor(rng() * pool.length)];
	}
}
