package biomes.ribbon;

/**
	The Ribbon's own layout: how a cell of `RibbonAutomaton`'s spacetime
	diagram maps to a patch of walkable ground, and where the edges of the
	world are.

	**The one idea in this biome.** The strip runs east-west along `x`
	(the automaton's own spatial axis) and **north-south along `z` is
	time** — decreasing `z` is *earlier*. So walking north walks into the
	past, generation by generation, and generation `0` (the initial
	condition somebody typed) sits at `z = 0` with nothing beyond it.
	`docs/game-design/direction/world-and-threads.md` states the design;
	this class is the two lines of arithmetic that make it literal.

	Kept separate from `RibbonBiome` so the mapping is testable without a
	scene graph, the same split `biomes.tower.TowerModel` and
	`biomes.mobius.MobiusModel` already use.
**/
class RibbonModel {
	/**
		Rule 110 — chosen for what it *is*, not for how it looks: it is the
		one elementary rule proved Turing-complete (Cook, 2004), which is
		the evidence
		`docs/game-design/direction/world-and-threads.md` wants the player
		standing on. It also happens to give the best terrain of the
		candidates, growing to one side only, so the diagram is a leaning
		wedge rather than a symmetric cone — asymmetry the player can
		orient by.
	**/
	public static inline final RULE:Int = 110;

	/**
		Cells across the strip — **narrower than it is deep, on purpose.**
		This place is called the Ribbon because it is meant to read as a
		line you walk along, not as a field, and the automaton's own
		spatial axis is the only thing setting its width.
	**/
	public static inline final WIDTH:Int = 61;

	/** Generations deep, including the initial condition — about a hundred seconds of walking end to end at `game.GameLoop.WALK_SPEED`. **/
	public static inline final GENERATIONS:Int = 240;

	/**
		Where the single live cell of generation `0` sits.

		Two cells in from the east edge, because Rule 110 grows *west* only
		(no neighbourhood with a dead centre and dead left produces a live
		cell): seeding mid-strip would waste half the ground on cells that
		are dead in every generation.

		**The wedge reaches the west edge around generation 58**, and what
		happens after that is the reason the strip is this shape rather
		than wide enough to avoid it. Past the wall, Rule 110 settles into
		its own periodic background with gliders running through it — which
		is both the visually interesting regime and the part that actually
		looks like a computation, rather than the smooth triangle of the
		opening generations. Bounded evolution against a dead edge is a
		perfectly well-defined automaton, just not the infinite-line one;
		see `RibbonAutomaton`'s own note on boundaries.
	**/
	public static inline final SEED_INDEX:Int = WIDTH - 3;

	/** World units per cell, each way. Wide enough that a single cell reads as a slab underfoot rather than as texture. **/
	public static inline final CELL_SIZE:Float = 6;

	/**
		How far a live cell stands above a dead one.

		Deliberately far below a step height: this is terrain to *read*,
		not to climb. At walking eye height the relief reads as a raised
		panel from a distance and as a low kerb underfoot, and the player
		never has to navigate it — which is the difference between "the
		past is legible" and "the past is an obstacle course".
	**/
	public static inline final RELIEF:Float = 1.6;

	/**
		How far the ground drops per generation walked into the past —
		**the fix for the first thing this biome got wrong.**

		Built flat first, and flat does not work. `world-and-threads.md`
		gives this space the legibility law *"the past is terrain; you can
		see where you came from, literally, as landscape"*, and a flat
		diagram viewed from a walking eye height delivers none of that: at
		any distance the relief foreshortens to well under a pixel and the
		whole history reads as one uniform grey plane. Verified by
		screenshot, which is exactly what the flat version looked like.

		Tilting the strip so the past lies *below* the present turns the
		diagram into a hillside the player looks down across, which is the
		stated law rather than a workaround for it — and it is free
		geometrically, because a tilted plane is still intrinsically flat,
		so this remains a κ = 0 space with nothing bent.

		It also reads correctly on its own terms: you **descend** into the
		past, and the deeper you go the more of the history stands above
		and behind you.
	**/
	public static inline final DESCENT_PER_GENERATION:Float = 3.0;

	/** Half the strip's own east-west extent. **/
	public static inline final HALF_WIDTH:Float = WIDTH * CELL_SIZE / 2;

	/**
		The far side of generation `0` — **the end of the world**, and the
		thing the whole biome is walked toward. Half a cell beyond the
		oldest row's own centre, so that row is a full tile to stand on
		rather than an edge to fall off.

		Named for time rather than for a compass direction, unlike the
		design doc's own "walk north into the past": in code the two would
		have to be kept in sync by hand, and past/present cannot be got
		backwards.
	**/
	public static inline final PAST_EDGE:Float = -CELL_SIZE / 2;

	/** The far side of the newest generation: the boundary the player spawns against, with their back to it. **/
	public static inline final PRESENT_EDGE:Float = (GENERATIONS - 1) * CELL_SIZE + CELL_SIZE / 2;

	/**
		Which generation a world `z` stands on. Clamped rather than
		rejected, since collision already keeps the player inside the strip
		and a caller should not have to handle a null for a position that
		cannot occur.
		@param z world z.
		@return the generation index, clamped into range.
	**/
	public static function generationAt(z:Float):Int {
		var g = Math.round(z / CELL_SIZE);
		return g < 0 ? 0 : (g > GENERATIONS - 1 ? GENERATIONS - 1 : Std.int(g));
	}

	/**
		Which cell of a generation a world `x` stands on, clamped — see
		`generationAt` for why clamped.
		@param x world x.
		@return the cell index, clamped into range.
	**/
	public static function cellIndexAt(x:Float):Int {
		var i = Math.round((x + HALF_WIDTH) / CELL_SIZE - 0.5);
		return i < 0 ? 0 : (i > WIDTH - 1 ? WIDTH - 1 : Std.int(i));
	}

	/** The world `x` of a cell's own centre. **/
	public static function xOf(index:Int):Float {
		return (index + 0.5) * CELL_SIZE - HALF_WIDTH;
	}

	/** The world `z` of a generation's own centre. **/
	public static function zOf(generation:Int):Float {
		return generation * CELL_SIZE;
	}

	/**
		The height of the strip's own tilted base at a world `z`, ignoring
		cell relief — `0` at generation `0` and rising toward the present.
		Linear in `z`, so the whole base is a single plane and the mesh
		needs no subdivision to follow it.
		@param z world z.
		@return the base height there.
	**/
	public static function baseHeightAt(z:Float):Float {
		return z / CELL_SIZE * DESCENT_PER_GENERATION;
	}

	/**
		How high the ground is directly under `pos`: the tilted base, plus
		`RELIEF` if the cell there is live. Fed straight to
		`biomes.common.Gravity.fallToSurface`'s own `groundHeight`, which
		is what makes the diagram walkable relief rather than a flat
		picture of itself.
		@param automaton the history being walked on.
		@param pos the position to sample under.
		@return the ground height at `pos`.
	**/
	public static function groundHeightAt(automaton:RibbonAutomaton, pos:h3d.Vector):Float {
		var live = automaton.isLive(generationAt(pos.z), cellIndexAt(pos.x));
		return baseHeightAt(pos.z) + (live ? RELIEF : 0);
	}

	/**
		Holds a position inside the strip, per axis independently.

		Per-axis rather than all-or-nothing so that walking into a boundary
		slides along it instead of stopping dead — the same courtesy
		`biomes.common.grid.GridCollision` extends against maze walls, and
		the reason the edges feel like edges of a place rather than like a
		bug.
		@param pos the position to constrain.
		@return `pos` clamped into the strip.
	**/
	public static function clampToBounds(pos:h3d.Vector):h3d.Vector {
		return new h3d.Vector(hxd.Math.clamp(pos.x, -HALF_WIDTH, HALF_WIDTH), pos.y, hxd.Math.clamp(pos.z, PAST_EDGE, PRESENT_EDGE));
	}
}
