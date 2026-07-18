package biomes.tower;

import biomes.tower.TowerModel.TowerData;
import entities.player.PlayerModel;

/**
	Movement/collision for the tower's own vertical shaft. Horizontal is a
	simple outer-wall circle bound — no internal maze walls within a layer,
	just the aperture pattern itself deciding where a floor exists — much
	simpler than `biomes.common.grid.GridCollision`'s wall-slide math (same
	"one fixed boundary, block the whole step" reasoning
	`biomes.hub.HubCollision` already uses for the hub's own column).

	Vertical is this biome's own real free-fall, not
	`biomes.common.Gravity.fallToSurface`'s cosmetic hop: gravity
	accelerates `player.verticalVelocity` downward with no cap — the longer
	the fall, the faster it gets — and `player.pos.y` is the player's actual
	world height here, not an offset from an always-present surface. Landing
	scans every layer boundary the step crosses (see `applyGravity`), not
	just the one the player started in, so an uncapped fall speed can never
	tunnel through a solid floor by covering more than one layer in a single
	fixed step.
**/
class TowerCollision {
	/** How far short of the outer wall's true rendered face a player is stopped — same role as `biomes.common.grid.GridGeometry.COLLISION_CLEARANCE`. **/
	public static inline final COLLISION_CLEARANCE:Float = 1;

	/** How many directions `isSupported` samples around its check point — cheap approximation of a small disk rather than exact edge-distance math against the tile grid's own curved/sheared boundaries. **/
	static inline final SUPPORT_SAMPLES:Int = 8;

	/**
		Attempts to move `player` by `distance` along `direction` — blocks
		the whole step (no wall-slide, same reasoning
		`biomes.hub.HubCollision.tryMove` uses for its own single boundary)
		if it would cross the outer wall.
		@param player the player to move.
		@param direction unit tangent at `player.pos` to move along.
		@param distance arc length to move; negative moves the opposite way.
	**/
	public static function tryMove(player:PlayerModel, direction:h3d.Vector, distance:Float):Void {
		var oldPos = player.pos;
		var oldForward = player.forward;
		player.moveAlong(direction, distance, 1); // FlatSpace.moveAlong ignores radius entirely - see its own doc.
		if (!isWithinOuterWall(player.pos)) {
			player.pos = oldPos;
			player.forward = oldForward;
		}
	}

	/**
		Whether `pos`'s horizontal distance from the shaft's own central axis
		is still within the outer wall, `COLLISION_CLEARANCE` short of its
		true rendered face.
		@param pos the position to check.
		@return true if `pos` hasn't crossed the outer wall.
	**/
	public static function isWithinOuterWall(pos:h3d.Vector):Bool {
		var distanceFromAxis = Math.sqrt(pos.x * pos.x + pos.z * pos.z);
		return distanceFromAxis <= TowerModel.OUTER_RADIUS - COLLISION_CLEARANCE;
	}

	/**
		Advances `player`'s own fall by one fixed step. Gravity integrates
		`verticalVelocity`/`pos.y` directly, uncapped; landing checks every
		layer boundary between the old and new height, in falling order, for
		the first one solid at the player's own `(x, z)` — not high jumps
		relative to `TowerModel.LAYER_HEIGHT` today, so a jump can't yet rise
		fast enough to hit a solid layer from below on the way up; revisit
		this if a much stronger jump or a taller layer gap ever makes that
		reachable.

		The landing scan only ever runs while `newY <= oldY` (actually
		falling, or resting exactly in place) — skipped outright while
		rising (e.g. the tick right after `PlayerModel.jump`), since there's
		nothing to "land on" while moving away from the floor. Without this,
		a jump from the topmost layer could never leave the ground at all:
		`TowerModel.layerAt` clamps to layer 0, so the layer scanned after
		rising off it was still layer 0 itself, immediately re-detected as
		solid and snapping the player straight back down.

		Within that scan, a layer already strictly below `oldY` (its own
		floor already fallen through in an earlier step) is never
		re-checked either — solidity is re-verified only for layers at or
		below the one `oldY` currently rests on. Without this, drifting
		sideways while falling past a solid tile's own underside (tiles
		have real relief/thickness now, not a zero-thickness plane) read as
		"landing" on top of that tile and snapped the player back up
		through it, rather than just continuing to fall past its side.
		@param player the player to update.
		@param gravity this biome's own gravity strength, in world units/s².
		@param layout the tower's own generated layout.
		@param dt fixed timestep duration, in seconds.
		@return the layer index the player ends this step standing on (if landed) or falling through (if still airborne) — `biomes.tower.TowerBiome`'s own "how deep has the player gotten" progress tracking.
	**/
	public static function applyGravity(player:PlayerModel, gravity:Float, layout:TowerData, dt:Float):Int {
		var oldY = player.pos.y;
		player.verticalVelocity -= gravity * dt;
		var newY = oldY + player.verticalVelocity * dt;
		var toLayer = TowerModel.layerAt(newY);

		if (newY <= oldY) {
			var fromLayer = TowerModel.layerAt(oldY);
			var firstCandidate = oldY < TowerModel.layerY(fromLayer) ? fromLayer + 1 : fromLayer;

			for (layer in firstCandidate...(toLayer + 1)) {
				if (isSupported(layout, layer, player.pos.x, player.pos.z)) {
					player.pos.y = TowerModel.layerY(layer);
					player.verticalVelocity = 0;
					player.grounded = true;
					return layer;
				}
			}
		}

		player.pos.y = newY;
		player.grounded = false;
		return toLayer;
	}

	/**
		Whether `(x, z)` counts as supported at `layer` — solid there itself,
		or within `COLLISION_CLEARANCE` of a solid *ring tile*. A bare
		`TowerModel.isSolid` point check has no margin at all, so the fixed
		step that carries the player's own collision point a hair's width
		past a solid tile's edge (horizontal movement runs before gravity
		within the same tick — see `game.GameLoop.fixedUpdate`) read as
		falling through the tile's own side rather than off its edge:
		reported directly as "feels like we fall through their sides." Same
		"give the player real clearance past a hard boundary" reasoning
		`COLLISION_CLEARANCE` already gives the outer wall
		(`isWithinOuterWall`), now covering the tower's interior tile edges
		too — sampled around the point rather than computed exactly, since
		the tile grid's edges are a mix of arcs and radial lines sheared per
		ring (see `TowerModel`'s own class doc), not one simple boundary
		shape an exact distance check could target directly.

		Samples landing within the always-solid center disk (`TowerModel.ringAt`
		returning `-1`) are excluded, not just checked via `TowerModel.isSolid`
		like every other sample: the disk is solid everywhere regardless of
		layout, so without this exclusion, *any* hole tile within
		`COLLISION_CLEARANCE` of the disk's own rim would read as
		"supported" by way of the disk rather than by anything actually
		underfoot — standing on a genuine hole immediately next to the disk
		would never fall. Caught by `TowerCollisionTest`'s own pre-existing
		free-fall cases, which all start players at `CENTER_DISK_RADIUS + 1`
		specifically to be off the disk, over an actual hole.
		@param layout the tower's own generated layout.
		@param layer the layer index to check.
		@param x horizontal position, relative to the shaft's own central axis.
		@param z horizontal position, relative to the shaft's own central axis.
		@return true if `(x, z)` is solid, or close enough to a solid ring tile to still count as supported.
	**/
	static function isSupported(layout:TowerData, layer:Int, x:Float, z:Float):Bool {
		if (TowerModel.isSolid(layout, layer, x, z)) {
			return true;
		}
		for (i in 0...SUPPORT_SAMPLES) {
			var angle = i * (2 * Math.PI / SUPPORT_SAMPLES);
			var sampleX = x + COLLISION_CLEARANCE * Math.cos(angle);
			var sampleZ = z + COLLISION_CLEARANCE * Math.sin(angle);
			if (TowerModel.ringAt(sampleX, sampleZ) >= 0 && TowerModel.isSolid(layout, layer, sampleX, sampleZ)) {
				return true;
			}
		}
		return false;
	}
}
