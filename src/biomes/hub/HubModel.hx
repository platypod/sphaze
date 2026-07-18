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
		that floor.

		Went through three real attempts before landing here, each one
		caught by hooman actually looking at it rather than by the numbers
		alone:
		1. `57`→`61`: still overlapped the floor at some reachable
		   approaches, and separately overshot `COLUMN_HALF_HEIGHT` — a
		   pure "raise the mount point" fix can't win both fights, since
		   raising it helps one and worsens the other.
		2. `57.4558`/height `9.0199`, `PAINTING_TRIGGER_DISTANCE` raised to
		   `20`: a bisection script confirmed this genuinely clears both
		   the floor and the cap, each with `0.3` units to spare — except
		   `0.3` turned out to not be enough margin once a real player
		   (approaching at a slightly different angle than the script's own
		   idealized head-on check) was actually looking at it, and a
		   trigger radius of `20` made the painting activate from
		   uncomfortably far away ("pulls you from a kilometer away").
		   Separately, that same round's `PaintingModel.fillWall` had its
		   own bug: it sized margin against the inner painting alone, not
		   `buildFrame`'s own border, which extends further out still —
		   invisible here since the hub doesn't use `fillWall`, but it's
		   what caused the tower's own paintings to visibly touch their
		   own wall/ceiling in the same round.
		3. `PAINTING_TRIGGER_DISTANCE` pulled back to `16` (nowhere near
		   the `20` that felt like it grabbed the player from across the
		   room, but still enough past the bare minimum `6` needed to dodge
		   an instant re-trigger to buy real room), and the bisection
		   margin doubled from `0.3` to `0.5` on both the floor and cap
		   side, accounting for `buildFrame`'s own border this time (the
		   frame's own outer edge, not the inner painting, is what actually
		   has to clear both). `60.544`/`9.0199` — still felt like it
		   pulled the player in from too far away.
		4. The real fix for the pull distance turned out to be a different
		   bug entirely: `toBiomePainting` was triggering off the painting's
		   own elevated visual center, not a floor-level point like every
		   other painting in this project — so part of `PAINTING_TRIGGER_DISTANCE`'s
		   own budget was always being spent just absorbing that vertical
		   offset rather than actual walking distance. Switched to
		   `midpointOf` (see its own doc) and re-ran the bisection with
		   *that* as the reference: `PAINTING_TRIGGER_DISTANCE` could come
		   down to `10` (nowhere near `16`) while keeping the same `0.5`
		   safety margin on both the floor and the cap. `63.457`/
		   `PAINTING_HEIGHT_SPAN` below are what that search found —
		   smaller again than the `16`-attempt's numbers, the direct cost
		   of the smaller trigger radius: less room opens up between the
		   floor and the cap the closer a player can get before triggering.

		Re-run that search (not hand algebra; see `docs/PROJECT_LOG.md`'s
		own entries on why the naive version of this kept predicting the
		wrong direction) whenever `RADIUS`/`COLUMN_RADIUS`/
		`PAINTING_TRIGGER_DISTANCE` change.
	**/
	static inline final PAINTING_HEIGHT:Float = 63.457;

	/** A face painting's own total height, floor-clearance to top edge — see `PAINTING_HEIGHT`'s own doc for how this was derived alongside it. Public so `HubMesh` can share it (see `toBiomeFaceEdge`'s own doc on why `baseHeight` is always `0` here). **/
	public static inline final PAINTING_HEIGHT_SPAN:Float = 2.634;

	/**
		How close the player needs to walk to trigger the to-biome painting
		— `PaintingModel.TRIGGER_DISTANCE` (4) doesn't clear the gap at
		this scale. Doubles as the knob that sets how close a player can
		physically get to a mounted painting at all (see `PAINTING_HEIGHT`'s
		own doc): raised past the minimum needed just to avoid an instant
		re-trigger, to push the closest reachable approach further from the
		pole where there's real vertical room. Still felt like it "pulls
		you from a kilometer away" at `16` (and, separately, at `20` before
		that) — pulled back to `10`, once `toBiomePainting` switched to
		triggering off `midpointOf` (floor-level) rather than the
		painting's own elevated visual center: that switch is what made a
		smaller value here viable at all, since the elevated reference
		needed a wide trigger radius just to absorb its own vertical
		offset from where the player actually stands.
	**/
	static inline final PAINTING_TRIGGER_DISTANCE:Float = 10;

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
	/**
		Triggers off `midpointOf` (the wall's own floor-level reference,
		matching `toBiomeFaceEdge`'s own point exactly), not the painting's
		actually-rendered, wall-mounted-height center: `pos` is a
		*feet*-level point, so comparing it against an elevated center
		needlessly ate into the trigger radius's own budget just absorbing
		that vertical offset — every other painting in this project already
		triggers this way (see `biomes.maze.MazeBiome.exitPaintings`).
	**/
	public static function toBiomePainting(faceIndex:Int, destinationBiomeId:String):PaintingModel {
		var left = toBiomeFaceEdge(faceIndex, true);
		var right = toBiomeFaceEdge(faceIndex, false);
		return new PaintingModel(PaintingModel.midpointOf(left, right), destinationBiomeId, PAINTING_TRIGGER_DISTANCE);
	}

	/**
		`faceIndex`'s left or right edge, at `PAINTING_HEIGHT` — the shared
		reference both `toBiomePainting` (the trigger position) and
		`HubMesh.buildColumn` (the rendered quad's own `baseHeight = 0`
		floor) mount a painting from, so the two always agree on where the
		wall itself starts. Public so `HubMesh` can share it.
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
		`PAINTING_TRIGGER_DISTANCE` (10) — so spawning there would
		immediately re-trigger it; this offset clears it by a comfortable
		margin (~3.7).
	**/
	static inline final RETURN_SPAWN_ARC_OFFSET:Float = 12;

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
