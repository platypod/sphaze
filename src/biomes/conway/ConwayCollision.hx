package biomes.conway;

import biomes.conway.ConwayMaze.ConwayMazeData;
import biomes.conway.ConwayMaze.ConwayNode;
import biomes.common.space.sphere.SphereMath;
import entities.player.PlayerModel;

/**
	Blocks movement across Conway closed edges — unless the player is
	airborne above `ConwayGrid.WALL_HEIGHT`, the same "high enough to clear
	it" gate `biomes.hub.MazeShrine.blocksMovement` already uses for its own
	walls (hooman, directly: "add a hitbox to the cells, so the player can
	jump on a cell, and from there, jump over a wall" — `ConwayGrid.groundHeightAt`
	is the matching half, the standable landing on a live cell's own top that
	makes reaching that height possible in the first place).
**/
class ConwayCollision {
	public static function tryMove(player:PlayerModel, direction:h3d.Vector, distance:Float, radius:Float, maze:ConwayMazeData):Bool {
		var fromNode = ConwayGrid.nodeAt(SphereMath.thetaOf(player.pos), SphereMath.phiOf(player.pos));
		var oldPos = player.pos;
		var oldForward = player.forward;

		player.moveAlong(direction, distance, radius);
		var atNode = ConwayGrid.nodeAt(SphereMath.thetaOf(player.pos), SphereMath.phiOf(player.pos));
		if (allowsStep(maze, fromNode, atNode, player.airborneHeight)) {
			return true;
		}

		player.pos = oldPos;
		player.forward = oldForward;
		return false;
	}

	static function allowsStep(maze:ConwayMazeData, fromNode:ConwayNode, atNode:ConwayNode, playerHeight:Float):Bool {
		return ConwayMaze.nodeKey(fromNode) == ConwayMaze.nodeKey(atNode)
			|| playerHeight >= ConwayGrid.WALL_HEIGHT
			|| ConwayMaze.isOpen(maze, fromNode, atNode);
	}
}
