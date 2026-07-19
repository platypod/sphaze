package biomes.mobius;

import biomes.common.space.mobius.MobiusMath;
import entities.player.PlayerModel;

/**
	Movement/collision for the bare Möbius ribbon: the only boundary is the
	ribbon's own edge (`MobiusModel.isWithinEdge`) — no internal walls or
	gaps yet (see `MobiusModel`'s own class doc for why). Same "block the
	whole step, no wall-slide" pragmatism `biomes.tower.TowerCollision`/
	`biomes.hub.HubCollision` already use for their own single boundary.
**/
class MobiusCollision {
	/**
		Attempts to move `player` by `distance` along `direction`, reverting
		the whole step if it would cross the ribbon's own edge.
		@param player the player to move.
		@param direction unit tangent at `player.pos` to move along.
		@param distance arc length to move; negative moves the opposite way.
		@param twists half-twists over one full lap around the loop.
		@param radius the loop's own centerline radius.
	**/
	public static function tryMove(player:PlayerModel, direction:h3d.Vector, distance:Float, twists:Int, radius:Float):Void {
		var oldPos = player.pos;
		var oldForward = player.forward;
		player.moveAlong(direction, distance, radius);
		var params = MobiusMath.paramsAt(player.pos, twists, radius);
		if (!MobiusModel.isWithinEdge(params.v)) {
			player.pos = oldPos;
			player.forward = oldForward;
		}
	}
}
