package tools.geodesic;

import biomes.common.maze.MazeCarver;
import biomes.common.maze.MazeEdges;
import biomes.common.maze.MazeTopology.MazeLayout;
import tools.geodesic.GeodesicLifeRule.GeodesicLifeRules;
import tools.geodesic.GeodesicSphere.GeodesicSphereData;
import utest.Assert;
import utest.Test;

/**
	Mirrors `biomes.conway.ConwayMazeReactivityTest`'s own shape (an edge
	opens when it gets hot, closes when it goes quiet, never closes under
	the player, core edges never move at all), plus the guarantee that
	actually matters on a sphere with no outer boundary: the maze stays
	fully connected no matter how long the reactive edges churn.
**/
class GeodesicReactivityTest extends Test {
	static inline final FREQUENCY:Int = 3;
	static inline final MAZE_SEED:Int = 7;

	/** Enough generations of flipping for one node's rolling activity to clear `OPEN_THRESHOLD` — `0.2, 0.36, 0.488, 0.59`, see `GeodesicLifeState`'s own decay. **/
	static inline final HOT_GENERATIONS:Int = 4;

	/** Comfortably more quiet generations than the decay back under `CLOSE_THRESHOLD` needs. **/
	static inline final QUIET_GENERATIONS:Int = 30;

	/** Enough churn for activity to have opened a good share of the reactive edges. **/
	static inline final CHURN_GENERATIONS:Int = 20;

	function testCoreAndReactiveEdgesTogetherAccountForEveryEdge():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var layout = carve(sphere);
		var reactivity = new GeodesicReactivity(sphere, layout);

		var totalEdges = MazeEdges.allEdges(new GeodesicTopology(sphere)).length;
		var coreEdges = countOpen(layout);

		Assert.equals(totalEdges - coreEdges, reactivity.reactiveEdgeCount());
	}

	/** A carve is a spanning tree, so core should be exactly `nodes - 1` — the property the connectivity guarantee rests on. **/
	function testTheCoreIsExactlyASpanningTree():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var layout = carve(sphere);

		Assert.equals(sphere.neighbors.length - 1, countOpen(layout));
	}

	function testIsCoreAgreesWithTheCarveInBothDirections():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var layout = carve(sphere);
		var reactivity = new GeodesicReactivity(sphere, layout);

		for (id in 0...sphere.neighbors.length) {
			for (neighbor in sphere.neighbors[id]) {
				var carvedOpen = MazeEdges.isOpen(layout, Std.string(id), Std.string(neighbor));
				Assert.equals(carvedOpen, reactivity.isCore(id, neighbor), 'edge $id-$neighbor');
				Assert.equals(reactivity.isCore(id, neighbor), reactivity.isCore(neighbor, id), 'edge $id-$neighbor should agree from either endpoint');
			}
		}
	}

	function testCoreEdgeKeysMatchesIsCoreForEveryEdge():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var layout = carve(sphere);
		var reactivity = new GeodesicReactivity(sphere, layout);

		var keys = reactivity.coreEdgeKeys(sphere);
		var keySet = new haxe.ds.StringMap<Bool>();
		for (key in keys) {
			keySet.set(key, true);
		}

		Assert.equals(sphere.neighbors.length - 1, keys.length, "the core should be exactly the spanning tree");
		for (id in 0...sphere.neighbors.length) {
			for (neighbor in sphere.neighbors[id]) {
				var key = MazeEdges.edgeKey(Std.string(id), Std.string(neighbor));
				Assert.equals(reactivity.isCore(id, neighbor), keySet.exists(key), 'edge $id-$neighbor');
			}
		}
	}

	/**
		The save/load path: reconstructing from a persisted core set (no
		"freshly carved" layout available, since a save is however many
		generations of reactive churn later) must produce a `isCore`-
		equivalent instance — checked by comparing every edge's own
		classification, not just a count, since two different core sets
		could coincidentally have the same size.
	**/
	function testFromCoreKeysReconstructsAnEquivalentInstance():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var layout = carve(sphere);
		var original = new GeodesicReactivity(sphere, layout);

		var restored = GeodesicReactivity.fromCoreKeys(sphere, original.coreEdgeKeys(sphere));

		Assert.equals(original.reactiveEdgeCount(), restored.reactiveEdgeCount());
		for (id in 0...sphere.neighbors.length) {
			for (neighbor in sphere.neighbors[id]) {
				Assert.equals(original.isCore(id, neighbor), restored.isCore(id, neighbor), 'edge $id-$neighbor');
			}
		}
	}

	/** A core edge is never drawn as a wall at all (`GeodesicMesh.addEdge`'s own third case) — reactivity must never move it, whatever the Life layer does. **/
	function testACoreEdgeStaysCoreThroughSustainedChurn():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var layout = carve(sphere);
		var reactivity = new GeodesicReactivity(sphere, layout);
		var coreEdge = someCoreEdge(sphere, layout);
		var state = new GeodesicLifeState(sphere, GeodesicLifeRules.DEFAULT);

		for (generation in 0...CHURN_GENERATIONS) {
			state.step(generation % 2 == 0 ? alwaysMutate() : neverMutate());
			reactivity.step(layout, (a, b) -> GeodesicReactivity.edgeActivity(state.activityOf, a, b), -1);
		}

		Assert.isTrue(reactivity.isCore(coreEdge.a, coreEdge.b));
		Assert.isTrue(MazeEdges.isOpen(layout, Std.string(coreEdge.a), Std.string(coreEdge.b)),
			"a core edge must stay open no matter how long the board churns");
	}

	function testAnEdgeOpensOnceItsEndpointGetsHot():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var layout = carve(sphere);
		var reactivity = new GeodesicReactivity(sphere, layout);
		var edge = someClosedEdgeTouching(sphere, layout, 0);
		var state = new GeodesicLifeState(sphere, GeodesicLifeRules.DEFAULT);

		heatUp(state, reactivity, layout, 0);

		Assert.isTrue(layout.openEdges.exists(edge));
	}

	function testAnOpenedEdgeClosesBackOnceItGoesQuiet():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var layout = carve(sphere);
		var reactivity = new GeodesicReactivity(sphere, layout);
		var edge = someClosedEdgeTouching(sphere, layout, 0);
		var state = new GeodesicLifeState(sphere, GeodesicLifeRules.DEFAULT);
		heatUp(state, reactivity, layout, 0);

		coolDown(state, reactivity, layout, -1);

		Assert.isFalse(layout.openEdges.exists(edge));
	}

	/** A wall must never arrive on top of a stationary player. **/
	function testAnEdgeUnderThePlayerIsNeverClosed():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var layout = carve(sphere);
		var reactivity = new GeodesicReactivity(sphere, layout);
		var edge = someClosedEdgeTouching(sphere, layout, 0);
		var state = new GeodesicLifeState(sphere, GeodesicLifeRules.DEFAULT);
		heatUp(state, reactivity, layout, 0);

		coolDown(state, reactivity, layout, 0);

		Assert.isTrue(layout.openEdges.exists(edge), "an edge touching the player's own node should have survived going quiet");
	}

	/**
		The whole reason a core set exists: churn the board hard enough that
		plenty of reactive edges open, then keep stepping it for a long
		while, and assert after every single generation that every node is
		still reachable from every other one.

		Churn is driven deterministically (mutate-everything alternated with
		mutate-nothing, so nearly every node flips every generation) rather
		than by seeding a random soup, which is how this test was first
		written and why it first failed: the board went extinct before
		anything ever opened. The reason turned out to have nothing to do
		with randomness — a carve is a spanning tree, so a node has only
		~2 open edges at all, while `B2/S23` needs 2 live *open* neighbors
		to survive or be born, which makes a bare carve uninhabitable no
		matter how it's seeded (measured in `GeodesicLifeReport`: every
		candidate rule dies within ~5 generations at that openness). The
		reactivity layer's own behavior is what's under test here, not the
		Life layer's dynamics, so the soup is gone.

		Deliberately does *not* assert the board settles back to exactly the
		core spanning tree once mutation stops, which is what
		`biomes.conway.ConwayMazeReactivity`'s own doc promises for the
		square grid ("a dead board settles back into a static maze"). It
		measurably doesn't here, and that's a property of the rule rather
		than a bug in this class: opening an edge raises its endpoints' own
		live-neighbor counts, which under `B2/S23` on a 6-neighbor graph
		feeds the board rather than starving it, so activity sustains itself
		with no mutation at all. Measured over `QUIET_GENERATIONS` with
		mutation fully off: population kept oscillating (`12`-`37` of `92`)
		and open edges never fell below roughly twice the core count. The
		single-edge version of "goes quiet and closes back" is still covered
		by `testAnOpenedEdgeClosesBackOnceItGoesQuiet`, on a board that is
		genuinely empty.
	**/
	function testTheMazeStaysFullyConnectedThroughSustainedChurn():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var layout = carve(sphere);
		var reactivity = new GeodesicReactivity(sphere, layout);
		var state = new GeodesicLifeState(sphere, GeodesicLifeRules.DEFAULT);
		var coreEdges = countOpen(layout);

		for (generation in 0...CHURN_GENERATIONS) {
			state.step(generation % 2 == 0 ? alwaysMutate() : neverMutate());
			reactivity.step(layout, (a, b) -> GeodesicReactivity.edgeActivity(state.activityOf, a, b), -1);
			Assert.equals(sphere.neighbors.length, reachableCount(sphere, layout));
		}
		var churned = countOpen(layout);
		Assert.isTrue(churned > coreEdges, 'expected activity to have opened reactive edges, still at $churned');

		for (_ in 0...QUIET_GENERATIONS) {
			state.step(neverMutate());
			reactivity.step(layout, (a, b) -> GeodesicReactivity.edgeActivity(state.activityOf, a, b), -1);
			Assert.equals(sphere.neighbors.length, reachableCount(sphere, layout));
			Assert.isTrue(countOpen(layout) >= coreEdges, "no core edge may ever close");
		}
	}

	static function carve(sphere:GeodesicSphereData):MazeLayout {
		return MazeCarver.carve(new GeodesicTopology(sphere), RandomizedDfs, 0, new SeededRandom(MAZE_SEED).asFunction());
	}

	/**
		Drives `nodeId`'s own rolling activity above `OPEN_THRESHOLD` by
		making it flip every generation. `GeodesicLifeState.step` calls its
		randomness source exactly once per node, in node-id order, so
		mutating only call `nodeId` targets exactly that node; alternating
		mutate/don't makes its ruled state (dead, with no live neighbors
		reachable) flip on and off rather than settle.
	**/
	static function heatUp(state:GeodesicLifeState, reactivity:GeodesicReactivity, layout:MazeLayout, nodeId:Int):Void {
		for (generation in 0...HOT_GENERATIONS) {
			state.step(generation % 2 == 0 ? mutateOnly(nodeId) : neverMutate());
			reactivity.step(layout, (a, b) -> GeodesicReactivity.edgeActivity(state.activityOf, a, b), -1);
		}
	}

	static function coolDown(state:GeodesicLifeState, reactivity:GeodesicReactivity, layout:MazeLayout, playerNode:Int):Void {
		for (_ in 0...QUIET_GENERATIONS) {
			state.step(neverMutate());
			reactivity.step(layout, (a, b) -> GeodesicReactivity.edgeActivity(state.activityOf, a, b), playerNode);
		}
	}

	/** @return a randomness source under `MUTATION_RATE` on its `nodeId`th call only, i.e. mutating exactly that one node. **/
	static function mutateOnly(nodeId:Int):Void->Float {
		var call = -1;
		return () -> {
			call++;
			return call == nodeId ? 0 : 1;
		};
	}

	static function neverMutate():Void->Float {
		return () -> 1;
	}

	/** @return a randomness source always under `MUTATION_RATE`, i.e. flipping every node's own ruled state. **/
	static function alwaysMutate():Void->Float {
		return () -> 0;
	}

	/** @return the key of some edge touching `nodeId` that the carve left closed, i.e. one this reactivity layer is actually allowed to move. **/
	static function someClosedEdgeTouching(sphere:GeodesicSphereData, layout:MazeLayout, nodeId:Int):String {
		for (neighbor in sphere.neighbors[nodeId]) {
			var key = MazeEdges.edgeKey(Std.string(nodeId), Std.string(neighbor));
			if (!layout.openEdges.exists(key)) {
				return key;
			}
		}
		throw 'expected node $nodeId to have at least one closed edge after carving';
	}

	/** @return some edge the carve left open, i.e. a core edge. **/
	static function someCoreEdge(sphere:GeodesicSphereData, layout:MazeLayout):{a:Int, b:Int} {
		for (id in 0...sphere.neighbors.length) {
			for (neighbor in sphere.neighbors[id]) {
				if (MazeEdges.isOpen(layout, Std.string(id), Std.string(neighbor))) {
					return {a: id, b: neighbor};
				}
			}
		}
		throw "expected the carve to leave at least one edge open";
	}

	static function countOpen(layout:MazeLayout):Int {
		var count = 0;
		for (_ in layout.openEdges.keys()) {
			count++;
		}
		return count;
	}

	/** Flood fill from node `0` over `layout`'s own open edges. **/
	static function reachableCount(sphere:GeodesicSphereData, layout:MazeLayout):Int {
		var seen = [for (_ in 0...sphere.neighbors.length) false];
		seen[0] = true;
		var pending = [0];
		var reached = 1;
		while (pending.length > 0) {
			var node = pending.pop();
			if (node == null) {
				break;
			}
			for (neighbor in sphere.neighbors[node]) {
				if (!seen[neighbor] && MazeEdges.isOpen(layout, Std.string(node), Std.string(neighbor))) {
					seen[neighbor] = true;
					reached++;
					pending.push(neighbor);
				}
			}
		}
		return reached;
	}
}
