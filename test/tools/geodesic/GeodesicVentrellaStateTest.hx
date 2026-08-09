package tools.geodesic;

import tools.geodesic.GeodesicVentrellaRule.GeodesicVentrellaRules;
import utest.Assert;
import utest.Test;

/**
	Mirrors `GeodesicLifeStateTest`'s own shape (isolated-cell behavior,
	mutation override, serialize round-trip) over the 4-state engine.
**/
class GeodesicVentrellaStateTest extends Test {
	static inline final FREQUENCY:Int = 3;

	/**
		An isolated live cell (no other live cell anywhere on the board)
		does *not* die in one step the way a lone `GeodesicLifeState` cell
		does — hand-verified against every `GeodesicVentrellaRules.SPHERE_CA`
		subrule whose own `referenceState` matches the cell's current state:
		state `1`'s own subrules 10 and 13 both fire off an all-quiescent
		neighborhood (both need exactly `0` state-`1` neighbors), subrule 13
		winning since it's checked later, landing on state `2`; state `2`'s
		own subrule 18 fires the same way (needs `0` state-`3` neighbors),
		landing on state `3`; state `3`'s own only subrule (19) needs
		exactly *one* state-`1` neighbor, which an isolated cell never has,
		so nothing matches and it finally reverts to quiescent — a
		3-generation cycle before extinction, not an instant kill, and a
		real behavioral difference from the birth/survival engine worth
		pinning down rather than assuming "isolated cell dies" still holds.
	**/
	function testAnIsolatedCellCyclesThroughStatesBeforeDying():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var state = new GeodesicVentrellaState(sphere, GeodesicVentrellaRules.SPHERE_CA);
		state.seedSingle(0, 1);

		state.step(noMutation);
		Assert.equals(2, state.stateOf(0));
		Assert.isTrue(state.isAlive(0));

		state.step(noMutation);
		Assert.equals(3, state.stateOf(0));

		state.step(noMutation);
		Assert.isFalse(state.isAlive(0));
		Assert.isTrue(state.justDiedAt(0));

		state.step(noMutation);
		Assert.isFalse(state.isAlive(0), "quiescent with an all-quiescent neighborhood is a fixed point");
		Assert.isFalse(state.justDiedAt(0), "already dead the generation before — this step has nothing new to flag");
	}

	/**
		A call-counted `random` pins mutation as the actual cause: node 0's
		own first call (its mutation check) is forced under `MUTATION_RATE`;
		its second call (the state pick) lands on `0.6`, `Std.int(0.6 * 4)
		== 2`; every later call (every other node's own check) also gets
		`0.6`, safely above `MUTATION_RATE`, so nothing else on this
		otherwise-empty board mutates. Node 0's own un-mutated computed
		value on an empty board is `0` (quiescent stays quiescent — the
		same "no spontaneous generation" property `testEveryNeighborCountsRegardlessOfAnyMaze`-style
		checks confirm elsewhere), so a final state of `2` is unambiguously
		the mutation, not incidental subrule math.
	**/
	function testMutationCanForceANodeAliveAgainstAnEmptyBoard():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var state = new GeodesicVentrellaState(sphere, GeodesicVentrellaRules.SPHERE_CA);
		var callCount = 0;
		var rng = function():Float {
			callCount++;
			return callCount == 1 ? 0.0 : 0.6;
		};

		state.step(rng);

		Assert.isTrue(state.isAlive(0));
		Assert.equals(2, state.stateOf(0));
	}

	function testStateOfIsZeroForANodeNeverTouched():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var state = new GeodesicVentrellaState(sphere, GeodesicVentrellaRules.SPHERE_CA);

		Assert.equals(0, state.stateOf(0));
		Assert.isFalse(state.isAlive(0));
	}

	function testSeedAtDensityOnePlacesEveryNodeAtStateOne():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var state = new GeodesicVentrellaState(sphere, GeodesicVentrellaRules.SPHERE_CA);

		state.seed(1, () -> 0); // rng() always < density(1): every node should end up seeded

		Assert.equals(sphere.neighbors.length, state.population());
		Assert.equals(1, state.stateOf(0));
	}

	function testSeedAtDensityZeroPlacesNoNode():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var state = new GeodesicVentrellaState(sphere, GeodesicVentrellaRules.SPHERE_CA);

		state.seed(0, noMutation); // rng() (always 1) is never < density(0): nothing should be placed

		Assert.equals(0, state.population());
	}

	/** `state`/`activity` both round-trip; `justDied` deliberately doesn't (see `serialize`'s own doc). **/
	function testSerializeRoundTripsStateAndActivity():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var state = new GeodesicVentrellaState(sphere, GeodesicVentrellaRules.SPHERE_CA);
		state.seedSingle(0, 1);
		state.step(noMutation); // gives node 0 a real activity reading and lands it on state 2

		var restored = GeodesicVentrellaState.deserialize(sphere, GeodesicVentrellaRules.SPHERE_CA, state.serialize());

		Assert.equals(state.stateOf(0), restored.stateOf(0));
		Assert.isTrue(restored.isAlive(0));
		Assert.equals(state.activityOf(0), restored.activityOf(0));
		Assert.equals(state.population(), restored.population());
		Assert.isFalse(restored.justDiedAt(0), "justDied is a one-generation visual cue, not persisted state");
	}

	function testDeserializeOfAnEmptyBoardIsEmpty():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var state = new GeodesicVentrellaState(sphere, GeodesicVentrellaRules.SPHERE_CA);

		var restored = GeodesicVentrellaState.deserialize(sphere, GeodesicVentrellaRules.SPHERE_CA, state.serialize());

		Assert.equals(0, restored.population());
	}

	static function noMutation():Float {
		return 1; // never below GeodesicVentrellaState.MUTATION_RATE
	}
}
