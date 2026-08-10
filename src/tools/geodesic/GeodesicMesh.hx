package tools.geodesic;

import biomes.common.maze.MazeEdges;
import biomes.common.maze.MazeTopology.MazeLayout;
import game.MeshBuilder;
import graphics.Colours;
import graphics.shaders.ConwayWallGlow;
import tools.geodesic.GeodesicLifecycle.LifecycleStage;
import tools.geodesic.GeodesicSphere.GeodesicSphereData;
import tools.geodesic.GeodesicWallSimplifier.WallSegment;

/**
	Renders the geodesic sphere's own Life layer, at real-game quality —
	the counterpart to `biomes.conway.ConwayMesh`, ported cell-by-cell
	rather than reimagined, and reusing that class's own palette
	(`graphics.Colours.CONWAY_*`) and wall shader (`ConwayWallGlow`)
	unchanged: same biome identity, different cell shape underneath.

	Three structural differences from the square-grid original, all forced
	by the geometry rather than chosen:
	- A cell is an N-gon (`GeodesicDual.cellBoundary`, 5 or 6 points), not
	  always-four corners — `addBlock`'s fixed `top[0..3]`/four side quads
	  becomes a loop over however many the boundary actually has. Pentagons
	  get no other special treatment; the pentagon-beacon mechanic is a
	  later phase, not a rendering concern yet.
	- A wall's own two endpoints come from `GeodesicDual.sharedEdge`, the
	  real shared boundary segment between two cells — not
	  `ConwayGrid.cornerAt`'s formula, since there's no `(theta, phi)`
	  formula here at all.
	- Open/core classification comes from `GeodesicReactivity.isCore`
	  (an instance method, since core is captured at construction rather
	  than derived from a `coreEdges` field on the data itself — see that
	  class's own doc) instead of `ConwayMaze.isCore`.

	Everything else — the lifecycle mesh buckets, alpha-blended live
	blocks, `ConwayWallGlow` for solid walls and its faded "ghost" variant
	for open-but-non-core edges, `TILE_LIFT`/`WALL_BASE_LIFT` — carries over
	unchanged, because none of it was ever about the grid's shape.

	**`build` vs. `buildLiveCells` (2026-08-10) — split for smoothness, not
	tidiness.** Live cell blocks used to be part of `build`'s own single
	per-generation pass, same cadence as the floor/walls — which meant a
	block popped fully into or out of existence the instant a generation
	advanced, reported directly as stuttering. `buildLiveCells` is now its
	own function, called every render frame (`GeodesicConwayBiome.tick`'s
	own 60Hz cadence, not the 0.75s generation step) with a lerp factor, so
	a block's own height animates smoothly between two consecutive
	generations' worth of `GeodesicLifecycle.stagesOf` snapshots instead of
	jumping. `build` itself keeps the floor/walls — genuinely static
	between generations, no reason to touch them more than once per step.

	**Z-fighting near the floor, found immediately after playing the
	smoothing above (2026-08-10, same day).** "Both wall-vs-cells and
	cells-vs-ground (when fade into oblivion) are not too clean-looking."
	Before continuous height interpolation existed, a live block was
	always one of three fixed heights (none smaller than `1.0`) or
	entirely absent — its own base reused the floor's own `TILE_LIFT`
	harmlessly, since a block's geometry was never anywhere near the
	floor's. A fading block's height now legitimately approaches `0`, at
	which point a `TILE_LIFT`-based base becomes *exactly* coincident with
	the separately-rendered floor mesh underneath it. `LIVE_CELL_BASE_LIFT`
	gives `buildLiveCells` its own dedicated base, offset from both the
	floor and a wall's own `WALL_BASE_LIFT` at every point during a fade,
	not just at the endpoints — see that constant's own doc.

	**`GeodesicWallSimplifier` (wall straightening) was tried here and
	retracted (2026-08-06)**, played in the real biome rather than judged
	from a screenshot: a merged chord's own endpoints stop lining up with
	whichever *one* edge collision actually blocks on, so a player gets
	stopped somewhere the drawn wall doesn't visibly explain; and because
	virtually every wall on this grid is already on the reactive edge set
	(the core spanning tree is never drawn as a wall at all), a chain
	recomputed fresh every generation reshapes visibly whenever *any*
	single edge inside it flips, not just its own short segment. Both
	problems are structural to merging geometry across several
	independently-collision-relevant, independently-reactive edges — not
	bugs in the merge itself. Every wall segment here is still exactly one
	graph edge, one quad, matching `biomes.conway.ConwayMesh`'s own
	original correspondence. See `docs/game-design/design-decisions-records.md`'s
	own entry for what's being tried next.
**/
class GeodesicMesh {
	/**
		World-unit sphere radius. Matches `biomes.conway.ConwayGrid.RADIUS`
		exactly (not a coincidence) — so wiring the real `Biome` swap on top
		of this rendering doesn't also have to re-tune spawn distances,
		jump physics, or anything else scaled against the old grid's own
		world size.
	**/
	public static inline final RADIUS:Float = 174;

	/** See `biomes.conway.ConwayMesh.TILE_LIFT`'s own doc. **/
	static inline final TILE_LIFT:Float = 0.03;

	/** See `biomes.conway.ConwayMesh.WALL_BASE_LIFT`'s own doc. **/
	static inline final WALL_BASE_LIFT:Float = 0.02;

	/**
		`buildLiveCells`'s own base lift for a block's `floorBoundary` —
		deliberately *not* `TILE_LIFT`, and deliberately its own constant
		rather than reusing `WALL_BASE_LIFT` too (2026-08-10). Before
		`buildLiveCells` existed, a live block was always one of three fixed
		heights (`ConwayGrid.YOUNG_BLOCK_HEIGHT`/`AGED_BLOCK_HEIGHT`/
		`DYING_BLOCK_HEIGHT`, none smaller than `1.0`) or entirely absent —
		reusing the floor's own `TILE_LIFT` for a block's base was harmless,
		since a block's own geometry was never anywhere near the floor's.
		Continuous height interpolation changes that: as a fading block's
		own height approaches `0`, a base built from `TILE_LIFT` becomes
		*exactly* coincident with the separately-rendered static floor mesh
		underneath it — genuine Z-fighting, not an approximation of it,
		reported directly as cells looking rough fading "into oblivion."
		This constant keeps a block's own base a real, fixed distance from
		both the floor (`TILE_LIFT`) and a wall's own base
		(`WALL_BASE_LIFT`) at every point during a fade, not just at the
		endpoints.
	**/
	static inline final LIVE_CELL_BASE_LIFT:Float = 0.04;

	/** See `biomes.conway.ConwayMesh.LIVE_BLOCK_OPACITY`'s own doc. **/
	static inline final LIVE_BLOCK_OPACITY:Float = 0.25;

	/** See `biomes.conway.ConwayMesh.GHOST_WALL_OPACITY`'s own doc. Public: `GeodesicPreview`'s own coarse-wall prototype reuses this exact value for its own ghost bucket. **/
	public static inline final GHOST_WALL_OPACITY:Float = 0.15;

	/**
		Builds the static floor/wall meshes under `parent` for the current
		generation — everything that doesn't need `buildLiveCells`'s own
		per-frame smoothing, since none of it changes between generations.
		Called once per `GeodesicVentrellaState.step`/`GeodesicReactivity.step`,
		the same "rebuild from scratch each generation" cadence
		`biomes.conway.ConwayBiome.tick` already uses — cheap relative to a
		0.75s step interval.
		@param parent the scene node to attach every mesh under.
		@param sphere the topology to render.
		@param boundaries every node's own cell polygon, `GeodesicDual.cellBoundaries(sphere)` — passed in rather than recomputed, since a caller stepping every generation already has it cached.
		@param state this generation's Ventrella layer.
		@param layout this generation's maze.
		@param reactivity the same instance driving `layout`'s own open/close, queried here only for `isCore` and `edgeActivity`.
	**/
	public static function build(parent:h3d.scene.Object, sphere:GeodesicSphereData, boundaries:Array<Array<Vec3>>, state:GeodesicVentrellaState,
			layout:MazeLayout, reactivity:GeodesicReactivity):Void {
		var floorPoints:Array<h3d.Vector> = [];
		var floorIdx = new hxd.IndexBuffer();
		var pentagonFloorPoints:Array<h3d.Vector> = [];
		var pentagonFloorIdx = new hxd.IndexBuffer();
		var wallSegments:Array<WallSegment> = [];
		var ghostSegments:Array<WallSegment> = [];

		for (id in 0...sphere.neighbors.length) {
			var boundary = boundaries[id];
			var floorBoundary = [for (p in boundary) lift(p, TILE_LIFT)];
			var hub = lift(sphere.positions[id], TILE_LIFT);
			if (sphere.neighbors[id].length == 5) {
				addFan(pentagonFloorPoints, pentagonFloorIdx, hub, floorBoundary);
			} else {
				addFan(floorPoints, floorIdx, hub, floorBoundary);
			}

			for (neighbor in sphere.neighbors[id]) {
				if (neighbor <= id) {
					continue; // each undirected edge once
				}
				collectEdge(sphere, boundaries, state, layout, reactivity, id, neighbor, wallSegments, ghostSegments);
			}
		}

		var floorMesh = new h3d.scene.Mesh(new h3d.prim.Polygon(floorPoints, floorIdx), parent);
		floorMesh.material.mainPass.addShader(new h3d.shader.FixedColor(Colours.CONWAY_TILE_DEAD));
		floorMesh.material.mainPass.culling = None;

		// A separate mesh/color rather than a per-vertex floor color so the
		// 12 pentagons can be told apart from `Colours.CONWAY_TILE_DEAD`
		// hexagons — or folded back in, opinion-pending (see that
		// constant's own doc): the split is the "trickery," the constant
		// value is the switch.
		addFloorMesh(parent, pentagonFloorPoints, pentagonFloorIdx, Colours.CONWAY_TILE_PENTAGON);

		// NOT run through GeodesicWallSimplifier — see this class's own doc
		// for why straightening was retracted (played in the real biome,
		// 2026-08-06): a merged chord's endpoints stop lining up with the
		// one specific edge collision actually blocks on, and a chain
		// recomputed whole every generation reshapes visibly whenever any
		// single edge in it flips, since virtually every wall here is on
		// the reactive edge set to begin with.
		var wallMesh = buildWallMesh(parent, wallSegments, new ConwayWallGlow(Colours.CONWAY_WALL_PANEL, Colours.CONWAY_WALL_GLOW));
		if (wallMesh != null) {
			wallMesh.material.mainPass.culling = None;
		}

		var ghostMesh = buildWallMesh(parent, ghostSegments,
			new ConwayWallGlow(Colours.CONWAY_WALL_PANEL, Colours.CONWAY_WALL_GLOW, ConwayWallGlow.DEFAULT_SEAM_DENSITY,
				ConwayWallGlow.DEFAULT_REST_BRIGHTNESS, GHOST_WALL_OPACITY));
		if (ghostMesh != null) {
			ghostMesh.material.mainPass.culling = None;
			ghostMesh.material.blendMode = h3d.mat.BlendMode.Alpha; // sets depthWrite = true as a side effect — depthWrite below must come after
			ghostMesh.material.mainPass.depthWrite = false;
		}
	}

	/**
		Builds just the live cell blocks under `parent`, with each node's
		own height lerped between its `previousStages` and `currentStages`
		reading — called every render frame (`GeodesicConwayBiome.tick`'s
		own 60Hz cadence), not once per generation, so a block's own
		appearance/disappearance animates instead of popping. See this
		class's own doc for why this is split from `build` rather than
		folded into it.

		A node contributes to whichever stage's own bucket (`Alive`/`Dying`)
		it's *arriving at* if it has any height left at `t`, or the stage
		it's *leaving* if it's fading out to nothing — never both, and never
		neither unless both readings are `Absent`. A cell alive in both
		readings (the common case: most of a stable structure, most
		generations) needs no lerp at all — `previousHeight == currentHeight`
		is just a no-op blend.
		@param parent the scene node to attach the live-cell meshes under.
		@param sphere the topology to render.
		@param boundaries every node's own cell polygon, `GeodesicDual.cellBoundaries(sphere)`.
		@param previousStages every node's own stage as of the last generation boundary (`GeodesicLifecycle.stagesOf`).
		@param currentStages every node's own stage as of the current generation boundary.
		@param t how far between the two readings "now" is, `0` (all `previousStages`) to `1` (all `currentStages`) — typically `accumulator / STEP_INTERVAL`, clamped here so a caller doesn't have to.
	**/
	public static function buildLiveCells(parent:h3d.scene.Object, sphere:GeodesicSphereData, boundaries:Array<Array<Vec3>>,
			previousStages:Array<LifecycleStage>, currentStages:Array<LifecycleStage>, t:Float):Void {
		var alivePoints:Array<h3d.Vector> = [];
		var aliveIdx = new hxd.IndexBuffer();
		var dyingPoints:Array<h3d.Vector> = [];
		var dyingIdx = new hxd.IndexBuffer();
		var clampedT = t < 0 ? 0 : (t > 1 ? 1 : t);

		for (id in 0...sphere.neighbors.length) {
			var previousHeight = GeodesicLifecycle.blockHeightOf(previousStages[id]);
			var currentHeight = GeodesicLifecycle.blockHeightOf(currentStages[id]);
			if (previousHeight == 0 && currentHeight == 0) {
				continue;
			}

			var height = previousHeight + (currentHeight - previousHeight) * clampedT;
			var floorBoundary = [for (p in boundaries[id]) lift(p, LIVE_CELL_BASE_LIFT)];

			switch currentHeight > 0 ? currentStages[id] : previousStages[id] {
				case Alive:
					addBlock(alivePoints, aliveIdx, floorBoundary, height);
				case Dying:
					addBlock(dyingPoints, dyingIdx, floorBoundary, height);
				case Absent: // unreachable: the continue above guards against both readings being Absent
			}
		}

		addLifecycleMesh(parent, alivePoints, aliveIdx, scaledColor(Colours.CONWAY_TILE_LIVE, GeodesicLifecycle.ALIVE_BRIGHTNESS));
		addLifecycleMesh(parent, dyingPoints, dyingIdx, scaledColor(Colours.CONWAY_TILE_LIVE, GeodesicLifecycle.DYING_BRIGHTNESS));
	}

	/** See `biomes.conway.ConwayMesh.addEdge`'s own doc — same three-way routing (closed/ghost/bare corridor), just addressed by node id and sourced from `GeodesicDual.sharedEdge` instead of a `(theta, phi)` corner formula, and collecting a raw `WallSegment` for `GeodesicWallSimplifier` rather than emitting a quad directly. **/
	static function collectEdge(sphere:GeodesicSphereData, boundaries:Array<Array<Vec3>>, state:GeodesicVentrellaState, layout:MazeLayout,
			reactivity:GeodesicReactivity, a:Int, b:Int, wallSegments:Array<WallSegment>, ghostSegments:Array<WallSegment>):Void {
		var edge = GeodesicDual.sharedEdge(sphere, boundaries, a, b);
		var activity = GeodesicReactivity.edgeActivity(state.activityOf, a, b);
		var aKey = Std.string(a);
		var bKey = Std.string(b);
		if (!MazeEdges.isOpen(layout, aKey, bKey)) {
			wallSegments.push({a: edge.a, b: edge.b, activity: activity});
		} else if (!reactivity.isCore(a, b)) {
			ghostSegments.push({a: edge.a, b: edge.b, activity: activity});
		}
	}

	/**
		Turns a set of wall segments into one `ConwayWallGlow` mesh, or
		`null` if there's nothing to draw — the shared tail end of what
		used to be duplicated inline for the wall and ghost buckets.
		Public: `GeodesicPreview`'s own two-sphere prototype
		(`docs/game-design/notes/geodesic-sphere-engineering.md`'s "coarse
		maze" attempt) reuses this directly for its own coarse-derived
		wall segments, rather than re-deriving the same UV/activity
		bookkeeping `addWall` already does correctly.
		@param parent the scene node to attach the mesh under.
		@param segments the segments to draw.
		@param shader the `ConwayWallGlow` instance to shade them with (solid vs. ghost differ only in this).
		@return the built mesh, or `null` if `segments` was empty.
	**/
	public static function buildWallMesh(parent:h3d.scene.Object, segments:Array<WallSegment>, shader:ConwayWallGlow):Null<h3d.scene.Mesh> {
		if (segments.length == 0) {
			return null; // Polygon rejects an empty vertex list, and a fully open/fully core generation legitimately produces one
		}
		var points:Array<h3d.Vector> = [];
		var idx = new hxd.IndexBuffer();
		var uvs:Array<h3d.prim.UV> = [];
		var activity:Array<h3d.col.Point> = [];
		for (segment in segments) {
			addWall(points, idx, uvs, activity, segment.a, segment.b, segment.activity);
		}

		var prim = new h3d.prim.Polygon(points, idx);
		prim.uvs = uvs;
		prim.normals = activity;
		var mesh = new h3d.scene.Mesh(prim, parent);
		mesh.material.mainPass.addShader(shader);
		return mesh;
	}

	/** An opaque flat-colored floor bucket, guarded the same way `addLifecycleMesh` is — currently only `pentagonFloorPoints`, but written generically since a bare-hexagon-only sphere (`FREQUENCY` such that no pentagon survives subdivision) is geometrically impossible, not just untested. **/
	static function addFloorMesh(parent:h3d.scene.Object, points:Array<h3d.Vector>, idx:hxd.IndexBuffer, color:Int):Void {
		if (points.length == 0) {
			return;
		}
		var mesh = new h3d.scene.Mesh(new h3d.prim.Polygon(points, idx), parent);
		mesh.material.mainPass.addShader(new h3d.shader.FixedColor(color));
		mesh.material.mainPass.culling = None;
	}

	/** See `biomes.conway.ConwayMesh.addLifecycleMesh`'s own doc. **/
	static function addLifecycleMesh(parent:h3d.scene.Object, points:Array<h3d.Vector>, idx:hxd.IndexBuffer, color:Int):Void {
		if (points.length == 0) {
			return; // Polygon rejects an empty vertex list, and an all-dead/all-settled generation legitimately produces one for some bucket
		}
		var mesh = new h3d.scene.Mesh(new h3d.prim.Polygon(points, idx), parent);
		mesh.material.mainPass.addShader(new h3d.shader.FixedColor(color, LIVE_BLOCK_OPACITY));
		mesh.material.mainPass.culling = None;
		mesh.material.blendMode = h3d.mat.BlendMode.Alpha; // sets depthWrite = true as a side effect (h3d.mat.Material.set_blendMode) — depthWrite below must come after, not before, or it's silently reset
		mesh.material.mainPass.depthWrite = false;
	}

	/** See `biomes.conway.ConwayMesh.scaledColor`'s own doc. **/
	static function scaledColor(color:Int, factor:Float):Int {
		var r = clampByte(((color >> 16) & 0xFF) * factor);
		var g = clampByte(((color >> 8) & 0xFF) * factor);
		var b = clampByte((color & 0xFF) * factor);
		return (r << 16) | (g << 8) | b;
	}

	static function clampByte(value:Float):Int {
		return Std.int(Math.min(255, Math.max(0, value)));
	}

	/** A cell's own floor tile, or its ceiling cap if `hub` and `boundary` are already lifted for a block's own top — a triangle fan, since a cell has 5 or 6 sides where `ConwayMesh.addQuad`'s square-grid tile only ever needed one quad. **/
	static function addFan(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, hub:h3d.Vector, boundary:Array<h3d.Vector>):Void {
		for (k in 0...boundary.length) {
			MeshBuilder.addTriangle(points, idx, hub, boundary[k], boundary[(k + 1) % boundary.length]);
		}
	}

	/**
		A live cell's own standable block: `floorBoundary` extruded further
		inward by `height` — the N-sided counterpart to
		`biomes.conway.ConwayMesh.addBlock`'s always-four-corner version. A
		top fan plus one side quad per boundary edge, same shape as that
		method's fixed unrolled version just looped.
	**/
	static function addBlock(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, floorBoundary:Array<h3d.Vector>, height:Float):Void {
		var top = [for (p in floorBoundary) liftFurther(p, height)];
		var hub = centroidOf(top);
		addFan(points, idx, hub, top);
		for (k in 0...floorBoundary.length) {
			var next = (k + 1) % floorBoundary.length;
			MeshBuilder.addQuad(points, idx, floorBoundary[k], floorBoundary[next], top[next], top[k]);
		}
	}

	/** The already-lifted `points`' own average — good enough for a fan hub on a small, near-regular polygon (every cell here is 5 or 6 sides and close to equilateral), unlike `GeodesicDual.circumcenter`'s stricter equidistance requirement, which only matters for the boundary vertices themselves, not an interior fan point. **/
	static function centroidOf(points:Array<h3d.Vector>):h3d.Vector {
		var sum = new h3d.Vector(0, 0, 0);
		for (p in points) {
			sum = sum.add(p);
		}
		return sum.scaled(1 / points.length);
	}

	/**
		Appends one wall quad plus its `ConwayWallGlow` UVs/activity — see
		`biomes.conway.ConwayMesh.addWall`'s own doc for the UV/activity
		convention, ported unchanged.
	**/
	static function addWall(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, uvs:Array<h3d.prim.UV>, activityOut:Array<h3d.col.Point>, edgeA:Vec3, edgeB:Vec3,
			activity:Float):Void {
		var baseA = lift(edgeA, WALL_BASE_LIFT);
		var baseB = lift(edgeB, WALL_BASE_LIFT);
		var topA = liftFurther(baseA, GeodesicLifecycle.WALL_HEIGHT);
		var topB = liftFurther(baseB, GeodesicLifecycle.WALL_HEIGHT);
		MeshBuilder.addQuad(points, idx, baseA, baseB, topB, topA);

		var wallLength = baseA.sub(baseB).length();
		uvs.push(new h3d.prim.UV(0, 0));
		uvs.push(new h3d.prim.UV(wallLength, 0));
		uvs.push(new h3d.prim.UV(wallLength, 1));
		uvs.push(new h3d.prim.UV(0, 1));
		for (_ in 0...4) {
			activityOut.push(new h3d.col.Point(activity, activity, activity));
		}
	}

	/** A unit-sphere direction, converted to a world point at `RADIUS - amount`. **/
	static function lift(direction:Vec3, amount:Float):h3d.Vector {
		return new h3d.Vector(direction.x, direction.y, direction.z).scaled(RADIUS - amount);
	}

	/** An already-world-scale point, pulled `amount` further toward the sphere's own center along its own direction from it — the block-extrusion counterpart to `lift`, which starts from a unit direction instead. **/
	static function liftFurther(point:h3d.Vector, amount:Float):h3d.Vector {
		return point.add(point.normalized().scaled(-amount));
	}
}

/**
	One `GeodesicGliderTracker`-tracked cell and the color its own generator
	site was assigned. No longer consumed by `GeodesicMesh.build`/`buildLiveCells`
	(that per-site coloring was specific to the old B2/S34 spawn-site design
	— see `GeodesicVentrellaState`'s own doc for why it was replaced) —
	kept only because `GeodesicGliderTracker.trackedCells` still returns it
	and that class stays untouched as a fallback.
**/
typedef TrackedCell = {id:Int, color:Int};
