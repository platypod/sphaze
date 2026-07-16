package game;

import entities.Player;
import maze.Maze;
import maze.Maze.MazeData;
import maze.Maze.MazeNode;

/**
	Blocks `Player.moveForward` from crossing a closed maze edge, sliding
	along it instead of stopping dead when it's hit at an angle. Kept as a
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
		Attempts to move `player` forward by `distance`. A step that would
		cross a closed edge is rolled back and re-tried as a slide along that
		wall instead (see `slideAlong`) — approaching square-on leaves ~nothing
		to slide with, approaching at a shallow angle keeps most of it, same
		physics as any FPS wall-slide. Moving within a single node (no edge
		crossed) is always allowed, including diagonal steps that skip past a
		grid corner without landing in a node adjacent to the start —
		`Maze.isOpen` reports no edge between non-adjacent nodes, so those are
		blocked too, same as an actual wall would.
		@param player the player to move.
		@param distance arc length to walk; negative walks backward.
		@param radius sphere radius — must match the maze's physical sphere (see MazeGeometry.RADIUS).
		@param maze the maze whose closed edges block movement.
		@return true if any movement was applied (a full step or a slide), false if a wall stopped the player outright.
	**/
	public static function tryMoveForward(player:Player, distance:Float, radius:Float, maze:MazeData):Bool {
		var fromNode = Maze.nodeAt(SphereMath.thetaOf(player.pos), SphereMath.phiOf(player.pos));
		var oldPos = player.pos;
		var oldForward = player.forward;

		player.moveForward(distance, radius);

		var toNode = Maze.nodeAt(SphereMath.thetaOf(player.pos), SphereMath.phiOf(player.pos));
		if (Maze.nodeKey(fromNode) == Maze.nodeKey(toNode) || Maze.isOpen(maze, fromNode, toNode)) {
			return true;
		}

		player.pos = oldPos;
		player.forward = oldForward;
		return slideAlong(player, fromNode, toNode, oldForward, distance, radius, maze);
	}

	/**
		Redirects a blocked step into a slide along the wall that blocked it,
		keeping the component of `forward` that runs along the wall and
		dropping the component that runs into it — the same projection any
		FPS wall-slide uses. Doesn't rotate `forward`: the slide moves the
		player's position, not where they're looking.

		The wall's tangent direction is derived from `blockedNode`'s nominal
		center as a plain 3D point (`oldPos`'s radial direction crossed with
		the direction toward that center), never from theta/phi evaluated at
		`player.pos` itself — that position can be right at a pole, where phi
		is meaningless (the same singularity `entities.Player`'s own
		orientation fix exists to avoid).
		@param player the player to move — `pos` must already be at the pre-blocked position.
		@param fromNode the node `player` was in before the blocked step.
		@param blockedNode the node the blocked step would have landed in.
		@param forward the direction the blocked step was attempted along.
		@param distance arc length of the original attempted step.
		@param radius sphere radius — must match the maze's physical sphere (see MazeGeometry.RADIUS).
		@param maze the maze whose closed edges block movement.
		@return true if the slide moved the player at all.
	**/
	static function slideAlong(player:Player, fromNode:MazeNode, blockedNode:MazeNode, forward:h3d.Vector, distance:Float, radius:Float, maze:MazeData):Bool {
		var oldPos = player.pos;
		var oldPosDir = oldPos.normalized();
		var blockedCenter = Maze.centerOf(blockedNode);
		var blockedDir = SphereMath.sphericalToCartesian(1, blockedCenter.theta, blockedCenter.phi);
		var wallTangent = oldPosDir.cross(blockedDir).normalized();

		var slideDistance = distance * forward.dot(wallTangent);
		// A near-exactly-perpendicular hit projects to a slide distance
		// that's only nonzero by floating-point noise (wallTangent and
		// forward each come from their own chain of cross products, so
		// their dot product isn't held to the same exact-zero guarantee
		// pure trig identities would give) — squash that noise rather than
		// let it jitter the player by a fraction of a unit on a square hit.
		if (Math.abs(slideDistance) < 1e-9) {
			return false;
		}
		player.moveAlong(wallTangent, slideDistance, radius);

		var slidNode = Maze.nodeAt(SphereMath.thetaOf(player.pos), SphereMath.phiOf(player.pos));
		if (Maze.nodeKey(fromNode) == Maze.nodeKey(slidNode) || Maze.isOpen(maze, fromNode, slidNode)) {
			return slideDistance != 0;
		}

		// The slide direction crosses a closed edge too (e.g. right at a
		// corner) — nowhere to go.
		player.pos = oldPos;
		return false;
	}
}
