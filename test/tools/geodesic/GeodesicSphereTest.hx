package tools.geodesic;

import tools.geodesic.Vec3.Vec3Math;
import utest.Assert;
import utest.Test;

class GeodesicSphereTest extends Test {
	static final FREQUENCIES_TO_CHECK = [1, 2, 3, 5];

	function testNodeCountMatchesTheClosedFormFormula():Void {
		for (frequency in FREQUENCIES_TO_CHECK) {
			var sphere = GeodesicSphere.generate(frequency);
			var expected = 10 * frequency * frequency + 2;
			Assert.equals(expected, sphere.neighbors.length, 'frequency $frequency: expected $expected nodes, got ${sphere.neighbors.length}');
			Assert.equals(expected, sphere.positions.length);
		}
	}

	function testExactlyTwelvePentagonsAtEveryFrequency():Void {
		for (frequency in FREQUENCIES_TO_CHECK) {
			var sphere = GeodesicSphere.generate(frequency);
			Assert.equals(12, GeodesicSphere.pentagons(sphere).length, 'frequency $frequency');
		}
	}

	function testEveryNodeIsDegreeFiveOrSix():Void {
		var sphere = GeodesicSphere.generate(3);
		for (id in 0...sphere.neighbors.length) {
			var degree = sphere.neighbors[id].length;
			Assert.isTrue(degree == 5 || degree == 6, 'node $id has degree $degree');
		}
	}

	/** Pentagons sit at the original icosahedron's own vertices, which are never adjacent to each other once subdivided — free spacing for a beacon mechanic, not something that has to be arranged separately. **/
	function testPentagonsAreMutuallyNonAdjacent():Void {
		var sphere = GeodesicSphere.generate(3);
		var pentagons = GeodesicSphere.pentagons(sphere);
		var pentagonSet = new haxe.ds.IntMap<Bool>();
		for (id in pentagons) {
			pentagonSet.set(id, true);
		}
		for (id in pentagons) {
			for (neighbor in sphere.neighbors[id]) {
				Assert.isFalse(pentagonSet.exists(neighbor), 'pentagon $id neighbors pentagon $neighbor');
			}
		}
	}

	function testAdjacencyIsSymmetric():Void {
		var sphere = GeodesicSphere.generate(2);
		for (id in 0...sphere.neighbors.length) {
			for (neighbor in sphere.neighbors[id]) {
				Assert.isTrue(sphere.neighbors[neighbor].indexOf(id) != -1, '$id lists $neighbor as a neighbor but not the reverse');
			}
		}
	}

	function testEveryNeighborIdIsInBounds():Void {
		var sphere = GeodesicSphere.generate(2);
		for (id in 0...sphere.neighbors.length) {
			for (neighbor in sphere.neighbors[id]) {
				Assert.isTrue(neighbor >= 0 && neighbor < sphere.neighbors.length);
			}
		}
	}

	function testEveryPositionIsUnitLength():Void {
		var sphere = GeodesicSphere.generate(2);
		for (p in sphere.positions) {
			Assert.floatEquals(1, Vec3Math.length(p));
		}
	}

	function testGenerateRejectsAFrequencyBelowOne():Void {
		Assert.raises(() -> GeodesicSphere.generate(0), String);
	}

	/** Round-trips through the exact JSON shape `GeodesicBake` writes — not a shape this test invents, so a change to the bake format that this parser doesn't also follow fails here instead of at runtime. **/
	function testFromJsonRoundTripsWhatBakeWrites():Void {
		var sphere = GeodesicSphere.generate(2);
		var json = haxe.Json.stringify({
			frequency: 2,
			positions: [for (p in sphere.positions) {x: p.x, y: p.y, z: p.z}],
			neighbors: sphere.neighbors,
			pentagons: GeodesicSphere.pentagons(sphere),
		});

		var loaded = GeodesicSphere.fromJson(json);

		Assert.equals(2, loaded.frequency);
		Assert.equals(sphere.positions.length, loaded.sphere.positions.length);
		for (id in 0...sphere.positions.length) {
			Assert.floatEquals(sphere.positions[id].x, loaded.sphere.positions[id].x);
			Assert.floatEquals(sphere.positions[id].y, loaded.sphere.positions[id].y);
			Assert.floatEquals(sphere.positions[id].z, loaded.sphere.positions[id].z);
			Assert.equals(sphere.neighbors[id].length, loaded.sphere.neighbors[id].length, 'node $id');
			for (neighbor in sphere.neighbors[id]) {
				Assert.isTrue(loaded.sphere.neighbors[id].indexOf(neighbor) != -1, 'node $id missing neighbor $neighbor after round-trip');
			}
		}
	}
}
