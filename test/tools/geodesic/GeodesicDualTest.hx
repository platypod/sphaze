package tools.geodesic;

import tools.geodesic.Vec3.Vec3Math;
import utest.Assert;
import utest.Test;

class GeodesicDualTest extends Test {
	static inline final FREQUENCY:Int = 3;

	function testCyclicNeighborsVisitsEveryNeighborExactlyOnce():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		for (id in 0...sphere.neighbors.length) {
			var ring = GeodesicDual.cyclicNeighbors(sphere, id);
			Assert.equals(sphere.neighbors[id].length, ring.length, 'node $id');
			for (n in sphere.neighbors[id]) {
				Assert.isTrue(ring.indexOf(n) != -1, 'node $id: $n missing from its own cyclic ring');
			}
		}
	}

	/** Consecutive entries in the cyclic ring are always themselves neighbors of each other — the actual "ring" property, not just "same set of ids." **/
	function testConsecutiveRingEntriesAreThemselvesNeighbors():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		for (id in 0...sphere.neighbors.length) {
			var ring = GeodesicDual.cyclicNeighbors(sphere, id);
			for (k in 0...ring.length) {
				var a = ring[k];
				var b = ring[(k + 1) % ring.length];
				Assert.isTrue(sphere.neighbors[a].indexOf(b) != -1, 'node $id: ring neighbors $a and $b are not themselves adjacent');
			}
		}
	}

	function testBoundaryVertexCountMatchesDegree():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var boundaries = GeodesicDual.cellBoundaries(sphere);
		for (id in 0...sphere.neighbors.length) {
			Assert.equals(sphere.neighbors[id].length, boundaries[id].length, 'node $id');
		}
	}

	function testEveryBoundaryPointIsUnitLength():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var boundaries = GeodesicDual.cellBoundaries(sphere);
		for (boundary in boundaries) {
			for (p in boundary) {
				Assert.floatEquals(1, Vec3Math.length(p));
			}
		}
	}

	/**
		Every maze edge's own wall segment must read the same regardless of
		which endpoint asks — this is the property `GeodesicMesh` actually
		depends on, since it only ever queries from the lower-numbered
		endpoint (`GeodesicMesh.build`'s own `neighbor <= id` dedupe).
	**/
	function testSharedEdgeAgreesFromEitherEndpoint():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var boundaries = GeodesicDual.cellBoundaries(sphere);

		for (id in 0...sphere.neighbors.length) {
			for (neighbor in sphere.neighbors[id]) {
				var fromHere = GeodesicDual.sharedEdge(sphere, boundaries, id, neighbor);
				var fromThere = GeodesicDual.sharedEdge(sphere, boundaries, neighbor, id);

				var forward = Vec3Math.distanceSquared(fromHere.a, fromThere.a) < 1e-12
					&& Vec3Math.distanceSquared(fromHere.b, fromThere.b) < 1e-12;
				var reversed = Vec3Math.distanceSquared(fromHere.a, fromThere.b) < 1e-12
					&& Vec3Math.distanceSquared(fromHere.b, fromThere.a) < 1e-12;
				Assert.isTrue(forward || reversed, 'edge $id-$neighbor: $fromHere from $id, $fromThere from $neighbor');
			}
		}
	}

	/** The two returned points must actually be boundary vertices of both cells — not just any two points near the edge. **/
	function testSharedEdgePointsBelongToBothCellsOwnBoundaries():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var boundaries = GeodesicDual.cellBoundaries(sphere);

		for (id in 0...sphere.neighbors.length) {
			for (neighbor in sphere.neighbors[id]) {
				var edge = GeodesicDual.sharedEdge(sphere, boundaries, id, neighbor);
				Assert.isTrue(containsPoint(boundaries[id], edge.a) && containsPoint(boundaries[id], edge.b),
					'edge $id-$neighbor: not both on $id\'s own boundary');
				Assert.isTrue(containsPoint(boundaries[neighbor], edge.a) && containsPoint(boundaries[neighbor], edge.b),
					'edge $id-$neighbor: not both on $neighbor\'s own boundary');
			}
		}
	}

	/** Every boundary point should sit closer to its own cell's center than to any neighboring cell's own center — the basic "this really is that cell's own boundary" sanity check. **/
	function testBoundaryPointsAreCloserToTheirOwnNodeThanToItsNeighbors():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var boundaries = GeodesicDual.cellBoundaries(sphere);
		for (id in 0...sphere.neighbors.length) {
			var center = sphere.positions[id];
			for (point in boundaries[id]) {
				var ownDist = Vec3Math.distanceSquared(point, center);
				for (neighbor in sphere.neighbors[id]) {
					var neighborDist = Vec3Math.distanceSquared(point, sphere.positions[neighbor]);
					Assert.isTrue(ownDist <= neighborDist + 1e-9, 'node $id: a boundary point is closer to neighbor $neighbor than to $id itself');
				}
			}
		}
	}

	static function containsPoint(boundary:Array<Vec3>, point:Vec3):Bool {
		for (p in boundary) {
			if (Vec3Math.distanceSquared(p, point) < 1e-12) {
				return true;
			}
		}
		return false;
	}
}
