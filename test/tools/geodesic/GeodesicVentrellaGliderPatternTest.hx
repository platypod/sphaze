package tools.geodesic;

import tools.geodesic.GeodesicVentrellaRule.GeodesicVentrellaRules;
import utest.Assert;
import utest.Test;

/**
	Covers `seed`'s own shape contract (exactly 3 cells, the right states,
	the right adjacency) — not whether the shape actually travels, which
	`GeodesicVentrellaFigure2`'s own long-run trace already confirmed by
	hand (see `docs/archive/decisions.md`'s 2026-08-09
	entry) and isn't worth re-proving in a fast unit test.
**/
class GeodesicVentrellaGliderPatternTest extends Test {
	static inline final FREQUENCY:Int = 10;

	function testSeedPlacesExactlyThreeCellsAtTheRightStates():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var origin = GeodesicGliderPatterns.flattestNode(sphere);
		var state = new GeodesicVentrellaState(sphere, GeodesicVentrellaRules.SPHERE_CA);

		var placed = GeodesicVentrellaGliderPattern.seed(state, sphere, origin, 0);

		Assert.equals(3, state.population());
		Assert.equals(1, state.stateOf(placed.black1));
		Assert.equals(1, state.stateOf(placed.black2));
		Assert.equals(3, state.stateOf(placed.gray1));
	}

	/** `black1`/`black2` are 2 hops apart (one empty hex between), never directly adjacent — the whole point of the shape, not incidental. **/
	function testTheTwoBlackCellsAreTwoHopsApartNotAdjacent():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var origin = GeodesicGliderPatterns.flattestNode(sphere);
		var state = new GeodesicVentrellaState(sphere, GeodesicVentrellaRules.SPHERE_CA);

		var placed = GeodesicVentrellaGliderPattern.seed(state, sphere, origin, 0);

		Assert.isTrue(sphere.neighbors[placed.black1].indexOf(placed.black2) == -1, "black1/black2 should not be direct neighbors");
		var distances = GeodesicShapeSignature.bfsDistances(sphere, placed.black1, [placed.black2]);
		Assert.equals(2, distances.get(placed.black2));
	}

	/** `gray1` is adjacent to `black2` — the cell it's meant to trail. **/
	function testGrayIsAdjacentToTheSecondBlackCell():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var origin = GeodesicGliderPatterns.flattestNode(sphere);
		var state = new GeodesicVentrellaState(sphere, GeodesicVentrellaRules.SPHERE_CA);

		var placed = GeodesicVentrellaGliderPattern.seed(state, sphere, origin, 0);

		Assert.isTrue(sphere.neighbors[placed.black2].indexOf(placed.gray1) != -1);
	}

	/** Different `southIndex` values (mod 6) actually pick different headings — the mechanism `GeodesicVentrellaGliderSpawner` relies on for launch-site variety. **/
	function testDifferentSouthIndexesProduceDifferentShapes():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var origin = GeodesicGliderPatterns.flattestNode(sphere);

		var stateA = new GeodesicVentrellaState(sphere, GeodesicVentrellaRules.SPHERE_CA);
		var placedA = GeodesicVentrellaGliderPattern.seed(stateA, sphere, origin, 0);

		var stateB = new GeodesicVentrellaState(sphere, GeodesicVentrellaRules.SPHERE_CA);
		var placedB = GeodesicVentrellaGliderPattern.seed(stateB, sphere, origin, 1);

		Assert.notEquals(placedA.black2, placedB.black2);
	}

	/** A non-hexagon origin is a caller bug, not a recoverable case — `GeodesicSphere`'s own invariant (pentagons mutually non-adjacent) guarantees `GeodesicVentrellaGliderSpawner`'s own anchors never hit this, but the check stays honest about needing one anyway. **/
	function testThrowsOnAPentagonOrigin():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var pentagon = GeodesicSphere.pentagons(sphere)[0];
		var state = new GeodesicVentrellaState(sphere, GeodesicVentrellaRules.SPHERE_CA);

		Assert.raises(() -> GeodesicVentrellaGliderPattern.seed(state, sphere, pentagon, 0));
	}
}
