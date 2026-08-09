package tools.geodesic;

import tools.geodesic.GeodesicLifecycle.LifecycleStage;
import tools.geodesic.GeodesicVentrellaRule.GeodesicVentrellaRules;
import utest.Assert;
import utest.Test;

/** Covers the alive/dying/absent → height/brightness rules, and specifically the one place render height and collision height deliberately disagree (`Dying`). **/
class GeodesicLifecycleTest extends Test {
	static inline final FREQUENCY:Int = 3;

	function testAFreshlySeededNodeIsAlive():Void {
		var state = newState();
		state.seedSingle(0);

		Assert.equals(LifecycleStage.Alive, GeodesicLifecycle.stageOf(state, 0));
	}

	function testANodeWithNothingHappeningIsAbsent():Void {
		var state = newState();

		Assert.equals(LifecycleStage.Absent, GeodesicLifecycle.stageOf(state, 0));
	}

	/**
		Seeded to state `3` specifically, not the default `1`: state `3`'s
		own only subrule (`GeodesicVentrellaRules.SPHERE_CA`'s index 19,
		`3111`) requires exactly one neighbor already in state `1`, which an
		isolated node alone on an otherwise-quiescent board never has — so
		no subrule matches and it correctly reverts to quiescent, the "dies"
		case this test wants. States `1`/`2` both have at least one subrule
		that fires from an all-quiescent neighborhood (verified by hand
		against the table, not assumed), so they don't isolate-and-die the
		way a lone cell would under `GeodesicLifeState`'s birth/survival
		rules — a real, rule-specific difference worth this comment rather
		than a silently "obvious" seed choice.
	**/
	function testANodeThatDiedThisGenerationIsDying():Void {
		var state = newState();
		state.seedSingle(0, 3);
		state.step(() -> 1); // rng() always 1: never below MUTATION_RATE, so this generation is pure subrule math

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
		state.seedSingle(0, 3); // see testANodeThatDiedThisGenerationIsDying's own doc for why state 3, not the default 1
		state.step(() -> 1);

		Assert.equals(GeodesicLifecycle.DYING_BLOCK_HEIGHT, GeodesicLifecycle.blockHeightOf(GeodesicLifecycle.stageOf(state, 0)));
		Assert.equals(0.0, GeodesicLifecycle.groundHeightOf(state, 0));
	}

	function testAnAbsentNodeIsNeitherDrawnNorStandable():Void {
		var state = newState();

		Assert.equals(0.0, GeodesicLifecycle.blockHeightOf(GeodesicLifecycle.stageOf(state, 0)));
		Assert.equals(0.0, GeodesicLifecycle.groundHeightOf(state, 0));
	}

	function testAnAliveNodeIsStandableAtItsFullRenderHeight():Void {
		var state = newState();
		state.seedSingle(0);

		Assert.equals(GeodesicLifecycle.ALIVE_BLOCK_HEIGHT, GeodesicLifecycle.groundHeightOf(state, 0));
	}

	/**
		The combo-jump mechanic this height exists for: a second jump's own
		apex (`~5.8`, see `biomes.conway.ConwayGrid.YOUNG_BLOCK_HEIGHT`) must
		clear `WALL_HEIGHT` from an `Alive` block. Asserted here so a future
		tweak to either constant can't silently break it — see
		`GeodesicLifecycle`'s own doc for why every live cell gets this
		height now (no more Young/Aged split).
	**/
	function testAnAliveBlockIsTallEnoughToJumpAWall():Void {
		var secondJumpApex = 5.8;

		Assert.isTrue(GeodesicLifecycle.ALIVE_BLOCK_HEIGHT + secondJumpApex > GeodesicLifecycle.WALL_HEIGHT);
	}

	function testAliveIsBrighterThanDying():Void {
		Assert.isTrue(GeodesicLifecycle.brightnessOf(Alive) > GeodesicLifecycle.brightnessOf(Dying));
	}

	static function newState():GeodesicVentrellaState {
		return new GeodesicVentrellaState(GeodesicSphere.generate(FREQUENCY), GeodesicVentrellaRules.SPHERE_CA);
	}
}
