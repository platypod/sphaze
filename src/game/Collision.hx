package game;

import entities.Player;
import maze.Maze;
import maze.Maze.MazeData;

/**
	Blocks `Player.moveForward` from crossing a closed maze edge. Kept as a
	thin wrapper around `Player` rather than teaching `Player` about `Maze` —
	`Player` is otherwise fully maze-agnostic (see its class doc), and the
	only thing collision needs is the node the player was in versus the node
	it ends up in.

	Works per fixed-timestep step, not by sweeping the whole path against
	wall geometry: a step that starts and ends in the same node never
	touches a wall (walls only sit on node boundaries), and a step landing in
	a different node is only allowed if that specific edge is open. A step
	fast enough to jump clean over an intervening node in one tick would slip
	through unnoticed, but at `Main.WALK_SPEED` versus the grid's cell size
	that doesn't happen in practice.
**/
class Collision {
	/**
		Attempts to move `player` forward by `distance`; rolled back if doing
		so would cross a closed edge in `maze`. Moving within a single node
		(no edge crossed) is always allowed, including diagonal steps that
		skip past a grid corner without landing in a node adjacent to the
		start — `Maze.isOpen` reports no edge between non-adjacent nodes, so
		those are blocked too, same as an actual wall would.
		@param player the player to move.
		@param distance arc length to walk; negative walks backward.
		@param radius sphere radius — must match the maze's physical sphere (see MazeGeometry.RADIUS).
		@param maze the maze whose closed edges block movement.
		@return true if the move was applied, false if a wall blocked it.
	**/
	public static function tryMoveForward(player:Player, distance:Float, radius:Float, maze:MazeData):Bool {
		var fromNode = Maze.nodeAt(SphereMath.thetaOf(player.pos), SphereMath.phiOf(player.pos));
		var oldPos = player.pos;
		var oldForward = player.forward;

		player.moveForward(distance, radius);

		var toNode = Maze.nodeAt(SphereMath.thetaOf(player.pos), SphereMath.phiOf(player.pos));
		if (Maze.nodeKey(fromNode) != Maze.nodeKey(toNode) && !Maze.isOpen(maze, fromNode, toNode)) {
			player.pos = oldPos;
			player.forward = oldForward;
			return false;
		}
		return true;
	}
}
