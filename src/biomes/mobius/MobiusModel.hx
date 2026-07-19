package biomes.mobius;

import biomes.common.space.mobius.MobiusMath;

/**
	The Möbius biome's own topology constants and queries — pure, no scene
	graph, same split `biomes.tower.TowerModel` keeps from `TowerMesh`/
	`TowerBiome`. A bare walkable ribbon for this first pass (see
	`docs/game-design.md`'s backlog and the "prototype the cheapest version
	first" pillar): no maze/wall/gap layout, just edge-of-strip boundaries
	(`isWithinEdge`) — evaluating the twisted shape and the walk-around-and-
	return-mirrored feel in isolation, before any obstacle layout gets
	designed on top of it.
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

	/**
		Whether `v` is still within the ribbon's own walkable width, short of
		its true edge by `COLLISION_CLEARANCE`.
		@param v across-width offset from the centerline.
		@return true if `v` hasn't crossed the ribbon's own edge.
	**/
	public static inline function isWithinEdge(v:Float):Bool {
		return Math.abs(v) <= HALF_WIDTH - COLLISION_CLEARANCE;
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
}
