package biomes.conway;

import biomes.conway.ConwayMaze.ConwayMazeData;
import biomes.conway.ConwayMaze.ConwayNode;
import biomes.common.space.sphere.SphereMath;
import entities.player.PlayerModel;

/**
	Blocks movement across Conway closed edges.
**/
class ConwayCollision {
	public static function tryMove(player:PlayerModel, direction:h3d.Vector, distance:Float, radius:Float, maze:ConwayMazeData):Bool {
		var fromNode = ConwayGrid.nodeAt(SphereMath.thetaOf(player.pos), SphereMath.phiOf(player.pos));
		var oldPos = player.pos;
		var oldForward = player.forward;

		player.moveAlong(direction, distance, radius);
		var atNode = ConwayGrid.nodeAt(SphereMath.thetaOf(player.pos), SphereMath.phiOf(player.pos));
		if (allowsStep(maze, fromNode, atNode)) {
			return true;
		}

		player.pos = oldPos;
		player.forward = oldForward;
		return false;
	}

	static function allowsStep(maze:ConwayMazeData, fromNode:ConwayNode, atNode:ConwayNode):Bool {
		return ConwayMaze.nodeKey(fromNode) == ConwayMaze.nodeKey(atNode) || ConwayMaze.isOpen(maze, fromNode, atNode);
	}
}
