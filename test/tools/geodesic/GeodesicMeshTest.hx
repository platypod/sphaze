package tools.geodesic;

import biomes.common.maze.MazeCarver;
import biomes.common.maze.MazeEdges;
import biomes.common.maze.MazeTopology.MazeLayout;
import tools.geodesic.GeodesicLifecycle.LifecycleStage;
import tools.geodesic.GeodesicSphere.GeodesicSphereData;
import tools.geodesic.GeodesicVentrellaRule.GeodesicVentrellaRules;
import utest.Assert;
import utest.Test;

/**
	`GeodesicMesh.build`/`buildLiveCells` are Heaps scene-graph code, which
	this project's own `utest` suite doesn't otherwise exercise (see
	`CLAUDE.md`'s own "Workflow / verification loop" — the suite covers
	game logic, not rendering). What's actually checkable here without a
	running `hxd.App` is that both never throw across a realistic spread of
	generations/seeds/lerp factors, plus `buildLiveCells`'s own real
	behavioral contract (nothing alive in either snapshot → nothing drawn;
	something fading out still draws, even though the *current* snapshot
	alone says nothing's alive) — the parts a screenshot can't catch as
	reliably as an automated sweep, since a screenshot only ever shows one
	instant.
**/
class GeodesicMeshTest extends Test {
	static inline final FREQUENCY:Int = 4;
	static inline final GENERATIONS:Int = 30;

	function testBuildNeverThrowsAcrossManyGenerations():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var boundaries = GeodesicDual.cellBoundaries(sphere);
		var layout = MazeCarver.carve(new GeodesicTopology(sphere), RandomizedDfs, 0, new SeededRandom(11).asFunction());
		var state = new GeodesicVentrellaState(sphere, GeodesicVentrellaRules.SPHERE_CA);
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
		var state = new GeodesicVentrellaState(sphere, GeodesicVentrellaRules.SPHERE_CA);
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
		var state = new GeodesicVentrellaState(sphere, GeodesicVentrellaRules.SPHERE_CA);
		var reactivity = new GeodesicReactivity(sphere, layout);
		var parent = new h3d.scene.Object();

		GeodesicMesh.build(parent, sphere, boundaries, state, layout, reactivity);

		Assert.isTrue(parent.numChildren > 0);
	}

	/**
		`h3d.mat.Material.set_blendMode`'s own `case Alpha` branch sets
		`mainPass.depthWrite = true` as a side effect (confirmed by reading
		Heaps' own source, not assumed) — so `depthWrite = false` has to be
		set *after* `blendMode = Alpha`, never before, or it's silently
		reset back to `true` at runtime despite what the surrounding code
		(and its own doc comments) claim. Every alpha-blended bucket this
		class builds (live cells, dying cells, ghost walls) shares this
		same ordering requirement — reported directly as "we still see
		cells through walls from time to time," since two alpha-blended
		things both writing depth (contrary to intent) can end up occluding
		each other in an order that flips as Heaps' own back-to-front alpha
		sort re-ranks them frame to frame, rather than blending as intended.
	**/
	function testAlphaBlendedLiveCellMeshesDoNotWriteDepth():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var boundaries = GeodesicDual.cellBoundaries(sphere);
		var previousStages = [for (id in 0...sphere.neighbors.length) LifecycleStage.Absent];
		var currentStages = [
			for (id in 0...sphere.neighbors.length)
				id < 3 ? LifecycleStage.Alive : LifecycleStage.Absent
		];
		var parent = new h3d.scene.Object();

		GeodesicMesh.buildLiveCells(parent, sphere, boundaries, previousStages, currentStages, 1.0);

		assertNoAlphaMeshWritesDepth(parent);
	}

	/**
		Same regression, for the ghost-wall bucket `build` produces.
		Deliberately bypasses any Life engine's own dynamics to open the
		ghost edge — `GeodesicReactivity.step` takes its activity as a
		plain `(Int, Int) -> Float` callback, so a synthetic "this one edge
		is always hot" function opens it deterministically in a single
		call, rather than depending on either engine's own ambient-soup
		behavior (fragile, and specifically the Ventrella engine's own
		ambient soup reliably collapses within a handful of generations —
		see `GeodesicVentrellaReport`'s own doc).
	**/
	function testAlphaBlendedGhostWallMeshDoesNotWriteDepth():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var boundaries = GeodesicDual.cellBoundaries(sphere);
		var layout = MazeCarver.carve(new GeodesicTopology(sphere), RandomizedDfs, 0, new SeededRandom(11).asFunction());
		var reactivity = new GeodesicReactivity(sphere, layout);
		var state = new GeodesicVentrellaState(sphere, GeodesicVentrellaRules.SPHERE_CA); // unseeded: only reactivity's own synthetic activity matters here
		var ghostEdge = someNonCoreEdge(sphere, reactivity);
		var parent = new h3d.scene.Object();

		reactivity.step(layout, (a, b) -> (a == ghostEdge.a && b == ghostEdge.b)
			|| (a == ghostEdge.b && b == ghostEdge.a) ? 1.0 : 0.0, -1);
		Assert.isTrue(MazeEdges.isOpen(layout, Std.string(ghostEdge.a), Std.string(ghostEdge.b)), "the synthetic activity should have opened this edge");
		GeodesicMesh.build(parent, sphere, boundaries, state, layout, reactivity);

		assertNoAlphaMeshWritesDepth(parent);
	}

	static function someNonCoreEdge(sphere:GeodesicSphereData, reactivity:GeodesicReactivity):{a:Int, b:Int} {
		for (id in 0...sphere.neighbors.length) {
			for (neighbor in sphere.neighbors[id]) {
				if (!reactivity.isCore(id, neighbor)) {
					return {a: id, b: neighbor};
				}
			}
		}
		throw "expected at least one non-core edge on a real carved maze";
	}

	static function assertNoAlphaMeshWritesDepth(parent:h3d.scene.Object):Void {
		var checked = 0;
		for (i in 0...parent.numChildren) {
			var child = parent.getChildAt(i);
			if (!(child is h3d.scene.Mesh)) {
				continue;
			}
			var mesh:h3d.scene.Mesh = cast child;
			if (mesh.material.blendMode == Alpha) {
				checked++;
				Assert.isFalse(mesh.material.mainPass.depthWrite,
					"an alpha-blended mesh should never write depth, or it can occlude another alpha-blended mesh in a camera-angle-dependent order instead of blending");
			}
		}
		Assert.isTrue(checked > 0, "expected at least one alpha-blended mesh in this scene to actually check");
	}

	function testBuildLiveCellsNeverThrowsAcrossManyGenerationsAndLerpFactors():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var boundaries = GeodesicDual.cellBoundaries(sphere);
		var state = new GeodesicVentrellaState(sphere, GeodesicVentrellaRules.SPHERE_CA);
		state.seed(0.24, new SeededRandom(3).asFunction());
		var parent = new h3d.scene.Object();

		var previousStages = GeodesicLifecycle.stagesOf(state, sphere);
		for (generation in 0...GENERATIONS) {
			state.step();
			var currentStages = GeodesicLifecycle.stagesOf(state, sphere);
			for (t in [0.0, 0.25, 0.5, 0.75, 1.0]) {
				parent.removeChildren();
				GeodesicMesh.buildLiveCells(parent, sphere, boundaries, previousStages, currentStages, t);
				Assert.isTrue(parent.numChildren >= 0, 'generation $generation t=$t: buildLiveCells should not throw');
			}
			previousStages = currentStages;
		}
	}

	/** Nothing alive/dying in either snapshot — genuinely nothing to draw, unlike `build`'s own floor/walls which always produce something. **/
	function testBuildLiveCellsProducesNoChildrenWhenBothSnapshotsAreEmpty():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var boundaries = GeodesicDual.cellBoundaries(sphere);
		var allAbsent = [for (id in 0...sphere.neighbors.length) LifecycleStage.Absent];
		var parent = new h3d.scene.Object();

		GeodesicMesh.buildLiveCells(parent, sphere, boundaries, allAbsent, allAbsent, 0.5);

		Assert.equals(0, parent.numChildren);
	}

	/** A node fading out (alive last snapshot, absent now) still needs to draw mid-fade — the whole point of tracking `previousStages` separately rather than just rendering `currentStages` at some opacity. **/
	function testBuildLiveCellsDrawsANodeFadingOutEvenThoughItsCurrentStageIsAbsent():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var boundaries = GeodesicDual.cellBoundaries(sphere);
		var previousStages = [
			for (id in 0...sphere.neighbors.length)
				id == 0 ? LifecycleStage.Alive : LifecycleStage.Absent
		];
		var currentStages = [for (id in 0...sphere.neighbors.length) LifecycleStage.Absent];
		var parent = new h3d.scene.Object();

		GeodesicMesh.buildLiveCells(parent, sphere, boundaries, previousStages, currentStages, 0.5);

		Assert.isTrue(parent.numChildren > 0, "a node mid-fade-out should still draw something at t=0.5");
	}

	/** At `t = 1` (fully at the current snapshot), a node with nothing in either snapshot except a `currentStages` entry still draws — the birth case. **/
	function testBuildLiveCellsDrawsANewlyBornNodeAtTOne():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var boundaries = GeodesicDual.cellBoundaries(sphere);
		var previousStages = [for (id in 0...sphere.neighbors.length) LifecycleStage.Absent];
		var currentStages = [
			for (id in 0...sphere.neighbors.length)
				id == 0 ? LifecycleStage.Alive : LifecycleStage.Absent
		];
		var parent = new h3d.scene.Object();

		GeodesicMesh.buildLiveCells(parent, sphere, boundaries, previousStages, currentStages, 1.0);

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
