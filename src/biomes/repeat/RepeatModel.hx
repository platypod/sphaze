package biomes.repeat;

/**
	The Repeat's layout: a city block generated deterministically, tiled
	across the plane, and the small divergences that make one tile worth
	comparing against the next.

	**This is deliberately not a quotient**, even though
	`geometry.DeckGroup` exists and would make it one.
	`docs/game/world.md` is explicit about
	the distinction and it is the whole design: a true torus has exactly
	*one* tile, rendered repeatedly, so there is nothing to compare and no
	mechanic. What this space needs is **many separate tiles that happen
	to be identical** — same seed, same rule, same future — so that a
	difference means something has actually intervened.

	So the group is used for the parts that are honestly about the
	lattice: where the tiles sit, and which of them to draw.
	`tileIndexAt` and the divergence live here, keyed on the tile's own
	integer coordinates, because those are what distinguish one tile from
	another — which under a real quotient they could not do.

	**Sameness is generated, not copied.** Every plot's building is a pure
	function of its position *within* a tile, with the tile's own
	coordinates deliberately absent from the hash. Two tiles are identical
	because nothing in their construction could make them differ, which is
	exactly the determinism argument the design rests the mechanic on.
**/
class RepeatModel {
	/** Plots along each edge of a tile. **/
	public static inline final PLOTS_PER_TILE:Int = 6;

	/** World units across one plot, street included. **/
	public static inline final PLOT_SIZE:Float = 40;

	/**
		How much of a plot the building fills; the remainder is street.

		Tuned down from `0.7` after looking at it. At that value the
		streets were twelve units wide between buildings up to a hundred
		and ten tall — a slot canyon, in which the player can see two walls
		and nothing else. That is fatal here specifically: the mechanic is
		spot-the-difference against a remembered **skyline**, and a city
		you cannot see across has no skyline to remember.
	**/
	public static inline final BUILDING_FOOTPRINT:Float = 0.55;

	/** One tile's own period — the distance the design's verb ("walk exactly one measured period") is measured in. About sixteen seconds at `game.GameLoop.WALK_SPEED`. **/
	public static inline final TILE_SIZE:Float = PLOTS_PER_TILE * PLOT_SIZE;

	/** Fraction of plots left as open ground rather than built on, so the city has squares and through-routes instead of a uniform grid of blocks. **/
	static inline final EMPTY_PLOT_RATE:Float = 0.36;

	/**
		Height range, low-rise on purpose — see `BUILDING_FOOTPRINT` for
		what the tall version cost. Manifold Garden's register, which this
		space borrows, is big legible geometry seen whole, not Manhattan
		seen from the pavement.
	**/
	static inline final MIN_BUILDING_HEIGHT:Float = 10;

	static inline final MAX_BUILDING_HEIGHT:Float = 52;

	/**
		Fraction of tiles carrying a divergence.

		High for a prototype. The design wants finding one to be an act of
		memory and comparison, which argues for rarity; but a rate low
		enough to be interesting is also low enough that a first playtest
		might walk four tiles and conclude the mechanic is not implemented.
		Tuned down once the mechanic is confirmed to read at all.
	**/
	static inline final DIVERGENCE_RATE:Float = 0.34;

	/**
		Which tile a world position falls in. Tiles are indexed by the
		lattice, so `(0, 0)` is the one containing the origin.
		@param x world x.
		@param z world z.
		@return the tile's own integer coordinates.
	**/
	public static function tileIndexAt(x:Float, z:Float):{i:Int, j:Int} {
		return {i: Math.floor(x / TILE_SIZE), j: Math.floor(z / TILE_SIZE)};
	}

	/** The world position of a tile's own south-west corner. **/
	public static function tileOrigin(i:Int, j:Int):{x:Float, z:Float} {
		return {x: i * TILE_SIZE, z: j * TILE_SIZE};
	}

	/**
		Whether a plot carries a building **in the reference layout** —
		that is, ignoring any divergence. A pure function of the plot's
		position within a tile, with no tile coordinate involved, which is
		what makes every tile identical by construction.
		@param plotX plot column within the tile, `0` to `PLOTS_PER_TILE - 1`.
		@param plotZ plot row within the tile.
		@return true if the reference layout builds here.
	**/
	public static function referenceHasBuilding(plotX:Int, plotZ:Int):Bool {
		return noise(plotX, plotZ, 1) >= EMPTY_PLOT_RATE;
	}

	/** How tall the building on a plot stands. Same determinism as `referenceHasBuilding`. **/
	public static function buildingHeight(plotX:Int, plotZ:Int):Float {
		return MIN_BUILDING_HEIGHT + noise(plotX, plotZ, 2) * (MAX_BUILDING_HEIGHT - MIN_BUILDING_HEIGHT);
	}

	/**
		Which plot of a tile diverges from the reference, or null if this
		tile is one of the untouched ones.

		**The divergence always removes a building**, never adds one, and
		that is the design rather than a simplification: "recognising the
		difference and reaching the new ground are the same act". A missing
		block is somewhere you can walk that you could not walk in the last
		tile; an extra block would be a difference you can only look at.
		@param i the tile's own x coordinate.
		@param j the tile's own z coordinate.
		@return the diverging plot, or null.
	**/
	public static function divergenceOf(i:Int, j:Int):Null<{plotX:Int, plotZ:Int}> {
		if (noise(i, j, 3) >= DIVERGENCE_RATE) {
			return null;
		}
		// Search from a hashed starting plot for one the reference builds
		// on — a divergence that removed an already-empty plot would be no
		// divergence at all, and every tile has plenty of built plots.
		var start = Math.floor(noise(i, j, 4) * PLOTS_PER_TILE * PLOTS_PER_TILE);
		for (offset in 0...PLOTS_PER_TILE * PLOTS_PER_TILE) {
			var plot = (start + offset) % (PLOTS_PER_TILE * PLOTS_PER_TILE);
			var plotX = plot % PLOTS_PER_TILE;
			var plotZ = Std.int(plot / PLOTS_PER_TILE);
			if (referenceHasBuilding(plotX, plotZ)) {
				return {plotX: plotX, plotZ: plotZ};
			}
		}
		return null; // unreachable for any sane EMPTY_PLOT_RATE, but a layout with no buildings has nothing to remove
	}

	/**
		Whether a plot of a *particular* tile actually carries a building —
		the reference layout, minus this tile's own divergence. The one
		function collision and mesh building should both ask, so the thing
		the player can see and the thing they can walk through cannot
		disagree.
		@param i the tile's own x coordinate.
		@param j the tile's own z coordinate.
		@param plotX plot column within the tile.
		@param plotZ plot row within the tile.
		@return true if there is a building standing there.
	**/
	public static function hasBuilding(i:Int, j:Int, plotX:Int, plotZ:Int):Bool {
		if (!referenceHasBuilding(plotX, plotZ)) {
			return false;
		}
		var divergence = divergenceOf(i, j);
		return divergence == null || divergence.plotX != plotX || divergence.plotZ != plotZ;
	}

	/** The world position of a plot's own centre, in the given tile. **/
	public static function plotCentre(i:Int, j:Int, plotX:Int, plotZ:Int):{x:Float, z:Float} {
		var origin = tileOrigin(i, j);
		return {x: origin.x + (plotX + 0.5) * PLOT_SIZE, z: origin.z + (plotZ + 0.5) * PLOT_SIZE};
	}

	/** Half a building's own footprint, so collision and geometry agree on where its walls are. **/
	public static function buildingHalfExtent():Float {
		return PLOT_SIZE * BUILDING_FOOTPRINT / 2;
	}

	/**
		A deterministic value in `[0, 1)` from two integers and a salt.

		Hash-based rather than a seeded PRNG walked in order, because
		every caller here needs to ask about an *arbitrary* plot or tile
		without having generated its neighbours first — collision asks
		about wherever the player happens to be standing, and the mesh
		asks about whatever is currently in view. A sequential generator
		would force the whole plane to be materialised in a fixed order.
		@param a first coordinate.
		@param b second coordinate.
		@param salt distinguishes independent questions about the same coordinates.
		@return a stable pseudo-random value in `[0, 1)`.
	**/
	static function noise(a:Int, b:Int, salt:Int):Float {
		var h = a * 374761393 + b * 668265263 + salt * 1274126177;
		h = (h ^ (h >> 13)) * 1274126177;
		h = h ^ (h >> 16);
		return (h & 0x7FFFFFFF) / 2147483648.0;
	}
}
