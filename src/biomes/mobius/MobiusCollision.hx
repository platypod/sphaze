package biomes.mobius;

import biomes.common.space.mobius.MobiusMath;
import biomes.mobius.MobiusForestGenerator.ForestLayout;
import entities.player.PlayerModel;

/**
	Movement/collision for the Möbius ribbon: the ribbon's own edge
	(`MobiusModel.isWithinEdge`) plus, now, every tree's own trunk (see
	`isBlockedByATrunk`) — foliage is purely visual, only the trunk itself
	has a hitbox, same "block the whole step, no wall-slide" pragmatism
	`biomes.tower.TowerCollision`/`biomes.hub.HubCollision` already use for
	their own boundaries.

	Trunk proximity is checked in real world 3D distance against every
	tree in the forest, not a spatial index — direct ask was "fully dense,
	weave required," so this runs a full linear scan every fixed step
	(`biomes.mobius.MobiusForestGenerator`'s own class doc has the actual
	cost math: cheap even at `MobiusModel.TARGET_TREE_COUNT`-many trees,
	60 times a second). Revisit with a `u`-bucketed grid if a much denser
	forest ever makes this measurably slow — not needed at today's density.
**/
class MobiusCollision {
	/**
		Attempts to move `player` by `distance` along `direction`, reverting
		the whole step if it would cross the ribbon's own edge or walk into
		a tree's own trunk.
		@param player the player to move.
		@param direction unit tangent at `player.pos` to move along.
		@param distance arc length to move; negative moves the opposite way.
		@param twists half-twists over one full lap around the loop.
		@param radius the loop's own centerline radius.
		@param forest the generated forest to check trunk proximity against.
	**/
	public static function tryMove(player:PlayerModel, direction:h3d.Vector, distance:Float, twists:Int, radius:Float, forest:ForestLayout):Void {
		var oldPos = player.pos;
		var oldForward = player.forward;
		var oldSurfaceUp = player.surfaceUp;
		player.moveAlong(direction, distance, radius);
		var params = MobiusMath.paramsAt(player.pos, twists, radius);
		if (!MobiusModel.isWithinEdge(params.v) || isBlockedByATrunk(player.pos, forest)) {
			player.pos = oldPos;
			player.forward = oldForward;
			player.surfaceUp = oldSurfaceUp;
		}
	}

	/**
		Whether `pos` is within any tree's own trunk radius (plus
		`MobiusModel.COLLISION_CLEARANCE`, same clearance role the ribbon's
		own edge boundary uses).
		@param pos the position to check — typically the player's own tentative new position.
		@param forest the generated forest to check against.
		@return true if `pos` is blocked by some tree's own trunk.
	**/
	public static function isBlockedByATrunk(pos:h3d.Vector, forest:ForestLayout):Bool {
		for (t in forest.trees) {
			var dx = pos.x - t.x;
			var dy = pos.y - t.y;
			var dz = pos.z - t.z;
			var clearance = t.trunkRadius + MobiusModel.COLLISION_CLEARANCE;
			if (dx * dx + dy * dy + dz * dz < clearance * clearance) {
				return true;
			}
		}
		return false;
	}
}
