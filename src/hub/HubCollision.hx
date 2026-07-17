package hub;

import entities.Player;

/**
	Movement/collision for the hub room. Doesn't reuse `game.Collision`/
	`Maze`'s grid-based approach — see `Hub`'s own class doc for why the hub
	isn't built on that pipeline at all; a sphere with one fixed central
	obstacle needs nothing more than "did this step cross into the column",
	not wall-thickness zones, sliding, or per-edge open/closed state.
**/
class HubCollision {
	/**
		Attempts to move `player` by `distance` along `direction` — a unit
		tangent at `player.pos`. Blocks the whole step (no wall-slide, unlike
		`game.Collision`) if it would cross into the column — good enough
		for a single fixed obstacle; revisit if a flat stop against it ever
		feels bad in practice.
		@param player the player to move.
		@param direction unit tangent at `player.pos` to move along.
		@param distance arc length to move; negative moves the opposite way.
	**/
	public static function tryMove(player:Player, direction:h3d.Vector, distance:Float):Void {
		var oldPos = player.pos;
		var oldForward = player.forward;
		player.moveAlong(direction, distance, Hub.RADIUS);
		if (!Hub.isInside(player.pos)) {
			player.pos = oldPos;
			player.forward = oldForward;
		}
	}
}
