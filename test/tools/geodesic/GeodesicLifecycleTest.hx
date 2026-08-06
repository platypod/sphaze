package tools.geodesic;

import tools.geodesic.GeodesicLifeRule.GeodesicLifeRules;
import tools.geodesic.GeodesicLifecycle.LifecycleStage;
import utest.Assert;
import utest.Test;

/** Covers the age → stage → height/brightness rules, and specifically the one place render height and collision height deliberately disagree (`Dying`). **/
class GeodesicLifecycleTest extends Test {
	static inline final FREQUENCY:Int = 3;

	function testAFreshlySeededNodeIsYoung():Void {
		var state = newState();
		state.seedSingle(0);

		Assert.equals(LifecycleStage.Young, GeodesicLifecycle.stageOf(state, 0));
	}

	function testANodeWithNothingHappeningIsAbsent():Void {
		var state = newState();

		Assert.equals(LifecycleStage.Absent, GeodesicLifecycle.stageOf(state, 0));
	}

	function testANodeThatDiedThisGenerationIsDying():Void {
		var state = newState();
		state.seedSingle(0);
		state.step(() -> 1); // alone on the board: no live neighbors, so it dies

		Assert.equals(LifecycleStage.Dying, GeodesicLifecycle.stageOf(state, 0));
	}

	/**
		A `Dying` node still draws its farewell flash but has already
		stopped being floor — the one case where `blockHeightOf` and
		`groundHeightOf` must not agree, so a player standing on a cell
		that just died falls instead of hovering.
	**/
	function testADyingNodeStillRendersButIsNoLongerStandable():Void {
		var state = newState();
		state.seedSingle(0);
		state.step(() -> 1);

		Assert.equals(GeodesicLifecycle.DYING_BLOCK_HEIGHT, GeodesicLifecycle.blockHeightOf(GeodesicLifecycle.stageOf(state, 0)));
		Assert.equals(0.0, GeodesicLifecycle.groundHeightOf(state, 0));
	}

	function testAnAbsentNodeIsNeitherDrawnNorStandable():Void {
		var state = newState();

		Assert.equals(0.0, GeodesicLifecycle.blockHeightOf(GeodesicLifecycle.stageOf(state, 0)));
		Assert.equals(0.0, GeodesicLifecycle.groundHeightOf(state, 0));
	}

	function testAYoungNodeIsStandableAtItsFullRenderHeight():Void {
		var state = newState();
		state.seedSingle(0);

		Assert.equals(GeodesicLifecycle.YOUNG_BLOCK_HEIGHT, GeodesicLifecycle.groundHeightOf(state, 0));
	}

	/**
		The whole point of the two standable heights: a second jump's own
		apex (`~5.8`, see `biomes.conway.ConwayGrid.YOUNG_BLOCK_HEIGHT`)
		must clear `WALL_HEIGHT` from a `Young` block and must not from an
		`Aged` one. Asserted here so a future tweak to any of the three
		constants can't silently break the combo-jump mechanic they exist
		for.
	**/
	function testOnlyAYoungBlockIsTallEnoughToJumpAWall():Void {
		var secondJumpApex = 5.8;

		Assert.isTrue(GeodesicLifecycle.YOUNG_BLOCK_HEIGHT + secondJumpApex > GeodesicLifecycle.WALL_HEIGHT);
		Assert.isFalse(GeodesicLifecycle.AGED_BLOCK_HEIGHT + secondJumpApex > GeodesicLifecycle.WALL_HEIGHT);
	}

	function testYoungIsBrighterThanAgedWhichIsBrighterThanDying():Void {
		Assert.isTrue(GeodesicLifecycle.brightnessOf(Young) > GeodesicLifecycle.brightnessOf(Aged));
		Assert.isTrue(GeodesicLifecycle.brightnessOf(Aged) > GeodesicLifecycle.brightnessOf(Dying));
	}

	static function newState():GeodesicLifeState {
		return new GeodesicLifeState(GeodesicSphere.generate(FREQUENCY), GeodesicLifeRules.DEFAULT);
	}
}
