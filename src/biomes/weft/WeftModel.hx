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
	`docs/game/world.md` says the space is
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
		Half the grid whose theta is short of the equator — `centerOf`'s own
		coordinate, so it agrees with everything else that reads a node's
		position, and small enough that a row-boundary edge spanning rows 6
		and 7 (the only rows whose average theta lands exactly on π/2) needs
		its own tie-break rather than a false read from float error.
	**/
	static inline final EQUATOR_EPSILON:Float = 1e-6;

	/**
		Which hemisphere an edge belongs to, by the average theta of its two
		endpoints — `enforceOpposite`'s own generating/mirrored split. A
		pole counts as theta 0 or π, same as `GridModel.centerOf` already
		gives it.

		**Well-defined for every pairable edge but the true equator seam.**
		`antipodeOf` maps row `r` to row `13 - r`, so a same-row edge or a
		cross-row edge between rows on the same side of the equator always
		pairs with an edge entirely on the other side — except the one
		row-boundary that sits *on* the equator (rows 6 and 7, whose average
		theta is exactly π/2), which pairs with another edge on that same
		seam. `null` there rather than an arbitrary true/false, so the
		caller can fall back to a different, still-deterministic rule
		instead of silently mislabelling a hemisphere that doesn't apply.
		@param a one end of the edge.
		@param b the other end.
		@return true if north, false if south, null if the edge is the equator seam itself.
	**/
	static function isNorthern(a:GridNode, b:GridNode):Null<Bool> {
		var thetaA = GridModel.centerOf(a).theta;
		var thetaB = GridModel.centerOf(b).theta;
		var midpoint = (thetaA + thetaB) / 2;
		if (Math.abs(midpoint - Math.PI / 2) < EQUATOR_EPSILON) {
			return null;
		}
		return midpoint < Math.PI / 2;
	}

	/**
		Forces the invariant across the whole sphere: **a paired wall and
		its partner are never in the same state.**

		**The northern hemisphere generates; the southern hemisphere is its
		mirror.** Within each antipodal pair, the edge in the north (per
		`isNorthern`) is left exactly as the base carve made it; its
		southern partner is forced to the opposite. `antipodeOf` maps row
		`r` to row `13 - r`, so this split is total — a paired edge is
		always north-with-south, never north-with-north — except the single
		row boundary sitting exactly on the equator, which pairs with
		itself in that sense and falls back to comparing edge keys, same as
		this function used to do everywhere.

		**An earlier version of this split was by edge key alone**, scattered
		arbitrarily across the whole sphere rather than by hemisphere — technically
		satisfying the invariant, but with no relationship a player standing
		anywhere could actually see: the "authoritative" edge near them was
		as likely to be the one forced from its partner as the one setting
		it, so the far side read as unrelated noise rather than a legible
		negative. That was flagged directly ("no symmetry in the maze").
		The hemisphere split is what the design always described — *the far
		side of the world is the photographic negative of the near side* —
		made into the actual generating rule instead of an emergent
		description of a scattered one.

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
				var northern = isNorthern(node, neighbor);
				var isSouth = northern != null ? !northern : edgeKeyIsHigher(node, neighbor, partner);
				if (isSouth) {
					continue; // the antipodal partner is the generating edge; this one is set from it, on that pass
				}
				setOpen(grid, partner.a, partner.b, !GridModel.isOpen(grid, node, neighbor));
			}
		}
	}

	/** The equator-seam tie-break `isNorthern` cannot make — same rule this function used everywhere before the hemisphere split. **/
	static function edgeKeyIsHigher(a:GridNode, b:GridNode, partner:{a:GridNode, b:GridNode}):Bool {
		return GridModel.edgeKey(a, b) >= GridModel.edgeKey(partner.a, partner.b);
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
