package biomes.mobius;

import biomes.common.space.mobius.MobiusMath;

/**
	The Möbius biome's own topology constants and queries — pure, no scene
	graph, same split `biomes.tower.TowerModel` keeps from `TowerMesh`/
	`TowerBiome`. Started as a bare ribbon (just `isWithinEdge`'s own edge
	boundary, no obstacles) to evaluate the twisted shape and the walk-
	around-and-return-mirrored feel in isolation first, per
	`docs/game-design/philosophy.md`'s "prototype the cheapest version first" pillar —
	now also carries the forest's own constants (see the block below), the
	first obstacle layout built on top of that bare ribbon.
**/
class MobiusModel {
	/** First twist count to actually look at — odd, so the ribbon stays one-sided (a real Möbius strip); try other values by constructing `biomes.mobius.MobiusBiome` with a different one. **/
	public static inline final DEFAULT_TWISTS:Int = 3;

	/** The loop's own centerline radius — 10x the original first-pass value ("make it 10 times bigger in every direction"). **/
	public static inline final RADIUS:Float = 400;

	/**
		Half the ribbon's own width, across `v` — length kept the same,
		width tripled again on top of the earlier 10x pass ("same length,
		but thrice the width"). `MobiusMath`'s own precondition only ever
		strictly required `HALF_WIDTH < RADIUS` (so `radius + v*cos(theta)`
		never reaches 0) — a real requirement, not just a safety margin —
		and this ratio (~1:2.2) still clears it with plenty of room.
	**/
	public static inline final HALF_WIDTH:Float = 180;

	/** How far short of the ribbon's true edge a player is stopped — same role as `biomes.tower.TowerCollision.COLLISION_CLEARANCE`. **/
	public static inline final COLLISION_CLEARANCE:Float = 1;

	/** How thick each safety wall is, measured inward from the ribbon's own open edge. **/
	public static inline final WALL_THICKNESS:Float = 4;

	/** Half the player's own eye height (`entities.player.Camera.EYE_HEIGHT / 2`) — the requested low parapet height. **/
	public static inline final WALL_HEIGHT:Float = 3;

	/**
		Whether `v` is still within the ribbon's own walkable width, stopping
		at the inside face of the safety wall and short of that by
		`COLLISION_CLEARANCE`.
		@param v across-width offset from the centerline.
		@return true if `v` hasn't crossed the ribbon's own edge.
	**/
	public static inline function isWithinEdge(v:Float):Bool {
		return Math.abs(v) <= HALF_WIDTH - WALL_THICKNESS - COLLISION_CLEARANCE;
	}

	/**
		Where a fresh arrival stands — the loop's own `u = 0`, dead center
		across the width (`v = 0`).
		@param twists half-twists over one full lap around the loop.
		@return the entrance spawn position.
	**/
	public static function spawnPosition(twists:Int):h3d.Vector {
		return MobiusMath.pointAt(0, 0, twists, RADIUS);
	}

	/**
		Which way a fresh arrival faces — along the ribbon's own length
		(`tu`), the direction of increasing `u`.
		@param twists half-twists over one full lap around the loop.
		@return the entrance spawn forward direction.
	**/
	public static function spawnForward(twists:Int):h3d.Vector {
		return MobiusMath.localFrameAt(0, 0, twists, RADIUS).tu;
	}

	// --- Forest (biomes.mobius.MobiusForestGenerator/MobiusCollision/MobiusMesh) ---
	// First-pass values, all retune-by-feel — see MobiusForestGenerator's own
	// class doc for how they interact (spacing vs. area vs. convergence).

	/** How many trees the generator aims for — a first-pass "proper forest" density, not a derived constant. **/
	public static inline final TARGET_TREE_COUNT:Int = 2500;

	/**
		Minimum center-to-center distance between two trees' own trunks —
		"fully dense, weave required" (direct ask: no guaranteed clear lane),
		but still enough room that a player-sized body can physically fit
		between two trunks at their closest.
	**/
	public static inline final MIN_TREE_SPACING:Float = 12;

	/** How far in from the ribbon's true edge a tree's own canopy stays clear of, on top of the player's own `COLLISION_CLEARANCE` — keeps a tree's foliage from visibly hanging off the ribbon. **/
	public static inline final TREE_EDGE_MARGIN:Float = 15;

	/** How close to the entrance spawn point no tree is allowed to root — a fresh arrival should never spawn inside a trunk. **/
	public static inline final TREE_SPAWN_CLEARANCE:Float = 20;

	/** Cap on scatter attempts before `MobiusForestGenerator.generate` gives up and returns however many trees it placed — a safety valve against `MIN_TREE_SPACING`/`TARGET_TREE_COUNT` combinations dense enough that rejection sampling would otherwise search close to forever. **/
	public static inline final TREE_SCATTER_MAX_ATTEMPTS:Int = 200000;

	public static inline final TRUNK_HEIGHT_MIN:Float = 8;
	public static inline final TRUNK_HEIGHT_MAX:Float = 16;
	public static inline final TRUNK_RADIUS_MIN:Float = 1.2;
	public static inline final TRUNK_RADIUS_MAX:Float = 2.2;
	public static inline final FOLIAGE_RADIUS_MIN:Float = 3.5;
	public static inline final FOLIAGE_RADIUS_MAX:Float = 5.5;
	public static inline final FOLIAGE_HEIGHT_MIN:Float = 6;
	public static inline final FOLIAGE_HEIGHT_MAX:Float = 10;

	/** How far a tree's own root is lifted off the ribbon surface, along local `up` — same z-fighting-avoidance role as `biomes.common.grass.GrassMesh.ROOT_LIFT`. **/
	public static inline final TREE_ROOT_LIFT:Float = 0.05;

	/**
		Where the forest's own unavoidable Möbius normal-sign branch cut lives.
		Kept opposite the spawn seam so the visually obvious "strip connects to
		itself here" region doesn't make tree meshes swap sides underfoot.
	**/
	public static inline final TREE_FRAME_CUT_U:Float = 3.141592653589793;
}
