package biomes.weft;

import biomes.common.grid.GridModel;
import biomes.common.grid.GridModel.GridData;
import biomes.common.grid.GridModel.GridNode;

/**
	The Weft's one authored idea: **every wall answers to the wall at its
	antipode, and the two are always in opposite states.**

	**No manifold trick.** The sphere is the same sphere the Fold walks —
	nothing is glued, there is exactly one of the player, and every
	location is where you would expect it to be. What is added is a *rule
	laid over* the geometry, which is precisely what
	`docs/game-design/direction/world-and-threads.md` says the space is
	for: the correspondence is authored, has no geometric necessity behind
	it, and is therefore the first evidence in the game that *someone
	decided these two things would answer to each other*.

	That entry also carries a correction worth not undoing. This space was
	once "the projective plane, walkable" — a real quotient — and that was
	abandoned because a quotient has only *one* wall per identified edge,
	so there is nothing for it to be opposite *to*. Everything here keeps
	two distinct walls at two distinct places.

	**Where the rule cannot apply, and why that is geometry rather than
	laziness.** `GridModel`'s rows carry different column counts by
	latitude, and the two rows nearest each pole have an **odd** count
	(`COLS / 4` = 7). The antipodal map shifts a row by half its columns,
	which on an odd row lands on a cell *boundary* rather than a cell — so
	the map is not an involution there, and no fixed-point-free pairing of
	an odd number of cells exists at all. Those rows are simply unpaired.
	The design's own "Exists" note anticipates a pole edge case; this is
	it, in the exact place it predicted.
**/
class WeftModel {
	/**
		The node diametrically opposite this one — `theta → pi - theta`,
		`phi → phi + pi`, the transform the design names.

		Poles swap. A ring node is resolved through `GridModel.nodeAt`
		rather than by arithmetic on `(row, col)`, so it stays correct
		whatever `colsForRow` does — including the odd rows where the
		result will not be involutive, which `isPairable` is what catches.
		@param node the node to reflect.
		@return the node at its antipode.
	**/
	public static function antipodeOf(node:GridNode):GridNode {
		return switch node {
			case PoleNode(North): PoleNode(South);
			case PoleNode(South): PoleNode(North);
			case RingNode(_, _):
				var centre = GridModel.centerOf(node);
				GridModel.nodeAt(Math.PI - centre.theta, (centre.phi + Math.PI) % (2 * Math.PI));
		}
	}

	/**
		Whether a node's antipode is a genuine partner: distinct from it,
		and mapping back. Checked rather than assumed — see the class doc
		for the odd-column rows where it fails.
		@param node the node to test.
		@return true if the pairing is a fixed-point-free involution here.
	**/
	public static function isPairable(node:GridNode):Bool {
		var partner = antipodeOf(node);
		var back = antipodeOf(partner);
		return !sameNode(node, partner) && sameNode(node, back);
	}

	/**
		The wall paired with the one between `a` and `b`, or null if this
		wall has no partner — either because an endpoint sits on an
		unpairable row, or because the antipodal pair is not adjacent and
		so names no wall at all.
		@param a one end of the wall's own edge.
		@param b the other end.
		@return the partner edge's endpoints, or null.
	**/
	public static function partnerOf(a:GridNode, b:GridNode):Null<{a:GridNode, b:GridNode}> {
		if (!isPairable(a) || !isPairable(b)) {
			return null;
		}
		var pa = antipodeOf(a);
		var pb = antipodeOf(b);
		if (sameNode(pa, a) || sameNode(pb, b)) {
			return null;
		}
		if (GridModel.edgeKey(pa, pb) == GridModel.edgeKey(a, b)) {
			return null; // a wall cannot be its own opposite
		}
		for (neighbor in GridModel.neighborsOf(pa)) {
			if (sameNode(neighbor, pb)) {
				return {a: pa, b: pb};
			}
		}
		return null;
	}

	/**
		Forces the invariant across the whole sphere: **a paired wall and
		its partner are never in the same state.**

		Within each antipodal *pair* one edge is authoritative and the
		other is made its complement, chosen by edge key so the result does
		not depend on iteration order. Note that this is per pair, not per
		hemisphere — the key ordering is arbitrary, so the authoritative
		edges are scattered over the whole sphere. (An earlier version of
		this comment said "one hemisphere is taken as authoritative", which
		is not what the code does.)

		The *result* is per-hemisphere all the same, and is the space's own
		character rather than a side effect: **the far side of the world is
		the photographic negative of the near side.** Every corridor here
		is a wall there.

		Pleasantly, both sides still read as mazes. A spanning-tree carve
		opens roughly half a grid's edges, so its complement is also
		roughly half — the negative hemisphere is not the open plain one
		might expect.

		**Connectivity is not preserved, and that is left standing.** The
		carve guarantees every cell is reachable; complementing half the
		edges destroys that guarantee, so the negative side can hold loops
		and sealed pockets. It is survivable rather than a bug, because
		this space's whole verb is opening walls: a player enclosed
		anywhere paired can always toggle their way out. A Weft that wants
		an authored *puzzle* will need its own generator — carve,
		complement, then repair — rather than the Fold's.
		@param grid the layout to constrain, modified in place.
	**/
	public static function enforceOpposite(grid:GridData):Void {
		for (node in GridModel.allNodes()) {
			for (neighbor in GridModel.neighborsOf(node)) {
				var partner = partnerOf(node, neighbor);
				if (partner == null) {
					continue;
				}
				var key = GridModel.edgeKey(node, neighbor);
				var partnerKey = GridModel.edgeKey(partner.a, partner.b);
				if (key >= partnerKey) {
					continue; // the other half of the pair is the authoritative one
				}
				setOpen(grid, partner.a, partner.b, !GridModel.isOpen(grid, node, neighbor));
			}
		}
	}

	/**
		Flips one wall, and its partner with it — so the invariant survives
		and, from the player's side, **closing a wall here opens the one at
		its antipode**.
		@param grid the layout to change, modified in place.
		@param a one end of the wall to flip.
		@param b the other end.
		@return true if anything changed; false if this wall has no partner and so is not the player's to move.
	**/
	public static function toggle(grid:GridData, a:GridNode, b:GridNode):Bool {
		var partner = partnerOf(a, b);
		if (partner == null) {
			return false;
		}
		var opened = !GridModel.isOpen(grid, a, b);
		setOpen(grid, a, b, opened);
		setOpen(grid, partner.a, partner.b, !opened);
		return true;
	}

	/** Whether a wall obeys the rule at all — what the player may act on, and what the ghost view is worth reading. **/
	public static function isPaired(a:GridNode, b:GridNode):Bool {
		return partnerOf(a, b) != null;
	}

	/**
		Opens or closes one wall.

		**`GridData.openEdges` is a presence set, not a map of booleans**,
		despite being typed `StringMap<Bool>`: `GridModel.isOpen` asks
		`exists`, never `get`, so the stored value is never read and
		closing an edge means *removing* its key. Writing `set(key, false)`
		leaves the edge reading as open — which is exactly what the first
		version of this did, and what `WeftModelTest` caught on its first
		run with "the wall itself did not flip".
	**/
	static function setOpen(grid:GridData, a:GridNode, b:GridNode, open:Bool):Void {
		var key = GridModel.edgeKey(a, b);
		if (open) {
			grid.openEdges.set(key, true);
		} else {
			grid.openEdges.remove(key);
		}
	}

	static function sameNode(a:GridNode, b:GridNode):Bool {
		return GridModel.nodeKey(a) == GridModel.nodeKey(b);
	}
}
