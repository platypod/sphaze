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

		var fromLayer = TowerModel.layerAt(oldY);
		var toLayer = TowerModel.layerAt(newY);

		for (layer in fromLayer...(toLayer + 1)) {
			if (TowerModel.isSolid(layout, layer, player.pos.x, player.pos.z)) {
				player.pos.y = TowerModel.layerY(layer);
				player.verticalVelocity = 0;
				player.grounded = true;
				return layer;
			}
		}

		player.pos.y = newY;
		player.grounded = false;
		return toLayer;
	}
}
