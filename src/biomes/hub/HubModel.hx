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

	/** Which of the column's 8 faces holds the painting back to the one existing biome — arbitrary, just needs to be a real face index. **/
	static inline final TO_BIOME_FACE_INDEX = 0;

	/** Extra margin `isInside` blocks at, short of the column's actual rendered face — same role as `biomes.common.grid.GridGeometry.COLLISION_CLEARANCE` plays for biomes. **/
	static inline final COLLISION_CLEARANCE:Float = 1;

	/**
		Height (along the column's own axis) a face painting mounts at —
		deliberately *not* 0 (equatorial, the column's widest cross-section
		and so the room's most spacious walking band): the player's own
		distance from the column's axis and their height are the same
		function of `theta` (`RADIUS*sin(theta)` and `RADIUS*cos(theta)`
		respectively), so the closest they can ever get to the column at all
		is right at the collision boundary itself — near the *top* of the
		walkable band, not the middle. A painting mounted at the equator
		would sit a full corridor-width (14 units) away from anywhere the
		player can actually stand.

		Every time `RADIUS`/`COLUMN_RADIUS` changes, this is re-derived from
		scratch, not scaled from whatever it was before: `PaintingModel`'s own
		`BASE_HEIGHT`/`HEIGHT` are fixed absolute constants (a painting is a
		physical object with its own natural size, not something that
		should balloon just because the room around it did), so naively
		scaling `PAINTING_HEIGHT` alone while that fixed offset stays put
		has overshot the reachable zone before. `57` puts the quad's own top
		edge (`57+9=66`) just under `COLUMN_HALF_HEIGHT` (`66.7757`), the
		highest this anchor can go, putting its visual center (`57+6=63`)
		as close as that allows to the collision boundary's own height
		(`RADIUS*cos(asin((COLUMN_RADIUS+COLLISION_CLEARANCE)/RADIUS))`) —
		confirmed numerically (a scratch script computing the true closest
		distance from the nearest reachable player position to this exact
		point), not assumed.
		`PAINTING_TRIGGER_DISTANCE` is sized against that same measurement
		rather than reusing `PaintingModel.TRIGGER_DISTANCE`, since how close the
		player can physically get to a mounting point scales with the room,
		not with a fixed constant tuned for biome-scale walls.
	**/
	static inline final PAINTING_HEIGHT:Float = 57;

	/**
		How close the player needs to walk to trigger the to-biome painting
		— `PaintingModel.TRIGGER_DISTANCE` (4) doesn't clear the gap at this
		scale (confirmed numerically — see `PAINTING_HEIGHT`'s own doc), so
		the hub's own painting gets its own value instead of that shared
		constant.
	**/
	static inline final PAINTING_TRIGGER_DISTANCE:Float = 6;

	/** Where the player spawns entering the hub: the equator — the room's widest, most open point, not particularly close to the column (see `PAINTING_HEIGHT`'s own doc for why that's the *least* reachable latitude, not the most). **/
	public static final SPAWN_THETA:Float = Math.PI / 2;

	public static final SPAWN_PHI:Float = Math.PI / COLUMN_SIDES;

	/**
		The hub's one painting back to a biome, mounted on `TO_BIOME_FACE_INDEX`
		at `PAINTING_HEIGHT` — matches exactly where `HubMesh.buildColumn` renders it.
		Takes the destination biome's id rather than hardcoding one so `HubModel`
		itself stays biome-agnostic — see `biomes.hub.HubBiome`, which is what
		actually knows which biome that is.
		@param destinationBiomeId the `biomes.common.Biome.id()` this painting leads to.
		@return the hub's exit painting.
	**/
	public static function toBiomePainting(destinationBiomeId:String):PaintingModel {
		var left = toBiomeFaceEdge(true);
		var right = toBiomeFaceEdge(false);
		return new PaintingModel(PaintingModel.centerOf(left, right, new h3d.Vector(0, 1, 0)), destinationBiomeId, PAINTING_TRIGGER_DISTANCE);
	}

	/**
		`TO_BIOME_FACE_INDEX`'s left or right edge, at `PAINTING_HEIGHT` — the
		shared reference both `toBiomePainting` and `HubMesh.buildColumn`
		mount the painting from, so the trigger position always matches
		where it's actually rendered. Public so `HubMesh` can share it.
	**/
	public static function toBiomeFaceEdge(left:Bool):h3d.Vector {
		var edge = columnEdge(TO_BIOME_FACE_INDEX + (left ? 0 : 1));
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
		the painting. Confirmed numerically: right at the boundary, the true
		distance to the painting's own trigger center is already inside
		`PAINTING_TRIGGER_DISTANCE` (6) — about 4.3 — so spawning there
		would immediately re-trigger it and bounce the player straight back
		out; this offset clears it by a comfortable margin (~8.3).
	**/
	static inline final RETURN_SPAWN_ARC_OFFSET:Float = 6;

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
		The to-biome painting's own azimuth around the column's axis — the
		`phi` its return spawn point shares, so the player reappears facing
		away from the column at the same angle the painting itself sits at,
		derived from `toBiomeFaceEdge`'s own points rather than duplicating
		them.
		@return azimuth around Y, in radians.
	**/
	public static function toBiomeFaceAzimuth():Float {
		var mid = PaintingModel.midpointOf(toBiomeFaceEdge(true), toBiomeFaceEdge(false));
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
