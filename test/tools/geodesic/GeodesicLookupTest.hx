package tools.geodesic;

import tools.geodesic.Vec3.Vec3Math;
import utest.Assert;
import utest.Test;

class GeodesicLookupTest extends Test {
	static inline final FREQUENCY:Int = 4;

	/** Phase 2's own exit check: every node's own stored center round-trips to itself. **/
	function testEveryNodesOwnPositionResolvesToItself():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var lookup = new GeodesicLookup(sphere, FREQUENCY);

		for (id in 0...sphere.positions.length) {
			var resolved = lookup.nodeAt(sphere.positions[id]);
			Assert.equals(id, resolved, 'node $id at ${sphere.positions[id]} resolved to $resolved instead');
		}
	}

	/** Phase 2's other exit check: a query works at any magnitude, not just exactly unit length. **/
	function testResolvesTheSameNodeRegardlessOfQueryMagnitude():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var lookup = new GeodesicLookup(sphere, FREQUENCY);
		var position = sphere.positions[0];

		Assert.equals(0, lookup.nodeAt(Vec3Math.scaled(position, 174))); // e.g. ConwayGrid.RADIUS scale
		Assert.equals(0, lookup.nodeAt(Vec3Math.scaled(position, 0.01)));
	}

	/**
		A shared edge's own midpoint is, by construction, exactly equidistant
		from its two endpoints — so a *third* node genuinely can be the
		correct answer there if it happens to sit even closer (this is
		exactly the case `nodeAt`'s own class doc records finding: node 11
		was, for one such midpoint at `FREQUENCY = 4`, closer than either of
		its own edge's endpoints). What has to hold regardless is that
		`nodeAt` never returns something *worse* than the obvious
		candidates — this checks that invariant directly rather than
		assuming a specific topological outcome.
	**/
	function testMidpointsResolveToANodeAtLeastAsCloseAsEitherEndpoint():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var lookup = new GeodesicLookup(sphere, FREQUENCY);

		for (id in 0...sphere.neighbors.length) {
			for (neighbor in sphere.neighbors[id]) {
				if (neighbor < id) {
					continue; // each undirected edge once
				}
				var midpoint = Vec3Math.normalized(Vec3Math.add(sphere.positions[id], sphere.positions[neighbor]));
				var resolvedId = lookup.nodeAt(midpoint);
				var resolvedDist = Vec3Math.distanceSquared(sphere.positions[resolvedId], midpoint);
				var endpointDist = Math.min(Vec3Math.distanceSquared(sphere.positions[id], midpoint),
					Vec3Math.distanceSquared(sphere.positions[neighbor], midpoint));
				Assert.isTrue(resolvedDist <= endpointDist + 1e-9,
					'midpoint of $id/$neighbor resolved to $resolvedId at distance $resolvedDist, worse than the nearer endpoint\'s own $endpointDist');
			}
		}
	}

	/** A dense sweep of arbitrary directions never throws — the "no match" failure mode the engineering note flagged as the one real open risk. **/
	function testADenseSweepOfArbitraryDirectionsNeverThrows():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var lookup = new GeodesicLookup(sphere, FREQUENCY);

		var thetaSteps = 37; // deliberately not a divisor of anything below - avoids accidentally only ever sampling face seams or their exact opposite
		var phiSteps = 53;
		for (thetaStep in 0...thetaSteps) {
			var theta = Math.PI * thetaStep / (thetaSteps - 1);
			for (phiStep in 0...phiSteps) {
				var phi = 2 * Math.PI * phiStep / phiSteps;
				var query = Vec3Math.make(Math.sin(theta) * Math.cos(phi), Math.cos(theta), Math.sin(theta) * Math.sin(phi));
				var id = lookup.nodeAt(query);
				Assert.isTrue(id >= 0 && id < sphere.neighbors.length, 'query (theta=$theta, phi=$phi) resolved to out-of-range id $id');
			}
		}
	}
}
