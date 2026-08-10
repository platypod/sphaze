package tools.geodesic;

import biomes.common.maze.MazeCarver;
import biomes.common.maze.MazeEdges;
import biomes.common.maze.MazeTopology.MazeLayout;
import biomes.maze.MazeGeneratorTest.SeededRandom;
import entities.player.PlayerModel;
import tools.geodesic.GeodesicCoarseMaze.BoundarySegment;
import tools.geodesic.GeodesicSphere.GeodesicSphereData;
import tools.geodesic.Vec3.Vec3Math;
import utest.Assert;
import utest.Test;

/**
	Exercises `GeodesicCollision.tryMove` against a real carved maze (via
	`GeodesicTopology` + `MazeCarver`) rather than a hand-built edge map —
	the same "go through the real machinery, not a duplicate of its own
	key format" reasoning `biomes.common.grid.GridCollisionTest`'s own
	class doc gives for doing the same thing on the square grid.
**/
class GeodesicCollisionTest extends Test {
	static inline final FREQUENCY:Int = 3;
	static inline final RADIUS:Float = 174;

	function testTryMoveBlocksAStepAcrossAClosedEdge():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var lookup = new GeodesicLookup(sphere, FREQUENCY);
		var layout = carveMaze(sphere);

		var edge = firstClosedEdge(sphere, layout);
		var player = playerAt(sphere, edge.from);
		var direction = directionToward(sphere, edge.from, edge.to);
		var distance = stepDistance(sphere, edge.from, edge.to);

		var moved = GeodesicCollision.tryMove(player, direction, distance, RADIUS, layout, lookup);

		Assert.isFalse(moved);
	}

	function testTryMoveAllowsAStepAcrossAnOpenEdge():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var lookup = new GeodesicLookup(sphere, FREQUENCY);
		var layout = carveMaze(sphere);

		var edge = firstOpenEdge(layout);
		var player = playerAt(sphere, edge.from);
		var direction = directionToward(sphere, edge.from, edge.to);
		var distance = stepDistance(sphere, edge.from, edge.to);

		var moved = GeodesicCollision.tryMove(player, direction, distance, RADIUS, layout, lookup);

		Assert.isTrue(moved);
	}

	/** The combo-jump mechanic: high enough above `GeodesicLifecycle.WALL_HEIGHT` and a closed edge no longer blocks — see `GeodesicCollision.allowsStep`'s own doc. **/
	function testTryMoveAllowsCrossingAClosedEdgeWhenAirborneAboveWallHeight():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var lookup = new GeodesicLookup(sphere, FREQUENCY);
		var layout = carveMaze(sphere);

		var edge = firstClosedEdge(sphere, layout);
		var player = playerAt(sphere, edge.from);
		player.airborneHeight = GeodesicLifecycle.WALL_HEIGHT + 1;
		var direction = directionToward(sphere, edge.from, edge.to);
		var distance = stepDistance(sphere, edge.from, edge.to);

		var moved = GeodesicCollision.tryMove(player, direction, distance, RADIUS, layout, lookup);

		Assert.isTrue(moved);
	}

	/** `GeodesicCoarseMaze`'s own wall-straightening attempt: `lookup` resolves fine ids, but `layout` is a maze over a coarser sphere — crossing must block exactly when the *coarse* edge between the two fine positions' own owning regions is closed. **/
	function testTryMoveWithFineToCoarseBlocksAcrossAClosedCoarseEdge():Void {
		var fineSphere = GeodesicSphere.generate(10);
		var coarseSphere = GeodesicSphere.generate(3);
		var coarseLookup = new GeodesicLookup(coarseSphere, 3);
		var fineToCoarse = GeodesicCoarseMaze.fineToCoarse(fineSphere, coarseLookup);
		var coarseLayout = MazeCarver.carve(new GeodesicTopology(coarseSphere), RandomizedDfs, 0, new SeededRandom(11).next);
		var fineLookup = new GeodesicLookup(fineSphere, 10);

		var boundary = firstBoundaryEdgeOverAClosedCoarseEdge(fineSphere, fineToCoarse, coarseLayout);
		var player = playerAt(fineSphere, boundary.from);
		var direction = directionToward(fineSphere, boundary.from, boundary.to);
		var distance = stepDistance(fineSphere, boundary.from, boundary.to);

		var moved = GeodesicCollision.tryMove(player, direction, distance, RADIUS, coarseLayout, fineLookup, fineToCoarse);

		Assert.isFalse(moved);
	}

	/** Two fine cells that share a coarse region must always be crossable, whatever the coarse layout says about *other* edges — there's no coarse edge for a same-region step to even check. **/
	function testTryMoveWithFineToCoarseAllowsAStepWithinTheSameCoarseRegion():Void {
		var fineSphere = GeodesicSphere.generate(10);
		var coarseSphere = GeodesicSphere.generate(3);
		var coarseLookup = new GeodesicLookup(coarseSphere, 3);
		var fineToCoarse = GeodesicCoarseMaze.fineToCoarse(fineSphere, coarseLookup);
		var coarseLayout:MazeLayout = {openEdges: new haxe.ds.StringMap()}; // nothing open anywhere at the coarse level
		var fineLookup = new GeodesicLookup(fineSphere, 10);

		var withinRegion = firstFineEdgeWithinTheSameCoarseRegion(fineSphere, fineToCoarse);
		var player = playerAt(fineSphere, withinRegion.from);
		var direction = directionToward(fineSphere, withinRegion.from, withinRegion.to);
		var distance = stepDistance(fineSphere, withinRegion.from, withinRegion.to);

		var moved = GeodesicCollision.tryMove(player, direction, distance, RADIUS, coarseLayout, fineLookup, fineToCoarse);

		Assert.isTrue(moved);
	}

	function testTryMoveAllowsAStepThatStaysWithinTheSameNode():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var lookup = new GeodesicLookup(sphere, FREQUENCY);
		var layout:MazeLayout = {openEdges: new haxe.ds.StringMap()}; // nothing open anywhere

		var player = playerAt(sphere, 0);
		var direction = new h3d.Vector(1, 0, 0);

		var moved = GeodesicCollision.tryMove(player, direction, 0.01, RADIUS, layout, lookup);

		Assert.isTrue(moved);
	}

	/**
		`boundarySegments` (2026-08-10): once closed walls got real thickness
		(`GeodesicMesh.WALL_THICKNESS`), the graph-only check above is no
		longer the whole story — `tryMove` also has to keep the player away
		from a *closed* segment's own slab. These tests build the synthetic
		segment/clearance geometry by hand, the same "hand-built edge map"
		style `testTryMoveAllowsAStepThatStaysWithinTheSameNode` already uses
		above, rather than deriving it from a real `GeodesicCoarseMaze` —
		what's under test here is `tryMove`'s own clearance arithmetic, not
		the coarse-maze machinery `testTryMoveWithFineToCoarse*` already
		covers. Every test below opens the *real* fine graph edge between the
		two nodes it moves across (when it isn't staying within one node's
		own cell), so a block is never attributable to the graph check this
		class's own tests above already cover — only to the new clearance
		one.
	**/
	function testTryMoveBlocksAStepThatEndsTooCloseToAClosedWallSegmentEvenWhenTheGraphEdgeIsOpen():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var lookup = new GeodesicLookup(sphere, FREQUENCY);
		var nodeId = 0;
		var neighborId = sphere.neighbors[nodeId][0];
		var layout:MazeLayout = {openEdges: new haxe.ds.StringMap()};
		MazeEdges.open(layout, Std.string(neighborId), Std.string(nodeId));

		var boundarySegments = wallPointAt(nodeId, sphere.positions[nodeId]);
		var player = playerAt(sphere, neighborId);
		var direction = directionToward(sphere, neighborId, nodeId);
		var distance = arcDistance(sphere, neighborId, nodeId) - 0.3; // lands just short of the wall point, well inside WALL_CLEARANCE

		var moved = GeodesicCollision.tryMove(player, direction, distance, RADIUS, layout, lookup, null, boundarySegments);

		Assert.isFalse(moved);
	}

	/** The "never trap the player" safety net: a player who's already too close to a closed wall (however that happened) must always be able to back away, even though the resulting clearance is still under `WALL_CLEARANCE`. **/
	function testTryMoveAllowsAStepThatIncreasesDistanceFromAnAlreadyTooCloseWall():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var lookup = new GeodesicLookup(sphere, FREQUENCY);
		var nodeId = 0;
		var neighborId = sphere.neighbors[nodeId][0];
		var layout:MazeLayout = {openEdges: new haxe.ds.StringMap()}; // irrelevant here: the move stays within node 0's own cell

		var boundarySegments = wallPointAt(nodeId, sphere.positions[nodeId]);
		var player = playerAt(sphere, nodeId); // starts exactly on the wall point itself: clearance 0, already too close
		var direction = directionToward(sphere, nodeId, neighborId); // move away from the wall

		var moved = GeodesicCollision.tryMove(player, direction, 0.5, RADIUS, layout, lookup, null, boundarySegments);

		Assert.isTrue(moved);
	}

	/** An *open* coarse pair isn't a wall at all right now, however close its own segment geometry sits — the clearance check must skip it entirely, the same as `MazeEdges.isOpen` already does for `nearestClosedWallDistance`'s own loop. **/
	function testTryMoveIgnoresClearanceNearAnOpenWallSegment():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var lookup = new GeodesicLookup(sphere, FREQUENCY);
		var nodeId = 0;
		var neighborId = sphere.neighbors[nodeId][0];
		var layout:MazeLayout = {openEdges: new haxe.ds.StringMap()};
		MazeEdges.open(layout, Std.string(neighborId), Std.string(nodeId));
		MazeEdges.open(layout, "1", "2"); // the synthetic segment's own coarse pair, explicitly open

		var boundarySegments = wallPointAt(nodeId, sphere.positions[nodeId]);
		var player = playerAt(sphere, neighborId);
		var direction = directionToward(sphere, neighborId, nodeId);
		var distance = arcDistance(sphere, neighborId, nodeId) - 0.3;

		var moved = GeodesicCollision.tryMove(player, direction, distance, RADIUS, layout, lookup, null, boundarySegments);

		Assert.isTrue(moved);
	}

	/** The combo-jump mechanic exempts the clearance check too, the same as it already exempts the graph check — a player high enough above `GeodesicLifecycle.WALL_HEIGHT` is meant to clear a wall entirely, slab and all. **/
	function testTryMoveIgnoresClearanceWhenAirborneAboveWallHeight():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var lookup = new GeodesicLookup(sphere, FREQUENCY);
		var nodeId = 0;
		var neighborId = sphere.neighbors[nodeId][0];
		var layout:MazeLayout = {openEdges: new haxe.ds.StringMap()};
		MazeEdges.open(layout, Std.string(neighborId), Std.string(nodeId));

		var boundarySegments = wallPointAt(nodeId, sphere.positions[nodeId]);
		var player = playerAt(sphere, neighborId);
		player.airborneHeight = GeodesicLifecycle.WALL_HEIGHT + 1;
		var direction = directionToward(sphere, neighborId, nodeId);
		var distance = arcDistance(sphere, neighborId, nodeId) - 0.3;

		var moved = GeodesicCollision.tryMove(player, direction, distance, RADIUS, layout, lookup, null, boundarySegments);

		Assert.isTrue(moved);
	}

	/** Backward compat: omitting `boundarySegments` entirely (every call site before 2026-08-10) must keep behaving exactly like the graph-only check alone — no clearance check ever runs. **/
	function testTryMoveIgnoresClearanceWhenNoBoundarySegmentsAreGiven():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var lookup = new GeodesicLookup(sphere, FREQUENCY);
		var nodeId = 0;
		var neighborId = sphere.neighbors[nodeId][0];
		var layout:MazeLayout = {openEdges: new haxe.ds.StringMap()};
		MazeEdges.open(layout, Std.string(neighborId), Std.string(nodeId));

		var player = playerAt(sphere, neighborId);
		var direction = directionToward(sphere, neighborId, nodeId);
		var distance = arcDistance(sphere, neighborId, nodeId) - 0.3;

		var moved = GeodesicCollision.tryMove(player, direction, distance, RADIUS, layout, lookup);

		Assert.isTrue(moved);
	}

	/**
		`tryMove`'s own slide-along-the-wall behavior (2026-08-10), asked
		directly: "movement along the walls does not work well... let's
		have the player slide along the wall rather than get stumped."
		Needs a *real* segment (an actual chord, not `wallPointAt`'s own
		degenerate single point — `wallTangentOf` on a zero-length segment
		is a zero vector, which would squash every slide attempt to
		nothing) with a clear tangent direction to slide along, so these
		build one by hand: a wall running along `north`, offset a few units
		`east` of the player's own starting position — both plain tangent
		directions at node 0, not needing to be real sphere adjacency.
	**/
	function testTryMoveSlidesAlongAClosedWallAtAShallowApproachAngle():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var lookup = new GeodesicLookup(sphere, FREQUENCY);
		var nodeId = 0;
		var layout:MazeLayout = {openEdges: new haxe.ds.StringMap()}; // the wall's own coarse pair (1, 2) stays closed

		var frame = tangentFrameAt(sphere, nodeId);
		var boundarySegments = wallSegmentAt(nodeId, frame.origin, frame.east, frame.north, 3, 10);

		var player = playerAt(sphere, nodeId);
		// mostly east (toward the wall, which sits 3 units east) with a north component to slide along — an
		// exact 0.8/0.6 unit direction, chosen so the unblocked attempt alone lands at east offset 3.2, well
		// inside WALL_CLEARANCE (0.8) of the wall's own east offset (3), not past it — a straight-line distance
		// check doesn't care about "crossing," only about ending up close.
		var direction = frame.east.scaled(0.8).add(frame.north.scaled(0.6));

		var moved = GeodesicCollision.tryMove(player, direction, 4, RADIUS, layout, lookup, null, boundarySegments);

		Assert.isTrue(moved, "a shallow-angle approach should slide, not stop dead");
		var travelled = player.pos.sub(frame.origin);
		var eastOffset = travelled.dot(frame.east);
		var northOffset = travelled.dot(frame.north);
		Assert.isTrue(Math.abs(eastOffset) < 1, 'the slide should not have carried the player toward the wall (east offset $eastOffset)');
		Assert.isTrue(northOffset > 1, 'the slide should have carried the player along the wall (north offset $northOffset)');
	}

	/** Approaching square-on leaves nothing to slide with — same physics as any FPS wall-slide, and `GridCollision.slideAlong`'s own doc for the square grid gives the same reasoning. **/
	function testTryMoveApproachingAWallSquareOnStopsDeadRatherThanSliding():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var lookup = new GeodesicLookup(sphere, FREQUENCY);
		var nodeId = 0;
		var layout:MazeLayout = {openEdges: new haxe.ds.StringMap()};

		var frame = tangentFrameAt(sphere, nodeId);
		var boundarySegments = wallSegmentAt(nodeId, frame.origin, frame.east, frame.north, 3, 10);

		var player = playerAt(sphere, nodeId);
		var direction = frame.east; // straight at the wall, nothing along it to slide with

		// lands at east offset 2.5 — inside WALL_CLEARANCE (0.8) of the wall's own east offset (3) — same reasoning as the shallow-angle test above
		var moved = GeodesicCollision.tryMove(player, direction, 2.5, RADIUS, layout, lookup, null, boundarySegments);

		Assert.isFalse(moved);
		Assert.isTrue(player.pos.distance(frame.origin) < 1e-6, "a square-on hit should leave the player exactly where they started");
	}

	/** Two tangent directions at `sphere.positions[nodeId]`'s own world position, plus that position itself — the local frame the slide tests build their own synthetic wall geometry in. **/
	static function tangentFrameAt(sphere:GeodesicSphereData, nodeId:Int):{origin:h3d.Vector, east:h3d.Vector, north:h3d.Vector} {
		var origin = playerAt(sphere, nodeId).pos;
		var up = origin.normalized();
		var neighborId = sphere.neighbors[nodeId][0];
		var east = directionToward(sphere, nodeId, neighborId).normalized();
		var north = up.cross(east).normalized();
		return {origin: origin, east: east, north: north};
	}

	/** A real (non-degenerate) wall segment running along `north` for `halfLength` in each direction, offset `eastOffset` units east of `origin` — indexed at `nodeId`, its own coarse pair (`1`/`2`) closed unless the caller opens it. **/
	static function wallSegmentAt(nodeId:Int, origin:h3d.Vector, east:h3d.Vector, north:h3d.Vector, eastOffset:Float,
			halfLength:Float):Map<Int, Array<BoundarySegment>> {
		var center = origin.add(east.scaled(eastOffset));
		var a = center.add(north.scaled(halfLength));
		var b = center.sub(north.scaled(halfLength));
		var index = new Map<Int, Array<BoundarySegment>>();
		index.set(nodeId, [
			{
				a: toUnitScale(a),
				b: toUnitScale(b),
				coarseA: 1,
				coarseB: 2
			}
		]);
		return index;
	}

	/** `point`, scaled down by `RADIUS` — the inverse of `GeodesicCollision`'s own `worldPoint`, since `BoundarySegment.a`/`.b` are unit-sphere-scale but the slide tests build their own wall geometry in world units. **/
	static function toUnitScale(point:h3d.Vector):Vec3 {
		return Vec3Math.make(point.x / RADIUS, point.y / RADIUS, point.z / RADIUS);
	}

	/** A degenerate, single-point "segment" (`a == b`) indexed at `nodeId`, its own coarse pair (`1`/`2`) left closed unless the caller opens it — the minimal fixture `nearestClosedWallDistance`'s point-to-segment math needs. **/
	static function wallPointAt(nodeId:Int, point:Vec3):Map<Int, Array<BoundarySegment>> {
		var index = new Map<Int, Array<BoundarySegment>>();
		index.set(nodeId, [
			{
				a: point,
				b: point,
				coarseA: 1,
				coarseB: 2
			}
		]);
		return index;
	}

	/** The exact great-circle arc length between two node centers, in world units — precise enough (unlike `stepDistance`'s own deliberate 1.2x overshoot) to land a move just short of a target point rather than past it. **/
	static function arcDistance(sphere:GeodesicSphereData, fromId:Int, toId:Int):Float {
		var from = Vec3Math.normalized(sphere.positions[fromId]);
		var to = Vec3Math.normalized(sphere.positions[toId]);
		var cosAngle = hxd.Math.clamp(Vec3Math.dot(from, to), -1, 1);
		return Math.acos(cosAngle) * RADIUS;
	}

	static function carveMaze(sphere:GeodesicSphereData):MazeLayout {
		return MazeCarver.carve(new GeodesicTopology(sphere), RandomizedDfs, 0, new SeededRandom(7).next);
	}

	static function playerAt(sphere:GeodesicSphereData, nodeId:Int):PlayerModel {
		var p = sphere.positions[nodeId];
		var pos = new h3d.Vector(p.x * RADIUS, p.y * RADIUS, p.z * RADIUS);
		return new PlayerModel(pos, new h3d.Vector(1, 0, 0));
	}

	static function directionToward(sphere:GeodesicSphereData, fromId:Int, toId:Int):h3d.Vector {
		var from = sphere.positions[fromId];
		var to = sphere.positions[toId];
		var d = Vec3Math.subtract(to, from);
		return new h3d.Vector(d.x, d.y, d.z);
	}

	/** Straight-line distance between the two node centers, with a margin, converted to world units — enough to land past the shared boundary regardless of the (slightly curved) actual geodesic path `moveAlong` follows. **/
	static function stepDistance(sphere:GeodesicSphereData, fromId:Int, toId:Int):Float {
		var d = Vec3Math.subtract(sphere.positions[toId], sphere.positions[fromId]);
		return Vec3Math.length(d) * RADIUS * 1.2;
	}

	static function firstClosedEdge(sphere:GeodesicSphereData, layout:MazeLayout):{from:Int, to:Int} {
		for (id in 0...sphere.neighbors.length) {
			for (neighbor in sphere.neighbors[id]) {
				if (!MazeEdges.isOpen(layout, Std.string(id), Std.string(neighbor))) {
					return {from: id, to: neighbor};
				}
			}
		}
		throw "expected at least one closed edge in a maze over more than one node";
	}

	static function firstOpenEdge(layout:MazeLayout):{from:Int, to:Int} {
		for (key in layout.openEdges.keys()) {
			var parts = key.split("|");
			return {from: Std.parseInt(parts[0]), to: Std.parseInt(parts[1])};
		}
		throw "expected at least one open edge in a carved maze";
	}

	static function firstBoundaryEdgeOverAClosedCoarseEdge(fineSphere:GeodesicSphereData, fineToCoarse:Array<Int>, coarseLayout:MazeLayout):{from:Int, to:Int} {
		for (id in 0...fineSphere.neighbors.length) {
			for (neighbor in fineSphere.neighbors[id]) {
				var coarseA = fineToCoarse[id];
				var coarseB = fineToCoarse[neighbor];
				if (coarseA == coarseB) {
					continue;
				}
				if (!MazeEdges.isOpen(coarseLayout, Std.string(coarseA), Std.string(coarseB))) {
					return {from: id, to: neighbor};
				}
			}
		}
		throw "expected at least one fine boundary edge over a closed coarse edge";
	}

	static function firstFineEdgeWithinTheSameCoarseRegion(fineSphere:GeodesicSphereData, fineToCoarse:Array<Int>):{from:Int, to:Int} {
		for (id in 0...fineSphere.neighbors.length) {
			for (neighbor in fineSphere.neighbors[id]) {
				if (fineToCoarse[id] == fineToCoarse[neighbor]) {
					return {from: id, to: neighbor};
				}
			}
		}
		throw "expected at least one fine edge within a single coarse region";
	}
}
