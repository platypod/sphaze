package tools.geodesic;

import tools.geodesic.GeodesicLifeRule.GeodesicLifeRules;
import utest.Assert;
import utest.Test;

class GeodesicCoarseMazeTest extends Test {
	static inline final FINE_FREQUENCY:Int = 10;
	static inline final COARSE_FREQUENCY:Int = 3;

	function testFineToCoarseAssignsEveryFineNodeToARealCoarseNode():Void {
		var fineSphere = GeodesicSphere.generate(FINE_FREQUENCY);
		var coarseSphere = GeodesicSphere.generate(COARSE_FREQUENCY);
		var lookup = new GeodesicLookup(coarseSphere, COARSE_FREQUENCY);

		var map = GeodesicCoarseMaze.fineToCoarse(fineSphere, lookup);

		Assert.equals(fineSphere.neighbors.length, map.length);
		for (coarseId in map) {
			Assert.isTrue(coarseId >= 0 && coarseId < coarseSphere.neighbors.length);
		}
	}

	/** The property `GeodesicCoarseMaze`'s own doc leans on: a boundary never skips a region — the two coarse owners of any crossing fine edge are themselves adjacent in the coarse sphere's own graph. **/
	function testEveryBoundaryEdgeCrossesToAnAdjacentCoarseRegion():Void {
		var fineSphere = GeodesicSphere.generate(FINE_FREQUENCY);
		var coarseSphere = GeodesicSphere.generate(COARSE_FREQUENCY);
		var lookup = new GeodesicLookup(coarseSphere, COARSE_FREQUENCY);
		var map = GeodesicCoarseMaze.fineToCoarse(fineSphere, lookup);

		var boundaries = GeodesicCoarseMaze.boundaryEdges(fineSphere, map);
		Assert.isTrue(boundaries.length > 0, "expected at least one boundary edge on a real sphere");
		for (edge in boundaries) {
			var coarseA = map[edge.a];
			var coarseB = map[edge.b];
			Assert.isTrue(coarseSphere.neighbors[coarseA].indexOf(coarseB) != -1,
				'coarse regions $coarseA/$coarseB (from fine edge ${edge.a}-${edge.b}) are not adjacent');
		}
	}

	function testBoundaryEdgesExcludesEveryEdgeWithinTheSameRegion():Void {
		var fineSphere = GeodesicSphere.generate(FINE_FREQUENCY);
		var coarseSphere = GeodesicSphere.generate(COARSE_FREQUENCY);
		var lookup = new GeodesicLookup(coarseSphere, COARSE_FREQUENCY);
		var map = GeodesicCoarseMaze.fineToCoarse(fineSphere, lookup);

		var boundaries = GeodesicCoarseMaze.boundaryEdges(fineSphere, map);
		for (edge in boundaries) {
			Assert.notEquals(map[edge.a], map[edge.b]);
		}
	}

	/**
		The actual property `boundaryActivity` exists for now (2026-08-06,
		binary rather than decaying — see this class's own doc): a coarse
		edge reads hot only while *both* of some crossing's own two fine
		endpoints are alive right now, not on lingering recency from either
		one. Seeds only the two specific fine cells a real boundary edge
		crosses, nothing else on the board, so there's no ambiguity about
		which crossing produced the reading.
	**/
	function testBoundaryActivityIsOneWhenBothOfACrossingsOwnFineEndpointsAreAlive():Void {
		var fineSphere = GeodesicSphere.generate(FINE_FREQUENCY);
		var coarseSphere = GeodesicSphere.generate(COARSE_FREQUENCY);
		var lookup = new GeodesicLookup(coarseSphere, COARSE_FREQUENCY);
		var map = GeodesicCoarseMaze.fineToCoarse(fineSphere, lookup);
		var boundaries = GeodesicCoarseMaze.boundaryEdges(fineSphere, map);
		var sample = boundaries[0];
		var coarseA = map[sample.a];
		var coarseB = map[sample.b];

		var state = new GeodesicLifeState(fineSphere, GeodesicLifeRules.DEFAULT);
		state.seedSingle(sample.a);
		state.seedSingle(sample.b);

		var activityOf = GeodesicCoarseMaze.boundaryActivity(state, boundaries, map);

		Assert.equals(1.0, activityOf(coarseA, coarseB));
		Assert.equals(1.0, activityOf(coarseB, coarseA), "should read the same regardless of which endpoint is asked first");
	}

	/** The other half of the same property: *one* of a crossing's own two fine endpoints alive is not enough — both must be, or the coarse edge reads cold. **/
	function testBoundaryActivityIsZeroWhenOnlyOneOfACrossingsOwnFineEndpointsIsAlive():Void {
		var fineSphere = GeodesicSphere.generate(FINE_FREQUENCY);
		var coarseSphere = GeodesicSphere.generate(COARSE_FREQUENCY);
		var lookup = new GeodesicLookup(coarseSphere, COARSE_FREQUENCY);
		var map = GeodesicCoarseMaze.fineToCoarse(fineSphere, lookup);
		var boundaries = GeodesicCoarseMaze.boundaryEdges(fineSphere, map);
		var sample = boundaries[0];
		var coarseA = map[sample.a];
		var coarseB = map[sample.b];

		var state = new GeodesicLifeState(fineSphere, GeodesicLifeRules.DEFAULT);
		state.seedSingle(sample.a);

		var activityOf = GeodesicCoarseMaze.boundaryActivity(state, boundaries, map);

		Assert.equals(0.0, activityOf(coarseA, coarseB));
	}

	function testBoundaryActivityIsZeroForACoarsePairWithNoBoundaryCrossing():Void {
		var fineSphere = GeodesicSphere.generate(FINE_FREQUENCY);
		var coarseSphere = GeodesicSphere.generate(COARSE_FREQUENCY);
		var lookup = new GeodesicLookup(coarseSphere, COARSE_FREQUENCY);
		var map = GeodesicCoarseMaze.fineToCoarse(fineSphere, lookup);
		var boundaries = GeodesicCoarseMaze.boundaryEdges(fineSphere, map);
		var state = new GeodesicLifeState(fineSphere, GeodesicLifeRules.DEFAULT);
		state.seed(1, () -> 0); // everyone alive — doesn't matter, node 0 never borders itself

		var activityOf = GeodesicCoarseMaze.boundaryActivity(state, boundaries, map);

		Assert.equals(0.0, activityOf(0, 0));
	}
}
