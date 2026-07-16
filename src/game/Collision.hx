package game;

import entities.Player;
import maze.Maze;
import maze.Maze.MazeData;
import maze.Maze.MazeNode;
import maze.Maze.RowBoundaryNeighbor;

/**
	Blocks `Player` from crossing a closed maze edge, sliding along it
	instead of stopping dead when it's hit at an angle. Kept as a thin
	wrapper around `Player` rather than teaching `Player` about `Maze` —
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
		`tryMove` along `player.forward` specifically — walking forward or
		backward. See `tryMove` for the general form (e.g. strafing).
		@param player the player to move.
		@param distance arc length to walk; negative walks backward.
		@param radius sphere radius — must match the maze's physical sphere (see MazeGeometry.RADIUS).
		@param maze the maze whose closed edges block movement.
		@return true if any movement was applied (a full step or a slide), false if a wall stopped the player outright.
	**/
	public static function tryMoveForward(player:Player, distance:Float, radius:Float, maze:MazeData):Bool {
		return tryMove(player, player.forward, distance, radius, maze);
	}

	/**
		Attempts to move `player` by `distance` along `direction` — a unit
		tangent at `player.pos`, not necessarily `player.forward` (e.g. the
		player's right vector, for strafing). A step that would cross into a
		wall's thickness is rolled back and re-tried as a slide along that
		wall instead (see `slideAlong`) — approaching square-on leaves
		~nothing to slide with, approaching at a shallow angle keeps most of
		it, same physics as any FPS wall-slide.
		@param player the player to move.
		@param direction unit tangent at `player.pos` to move along.
		@param distance arc length to move; negative moves the opposite way.
		@param radius sphere radius — must match the maze's physical sphere (see MazeGeometry.RADIUS).
		@param maze the maze whose closed edges block movement.
		@return true if any movement was applied (a full step or a slide), false if a wall stopped the player outright.
	**/
	public static function tryMove(player:Player, direction:h3d.Vector, distance:Float, radius:Float, maze:MazeData):Bool {
		var fromTheta = SphereMath.thetaOf(player.pos);
		var fromPhi = SphereMath.phiOf(player.pos);
		var fromNode = Maze.nodeAt(fromTheta, fromPhi);
		var oldPos = player.pos;
		var oldForward = player.forward;

		player.moveAlong(direction, distance, radius);

		var blocked = blockingNode(maze, fromNode, fromTheta, fromPhi, SphereMath.thetaOf(player.pos), SphereMath.phiOf(player.pos), radius);
		if (blocked == null) {
			return true;
		}

		player.pos = oldPos;
		player.forward = oldForward;
		return slideAlong(player, fromNode, blocked, direction, distance, radius, maze);
	}

	/**
		Whichever node blocks a position nominally within `fromNode`: a
		neighbor whose wall-zone (see `Maze.wallZoneNeighbor`) has been
		entered *more deeply than at* `fromTheta`/`fromPhi`, or — the
		fallback described in the class doc — a genuinely different,
		non-open neighbor landed in directly, for a step large enough to
		skip clean over the wall-zone check.
		@param maze the maze whose closed edges block movement.
		@param fromNode the node the step started in.
		@param fromTheta this tick's starting polar angle, before the attempted move.
		@param fromPhi this tick's starting azimuth, before the attempted move.
		@param theta the candidate position's polar angle.
		@param phi the candidate position's azimuth.
		@param radius sphere radius — must match the maze's physical sphere (see MazeGeometry.RADIUS).
		@return the node whose wall blocks this position, or null if it's unobstructed.
	**/
	static function blockingNode(maze:MazeData, fromNode:MazeNode, fromTheta:Float, fromPhi:Float, theta:Float, phi:Float, radius:Float):Null<MazeNode> {
		var wallZone = Maze.wallZoneNeighbor(maze, fromNode, fromTheta, fromPhi, theta, phi, radius);
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
		keeping the component of `attemptedDirection` that runs along the
		wall and dropping the component that runs into it — the same
		projection any FPS wall-slide uses. `player.forward` still gets
		parallel-transported by `Player.moveAlong` (not left untouched — see
		its doc comment for why), so both `pos` and `forward` are
		snapshotted here and restored together if the slide itself turns out
		to be blocked too.

		The wall's tangent direction is derived from the grid axis the wall
		itself is fixed on — `thetaTangentAt` (north-south) for an east/west
		wall between same-row neighbors, evaluated at `player.pos`'s own
		current theta/phi; a chord between the wall segment's own two
		corners (north-south wall between different rows, or a pole) for
		everything else. See `wallTangentAlong`'s doc comment for why these
		two cases need different treatment — in short, a meridian is a
		geodesic so it can be recomputed fresh anywhere along it, but a
		parallel of latitude away from the equator isn't, and evaluating a
		"tangent to the parallel" fresh every tick sends the player drifting
		along a slightly different great circle each time, curving deeper
		into the wall until the slide grinds to a halt.
		@param player the player to move — `pos` must already be at the pre-blocked position.
		@param fromNode the node `player` was in before the blocked step.
		@param blockedNode the node whose wall blocked the step (see `blockingNode`).
		@param attemptedDirection the direction the blocked step was attempted along — not necessarily `player.forward` (e.g. strafing).
		@param distance arc length of the original attempted step.
		@param radius sphere radius — must match the maze's physical sphere (see MazeGeometry.RADIUS).
		@param maze the maze whose closed edges block movement.
		@return true if the slide moved the player at all.
	**/
	static function slideAlong(player:Player, fromNode:MazeNode, blockedNode:MazeNode, attemptedDirection:h3d.Vector, distance:Float, radius:Float,
			maze:MazeData):Bool {
		var oldPos = player.pos;
		var oldForward = player.forward;
		var oldPosDir = oldPos.normalized();
		var fromTheta = SphereMath.thetaOf(oldPos);
		var fromPhi = SphereMath.phiOf(oldPos);
		var wallTangent = wallTangentAlong(fromNode, blockedNode, oldPosDir);

		var slideDistance = distance * attemptedDirection.dot(wallTangent);
		// A near-exactly-perpendicular hit projects to a slide distance
		// that's only nonzero by floating-point noise (wallTangent and
		// attemptedDirection each come from their own chain of cross
		// products, so their dot product isn't held to the same exact-zero
		// guarantee pure trig identities would give) — squash that noise
		// rather than let it jitter the player by a fraction of a unit on a
		// square hit.
		if (Math.abs(slideDistance) < 1e-9) {
			return false;
		}
		player.moveAlong(wallTangent, slideDistance, radius);

		if (blockingNode(maze, fromNode, fromTheta, fromPhi, SphereMath.thetaOf(player.pos), SphereMath.phiOf(player.pos), radius) == null) {
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

	/**
		Unit tangent along the wall between `fromNode` and `blockedNode`, at
		`pos`. Same-row `RingNode`s (an east/west neighbor pair) share a
		latitude, so the wall between them is a meridian — a full great
		circle — and its tangent, `thetaTangentAt` evaluated fresh at
		`pos`'s own current theta/phi, stays exact no matter how far along
		it the player has traveled.

		A different-row pair's wall instead runs along a parallel of
		latitude, which away from the equator *isn't* a great circle (only
		the poles' own meridians and the equator itself are geodesics) —
		`phiTangentAt(phi)` is tangent to that parallel only at the exact
		instant it's evaluated. Recomputing it fresh every tick (as the
		same-row case correctly does) sends each tick's step along a
		slightly different great circle, each one curving away from the
		parallel toward the equator — i.e. deeper into the wall for a cell
		north of it, since theta increases toward the equator there — until
		the slide asymptotically grinds to a halt (confirmed by tracing
		theta tick-by-tick: it climbs smoothly toward the wall-zone boundary
		and plateaus just short of crossing it, not a sudden jump).

		Fixed by using the great circle that actually passes through the
		wall segment's two corners — its plane's normal (`corner1.cross(
		corner2)`) is a fixed axis, computed once from `fromNode`'s own
		center, then re-crossed with the player's *current* position fresh
		every tick to get the tangent there. That stays exact for the whole
		segment: unlike a "direction" snapshot (which drifts once the
		player isn't sitting exactly where it was taken), an axis doesn't
		drift — re-deriving the tangent from a fixed axis against a moving
		position traces that one great circle exactly, however far along it
		the player has moved. (An earlier version of this fix used the
		corners' plain vector difference as the "direction" instead, which
		looks similar but isn't the actual great-circle tangent except
		exactly at one corner — it reproduced the same drift-to-a-halt
		bug it was meant to fix.) The player naturally moves onto the next
		segment's own (freshly computed) axis once they cross into the next
		column.

		The segment's own two corners come from `fromNode`'s specific
		`Maze.rowBoundaryNeighbors` entry matching `blockedNode`, not
		`fromNode`'s own full phi width — at a row boundary where column
		count doubles moving away from a pole, the wall segment actually
		blocking the step is only *half* that width (see that function's
		own doc), and using the full width there would span a chord that
		doesn't match the true wall segment at all, silently reintroducing
		this same drift-to-a-halt bug at exactly the rows it doesn't apply
		to elsewhere.

		Either node being a `PoleNode` instead falls back to the plain
		cross-product tangent against `blockedNode`'s nominal center: `pos`
		is right at (or immediately next to) the pole in that case, where
		phi is undefined, so a chord built from `Maze.centerOf`'s
		placeholder phi at the pole would be meaningless. The cross-product
		is exact for this one endpoint regardless, and a pole never has a
		same-row *or* cross-row slide long enough to drift along.
		@param fromNode the node the blocked step started in.
		@param blockedNode the node whose wall blocked the step.
		@param pos the position to evaluate the tangent at — typically the player's own current position.
		@return unit tangent along the wall at `pos`.
	**/
	static function wallTangentAlong(fromNode:MazeNode, blockedNode:MazeNode, pos:h3d.Vector):h3d.Vector {
		var fromRow = ringRow(fromNode);
		var blockedRow = ringRow(blockedNode);
		if (fromRow == null || blockedRow == null) {
			var blockedCenter = Maze.centerOf(blockedNode);
			var blockedDir = SphereMath.sphericalToCartesian(1, blockedCenter.theta, blockedCenter.phi);
			return pos.normalized().cross(blockedDir).normalized();
		}

		if (fromRow == blockedRow) {
			return SphereMath.thetaTangentAt(SphereMath.thetaOf(pos), SphereMath.phiOf(pos));
		}

		var fromCol = ringCol(fromNode);
		if (fromCol == null) {
			// unreachable: fromRow != null already means fromNode is a RingNode.
			return SphereMath.thetaTangentAt(SphereMath.thetaOf(pos), SphereMath.phiOf(pos));
		}

		var halfTheta = Math.PI / (Maze.ROWS - 1) / 2;
		var sign = blockedRow > fromRow ? 1 : -1;
		var wallTheta = Math.PI * fromRow / (Maze.ROWS - 1) + sign * halfTheta;
		var entry = matchingRowBoundaryEntry(fromRow, fromCol, blockedRow, blockedNode);
		var corner1 = SphereMath.sphericalToCartesian(1, wallTheta, entry.phiStart);
		var corner2 = SphereMath.sphericalToCartesian(1, wallTheta, entry.phiEnd);
		var axis = corner1.cross(corner2).normalized();
		return axis.cross(pos.normalized()).normalized();
	}

	/**
		Whichever of `fromNode`'s `Maze.rowBoundaryNeighbors` entries toward
		`otherRow` is actually `blockedNode` — the specific phi sub-range of
		the wall segment that blocked the step, not `fromNode`'s own full
		width (see `wallTangentAlong`'s doc comment for why that distinction
		matters here specifically).
		@param row `fromNode`'s row.
		@param col `fromNode`'s column.
		@param otherRow the row to find boundary neighbors toward — row - 1 or row + 1.
		@param blockedNode the specific neighbor to find the matching entry for.
		@return that entry.
	**/
	static function matchingRowBoundaryEntry(row:Int, col:Int, otherRow:Int, blockedNode:MazeNode):RowBoundaryNeighbor {
		var blockedKey = Maze.nodeKey(blockedNode);
		for (entry in Maze.rowBoundaryNeighbors(row, col, otherRow)) {
			if (Maze.nodeKey(entry.node) == blockedKey) {
				return entry;
			}
		}
		throw 'unreachable: $blockedKey must be one of fromNode\'s own rowBoundaryNeighbors entries toward row $otherRow';
	}

	/** A `RingNode`'s row, or null for a `PoleNode` (which has no row). **/
	static function ringRow(node:MazeNode):Null<Int> {
		return switch node {
			case RingNode(row, _): row;
			case PoleNode(_): null;
		}
	}

	/** A `RingNode`'s column, or null for a `PoleNode` (which has no column). **/
	static function ringCol(node:MazeNode):Null<Int> {
		return switch node {
			case RingNode(_, col): col;
			case PoleNode(_): null;
		}
	}
}
