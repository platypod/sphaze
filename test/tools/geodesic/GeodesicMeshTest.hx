package tools.geodesic;

import biomes.common.maze.MazeCarver;
import biomes.common.maze.MazeTopology.MazeLayout;
import tools.geodesic.GeodesicLifeRule.GeodesicLifeRules;
import tools.geodesic.GeodesicSphere.GeodesicSphereData;
import utest.Assert;
import utest.Test;

/**
	`GeodesicMesh.build` is Heaps scene-graph code, which this project's own
	`utest` suite doesn't otherwise exercise (see `CLAUDE.md`'s own
	"Workflow / verification loop" — the suite covers game logic, not
	rendering). What's actually checkable here without a running `hxd.App`
	is that `build` never throws across a realistic spread of generations
	and seeds — the one failure mode a screenshot can't catch as reliably
	as an automated sweep can, since a screenshot only ever shows one
	generation. `GeodesicPreview`, screenshotted directly, is the visual
	exit check this doesn't replace.
**/
class GeodesicMeshTest extends Test {
	static inline final FREQUENCY:Int = 4;
	static inline final GENERATIONS:Int = 30;

	function testBuildNeverThrowsAcrossManyGenerations():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var boundaries = GeodesicDual.cellBoundaries(sphere);
		var layout = MazeCarver.carve(new GeodesicTopology(sphere), RandomizedDfs, 0, new SeededRandom(11).asFunction());
		var state = new GeodesicLifeState(sphere, GeodesicLifeRules.DEFAULT);
		var reactivity = new GeodesicReactivity(sphere, layout);
		state.seed(0.24, new SeededRandom(3).asFunction());
		var parent = new h3d.scene.Object();

		for (generation in 0...GENERATIONS) {
			state.step();
			reactivity.step(layout, (a, b) -> GeodesicReactivity.edgeActivity(state.activityOf, a, b), -1);
			parent.removeChildren();
			GeodesicMesh.build(parent, sphere, boundaries, state, layout, reactivity);
			Assert.isTrue(parent.numChildren > 0, 'generation $generation produced no meshes at all');
		}
	}

	/** An empty sphere (nothing alive, nothing dying) must still build a valid floor+wall mesh — the all-empty-buckets edge case `addLifecycleMesh`'s own `points.length == 0` guard exists for. **/
	function testBuildHandlesAnEntirelyDeadBoard():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var boundaries = GeodesicDual.cellBoundaries(sphere);
		var layout = MazeCarver.carve(new GeodesicTopology(sphere), RandomizedDfs, 0, new SeededRandom(11).asFunction());
		var state = new GeodesicLifeState(sphere, GeodesicLifeRules.DEFAULT);
		var reactivity = new GeodesicReactivity(sphere, layout);
		// deliberately not seeded: every node starts dead and stays dead
		var parent = new h3d.scene.Object();

		state.step();
		reactivity.step(layout, (a, b) -> GeodesicReactivity.edgeActivity(state.activityOf, a, b), -1);
		GeodesicMesh.build(parent, sphere, boundaries, state, layout, reactivity);

		Assert.isTrue(parent.numChildren > 0, "a dead board should still render its floor and walls");
	}

	/** An entirely open layout (no wall, no ghost) must still build without throwing — the `wallPoints`/`ghostPoints` own empty-buffer edge case. **/
	function testBuildHandlesAnEntirelyOpenLayout():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var boundaries = GeodesicDual.cellBoundaries(sphere);
		var layout = allOpen(sphere);
		var state = new GeodesicLifeState(sphere, GeodesicLifeRules.DEFAULT);
		var reactivity = new GeodesicReactivity(sphere, layout);
		var parent = new h3d.scene.Object();

		GeodesicMesh.build(parent, sphere, boundaries, state, layout, reactivity);

		Assert.isTrue(parent.numChildren > 0);
	}

	static function allOpen(sphere:GeodesicSphereData):MazeLayout {
		var openEdges = new haxe.ds.StringMap<Bool>();
		for (id in 0...sphere.neighbors.length) {
			for (neighbor in sphere.neighbors[id]) {
				openEdges.set(biomes.common.maze.MazeEdges.edgeKey(Std.string(id), Std.string(neighbor)), true);
			}
		}
		return {openEdges: openEdges};
	}
}
