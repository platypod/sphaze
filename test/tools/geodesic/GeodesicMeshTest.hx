package tools.geodesic;

import biomes.common.maze.MazeCarver;
import biomes.common.maze.MazeEdges;
import biomes.common.maze.MazeTopology.MazeLayout;
import graphics.Colours;
import graphics.shaders.ConwayWallGlow;
import tools.geodesic.GeodesicLifecycle.LifecycleStage;
import tools.geodesic.GeodesicSphere.GeodesicSphereData;
import tools.geodesic.GeodesicVentrellaRule.GeodesicVentrellaRules;
import tools.geodesic.GeodesicWallSimplifier.WallSegment;
import tools.geodesic.Vec3.Vec3Math;
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

	/**
		`buildWallMesh`'s own junction posts (2026-08-10): reported directly,
		screenshot attached, of a wall corner shot from an angle that looked
		straight into a gap in the geometry — two segments meeting at a
		point don't share a thickness direction, so their own faces don't
		line up there unless something extra plugs the seam. Hand-built
		segments rather than a real sphere's own, since what's under test is
		`addJunctionPosts`'s own counting logic, not real wall geometry
		(`testBuildNeverThrowsAcrossManyGenerations` and friends already
		exercise that through a real carved maze).
	**/
	function testBuildWallMeshAddsNoExtraGeometryWhenNoSegmentsShareAnEndpoint():Void {
		var a = Vec3Math.make(1, 0, 0);
		var b = Vec3Math.make(0, 1, 0);
		var c = Vec3Math.make(0, 0, 1);
		var d = Vec3Math.make(-1, 0, 0);

		var oneSegmentVerts = vertCountOf(GeodesicMesh.buildWallMesh(new h3d.scene.Object(), [segment(a, b)], glow()));
		var twoDisjointVerts = vertCountOf(GeodesicMesh.buildWallMesh(new h3d.scene.Object(), [segment(a, b), segment(c, d)], glow()));

		Assert.equals(oneSegmentVerts * 2, twoDisjointVerts);
	}

	/** The actual reported bug: a shared endpoint must add a post's own geometry beyond what the two segments alone contribute — and, whether two or three segments share that one point, exactly one post, never one per pair. **/
	function testBuildWallMeshAddsExactlyOneJunctionPostRegardlessOfHowManySegmentsMeetThere():Void {
		var shared = Vec3Math.make(0, 0, 1);
		var a = Vec3Math.make(1, 0, 0);
		var b = Vec3Math.make(0, 1, 0);
		var c = Vec3Math.make(-1, 0, 0);

		var oneSegmentVerts = vertCountOf(GeodesicMesh.buildWallMesh(new h3d.scene.Object(), [segment(a, shared)], glow()));
		var twoAtTheJunctionVerts = vertCountOf(GeodesicMesh.buildWallMesh(new h3d.scene.Object(), [segment(a, shared), segment(b, shared)], glow()));
		var perPostVerts = twoAtTheJunctionVerts - oneSegmentVerts * 2;
		Assert.isTrue(perPostVerts > 0, "a shared endpoint should add a junction post's own geometry beyond the two segments alone");

		var threeAtTheJunctionVerts = vertCountOf(GeodesicMesh.buildWallMesh(new h3d.scene.Object(),
			[segment(a, shared), segment(b, shared), segment(c, shared)], glow()));
		Assert.equals(oneSegmentVerts * 3 + perPostVerts, threeAtTheJunctionVerts,
			"three segments sharing one endpoint should still add exactly one post, not one per pair");
	}

	/**
		The pillar's own orientation balances across every wall meeting
		there, not just the first (2026-08-10, reported directly against a
		real screenshot: "the pillars are not centered on the wall in all
		directions"). A first version oriented a pillar to whichever
		segment it found first, which is exact only when every departure is
		*exactly* 120° from the next — true on average (`addJunctionPost`'s
		own doc has the honeycomb-vertex reasoning) but not exactly, most
		visibly near a pentagon. Two walls 110° apart (not the ideal 120°)
		simulate that real deviation directly, independent of any actual
		sphere geometry.

		Goes through the public `buildWallMesh` API and extracts the built
		pillar's own corners, the same "real machinery, not a duplicate of
		its own internals" preference `GeodesicCollisionTest`'s own doc
		gives for testing through public entry points — `bestFitReference`/
		`tangentDirection` themselves aren't `public`, on purpose, so this
		measures the actual shipped geometry rather than calling into
		private helpers directly. The "naive" comparison (anchor to one
		wall alone) is computed independently, from the two departure
		angles chosen above — not by reaching into the pre-fix behavior,
		which no longer exists as a separate code path to call.
	**/
	function testJunctionPillarOrientationBalancesAcrossBothWalls():Void {
		var shared = Vec3Math.make(0, 0, 1);
		var far0 = Vec3Math.make(1, 0, 0);
		var far1Angle = 110 * Math.PI / 180;
		var far1 = Vec3Math.make(Math.cos(far1Angle), Math.sin(far1Angle), 0);

		var meshes = GeodesicMesh.buildWallMesh(new h3d.scene.Object(), [segment(far0, shared), segment(far1, shared)], glow());
		Assert.equals(1, meshes.length, "2 segments + 1 post is well under the vertex budget — expected a single mesh");
		var polygon:h3d.prim.Polygon = cast meshes[0].primitive;

		// addWall pushes 24 points per segment (2 segments = 48); addJunctionPost's own 6 side faces follow,
		// each pushing [baseCorner_i, baseCorner_next, topCorner_next, topCorner_i] — so baseCorners[i] is
		// always the first vertex of face i, at global index 48 + 4*i.
		var baseCorners = [for (i in 0...6) polygon.points[48 + 4 * i]];
		var postCenter = new h3d.Vector(0, 0, 0);
		for (corner in baseCorners) {
			postCenter = postCenter.add(corner);
		}
		postCenter = postCenter.scaled(1 / baseCorners.length);
		var up = postCenter.normalized();

		// The hex's own face-normal-0 sits 30° before vertex 0 in the local frame `hexCorners` builds
		// (vertices at 30°, 90°, ...) — so the actual chosen reference direction is vertex 0's own angle,
		// measured against an arbitrary independent zero axis (`far0`'s own tangent direction), minus 30°.
		var zero = tangentToward(postCenter, up, far0);
		var perpendicular = up.cross(zero);
		var vertex0Angle = Math.atan2(baseCorners[0].sub(postCenter).dot(perpendicular), baseCorners[0].sub(postCenter).dot(zero));
		var actualOffset = vertex0Angle - Math.PI / 6;

		var naiveWorst = Math.max(faceMisalignment(0), faceMisalignment(far1Angle));
		var balancedWorst = Math.max(faceMisalignment(-actualOffset), faceMisalignment(far1Angle - actualOffset));

		Assert.isTrue(balancedWorst < naiveWorst,
			'expected the balanced pillar to reduce the worst-case misalignment (naive=$naiveWorst, balanced=$balancedWorst)');
	}

	/** How far `angle` sits from the *nearest* multiple of 60° — hex face-normals repeat every 60°, so this is a wall's own misalignment from the closest one. **/
	static function faceMisalignment(angle:Float):Float {
		var period = Math.PI / 3;
		var folded = angle % period;
		if (folded < 0) {
			folded += period;
		}
		return Math.min(folded, period - folded);
	}

	/** The unit tangent at `from` (with local "up" `up`) pointing toward `toward`'s own world position — independently written, not a call into `GeodesicMesh.tangentDirection`, which isn't `public`. **/
	static function tangentToward(from:h3d.Vector, up:h3d.Vector, toward:Vec3):h3d.Vector {
		var target = new h3d.Vector(toward.x, toward.y, toward.z).scaled(GeodesicMesh.RADIUS);
		var raw = target.sub(from);
		return raw.sub(up.scaled(raw.dot(up))).normalized();
	}

	/**
		The actual root cause behind the hex-pillar reveal above:
		`hxd.IndexBuffer` is `UInt16`-backed, so a single `Polygon` can never
		safely exceed 65536 vertices — a real game-scale wall mesh with
		junction pillars hit just over 100,000, more than 65536 past the
		ceiling, and every wrapped index rendered as a triangle stretched
		between two unrelated, often-distant vertices, reported directly as
		"texture is stretched from one object to a distant one, a lot of
		times." Enough disjoint segments (no shared endpoints, so no
		junction posts complicate the arithmetic) to force at least one
		split, checked against the actual `UInt16` ceiling rather than
		`WALL_VERTEX_BUDGET` — the budget is where `buildWallMesh` chooses
		to split, not the hard limit itself.
	**/
	function testBuildWallMeshSplitsIntoMultipleMeshesPastTheVertexBudget():Void {
		var segments = [];
		for (i in 0...3000) {
			var angle = i * 0.7;
			var a = Vec3Math.make(Math.cos(angle), Math.sin(angle), i * 0.001);
			var b = Vec3Math.make(Math.cos(angle + 0.05), Math.sin(angle + 0.05), i * 0.001 + 0.001);
			segments.push(segment(a, b));
		}

		var meshes = GeodesicMesh.buildWallMesh(new h3d.scene.Object(), segments, glow());

		Assert.isTrue(meshes.length >= 2, "3000 disjoint segments should need more than one Polygon to stay under the UInt16 index ceiling");
		for (mesh in meshes) {
			var polygon:h3d.prim.Polygon = cast mesh.primitive;
			Assert.isTrue(polygon.points.length <= 65536, 'a single Polygon exceeded the UInt16 index ceiling: ${polygon.points.length}');
		}
		Assert.equals(segments.length * 24, vertCountOf(meshes), "chunking must not drop or duplicate any vertex");
	}

	static function segment(a:Vec3, b:Vec3):WallSegment {
		return {a: a, b: b, activity: 1};
	}

	static function glow():ConwayWallGlow {
		return new ConwayWallGlow(Colours.CONWAY_WALL_PANEL, Colours.CONWAY_WALL_GLOW);
	}

	static function vertCountOf(meshes:Array<h3d.scene.Mesh>):Int {
		var total = 0;
		for (mesh in meshes) {
			var polygon:h3d.prim.Polygon = cast mesh.primitive;
			total += polygon.points.length;
		}
		return total;
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
