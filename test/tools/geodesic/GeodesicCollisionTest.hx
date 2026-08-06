package tools.geodesic;

import biomes.common.maze.MazeCarver;
import biomes.common.maze.MazeEdges;
import biomes.common.maze.MazeTopology.MazeLayout;
import biomes.maze.MazeGeneratorTest.SeededRandom;
import entities.player.PlayerModel;
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
