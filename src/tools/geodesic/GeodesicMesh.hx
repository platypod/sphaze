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

	/**
		`buildEngraving`'s own lift for a footprint cell's panel — clear of
		`TILE_LIFT`/`WALL_BASE_LIFT`/`LIVE_CELL_BASE_LIFT` (all under `0.1`)
		by a wide margin, so the engraving reads as its own layer sitting
		above the ordinary floor rather than z-fighting with it. Untuned —
		a reasonable first guess, not a measured value.
	**/
	static inline final ENGRAVING_LIFT:Float = 0.5;

	/** How dim an "off" engraved cell is relative to `Colours.CONWAY_TILE_GLIDER` — same amber as an "on" cell, just dimmed, so the whole footprint reads as one lit-up surface rather than mixing in an unrelated hue; dim enough to read as inactive next to an "on" cell's full brightness, bright enough to still show the footprint's own outline. Untuned — a reasonable first guess. **/
	static inline final ENGRAVING_OFF_BRIGHTNESS:Float = 0.35;

	/** See `biomes.conway.ConwayMesh.GHOST_WALL_OPACITY`'s own doc. Public: `GeodesicPreview`'s own coarse-wall prototype reuses this exact value for its own ghost bucket. **/
	public static inline final GHOST_WALL_OPACITY:Float = 0.15;

	/**
		How thick a solid wall's own slab is, in world units — `addWall`
		used to build a single zero-thickness quad, which "we still see
		cells through walls from time to time" traced back to: at a
		grazing viewing angle (looking nearly *along* the wall's own plane
		rather than at it), a flat panel's own on-screen width shrinks
		toward nothing, letting the camera's own view ray slip past it.
		Real thickness means every possible viewing ray that would cross
		the wall's own plane has to pass through actual volume first,
		regardless of angle. Public: `GeodesicCollision.WALL_CLEARANCE`
		derives from this same constant rather than a second copy that
		could drift out of sync — the two have to agree, since a player
		allowed to stand closer to a wall than this thickness extends would
		render with their own camera inside the new solid geometry.
		Untuned against real cell dimensions — a reasonable first guess,
		not a measured value; revisit after playing.
	**/
	public static inline final WALL_THICKNESS:Float = 1.0;

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
		for (wallMesh in buildWallMesh(parent, wallSegments, new ConwayWallGlow(Colours.CONWAY_WALL_PANEL, Colours.CONWAY_WALL_GLOW))) {
			wallMesh.material.mainPass.culling = None;
		}

		for (ghostMesh in buildWallMesh(parent, ghostSegments,
			new ConwayWallGlow(Colours.CONWAY_WALL_PANEL, Colours.CONWAY_WALL_GLOW, ConwayWallGlow.DEFAULT_SEAM_DENSITY,
				ConwayWallGlow.DEFAULT_REST_BRIGHTNESS, GHOST_WALL_OPACITY))) {
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
		addLifecycleMesh(parent, dyingPoints, dyingIdx, scaledColor(Colours.CONWAY_TILE_DYING, GeodesicLifecycle.DYING_BRIGHTNESS));
	}

	/**
		Draws the pentagon-composing engraving's own footprint: one glowing
		panel per footprint cell, alpha-blended exactly like a live cell
		(`addLifecycleMesh`, `LIVE_BLOCK_OPACITY`) rather than an opaque
		flat fill — the same "lit up, translucent" treatment the rest of
		this biome already uses for anything alive, reused here rather than
		invented fresh (asked for directly, "a bit translucent, well, as
		usual," after a first opaque-panel version shipped with no visible
		on/off distinction at all). Full-brightness `Colours.CONWAY_TILE_GLIDER`
		where the composed pattern is on, the same amber dimmed by
		`ENGRAVING_OFF_BRIGHTNESS` where it's off — one hue family for the
		whole footprint, not an unrelated color marking "off" — see
		`GeodesicPentagonEngraving`'s own doc for the pattern data behind
		`stateAt`. Rebuilt wholesale on every toggle and on enter/exit (same
		"removeChildren then rebuild from scratch" discipline
		`GeodesicConwayBiome.rebuildMesh` already uses for the floor/walls)
		— a footprint is only 6 cells, cheap regardless of cadence.
		@param parent the scene node to attach the engraving mesh under.
		@param boundaries every node's own cell polygon, `GeodesicDual.cellBoundaries(sphere)`.
		@param footprint the pentagon's own editable footprint, `GeodesicPentagonEngraving.footprintOf`.
		@param stateAt reads a footprint node's own composed state (`0`/`1`) — a plain function rather than the engraving instance itself, so this class doesn't need to depend on `GeodesicPentagonEngraving`'s own type.
	**/
	public static function buildEngraving(parent:h3d.scene.Object, boundaries:Array<Array<Vec3>>, footprint:Array<Int>, stateAt:Int->Int):Void {
		var onPoints:Array<h3d.Vector> = [];
		var onIdx = new hxd.IndexBuffer();
		var offPoints:Array<h3d.Vector> = [];
		var offIdx = new hxd.IndexBuffer();

		for (nodeId in footprint) {
			var boundary = [for (p in boundaries[nodeId]) lift(p, ENGRAVING_LIFT)];
			var hub = centroidOf(boundary);
			if (stateAt(nodeId) != 0) {
				addFan(onPoints, onIdx, hub, boundary);
			} else {
				addFan(offPoints, offIdx, hub, boundary);
			}
		}

		addLifecycleMesh(parent, onPoints, onIdx, Colours.CONWAY_TILE_GLIDER);
		addLifecycleMesh(parent, offPoints, offIdx, scaledColor(Colours.CONWAY_TILE_GLIDER, ENGRAVING_OFF_BRIGHTNESS));
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
		Heaps' own `hxd.IndexBuffer` is `UInt16`-backed — a single `Polygon`
		can never safely hold more than 65536 vertices, or an index past
		that silently wraps and ends up referencing an arbitrary, often-
		distant vertex instead. `WALL_VERTEX_BUDGET` is the point past which
		`buildWallMesh` starts a fresh `Polygon` rather than keep appending
		to one already this close to that ceiling — some headroom under the
		hard `65536` limit since one more `addWall`/`addJunctionPost` call
		could add up to `POST_VERTEX_COUNT` vertices at once.

		Found the hard way (2026-08-10): junction pillars pushed a real
		game-scale wall mesh's own vertex count to just over 100,000 —
		double the ceiling — reported directly as "texture is stretched
		from one object to a distant one, but a lot of times," which is
		exactly what a wrapped `UInt16` index looks like once rendered:
		every wrapped triangle references whatever vertex happens to sit at
		`index - 65536`, wherever in the mesh that is.
	**/
	static inline final WALL_VERTEX_BUDGET:Int = 60000;

	/** How many vertices one `addWall` call appends — 6 faces (front, back, 2 side caps, top, bottom), 4 each. **/
	static inline final WALL_VERTEX_COUNT:Int = 24;

	/** How many vertices one `addJunctionPost` call appends — 6 side faces (4 each) plus 2 fan caps (6 triangles of 3 verts each). **/
	static inline final POST_VERTEX_COUNT:Int = 60;

	/**
		Turns a set of wall segments into one or more `ConwayWallGlow`
		meshes — split across several `Polygon`s, `WALL_VERTEX_BUDGET` at a
		time (see that constant's own doc for why), rather than assuming
		everything always fits in one. Empty when `segments` was empty —
		`Polygon` rejects an empty vertex list, and a fully open/fully core
		generation legitimately produces one.
		@param parent the scene node to attach the mesh(es) under.
		@param segments the segments to draw.
		@param shader the `ConwayWallGlow` instance to shade them with (solid vs. ghost differ only in this) — shared across every chunk, but each `h3d.scene.Mesh` still gets its own `material`, so a caller mutating one mesh's material (`culling`, `blendMode`, ...) never affects another.
		@return every mesh actually built, in no particular order — empty when `segments` was empty.
	**/
	public static function buildWallMesh(parent:h3d.scene.Object, segments:Array<WallSegment>, shader:ConwayWallGlow):Array<h3d.scene.Mesh> {
		if (segments.length == 0) {
			return [];
		}

		var meshes:Array<h3d.scene.Mesh> = [];
		var points:Array<h3d.Vector> = [];
		var idx = new hxd.IndexBuffer();
		var uvs:Array<h3d.prim.UV> = [];
		var activity:Array<h3d.col.Point> = [];

		function flush():Void {
			if (points.length == 0) {
				return;
			}
			var prim = new h3d.prim.Polygon(points, idx);
			prim.uvs = uvs;
			prim.normals = activity;
			var mesh = new h3d.scene.Mesh(prim, parent);
			mesh.material.mainPass.addShader(shader);
			meshes.push(mesh);
			points = [];
			idx = new hxd.IndexBuffer();
			uvs = [];
			activity = [];
		}

		for (segment in segments) {
			if (points.length + WALL_VERTEX_COUNT > WALL_VERTEX_BUDGET) {
				flush();
			}
			addWall(points, idx, uvs, activity, segment.a, segment.b, segment.activity);
		}
		for (junction in collectJunctions(segments)) {
			if (points.length + POST_VERTEX_COUNT > WALL_VERTEX_BUDGET) {
				flush();
			}
			addJunctionPost(points, idx, uvs, activity, junction);
		}
		flush();
		return meshes;
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
		Appends one wall's own sealed slab — front face, back face, two side
		caps, and a top+bottom cap, `WALL_THICKNESS` apart — instead of the
		single zero-thickness quad `biomes.conway.ConwayMesh.addWall` still
		builds (see `WALL_THICKNESS`'s own doc for why a flat panel isn't
		enough here). **Actually sealed (2026-08-10) — the first version of
		this method claimed to be but wasn't.** It built the 4 vertical faces
		only, leaving the slab open at the top; reported directly, screenshot
		attached, of a wall corner shot from above showing straight into the
		hollow interior — this game's own "raise your head to see across the
		level" mechanic (`CLAUDE.md`'s own one-line pitch) makes that gap
		trivial to spot, not a corner case. The top/bottom caps close it.
		The original single-quad UV/activity convention carries over
		unchanged, just repeated once per face — each face gets its own
		independent `0..wallLength` strip, matching what the one face used
		to get alone.
	**/
	static function addWall(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, uvs:Array<h3d.prim.UV>, activityOut:Array<h3d.col.Point>, edgeA:Vec3, edgeB:Vec3,
			activity:Float):Void {
		var baseA = lift(edgeA, WALL_BASE_LIFT);
		var baseB = lift(edgeB, WALL_BASE_LIFT);
		var topA = liftFurther(baseA, GeodesicLifecycle.WALL_HEIGHT);
		var topB = liftFurther(baseB, GeodesicLifecycle.WALL_HEIGHT);

		// perpendicular to the panel itself — cross of its own two edges (along its length, and up its own height)
		var faceNormal = baseB.sub(baseA).cross(topA.sub(baseA)).normalized();
		var half = faceNormal.scaled(WALL_THICKNESS / 2);

		var frontBaseA = baseA.add(half);
		var frontBaseB = baseB.add(half);
		var frontTopA = topA.add(half);
		var frontTopB = topB.add(half);
		var backBaseA = baseA.sub(half);
		var backBaseB = baseB.sub(half);
		var backTopA = topA.sub(half);
		var backTopB = topB.sub(half);

		addWallFace(points, idx, uvs, activityOut, frontBaseA, frontBaseB, frontTopB, frontTopA, activity);
		addWallFace(points, idx, uvs, activityOut, backBaseB, backBaseA, backTopA, backTopB, activity);
		addWallFace(points, idx, uvs, activityOut, backBaseA, frontBaseA, frontTopA, backTopA, activity); // A-side cap
		addWallFace(points, idx, uvs, activityOut, frontBaseB, backBaseB, backTopB, frontTopB, activity); // B-side cap
		addWallFace(points, idx, uvs, activityOut, frontTopA, frontTopB, backTopB, backTopA, activity); // top cap
		addWallFace(points, idx, uvs, activityOut, frontBaseB, frontBaseA, backBaseA, backBaseB, activity); // bottom cap
	}

	/** One quad plus its `ConwayWallGlow` UVs/activity — see `biomes.conway.ConwayMesh.addWall`'s own doc for the UV/activity convention, ported unchanged; `addWall` now calls this once per face of a sealed slab instead of once for a single flat panel. **/
	static function addWallFace(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, uvs:Array<h3d.prim.UV>, activityOut:Array<h3d.col.Point>, a:h3d.Vector,
			b:h3d.Vector, c:h3d.Vector, d:h3d.Vector, activity:Float):Void {
		MeshBuilder.addQuad(points, idx, a, b, c, d);

		var faceLength = a.sub(b).length();
		uvs.push(new h3d.prim.UV(0, 0));
		uvs.push(new h3d.prim.UV(faceLength, 0));
		uvs.push(new h3d.prim.UV(faceLength, 1));
		uvs.push(new h3d.prim.UV(0, 1));
		for (_ in 0...4) {
			activityOut.push(new h3d.col.Point(activity, activity, activity));
		}
	}

	/**
		Plugs the seam a per-segment `addWall` slab leaves wherever two or
		more wall segments meet (2026-08-10) — reported directly, screenshot
		attached, of a corner shot from an angle that looks straight into a
		gap in the geometry. Each segment computes its own thickness offset
		perpendicular to *its own* length, so two segments meeting at a
		junction generally don't share a common thickness direction; their
		own front/back faces simply don't line up there, leaving a gap clean
		through the slab rather than a mitered joint.

		**A hexagonal pillar, not a square post (2026-08-10, same day,
		second revision) — the square one worked but looked wrong, asked
		directly to replace it.** Every dual vertex on this mesh is the
		circumcenter of exactly one triangle, so at most 3 wall segments
		ever meet at one — spaced roughly 120° apart by construction, the
		same reason a honeycomb's own vertices are 3-valent. A regular
		hexagon's own faces sit 60° apart, so orienting one face to square
		up with any *one* of those segments' own departure directions lands
		roughly every *other* face on the others too, letting each wall meet
		its own face close to head-on ("only orthogonal contacts") instead
		of at a corner. `POST_RADIUS` is chosen so a face lands exactly
		`WALL_THICKNESS` wide at that alignment, flush with the wall's own
		edges rather than over- or under-covering it — exact when the real
		angle is exactly 120° (true away from the 12 pentagons), a close
		approximation near them.

		A "junction" here is any point shared by 2+ segments in `segments`
		*by floating-point proximity*, not exact equality — the same
		physical dual vertex, queried once per neighboring node via
		`GeodesicDual.sharedEdge`, comes back numerically close but not
		bit-identical each time (`GeodesicDualTest.testSharedEdgeAgreesFromEitherEndpoint`'s
		own `1e-12` distance-squared tolerance is why), so `GeodesicSphere.weldKey`'s
		existing rounding (already trusted for the same "same point, computed
		twice" problem in `GeodesicLookup`'s own weld map) is reused here
		rather than assuming exact matches.

		Returns the data rather than building geometry directly (2026-08-10,
		same day) — `buildWallMesh`'s own vertex-budget chunking needs to
		check *before* committing to a post's own `POST_VERTEX_COUNT`
		vertices, which means it has to see every junction up front rather
		than have this method push straight into a `points` buffer it
		doesn't otherwise control the size of.
		@param segments the same segment list `addWall` is called for, once each.
		@return every point touched by 2+ of `segments`, with the data `addJunctionPost` needs to build one.
	**/
	static function collectJunctions(segments:Array<WallSegment>):Array<Junction> {
		var junctions = new Map<String, Junction>();
		for (segment in segments) {
			accumulateJunction(junctions, segment.a, segment.b, segment.activity);
			accumulateJunction(junctions, segment.b, segment.a, segment.activity);
		}
		var result = [];
		for (junction in junctions) {
			if (junction.count >= 2) {
				result.push(junction);
			}
		}
		return result;
	}

	static function accumulateJunction(junctions:Map<String, Junction>, point:Vec3, away:Vec3, activity:Float):Void {
		var key = GeodesicSphere.weldKey(point);
		var existing = junctions.get(key);
		if (existing == null) {
			junctions.set(key, {
				point: point,
				count: 1,
				activity: activity,
				departures: [away]
			});
		} else {
			existing.count++;
			existing.departures.push(away);
			if (activity > existing.activity) {
				existing.activity = activity; // the post reads as lit whenever any segment meeting there is
			}
		}
	}

	/** A hexagonal pillar's own circumradius — chosen so that, oriented with a face toward `hexCorners`'s own `reference` direction, that face is exactly `WALL_THICKNESS` wide: face width is `2 * apothem * tan(30°)`, and apothem-to-circumradius is `cos(30°)`, which combine to exactly `WALL_THICKNESS` itself. **/
	static inline final POST_RADIUS:Float = WALL_THICKNESS;

	/** How much taller than a wall's own `GeodesicLifecycle.WALL_HEIGHT` a junction pillar stands — asked directly ("slightly higher... not much"), so a small, untuned margin rather than a measured one. **/
	static inline final POST_HEIGHT_MARGIN:Float = 0.5;

	/** A sealed hexagonal prism straddling `junction.point`, oriented by `bestFitReference` across every one of `junction.departures` at once — see that function's own doc for why picking just one wasn't enough. Winding isn't hardened for outward normals the way `addWall`'s own faces are — `buildWallMesh`'s own mesh already renders with `culling = None`, so it doesn't need to be. **/
	static function addJunctionPost(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, uvs:Array<h3d.prim.UV>, activityOut:Array<h3d.col.Point>,
			junction:Junction):Void {
		var base = lift(junction.point, WALL_BASE_LIFT);
		var top = liftFurther(base, GeodesicLifecycle.WALL_HEIGHT + POST_HEIGHT_MARGIN);
		var up = base.normalized();
		var reference = bestFitReference(base, up, junction.departures);
		var perpendicular = up.cross(reference);

		var baseCorners = hexCorners(base, reference, perpendicular);
		var topCorners = hexCorners(top, reference, perpendicular);

		for (i in 0...6) {
			var next = (i + 1) % 6;
			addWallFace(points, idx, uvs, activityOut, baseCorners[i], baseCorners[next], topCorners[next], topCorners[i], junction.activity);
		}
		addPostCap(points, idx, uvs, activityOut, topCorners, junction.activity);
		addPostCap(points, idx, uvs, activityOut, baseCorners, junction.activity);
	}

	/** The unit tangent at `from` pointing (roughly) toward `toward` — `toward`'s own radial component relative to `from` discarded, so the result actually lies in `from`'s own tangent plane instead of tilting toward or away from the sphere's center. **/
	static function tangentDirection(from:h3d.Vector, toward:Vec3):h3d.Vector {
		var target = lift(toward, WALL_BASE_LIFT);
		var up = from.normalized();
		var raw = target.sub(from);
		return raw.sub(up.scaled(raw.dot(up))).normalized();
	}

	/** Hex face-normals repeat every 60°. **/
	static final HEX_FACE_PERIOD:Float = Math.PI / 3;

	/**
		A hex orientation balanced across *every* one of `departures`, not
		just the first — reported directly ("the pillars are not centered
		on the wall in all directions") after a first version anchored the
		whole hexagon to `departures[0]` alone. That's exactly right when
		every departure is exactly 120° (`2 * HEX_FACE_PERIOD`) from the
		next, but `addJunctionPosts`'s own doc already notes the real angle
		only *approximates* 120° away from the 12 pentagons — a spread of a
		few degrees either way, measured directly. Anchoring to one
		departure gives it a perfect fit and leaves the others to whatever
		residual the real angle happens to land on; this instead folds every
		departure's own angle (relative to an arbitrary zero direction) into
		a single `HEX_FACE_PERIOD` residual and *circular*-averages those
		residuals — scaling the period up to a full turn before averaging,
		the standard trick for a folded/periodic quantity, so a residual
		near one edge of the fold doesn't average incorrectly with one near
		the other edge of it — landing on the single rotation that
		minimizes the total misalignment across every departure at once,
		instead of favoring whichever happened to be first.
		@param base the junction's own already-lifted world position (`addJunctionPost`'s own `base`).
		@param up the local radial direction at `base` (`addJunctionPost`'s own `up`).
		@param departures every wall's own "other endpoint" touching this junction, world-space, unit-sphere Vec3 — `Junction.departures`.
		@return a unit tangent at `base`, to use as `hexCorners`'s own `reference`.
	**/
	static function bestFitReference(base:h3d.Vector, up:h3d.Vector, departures:Array<Vec3>):h3d.Vector {
		var zero = tangentDirection(base, departures[0]);
		var perpZero = up.cross(zero);

		var sumX = 0.0;
		var sumY = 0.0;
		for (departure in departures) {
			var dir = tangentDirection(base, departure);
			var angle = Math.atan2(dir.dot(perpZero), dir.dot(zero));
			var folded = angle % HEX_FACE_PERIOD;
			if (folded < 0) {
				folded += HEX_FACE_PERIOD;
			}
			var onFullTurn = folded * (2 * Math.PI / HEX_FACE_PERIOD);
			sumX += Math.cos(onFullTurn);
			sumY += Math.sin(onFullTurn);
		}
		var meanFolded = Math.atan2(sumY, sumX) * (HEX_FACE_PERIOD / (2 * Math.PI));

		return zero.scaled(Math.cos(meanFolded)).add(perpZero.scaled(Math.sin(meanFolded)));
	}

	/** The 6 corners of a `POST_RADIUS`-circumradius hexagon centered on `center`, in the tangent plane spanned by `reference`/`perpendicular` (both assumed unit and mutually perpendicular) — offset 30° from `reference` itself, so the face spanning the first and last corners is centered on (and perpendicular to) `reference`. **/
	static function hexCorners(center:h3d.Vector, reference:h3d.Vector, perpendicular:h3d.Vector):Array<h3d.Vector> {
		var corners = [];
		for (i in 0...6) {
			var angle = Math.PI / 6 + i * Math.PI / 3;
			var offset = reference.scaled(Math.cos(angle) * POST_RADIUS).add(perpendicular.scaled(Math.sin(angle) * POST_RADIUS));
			corners.push(center.add(offset));
		}
		return corners;
	}

	/** A pillar's own top or bottom cap — a 6-triangle fan around `corners`' own centroid, each triangle getting a flat, unseamed UV/activity reading (this is a small end cap, not a `ConwayWallGlow` seam surface like `addWall`'s own faces) rather than reusing `addFan`/`MeshBuilder.addTriangle` directly, since those don't push the UV/activity entries this mesh's `uvs`/`activityOut` buffers need kept in lockstep with `points`. **/
	static function addPostCap(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, uvs:Array<h3d.prim.UV>, activityOut:Array<h3d.col.Point>,
			corners:Array<h3d.Vector>, activity:Float):Void {
		var hub = centroidOf(corners);
		for (k in 0...corners.length) {
			var next = (k + 1) % corners.length;
			MeshBuilder.addTriangle(points, idx, hub, corners[k], corners[next]);
			uvs.push(new h3d.prim.UV(0, 0));
			uvs.push(new h3d.prim.UV(1, 0));
			uvs.push(new h3d.prim.UV(1, 1));
			for (_ in 0...3) {
				activityOut.push(new h3d.col.Point(activity, activity, activity));
			}
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

/** One dual vertex's own tally, built by `GeodesicMesh.addJunctionPosts`: how many segments in the current bucket touch it, the direction each one departs toward (`departures`, one per occurrence — `addJunctionPost` only actually needs the first, but keeping all of them is cheap and self-documenting), and the brightest activity among them. **/
typedef Junction = {point:Vec3, count:Int, activity:Float, departures:Array<Vec3>};
