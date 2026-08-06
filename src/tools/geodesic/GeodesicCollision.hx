package tools.geodesic;

import biomes.common.maze.MazeEdges;
import biomes.common.maze.MazeTopology.MazeLayout;
import entities.player.PlayerModel;
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
**/
class GeodesicCollision {
	/**
		@param player the player attempting to move — reverted in place if the move is blocked.
		@param direction world-space direction to move in (tangent-projected internally by `PlayerModel.moveAlong`).
		@param distance how far to move, in world units.
		@param radius the sphere's own radius.
		@param layout which edges are currently open — addressed by whatever id space `lookup` (as remapped by `fineToCoarse`, if given) actually resolves to.
		@param lookup resolves a world position to the node it's standing on.
		@param fineToCoarse when `lookup` resolves to a *fine* sphere but `layout` is a coarser maze built over a different sphere (`GeodesicCoarseMaze`'s own wall-straightening attempt), the fine→coarse map to remap through before checking `layout`. `null` when `lookup` and `layout` already share one id space — every use before the coarse maze existed.
		@return whether the move was allowed.
	**/
	public static function tryMove(player:PlayerModel, direction:h3d.Vector, distance:Float, radius:Float, layout:MazeLayout, lookup:GeodesicLookup,
			?fineToCoarse:Array<Int>):Bool {
		var fromId = resolve(lookup, fineToCoarse, toVec3(player.pos));
		var oldPos = player.pos;
		var oldForward = player.forward;

		player.moveAlong(direction, distance, radius);
		var toId = resolve(lookup, fineToCoarse, toVec3(player.pos));

		if (allowsStep(layout, fromId, toId, player.airborneHeight)) {
			return true;
		}

		player.pos = oldPos;
		player.forward = oldForward;
		return false;
	}

	/** `lookup.nodeAt(pos)`, remapped through `fineToCoarse` when one is given. **/
	static function resolve(lookup:GeodesicLookup, fineToCoarse:Null<Array<Int>>, pos:Vec3):Int {
		var fine = lookup.nodeAt(pos);
		return fineToCoarse == null ? fine : fineToCoarse[fine];
	}

	static function allowsStep(layout:MazeLayout, fromId:Int, toId:Int, playerHeight:Float):Bool {
		return fromId == toId
			|| playerHeight >= GeodesicLifecycle.WALL_HEIGHT
			|| MazeEdges.isOpen(layout, Std.string(fromId), Std.string(toId));
	}

	static function toVec3(pos:h3d.Vector):Vec3 {
		return Vec3Math.make(pos.x, pos.y, pos.z);
	}
}
