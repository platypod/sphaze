package tools.geodesic;

import biomes.common.maze.MazeCarver;
import biomes.common.maze.MazeTopology.MazeLayout;
import graphics.Colours;
import graphics.shaders.ConwayWallGlow;
import tools.geodesic.GeodesicLifeRule.GeodesicLifeRules;
import tools.geodesic.GeodesicSphere.GeodesicSphereData;

/** Everything the preview builds once in `init` and then reuses every generation — one nullable field instead of many, so the null-safety guard in `update` is a single check. **/
typedef PreviewWorld = {
	var fineSphere:GeodesicSphereData;
	var fineBoundaries:Array<Array<Vec3>>;
	var coarseSphere:GeodesicSphereData;
	var fineToCoarse:Array<Int>;
	var boundaryEdges:Array<{a:Int, b:Int}>;
	var coarseLayout:MazeLayout;
	var fineState:GeodesicLifeState;
	var coarseReactivity:GeodesicReactivity;

	/** No-op stand-in `(layout, reactivity)` passed to `GeodesicMesh.build` so it draws only the fine floor/blocks — every fine edge is "core" to it, so its own wall/ghost buckets always come out empty. See `noOpFineMazeLayer`'s own doc. **/
	var noOpFineLayout:MazeLayout;

	var noOpFineReactivity:GeodesicReactivity;
}

/**
	Standalone visual harness — genuinely separate from the actual game
	(own `-main`, own `preview.hxml`/`geodesic-preview.html`, never
	referenced from `Main`/`GameLoop`), since it exists to isolate
	geometry bugs from simulation bugs, per the build order.

	**Currently prototyping the "coarse maze" attempt at wall
	straightening (2026-08-06)**, the second one — the first
	(`GeodesicWallSimplifier`, merging wall geometry after the fact) was
	built, played in the real biome, and retracted: a merged chord no
	longer corresponds to any *one* collision-relevant edge, and a chain
	recomputed whole every generation reshaped visibly whenever any single
	edge inside it flipped. This attempt doesn't merge geometry. It
	changes what the maze graph *is*: a coarser `GeodesicSphere`
	(`COARSE_FREQUENCY`) carries the maze itself — carving, reactivity,
	and (once this moves into the real biome) collision — while the fine
	sphere (`FINE_FREQUENCY`) still carries the floor and the Life
	simulation, unchanged. `GeodesicCoarseMaze.fineToCoarse` assigns every
	fine cell to the coarse region it falls inside; a wall gets drawn for
	a fine edge only where that assignment actually crosses a coarse
	boundary, using the fine edge's own real geometry but the *coarse*
	edge's own open/closed/ghost state — so the wall and the thing that
	blocks the player are the same object again, just coarser, not a
	chord approximating several of them at once.

	Floor and blocks still come from `GeodesicMesh.build` directly, called
	with a synthetic all-open, all-core `(layout, reactivity)` pair so it
	draws nothing *but* floor/blocks — see `noOpFineMazeLayer`'s own doc.
	Walls are this class's own new code, reusing `GeodesicMesh.buildWallMesh`
	(now public) for the actual mesh/UV/shader bookkeeping rather than
	re-deriving it.
**/
class GeodesicPreview extends hxd.App {
	/**
		Close to `GeodesicBake`'s own `11` (not identical — this is a visual
		check, not the tuned pacing value). Started at `6` for a quicker
		render, moved up once a real question came up that only a finer
		mesh could answer: whether some cells' own odd shapes were a
		genuine bug or a viewing-angle artifact of the coarser preview (it
		was the latter — see `docs/game-design/notes/geodesic-sphere-engineering.md`'s
		Phase 3 entry).
	**/
	static inline final FINE_FREQUENCY:Int = 10;

	/**
		The maze's own frequency — chosen so a fine cell's own coarse
		region averages `4`-`6` cells (measured directly, not guessed: at
		`FINE_FREQUENCY = 10`/`5`, average region size came out `4.8`,
		range `4`-`6`, with zero cases anywhere of a boundary crossing
		into a non-adjacent coarse region — see `GeodesicCoarseMaze`'s own
		doc for the full measurement).
	**/
	static inline final COARSE_FREQUENCY:Int = 5;

	/** `GeodesicMesh.RADIUS`, under a shorter local name for the camera-placement arithmetic below. **/
	static inline final RADIUS:Float = GeodesicMesh.RADIUS;

	/** How long one generation lasts, in seconds — `biomes.conway.ConwayBiome.STEP_INTERVAL`'s own pacing, slow enough to actually watch patterns move. **/
	static inline final STEP_INTERVAL:Float = 0.75;

	/** Starting share of live cells — the same density `GeodesicLifeReport` compares the rule candidates at. **/
	static inline final SEED_DENSITY:Float = 0.24;

	/**
		Query parameter fast-forwarding the simulation before the first
		frame is drawn (`geodesic-preview.html?generations=30`). Exists
		because an automated browser pane keeps its document `hidden`, and a
		hidden document never fires `requestAnimationFrame` — so the timed
		loop below simply doesn't run there and every screenshot comes back
		byte-identical to generation `0`. Rather than conclude from that
		that the simulation was broken (it wasn't — the tab was), this makes
		any single generation reachable as a still frame, which is all a
		screenshot can honestly show anyway.
	**/
	static inline final GENERATIONS_PARAM:String = "generations";

	var world:Null<PreviewWorld>;
	var container:Null<h3d.scene.Object>;
	var sinceStep:Float = 0;

	override function init():Void {
		engine.backgroundColor = 0xFF05070D;

		var fineSphere = GeodesicSphere.generate(FINE_FREQUENCY);
		var coarseSphere = GeodesicSphere.generate(COARSE_FREQUENCY);
		var coarseLookup = new GeodesicLookup(coarseSphere, COARSE_FREQUENCY);
		var fineToCoarse = GeodesicCoarseMaze.fineToCoarse(fineSphere, coarseLookup);

		var coarseLayout = MazeCarver.carve(new GeodesicTopology(coarseSphere), RandomizedDfs, 0);
		var fineState = new GeodesicLifeState(fineSphere, GeodesicLifeRules.DEFAULT);
		fineState.seed(SEED_DENSITY);

		var noOp = GeodesicCoarseMaze.noOpFineMazeLayer(fineSphere);

		var current:PreviewWorld = {
			fineSphere: fineSphere,
			fineBoundaries: GeodesicDual.cellBoundaries(fineSphere),
			coarseSphere: coarseSphere,
			fineToCoarse: fineToCoarse,
			boundaryEdges: GeodesicCoarseMaze.boundaryEdges(fineSphere, fineToCoarse),
			coarseLayout: coarseLayout,
			fineState: fineState,
			// captured before anything steps, so the core set really is the carve — see `GeodesicReactivity`'s own doc
			coarseReactivity: new GeodesicReactivity(coarseSphere, coarseLayout),
			noOpFineLayout: noOp.layout,
			noOpFineReactivity: noOp.reactivity
		};
		world = current;
		container = new h3d.scene.Object(s3d);

		for (_ in 0...requestedGenerations()) {
			stepOnce(current);
		}
		rebuild();

		s3d.camera.pos.set(RADIUS * 4.5, RADIUS * 2.8, RADIUS * 4.5);
		s3d.camera.target.set(0, 0, 0);
	}

	override function update(dt:Float):Void {
		var current = world;
		if (current == null) {
			return;
		}

		sinceStep += dt;
		if (sinceStep < STEP_INTERVAL) {
			return;
		}
		sinceStep -= STEP_INTERVAL;

		stepOnce(current);
		rebuild();
	}

	static function stepOnce(world:PreviewWorld):Void {
		world.fineState.step();
		var edgeActivityOf = GeodesicCoarseMaze.boundaryActivity(world.fineState, world.boundaryEdges, world.fineToCoarse);
		// no player in this harness, so nothing to protect from a closing wall
		world.coarseReactivity.step(world.coarseLayout, edgeActivityOf, -1);
	}

	/** @return how many generations `GENERATIONS_PARAM` asks to skip past, or `0` if it's absent or unparseable. **/
	static function requestedGenerations():Int {
		var query = new EReg('[?&]$GENERATIONS_PARAM=([0-9]+)', "");
		if (!query.match(js.Browser.location.search)) {
			return 0;
		}
		var requested = Std.parseInt(query.matched(1));
		return requested == null ? 0 : requested;
	}

	/**
		Rebuilds every generation — floor/blocks via `GeodesicMesh.build`
		(fed the no-op layer so it draws nothing else), walls via this
		class's own coarse-aware pass.
	**/
	function rebuild():Void {
		var current = world;
		var parent = container;
		if (current == null || parent == null) {
			return;
		}

		parent.removeChildren();
		GeodesicMesh.build(parent, current.fineSphere, current.fineBoundaries, current.fineState, current.noOpFineLayout, current.noOpFineReactivity);
		buildCoarseWalls(parent, current);
	}

	/**
		The actual point of this prototype: one wall panel per fine edge
		that crosses a coarse boundary, geometry from the fine sphere
		(`GeodesicDual.sharedEdge`, so it still hugs the real fine-cell
		edge, not a chord), state from the *coarse* edge the whole
		boundary shares — every fine panel along one coarse boundary opens
		and closes together, because there's only one coarse edge deciding
		all of them. Classification itself is `GeodesicCoarseMaze.wallSegments`,
		shared with `GeodesicConwayBiome` — this method is just the Heaps
		mesh-building tail end.
	**/
	static function buildCoarseWalls(parent:h3d.scene.Object, world:PreviewWorld):Void {
		var edgeActivityOf = GeodesicCoarseMaze.boundaryActivity(world.fineState, world.boundaryEdges, world.fineToCoarse);
		var segments = GeodesicCoarseMaze.wallSegments(world.fineSphere, world.fineBoundaries, world.boundaryEdges, world.fineToCoarse, world.coarseLayout,
			world.coarseReactivity, edgeActivityOf);

		var wallMesh = GeodesicMesh.buildWallMesh(parent, segments.walls, new ConwayWallGlow(Colours.CONWAY_WALL_PANEL, Colours.CONWAY_WALL_GLOW));
		if (wallMesh != null) {
			wallMesh.material.mainPass.culling = None;
		}

		var ghostMesh = GeodesicMesh.buildWallMesh(parent, segments.ghosts,
			new ConwayWallGlow(Colours.CONWAY_WALL_PANEL, Colours.CONWAY_WALL_GLOW, ConwayWallGlow.DEFAULT_SEAM_DENSITY,
				ConwayWallGlow.DEFAULT_REST_BRIGHTNESS, GeodesicMesh.GHOST_WALL_OPACITY));
		if (ghostMesh != null) {
			ghostMesh.material.mainPass.culling = None;
			ghostMesh.material.mainPass.depthWrite = false;
			ghostMesh.material.blendMode = h3d.mat.BlendMode.Alpha;
		}
	}

	static function main():Void {
		new GeodesicPreview();
	}
}
