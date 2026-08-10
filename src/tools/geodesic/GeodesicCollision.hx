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
		@param boundarySegments the fine-node-indexed wall geometry (`GeodesicCoarseMaze.boundarySegmentsByFineNode`) to keep the player's own head `WALL_CLEARANCE` away from a *closed* wall's own now-solid slab (`GeodesicMesh.WALL_THICKNESS`), so the camera can't end up inside it. `null` skips the check entirely — every use before walls got thickness.
		@return whether the move was allowed.
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

		player.pos = oldPos;
		player.forward = oldForward;
		return false;
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
		if (boundarySegments == null) {
			return Math.POSITIVE_INFINITY;
		}
		var segments = boundarySegments.get(fineId);
		if (segments == null) {
			return Math.POSITIVE_INFINITY;
		}
		var nearest = Math.POSITIVE_INFINITY;
		for (segment in segments) {
			if (MazeEdges.isOpen(layout, Std.string(segment.coarseA), Std.string(segment.coarseB))) {
				continue;
			}
			var d = distanceToSegment(pos, segment);
			if (d < nearest) {
				nearest = d;
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
