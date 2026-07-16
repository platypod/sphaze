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
	only thing collision needs is the node the player was in versus whatever
	blocks the step.

	Works per fixed-timestep step, not by sweeping the whole path against
	wall geometry. A step is blocked one of two ways (see `blockingNode`):
	entering the *wall-zone* of a closed side without necessarily leaving the
	current node (the thickness a wall actually occupies, per
	`Maze.wallZoneNeighbor` — this is the common case now that walls have
	real thickness, not the zero-width planes they started as), or, as a
	fallback for a step large enough to skip clean over that check, landing
	directly in a different, non-open node. At `Main.WALK_SPEED` versus the
	grid's cell size the fallback essentially never fires in practice.
**/
class Collision {
	/**
		Attempts to move `player` forward by `distance`. A step that would
		cross into a wall's thickness is rolled back and re-tried as a slide
		along that wall instead (see `slideAlong`) — approaching square-on
		leaves ~nothing to slide with, approaching at a shallow angle keeps
		most of it, same physics as any FPS wall-slide.
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

		var blocked = blockingNode(maze, fromNode, SphereMath.thetaOf(player.pos), SphereMath.phiOf(player.pos), radius);
		if (blocked == null) {
			return true;
		}

		player.pos = oldPos;
		player.forward = oldForward;
		return slideAlong(player, fromNode, blocked, oldForward, distance, radius, maze);
	}

	/**
		Whichever node blocks a position nominally within `fromNode`: a
		neighbor whose wall-zone (see `Maze.wallZoneNeighbor`) has been
		entered, or — the fallback described in the class doc — a genuinely
		different, non-open neighbor landed in directly, for a step large
		enough to skip clean over the wall-zone check.
		@param maze the maze whose closed edges block movement.
		@param fromNode the node the step started in.
		@param theta the candidate position's polar angle.
		@param phi the candidate position's azimuth.
		@param radius sphere radius — must match the maze's physical sphere (see MazeGeometry.RADIUS).
		@return the node whose wall blocks this position, or null if it's unobstructed.
	**/
	static function blockingNode(maze:MazeData, fromNode:MazeNode, theta:Float, phi:Float, radius:Float):Null<MazeNode> {
		var wallZone = Maze.wallZoneNeighbor(maze, fromNode, theta, phi, radius);
		if (wallZone != null) {
			return wallZone;
		}

		var atNode = Maze.nodeAt(theta, phi);
		if (Maze.nodeKey(fromNode) != Maze.nodeKey(atNode) && !Maze.isOpen(maze, fromNode, atNode)) {
			return atNode;
		}
		return null;
	}

	/**
		Redirects a blocked step into a slide along the wall that blocked it,
		keeping the component of `forward` that runs along the wall and
		dropping the component that runs into it — the same projection any
		FPS wall-slide uses. `forward` still gets parallel-transported by
		`Player.moveAlong` (not left untouched — see its doc comment for why),
		so both `pos` and `forward` are snapshotted here and restored
		together if the slide itself turns out to be blocked too.

		The wall's tangent direction is derived from `blockedNode`'s nominal
		center as a plain 3D point (`oldPos`'s radial direction crossed with
		the direction toward that center), never from theta/phi evaluated at
		`player.pos` itself — that position can be right at a pole, where phi
		is meaningless (the same singularity `entities.Player`'s own
		orientation fix exists to avoid).
		@param player the player to move — `pos` must already be at the pre-blocked position.
		@param fromNode the node `player` was in before the blocked step.
		@param blockedNode the node whose wall blocked the step (see `blockingNode`).
		@param forward the direction the blocked step was attempted along.
		@param distance arc length of the original attempted step.
		@param radius sphere radius — must match the maze's physical sphere (see MazeGeometry.RADIUS).
		@param maze the maze whose closed edges block movement.
		@return true if the slide moved the player at all.
	**/
	static function slideAlong(player:Player, fromNode:MazeNode, blockedNode:MazeNode, forward:h3d.Vector, distance:Float, radius:Float, maze:MazeData):Bool {
		var oldPos = player.pos;
		var oldForward = player.forward;
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

		if (blockingNode(maze, fromNode, SphereMath.thetaOf(player.pos), SphereMath.phiOf(player.pos), radius) == null) {
			return slideDistance != 0;
		}

		// The slide direction crosses into a wall's thickness too (e.g.
		// right at a corner) — nowhere to go. moveAlong touched forward as
		// well as pos (see its doc comment), so both need restoring here,
		// not just pos.
		player.pos = oldPos;
		player.forward = oldForward;
		return false;
	}
}
