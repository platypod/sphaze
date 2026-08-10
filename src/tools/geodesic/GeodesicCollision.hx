package tools.geodesic;

import biomes.common.maze.MazeEdges;
import biomes.common.maze.MazeTopology.MazeLayout;
import entities.player.PlayerModel;
import tools.geodesic.GeodesicCoarseMaze.BoundarySegment;
import tools.geodesic.Vec3.Vec3Math;

/**
	Blocks movement across closed edges of a geodesic sphere's own carved
	maze — the `GeodesicLookup`-based counterpart to
	`biomes.conway.ConwayCollision`.

	Originally (Phase 4) had no wall-height/jump gate at all — that
	mechanic is tied to a live cell's own standable height, which didn't
	exist until `GeodesicLifecycle` generalized `ConwayGrid`'s heights onto
	this grid. Now that it does, the gate is ported too: airborne above
	`GeodesicLifecycle.WALL_HEIGHT` clears a closed edge, the same "jump on
	a live block, then jump again over the wall" combo
	`ConwayCollision.allowsStep`'s own `playerHeight >=
	ConwayGrid.WALL_HEIGHT` clause enables on the square grid.

	The one file in `tools.geodesic` that isn't Heaps-free by necessity —
	`PlayerModel`/`h3d.Vector` are how movement actually happens in this
	game, so bridging to them is unavoidable here the same way it's
	unavoidable in `ConwayCollision` itself.

	`tryMove`'s own optional `fineToCoarse` (2026-08-06) is what actually
	lets `GeodesicCoarseMaze`'s own wall-straightening attempt block
	movement at all: `lookup` still resolves the player's own position to
	a *fine* node (the sphere the floor/Life simulation runs on), but the
	maze itself now lives on a coarser sphere, so that fine id has to be
	remapped before `layout` — addressed by coarse ids — can answer
	whether the edge between two positions is actually open.

	`tryMove`'s own optional `boundarySegments` (2026-08-10) adds a second,
	distance-based gate on top of that graph-based one: once a closed wall
	got real thickness (`GeodesicMesh.WALL_THICKNESS`) instead of a
	zero-thickness quad, the graph check alone (which cell am I in?) is no
	longer enough — it happily lets the player walk up to the exact line a
	wall sits on, which is now *inside* the wall's own slab. `WALL_CLEARANCE`
	keeps the player's own head that slab's own half-thickness plus a small
	margin away from it. Its own "never trap the player" safety net — only
	blocking a move that makes clearance *worse* than it already was — is
	load-bearing: without it, a player who ever ends up too close (a tight
	spawn point, a save from before this landed, a future clearance-radius
	tweak) could get stuck unable to move at all.

	**Sliding, not stopping dead (2026-08-10, same day).** Reported
	directly: "movement along the walls does not work well... let's have
	the player slide along the wall rather than get stumped." A blocked
	move used to just revert outright, same as `allowsStep`'s own original
	all-or-nothing behavior before `WALL_CLEARANCE` existed — fine for a
	graph-only block (there's no wall geometry to slide along yet), but
	once `boundarySegments` gives every wall a real position and tangent,
	stopping dead at a shallow approach angle looks and feels wrong,
	exactly the itch `biomes.common.grid.GridCollision.slideAlong` already
	scratches on the square grid. `slideAlong` here ports that same
	projection (keep the component of the attempted move that runs along
	the blocking wall, drop the component that runs into it) onto this
	grid's own wall representation — a `BoundarySegment`'s own two
	endpoints, rather than `GridModel`'s row/column wall geometry.
**/
class GeodesicCollision {
	/** How far the player's own head must stay from a *closed* wall's centerline — half the wall's own thickness, plus a small margin so the camera doesn't graze the slab's own face. **/
	public static inline final WALL_CLEARANCE:Float = GeodesicMesh.WALL_THICKNESS / 2 + 0.3;

	/**
		@param player the player attempting to move — reverted in place if the move is blocked.
		@param direction world-space direction to move in (tangent-projected internally by `PlayerModel.moveAlong`).
		@param distance how far to move, in world units.
		@param radius the sphere's own radius.
		@param layout which edges are currently open — addressed by whatever id space `lookup` (as remapped by `fineToCoarse`, if given) actually resolves to.
		@param lookup resolves a world position to the node it's standing on.
		@param fineToCoarse when `lookup` resolves to a *fine* sphere but `layout` is a coarser maze built over a different sphere (`GeodesicCoarseMaze`'s own wall-straightening attempt), the fine→coarse map to remap through before checking `layout`. `null` when `lookup` and `layout` already share one id space — every use before the coarse maze existed.
		@param boundarySegments the fine-node-indexed wall geometry (`GeodesicCoarseMaze.boundarySegmentsByFineNode`) to keep the player's own head `WALL_CLEARANCE` away from a *closed* wall's own now-solid slab (`GeodesicMesh.WALL_THICKNESS`), so the camera can't end up inside it — also what a blocked move slides along instead of stopping dead. `null` skips both entirely — every use before walls got thickness.
		@return whether the move was allowed, whether as a full step or a slide.
	**/
	public static function tryMove(player:PlayerModel, direction:h3d.Vector, distance:Float, radius:Float, layout:MazeLayout, lookup:GeodesicLookup,
			?fineToCoarse:Array<Int>, ?boundarySegments:Map<Int, Array<BoundarySegment>>):Bool {
		var fromFine = lookup.nodeAt(toVec3(player.pos));
		var fromId = toCoarse(fromFine, fineToCoarse);
		var oldPos = player.pos;
		var oldForward = player.forward;
		var oldClearance = nearestClosedWallDistance(oldPos, fromFine, layout, boundarySegments);

		player.moveAlong(direction, distance, radius);
		var toFine = lookup.nodeAt(toVec3(player.pos));
		var toId = toCoarse(toFine, fineToCoarse);

		if (allowsStep(layout, fromId, toId, player.airborneHeight)
			&& !clipsIntoWall(player, toFine, layout, boundarySegments, oldClearance)) {
			return true;
		}

		var attemptedPos = player.pos;
		player.pos = oldPos;
		player.forward = oldForward;

		if (boundarySegments == null || player.airborneHeight >= GeodesicLifecycle.WALL_HEIGHT) {
			return false; // nothing to slide along without wall geometry — the graph-only, pre-thickness behavior
		}
		return slideAlong(player, oldPos, oldForward, fromId, oldClearance, attemptedPos, toFine, direction, distance, radius, layout, lookup, fineToCoarse,
			boundarySegments);
	}

	/**
		Redirects a blocked step into a slide along whichever closed wall
		blocked it, keeping the component of `attemptedDirection` that runs
		along the wall and dropping the component that runs into it — the
		same projection `GridCollision.slideAlong`'s own doc walks through
		for the square grid. `player.pos`/`forward` are already back at
		`oldPos`/`oldForward` by the time this is called (`tryMove` reverts
		before trying a slide); this only ever leaves them there or moves
		them to a new, verified-safe position — never partway.
		@param player the player to move — `pos`/`forward` must already be at `oldPos`/`oldForward`.
		@param oldPos the position before this tick's own attempted move.
		@param oldForward the forward vector before this tick's own attempted move.
		@param fromId the coarse-or-fine id (matching `layout`'s own id space) `oldPos` resolves to.
		@param oldClearance `oldPos`'s own distance to the nearest closed wall — the slide's own retry needs this for the same "never trap the player" comparison `clipsIntoWall` already does.
		@param attemptedPos where the original, blocked move would have landed — the position `nearestClosedWallSegment` uses to find which wall actually blocked it.
		@param attemptedToFine `attemptedPos`'s own fine node — indexes `boundarySegments`.
		@param attemptedDirection the direction the blocked step was attempted along.
		@param distance arc length of the original attempted step.
		@param radius sphere radius.
		@param layout which edges are currently open.
		@param lookup resolves a world position to the node it's standing on.
		@param fineToCoarse see `tryMove`'s own doc.
		@param boundarySegments see `tryMove`'s own doc.
		@return whether the slide moved the player at all.
	**/
	static function slideAlong(player:PlayerModel, oldPos:h3d.Vector, oldForward:h3d.Vector, fromId:Int, oldClearance:Float, attemptedPos:h3d.Vector,
			attemptedToFine:Int, attemptedDirection:h3d.Vector, distance:Float, radius:Float, layout:MazeLayout, lookup:GeodesicLookup,
			fineToCoarse:Null<Array<Int>>, boundarySegments:Map<Int, Array<BoundarySegment>>):Bool {
		var blocking = nearestClosedWallSegment(attemptedPos, attemptedToFine, layout, boundarySegments);
		if (blocking == null) {
			return false; // the graph blocked it, but there's no indexed wall geometry there to slide along
		}

		var wallTangent = wallTangentOf(blocking);
		var slideDistance = distance * attemptedDirection.dot(wallTangent);
		// A near-exactly-square hit projects to a slide distance that's only
		// nonzero by floating-point noise — see GridCollision.slideAlong's
		// own doc for the same squash, same reasoning.
		if (Math.abs(slideDistance) < 1e-9) {
			return false;
		}

		player.moveAlong(wallTangent, slideDistance, radius);
		var newToFine = lookup.nodeAt(toVec3(player.pos));
		var newToId = toCoarse(newToFine, fineToCoarse);

		if (allowsStep(layout, fromId, newToId, player.airborneHeight)
			&& !clipsIntoWall(player, newToFine, layout, boundarySegments, oldClearance)) {
			return true;
		}

		// The slide direction runs into a wall's own thickness too (e.g.
		// right at a corner) — nowhere to go.
		player.pos = oldPos;
		player.forward = oldForward;
		return false;
	}

	/** Unit tangent along `segment`, world-space. **/
	static function wallTangentOf(segment:BoundarySegment):h3d.Vector {
		return worldPoint(segment.b).sub(worldPoint(segment.a)).normalized();
	}

	/** `fine`, remapped through `fineToCoarse` when one is given. **/
	static function toCoarse(fine:Int, fineToCoarse:Null<Array<Int>>):Int {
		return fineToCoarse == null ? fine : fineToCoarse[fine];
	}

	static function allowsStep(layout:MazeLayout, fromId:Int, toId:Int, playerHeight:Float):Bool {
		return fromId == toId
			|| playerHeight >= GeodesicLifecycle.WALL_HEIGHT
			|| MazeEdges.isOpen(layout, Std.string(fromId), Std.string(toId));
	}

	/**
		Whether the move just taken would land the player's own head closer
		than `WALL_CLEARANCE` to a *closed* wall's own slab than it already
		was — never blocks a move that keeps the same or improves distance,
		so a player who somehow started too close (spawn, an old save, a
		clearance-radius tweak) can always back away rather than getting
		trapped. Exempt once airborne above `GeodesicLifecycle.WALL_HEIGHT`,
		matching `allowsStep`'s own jump-over-the-wall gate.
	**/
	static function clipsIntoWall(player:PlayerModel, toFine:Int, layout:MazeLayout, boundarySegments:Null<Map<Int, Array<BoundarySegment>>>,
			oldClearance:Float):Bool {
		if (boundarySegments == null || player.airborneHeight >= GeodesicLifecycle.WALL_HEIGHT) {
			return false;
		}
		var newClearance = nearestClosedWallDistance(player.pos, toFine, layout, boundarySegments);
		return newClearance < WALL_CLEARANCE && newClearance < oldClearance;
	}

	/** How far `pos` is from the nearest *closed* wall segment indexed at fine node `fineId` — `Math.POSITIVE_INFINITY` when there's no index, or no closed segment there, to check against. **/
	static function nearestClosedWallDistance(pos:h3d.Vector, fineId:Int, layout:MazeLayout, boundarySegments:Null<Map<Int, Array<BoundarySegment>>>):Float {
		var nearest = nearestClosedWallSegment(pos, fineId, layout, boundarySegments);
		return nearest == null ? Math.POSITIVE_INFINITY : distanceToSegment(pos, nearest);
	}

	/** The nearest *closed* wall segment indexed at fine node `fineId`, or `null` when there's no index, or no closed segment there — `nearestClosedWallDistance`'s own search, but returning the segment itself (`slideAlong`'s own `wallTangentOf` needs it), not just how far it is. **/
	static function nearestClosedWallSegment(pos:h3d.Vector, fineId:Int, layout:MazeLayout,
			boundarySegments:Null<Map<Int, Array<BoundarySegment>>>):Null<BoundarySegment> {
		if (boundarySegments == null) {
			return null;
		}
		var segments = boundarySegments.get(fineId);
		if (segments == null) {
			return null;
		}
		var nearest:Null<BoundarySegment> = null;
		var nearestDistance = Math.POSITIVE_INFINITY;
		for (segment in segments) {
			if (MazeEdges.isOpen(layout, Std.string(segment.coarseA), Std.string(segment.coarseB))) {
				continue;
			}
			var d = distanceToSegment(pos, segment);
			if (d < nearestDistance) {
				nearestDistance = d;
				nearest = segment;
			}
		}
		return nearest;
	}

	/** Point-to-segment distance, `pos` against `segment`'s own world-scale endpoints — the standard project-and-clamp: the closest point on the segment to `pos` is `a + clamp(t, 0, 1) * (b - a)`, `t` being how far along `a→b` `pos`'s own projection falls. **/
	static function distanceToSegment(pos:h3d.Vector, segment:BoundarySegment):Float {
		var a = worldPoint(segment.a);
		var b = worldPoint(segment.b);
		var ab = b.sub(a);
		var lengthSq = ab.lengthSq();
		var t = lengthSq > 0 ? pos.sub(a).dot(ab) / lengthSq : 0;
		t = hxd.Math.clamp(t, 0, 1);
		var closest = a.add(ab.scaled(t));
		return pos.distance(closest);
	}

	/** A unit-sphere `BoundarySegment` endpoint, converted to a world point — matching `GeodesicMesh.lift`'s own scale (its `WALL_BASE_LIFT` is negligible here; this only needs to be close enough to gate a distance-based clearance check, not exact wall geometry). **/
	static function worldPoint(direction:Vec3):h3d.Vector {
		return new h3d.Vector(direction.x, direction.y, direction.z).scaled(GeodesicMesh.RADIUS);
	}

	static function toVec3(pos:h3d.Vector):Vec3 {
		return Vec3Math.make(pos.x, pos.y, pos.z);
	}
}
