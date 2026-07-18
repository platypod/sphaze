package biomes.hub;

import biomes.common.space.sphere.SphereMath;
import entities.painting.PaintingModel;

/**
	The hub's own state and pure geometry queries — no scene graph here (see
	`HubMesh` for the actual mesh building), same `Model`/`Mesh` split
	`biomes.common.grid.GridModel`/`GridMesh` already use.

	Conceptually: a large sphere with a freestanding octagonal column through
	its middle — the diegetic menu space reached by walking into a painting
	instead of a UI overlay (see `docs/PROJECT_LOG.md`'s 2026-07-17 entry for
	the decision and its rejected alternative, and its later entry for this
	bigger redesign).

	The player is always confined to this sphere's own surface (same
	`Player`/`SphereMath` convention biomes use), which rules out a column
	shaped like a smaller *concentric* sphere: the true nearest-point
	distance from any point on the outer sphere to a sphere concentric with
	it is the constant `RADIUS - innerRadius` everywhere, so walking around
	never gets any closer to one. A column with a *constant* cross-section
	radius (a straight prism, not scaled by `sin(theta)` the way the outer
	sphere's own cross-section is) doesn't have that problem: the player's
	own distance from the column's axis shrinks as they walk toward a pole,
	so it eventually meets the prism's fixed radius somewhere — a real,
	walkable, touchable wall.

	`COLUMN_RADIUS`/`COLUMN_HALF_HEIGHT` are chosen so the column's flat end
	caps sit exactly flush against the sphere's own inner wall — no gap, no
	poking through — rather than tapering to the literal pole points, which
	would need a hand-profiled bicone/capsule mesh generator for a purely
	architectural centerpiece. The same single `isInside` check blocks the
	player from ever reaching either sealed-off polar cap beyond it, without
	needing a separate latitude check.
**/
class HubModel {
	/**
		This sphere's own radius — no longer `biomes.common.grid.GridGeometry.RADIUS`; the
		hub isn't biome-scale. Doubled from an initial `35` after hooman
		found that scale disorienting.
	**/
	public static inline final RADIUS:Float = 70;

	/**
		The column's fixed distance from its own pole-to-pole axis. Halved
		from an initial `42` (a 3-4-5-ratio fit against `RADIUS`) after
		hooman found the column too large relative to the room — no longer
		lands on a clean integer ratio, but "flush against the sphere, no
		gap" (see `COLUMN_HALF_HEIGHT`) doesn't require one, just the right
		formula.
	**/
	public static inline final COLUMN_RADIUS:Float = 21;

	/** Half the column's length along its axis — chosen (with RADIUS/COLUMN_RADIUS) so its end caps sit exactly flush against the sphere's inner wall: `sqrt(RADIUS^2 - COLUMN_RADIUS^2)`. **/
	public static inline final COLUMN_HALF_HEIGHT:Float = 66.7757;

	public static inline final COLUMN_SIDES = 8;

	/** Extra margin `isInside` blocks at, short of the column's actual rendered face — same role as `biomes.common.grid.GridGeometry.COLLISION_CLEARANCE` plays for biomes. **/
	static inline final COLLISION_CLEARANCE:Float = 1;

	/**
		Height (along the column's own axis) a face painting's own *bottom
		edge* sits at — deliberately mounted near the pole, not 0
		(equatorial, the column's widest cross-section and so the room's
		most spacious walking band): the player's own distance from the
		column's axis and their height are the same function of `theta`
		(`RADIUS*sin(theta)` and `RADIUS*cos(theta)` respectively), so the
		closest they can ever get to the column at all is right at the
		collision boundary itself — near the *top* of the walkable band,
		not the middle. A painting mounted at the equator would sit a full
		corridor-width (14 units) away from anywhere the player can
		actually stand.

		This whole neighborhood turned out to be a real, numerically-
		confirmed squeeze, not a tuning knob: right where the column meets
		the sphere (deep in "near the pole" territory, where the sphere's
		own surface is steep), the *floor* the player can walk right up to
		is itself within a fraction of a unit of `COLUMN_HALF_HEIGHT` — so
		a painting sized anywhere close to a normal wall-mounted one (this
		project's other paintings fill most of a 12-unit-tall wall) has
		nowhere to sit that's both below the column's own cap and above
		that floor. Reported twice: first as the painting's lower half
		swallowed by the floor (this constant alone raised, `57`→`61`,
		wasn't enough — a scratch script bisecting the *actual* worst-case
		approach, bounded by `PAINTING_TRIGGER_DISTANCE` rather than raw
		collision, showed `61` still overlapped the floor at some
		approaches and *also* overshot `COLUMN_HALF_HEIGHT`, a second bug
		that first script run caught), then as "much bigger, filling the
		wall" — both resolved together by widening
		`PAINTING_TRIGGER_DISTANCE` instead of moving this constant alone:
		a bigger trigger radius pushes the closest reachable approach
		further from the pole, where the floor is meaningfully lower,
		opening up real vertical room. `57.4558`/`PAINTING_HEIGHT_SPAN`
		below are the bottom edge and total height a bisection search found
		that (a) stays `0.3` clear of `COLUMN_HALF_HEIGHT` at the top and
		(b) stays `0.3` clear of the floor at the closest reachable
		approach (now bounded by the wider `PAINTING_TRIGGER_DISTANCE`) at
		the bottom — re-run that search (not hand algebra; see
		`docs/PROJECT_LOG.md`'s own entry on why the naive version of this
		kept predicting the wrong direction) whenever `RADIUS`/
		`COLUMN_RADIUS`/`PAINTING_TRIGGER_DISTANCE` change.
	**/
	static inline final PAINTING_HEIGHT:Float = 57.4558;

	/** A face painting's own total height, floor-clearance to top edge — see `PAINTING_HEIGHT`'s own doc for how this was derived alongside it. Public so `HubMesh` can share it (see `toBiomeFaceEdge`'s own doc on why `baseHeight` is always `0` here). **/
	public static inline final PAINTING_HEIGHT_SPAN:Float = 9.0199;

	/**
		How close the player needs to walk to trigger the to-biome painting
		— `PaintingModel.TRIGGER_DISTANCE` (4) doesn't clear the gap at
		this scale. Doubles as the knob that sets how close a player can
		physically get to a mounted painting at all (see `PAINTING_HEIGHT`'s
		own doc): raised well past the minimum needed just to avoid an
		instant re-trigger, specifically to push the closest reachable
		approach far enough from the pole that there's real vertical room
		for a big painting between the floor and `COLUMN_HALF_HEIGHT`.
	**/
	static inline final PAINTING_TRIGGER_DISTANCE:Float = 20;

	/** Where the player spawns entering the hub: the equator — the room's widest, most open point, not particularly close to the column (see `PAINTING_HEIGHT`'s own doc for why that's the *least* reachable latitude, not the most). **/
	public static final SPAWN_THETA:Float = Math.PI / 2;

	public static final SPAWN_PHI:Float = Math.PI / COLUMN_SIDES;

	/**
		A painting back to a biome, mounted on `faceIndex` at
		`PAINTING_HEIGHT` — matches exactly where `HubMesh.buildColumn`
		renders it. Takes the destination biome's id rather than hardcoding
		one so `HubModel` itself stays biome-agnostic — see
		`biomes.hub.HubBiome`, which is what actually knows which face leads
		to which biome.
		@param faceIndex which of the column's `COLUMN_SIDES` faces this painting mounts on.
		@param destinationBiomeId the `biomes.common.Biome.id()` this painting leads to.
		@return the hub's exit painting for that destination.
	**/
	public static function toBiomePainting(faceIndex:Int, destinationBiomeId:String):PaintingModel {
		var left = toBiomeFaceEdge(faceIndex, true);
		var right = toBiomeFaceEdge(faceIndex, false);
		var center = PaintingModel.centerOf(left, right, 0, PAINTING_HEIGHT_SPAN, new h3d.Vector(0, 1, 0));
		return new PaintingModel(center, destinationBiomeId, PAINTING_TRIGGER_DISTANCE);
	}

	/**
		`faceIndex`'s left or right edge, at `PAINTING_HEIGHT` — the shared
		reference both `toBiomePainting` and `HubMesh.buildColumn` mount a
		painting from, so a trigger position always matches where it's
		actually rendered. Already the painting's own *bottom* edge (see
		`PAINTING_HEIGHT`'s own doc), so every caller passes `baseHeight = 0`
		to `PaintingModel.centerOf`/`buildQuad`, not a further offset on top.
		Public so `HubMesh` can share it.
		@param faceIndex which of the column's `COLUMN_SIDES` faces to use.
		@param left the face's left edge if true, right edge if false.
	**/
	public static function toBiomeFaceEdge(faceIndex:Int, left:Bool):h3d.Vector {
		var edge = columnEdge(faceIndex + (left ? 0 : 1));
		return new h3d.Vector(edge.top.x, PAINTING_HEIGHT, edge.top.z);
	}

	/**
		How far past the walkable boundary nearest the column (see
		`isInside`) the player reappears, arc-length along this sphere, when
		a biome's own exit painting warps them back into the hub — plays the
		same role `biomes.maze.MazeBiome.RETURN_SPAWN_OFFSET` does for the
		trip the other way, just measured from the column's own collision
		boundary rather than a flat wall: that boundary — not
		`toBiomeFaceEdge` itself, which isn't even a point on this sphere —
		is what actually limits how close the player can already stand to
		the painting. Re-derived alongside `PAINTING_TRIGGER_DISTANCE`'s own
		bump (a scratch script, not hand algebra — see `PAINTING_HEIGHT`'s
		own doc): confirmed numerically that right at the boundary, the true
		distance to the painting's own trigger center is now deep inside
		`PAINTING_TRIGGER_DISTANCE` (20) — about 8.5 — so spawning there
		would immediately re-trigger it; this offset clears it by a
		comfortable margin (~4.6).
	**/
	static inline final RETURN_SPAWN_ARC_OFFSET:Float = 24;

	/**
		The polar angle nearest the column a player can actually stand at —
		`isInside`'s own boundary distance-from-axis (`COLUMN_RADIUS +
		COLLISION_CLEARANCE`), expressed as theta so `returnSpawnTheta` can
		build on it directly.
		@return theta at the walkable boundary nearest the column.
	**/
	static function walkableBoundaryTheta():Float {
		return Math.asin((COLUMN_RADIUS + COLLISION_CLEARANCE) / RADIUS);
	}

	/**
		Where the player reappears on this sphere after warping back into
		the hub through a biome's own exit painting: `RETURN_SPAWN_ARC_OFFSET`
		past the walkable boundary nearest the to-biome painting's own
		column face — close enough to read as standing in front of the
		painting, not clear across the room at `SPAWN_THETA` (only used for
		a genuinely fresh arrival — see `HubBiome.spawnPlayer`).
		@return theta for `PlayerModel.spawnAt`.
	**/
	public static function returnSpawnTheta():Float {
		return walkableBoundaryTheta() + RETURN_SPAWN_ARC_OFFSET / RADIUS;
	}

	/**
		A to-biome painting's own azimuth around the column's axis — the
		`phi` its return spawn point shares, so the player reappears facing
		away from the column at the same angle the painting itself sits at,
		derived from `toBiomeFaceEdge`'s own points rather than duplicating
		them.
		@param faceIndex which of the column's `COLUMN_SIDES` faces to use.
		@return azimuth around Y, in radians.
	**/
	public static function toBiomeFaceAzimuth(faceIndex:Int):Float {
		var mid = PaintingModel.midpointOf(toBiomeFaceEdge(faceIndex, true), toBiomeFaceEdge(faceIndex, false));
		return SphereMath.phiOf(mid);
	}

	/**
		Whether `pos` is still on the walkable side of the column, a
		`COLLISION_CLEARANCE` margin short of its actual rendered face —
		checked via distance from the column's own axis (the Y axis), which
		for any point *on this sphere* is exactly `RADIUS * sin(theta)`. The
		same check blocks the player well before either polar cap too: as
		`theta` approaches 0 or PI, this distance shrinks below the
		column's radius long before reaching the pole itself.
		@param pos the position to check.
		@return true if `pos` hasn't crossed into the column.
	**/
	public static function isInside(pos:h3d.Vector):Bool {
		var theta = SphereMath.thetaOf(pos);
		var distanceFromAxis = RADIUS * Math.sin(theta);
		return distanceFromAxis > COLUMN_RADIUS + COLLISION_CLEARANCE;
	}

	/**
		The column's `i`th vertical edge (wrapping every `COLUMN_SIDES`): top
		and bottom points at that angle around the axis. Public so `HubMesh`
		can build the column's geometry from the exact same points this
		class's own queries (`toBiomeFaceEdge`) use.
	**/
	public static function columnEdge(i:Int):{top:h3d.Vector, bottom:h3d.Vector} {
		var angle = (i % COLUMN_SIDES) * (2 * Math.PI / COLUMN_SIDES);
		var x = COLUMN_RADIUS * Math.cos(angle);
		var z = COLUMN_RADIUS * Math.sin(angle);
		return {top: new h3d.Vector(x, COLUMN_HALF_HEIGHT, z), bottom: new h3d.Vector(x, -COLUMN_HALF_HEIGHT, z)};
	}
}
