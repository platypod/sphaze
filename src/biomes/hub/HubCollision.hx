package biomes.hub;

import biomes.hub.HubStructure.StructureBasis;
import entities.hourglass.Hourglass;
import entities.player.PlayerModel;

/**
	Movement/collision for the hub room. Doesn't reuse `biomes.common.grid.GridCollision`/
	`biomes.common.grid.GridModel`'s grid-based approach — a sphere with a
	handful of small freestanding landmark structures needs nothing more
	than "did this step cross into any of them," not wall-thickness zones,
	sliding, or per-edge open/closed state.
**/
class HubCollision {
	/**
		Attempts to move `player` by `distance` along `direction` — a unit
		tangent at `player.pos`. Blocks the whole step (no wall-slide, unlike
		`biomes.common.grid.GridCollision`) if it would cross into any
		structure — good enough for a few small fixed obstacles; revisit if
		a flat stop against one ever feels bad in practice.
		@param player the player to move.
		@param direction unit tangent at `player.pos` to move along.
		@param distance arc length to move; negative moves the opposite way.
		@param mazeShrineBasis the maze shrine's own local frame.
		@param towerReplicaBasis the tower replica's own local frame.
		@param hourglassBasis the hourglass's own local frame.
	**/
	public static function tryMove(player:PlayerModel, direction:h3d.Vector, distance:Float, mazeShrineBasis:StructureBasis, towerReplicaBasis:StructureBasis,
			hourglassBasis:StructureBasis):Void {
		var oldPos = player.pos;
		var oldForward = player.forward;
		player.moveAlong(direction, distance, HubModel.RADIUS);
		if (MazeShrine.blocksMovement(mazeShrineBasis, player.pos, player.airborneHeight)
			|| TowerReplica.blocksMovement(towerReplicaBasis, player.pos)
			|| Hourglass.blocksMovement(hourglassBasis, player.pos)) {
			player.pos = oldPos;
			player.forward = oldForward;
		}
	}
}
