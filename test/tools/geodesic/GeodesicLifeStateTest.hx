package tools.geodesic;

import tools.geodesic.GeodesicLifeRule.GeodesicLifeRules;
import tools.geodesic.GeodesicSphere.GeodesicSphereData;
import utest.Assert;
import utest.Test;

/**
	Mirrors `biomes.conway.ConwayStateTest`'s own shape (isolated cell
	dies, mutation can override the rule, age/justDied track correctly) —
	the same mechanics on the new node-id addressing, tested the same way.

	Notably *without* any `MazeLayout` setup, which the first version of
	this file was full of: this simulation runs on the sphere's own full
	adjacency and walls no longer gate it. See `GeodesicLifeState`'s own
	class doc for why that gate came back out.
**/
class GeodesicLifeStateTest extends Test {
	static inline final FREQUENCY:Int = 3;

	function testALoneNodeDiesOfUnderPopulation():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var state = new GeodesicLifeState(sphere, GeodesicLifeRules.DEFAULT);
		state.seedSingle(0);

		state.step(noMutation);

		Assert.isFalse(state.isAlive(0));
		Assert.isTrue(state.justDiedAt(0));
	}

	function testMutationCanFlipANodeAgainstWhatTheRuleAloneWouldDo():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var state = new GeodesicLifeState(sphere, GeodesicLifeRules.DEFAULT);
		// an empty board: every node has zero live neighbors, so the rule alone leaves them all dead forever

		state.step(alwaysMutate);

		Assert.isTrue(state.isAlive(0), "a random() always under MUTATION_RATE should flip every node's ruled state");
	}

	/**
		Two adjacent nodes seeded alive, and a third adjacent to both of
		them. Under `DEFAULT` (`B2/S34`) the third has exactly 2 live
		neighbors, so it's born (`birth = [2]`); each seeded node has
		exactly 1 live neighbor (the other), short of `survive = [3, 4]`,
		so both die. Next generation: the third node alive at age `1`, the
		original two `justDiedAt`. Would need updating if `DEFAULT` ever
		moves to `B3_S34` specifically (the one candidate with `birth =
		[3]`, not `[2]`) — every other candidate in
		`GeodesicLifeRules.ALL` shares this test's own arithmetic.

		Only asserts about these three nodes. Every edge of a triangulated
		mesh is shared by two triangles, so the *other* node opposite this
		edge is born in the same step by the identical arithmetic — correct,
		and none of this test's business.
	**/
	function testBirthAndDeathOnAHandBuiltTriangle():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var triangle = findTriangle(sphere);
		var state = new GeodesicLifeState(sphere, GeodesicLifeRules.DEFAULT);
		state.seedSingle(triangle.a);
		state.seedSingle(triangle.b);

		state.step(noMutation);

		Assert.isFalse(state.isAlive(triangle.a));
		Assert.isFalse(state.isAlive(triangle.b));
		Assert.isTrue(state.isAlive(triangle.c));
		Assert.equals(1, state.ageOf(triangle.c));
		Assert.isTrue(state.justDiedAt(triangle.a));
		Assert.isTrue(state.justDiedAt(triangle.b));
	}

	/** The property the wall-gate removal is actually about: a node's neighbors all count, whatever the maze is doing. **/
	function testEveryNeighborCountsRegardlessOfAnyMaze():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var triangle = findTriangle(sphere);
		var state = new GeodesicLifeState(sphere, GeodesicLifeRules.DEFAULT);
		state.seedSingle(triangle.a);
		state.seedSingle(triangle.b);

		state.step(noMutation);

		Assert.isTrue(state.isAlive(triangle.c), "a node with 2 live neighbors should be born with no maze involved at all");
	}

	function testAgeIsZeroForANodeThatIsNotAlive():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var state = new GeodesicLifeState(sphere, GeodesicLifeRules.DEFAULT);

		Assert.equals(0, state.ageOf(0));
	}

	function testSeedAtDensityOnePlacesEveryNode():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var state = new GeodesicLifeState(sphere, GeodesicLifeRules.DEFAULT);

		state.seed(1, () -> 0); // rng() always < density(1): every node should end up alive

		Assert.equals(sphere.neighbors.length, state.population());
	}

	function testSeedAtDensityZeroPlacesNoNode():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var state = new GeodesicLifeState(sphere, GeodesicLifeRules.DEFAULT);

		state.seed(0, noMutation); // rng() (always 1) is never < density(0): nothing should be placed

		Assert.equals(0, state.population());
	}

	/** `live`/`activity`/`age` all round-trip; `justDied` deliberately doesn't (see `serialize`'s own doc). **/
	function testSerializeRoundTripsAliveActivityAndAge():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var triangle = findTriangle(sphere);
		var state = new GeodesicLifeState(sphere, GeodesicLifeRules.DEFAULT);
		state.seedSingle(triangle.a);
		state.seedSingle(triangle.b);
		state.step(noMutation); // gives triangle.c a real age/activity, and leaves a/b justDiedAt

		var restored = GeodesicLifeState.deserialize(sphere, GeodesicLifeRules.DEFAULT, state.serialize());

		Assert.isTrue(restored.isAlive(triangle.c));
		Assert.equals(state.ageOf(triangle.c), restored.ageOf(triangle.c));
		Assert.equals(state.activityOf(triangle.c), restored.activityOf(triangle.c));
		Assert.isFalse(restored.isAlive(triangle.a));
		Assert.equals(state.population(), restored.population());
		Assert.isFalse(restored.justDiedAt(triangle.a), "justDied is a one-generation visual cue, not persisted state");
	}

	function testDeserializeOfAnEmptyBoardIsEmpty():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var state = new GeodesicLifeState(sphere, GeodesicLifeRules.DEFAULT);

		var restored = GeodesicLifeState.deserialize(sphere, GeodesicLifeRules.DEFAULT, state.serialize());

		Assert.equals(0, restored.population());
	}

	static function noMutation():Float {
		return 1; // never below GeodesicLifeState.MUTATION_RATE
	}

	static function alwaysMutate():Float {
		return 0; // always below GeodesicLifeState.MUTATION_RATE
	}

	static function findTriangle(sphere:GeodesicSphereData):{a:Int, b:Int, c:Int} {
		for (a in 0...sphere.neighbors.length) {
			var neighborsOfA = sphere.neighbors[a];
			for (b in neighborsOfA) {
				for (c in neighborsOfA) {
					if (c != b && sphere.neighbors[b].indexOf(c) != -1) {
						return {a: a, b: b, c: c};
					}
				}
			}
		}
		throw "expected at least one triangle in a triangulated mesh";
	}
}
