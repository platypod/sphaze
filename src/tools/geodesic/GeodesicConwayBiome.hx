package tools.geodesic;

import biomes.common.Biome;
import biomes.common.Gravity;
import biomes.common.maze.MazeCarver;
import biomes.common.maze.MazeTopology.MazeLayout;
import biomes.common.space.sphere.SphereMath;
import biomes.conway.ConwayBiome;
import biomes.hub.HubBiome;
import entities.painting.PaintingModel;
import entities.player.Camera.CameraOverride;
import entities.player.PlayerModel;
import graphics.Colours;
import graphics.shaders.ConwayWallGlow;
import tools.geodesic.GeodesicCoarseMaze.BoundarySegment;
import tools.geodesic.GeodesicLifecycle.LifecycleStage;
import tools.geodesic.GeodesicSphere.GeodesicSphereData;
import tools.geodesic.GeodesicVentrellaRule.GeodesicVentrellaRules;
import tools.geodesic.Vec3.Vec3Math;

/**
	The geodesic sphere, wired up as an actual playable `Biome` — steps 2
	and 4 of `docs/game-design/notes/geodesic-sphere-engineering.md`'s own
	"wiring into the real game" list.

	**Deliberately reuses `ConwayBiome.ID`.** `biomes.hub.ConwayWaypoint`
	references the id string, not the class, and reuses `ConwayBiome`'s
	own tuned `GRAVITY`/`STEP_INTERVAL`/`backgroundColor` rather than
	re-deriving them: none of that tuning was ever about the grid's shape.

	**Two spheres, not one (2026-08-06) — the "coarse maze" wall-
	straightening attempt, moved here from `GeodesicPreview` once it had
	nothing further to prove standalone.** `fineSphere` still carries the
	floor tessellation and the Life simulation, unchanged since Phase 6.
	A separate, coarser `coarseSphere` carries the maze itself — carving,
	reactivity, and now collision too. `GeodesicCoarseMaze.fineToCoarse`
	assigns every fine cell to the coarse region it falls inside; walls
	render only where that assignment crosses a coarse boundary
	(`GeodesicCoarseMaze.wallSegments`), and `GeodesicCollision.tryMove`'s
	own `fineToCoarse` parameter remaps the player's fine position before
	checking the coarse layout — so what blocks the player and what's
	drawn as a wall are the same coarse edge, not approximations of each
	other. See `GeodesicCoarseMaze`'s own doc for the full reasoning, and
	`docs/game-design/design-decisions-records.md` for why a first
	attempt (`GeodesicWallSimplifier`, merging wall geometry after the
	fact) was retracted rather than fixed.

	**Ventrella rule (2026-08-09) — replaces the earlier `GeodesicLifeState`/B2/S34
	engine.** `GeodesicGliderSearchMultiRule`'s own exhaustive 2-ring search
	found zero confirmed travelers under any 2-state rule tried (B2/S34,
	B24/S46, B35/S2) in the 3-5 cell range, where Jeffrey Ventrella's own
	published 4-state hex-CA (`https://www.ventrella.com/SphereCA/`)
	demonstrates a period-2 glider that survives collisions on this exact
	topology — see `GeodesicVentrellaState`'s own doc for the full
	rationale.

	**Scripted glider spawns, not ambient soup (2026-08-09, same day, second
	revision).** First tried ambient random seeding (matching what
	`GeodesicVentrellaState.seed` is built for) — measured badly in play
	("very much 'not much' happening... random isolated cells birth, then
	die," `docs/game-design/design-decisions-records.md`'s own entry has
	the numbers: every density from `0.1` to `1.0` collapsed to `~0.1%`
	population). The fix wasn't a better density — it was reproducing
	Ventrella's own documented glider directly (hand-reconstructed from a
	description of the source paper's own Figure 2, self-verified before
	trusting it) and confirming it actually travels on this mesh — chord
	drift up to `1.812` on a unit sphere before looping back around and
	colliding with its own launch site. `GeodesicVentrellaGliderSpawner`
	now reseeds that confirmed shape from 12 sites (one per pentagon, each
	its own heading, staggered clocks) every tick; `state.step` runs with
	`noRandomBirths` the same way the old `GeodesicGliderTracker`-driven
	design once did, so the board's population is entirely attributable to
	deliberate spawns, never ambient noise. `GeodesicLifeState`/`GeodesicLifeRule`/
	`GeodesicGliderTracker`/every tool built on the old engine are untouched
	and still compile — a complete, trivially-revertible fallback, the same
	precedent this class's own doc already set when it replaced
	`biomes.conway.ConwayBiome`.

	**Smooth live-cell blocks, not per-generation pops (2026-08-10).**
	Reported directly after the spawner shipped: "the whole thing feels
	like it's stuttering, since cells move only at each tick." Live cell
	blocks used to rebuild once per `STEP_INTERVAL` alongside the floor/walls,
	so a block appeared or vanished in a single frame. `previousStages`/
	`currentStages` now snapshot `GeodesicLifecycle.stagesOf` at each
	generation boundary, and `rebuildLiveCells` — called every `tick`, at
	the engine's own 60Hz fixed-update cadence (`Main.FIXED_DT`), not the
	0.75s generation step — rebuilds just the live-cell meshes with height
	lerped between those two snapshots via `GeodesicMesh.buildLiveCells`.
	Collision (`applyGravity`'s own `GeodesicLifecycle.groundHeightOf`)
	deliberately still reads the discrete, post-step `state` directly, never
	interpolated — smoothing is a visual-only concern; blending jump timing
	against a fractional block height would make it feel mushy, not smooth.
	The floor/walls (`container`/`rebuildMesh`) are unaffected — genuinely
	static between generations, so still only rebuilt when a step actually
	happens, cheap relative to a per-frame live-cell rebuild whose own cost
	stays bounded by population size, not `sphere.neighbors.length`.

	**Thick walls need a matching clearance check (2026-08-10).** Reported
	after the smoothing fix: "we still see cells through walls," even with
	depth-write already correct — traced to `GeodesicMesh.addWall` building a
	single zero-thickness quad, which vanishes at grazing viewing angles no
	matter how depth/blend state is set. `GeodesicMesh.addWall` now extrudes
	a real slab (`GeodesicMesh.WALL_THICKNESS`), but `GeodesicCollision.tryMove`
	was purely graph-based — "which cell am I in" — with no distance buffer,
	so thickening the render geometry alone would let the camera end up
	*inside* it. `boundarySegments` (`GeodesicCoarseMaze.boundarySegmentsByFineNode`,
	computed once here since it's static geometry) indexes wall segments by
	fine node so `tryMove` can reject a move that lands too close to a
	*closed* one — see `GeodesicCollision`'s own doc for the "never trap the
	player" safety net that makes this an actual guarantee, not just a
	usual-case mitigation.

	**`serialize`/`restore`.** `fineSphere`/`coarseSphere`/`fineToCoarse`/
	`boundaryEdges`/`boundarySegments`/lookups aren't part of the save —
	every session derives them fresh from the same checked-in baked asset
	plus the same `COARSE_FREQUENCY`, so persisting a copy would be pure
	redundancy.
	`gliderSpawner` likewise isn't persisted — its 12 sites are a pure
	function of the checked-in sphere's own pentagon positions, so a fresh
	instance reconstructs identically. What *is* persisted:
	`coarseLayout.openEdges`, the coarse core edge set
	(`GeodesicReactivity.coreEdgeKeys`/`fromCoreKeys` — a save has no
	"freshly carved" layout lying around, so the immutable core set has to
	travel on its own), the Ventrella state, `generation` (so a restored
	save's spawn sites stay on the same clock rather than resetting to
	phase `0`), and the tick accumulator.

	**Pentagon composing (2026-08-10).** Player-authored counterpart to
	`gliderSpawner`'s own ambient shape — see `GeodesicPentagonEngraving`'s
	own doc for the full mechanic and `docs/game-design/ideas-backlog.md`'s
	"Deliberate pentagon activation" entry for the design conversation
	behind it. `interact` toggles `editingPentagon` on/off (entering only
	from a pentagon node itself, per `fineLookup.nodeAt`); `cameraOverride`
	dollies the camera in toward it while editing, and `capturesInput`
	reports the engraving being open, which is what `GameLoop` reads to
	suspend normal movement/turning and switch the mouse out of
	pointer-lock for clicking; `onEditClick` resolves a click's
	own ray against the sphere analytically (`raySphereIntersection`)
	and toggles whichever footprint cell it lands on. `engraving.tickAll`
	runs every `tick` unconditionally — a composed pentagon keeps
	restamping itself onto the live board whether or not the player is
	currently there, deliberately, so it acts as a sustaining source rather
	than a one-shot seed. `accumulator`'s own `while` loop (the
	simulation's real generation-advance) is skipped entirely while
	`editingPentagon != null`, so composing a pattern happens against a
	frozen board — the "freeze while zoomed in" the design conversation
	asked for; `engraving.tickAll`'s own restamp clock is unaffected by
	that freeze (it runs on real ticks, not generations), so a pentagon's
	pattern still restamps on schedule even while another pentagon is
	being edited. Not yet persisted across `serialize`/`restore` — an open
	gap, not a considered omission; a composed pattern is currently lost on
	reload the same way `gliderSpawner`'s sites *aren't* (those are a pure
	function of the sphere, this is genuine player state).
**/
class GeodesicConwayBiome implements Biome {
	static inline final RESOURCE_PATH:String = "geodesic/conway-sphere.json";

	/** See `GeodesicPreview.COARSE_FREQUENCY`'s own doc for the measurement this is picked from — same value, same reasoning, independently declared since the two classes have no shared base to hang a single constant off. **/
	static inline final COARSE_FREQUENCY:Int = 5;

	static inline final STEP_INTERVAL:Float = 0.75;
	static inline final EXIT_ARC_OFFSET:Float = 16;
	static inline final SPAWN_FACING:Float = 0.0;

	/**
		How far above a pentagon's own world position the dollied-in
		composing camera sits — close enough to read individual footprint
		cells clearly, far enough to see the whole 6-cell footprint at once.
		Untuned — a reasonable first guess against `GeodesicMesh.RADIUS`
		(`174`), not a measured value against real cell spacing; revisit
		after playing.
	**/
	static inline final ENGRAVING_VIEW_HEIGHT:Float = 30;

	var fineSphere:GeodesicSphereData;
	var fineBoundaries:Array<Array<Vec3>>;
	var fineLookup:GeodesicLookup;
	var coarseSphere:GeodesicSphereData;
	var fineToCoarse:Array<Int>;
	var boundaryEdges:Array<{a:Int, b:Int}>;
	var boundarySegments:Map<Int, Array<BoundarySegment>>;
	var coarseLayout:MazeLayout;
	var coarseReactivity:GeodesicReactivity;
	var state:GeodesicVentrellaState;
	var gliderSpawner:GeodesicVentrellaGliderSpawner;
	var generation:Int = 0;

	/** Every node's own stage as of the last two generation boundaries — what `rebuildLiveCells` lerps between. See this class's own "Smooth live-cell blocks" doc. **/
	var previousStages:Array<LifecycleStage>;

	var currentStages:Array<LifecycleStage>;
	var noOpFineLayout:MazeLayout;
	var noOpFineReactivity:GeodesicReactivity;
	var spawnNode:Int;
	var accumulator:Float = 0;
	var container:Null<h3d.scene.Object>;
	var liveCellsContainer:Null<h3d.scene.Object>;

	/** Player-composed patterns at each pentagon — see this class's own "Pentagon composing" doc and `GeodesicPentagonEngraving`'s own class doc. **/
	var engraving:GeodesicPentagonEngraving;

	/** Which pentagon (a node id) the player is currently composing at, or null while playing normally — the sole source of truth `cameraOverride`/`onEditClick`/`tick`'s own freeze all read. **/
	var editingPentagon:Null<Int> = null;

	/** The composing camera's own screen-up while `editingPentagon != null` — the player's own facing at the moment they entered, projected into the pentagon's tangent plane, captured once on entry so the zoomed view doesn't spin freely. **/
	var engravingViewUp:h3d.Vector;

	var engravingContainer:Null<h3d.scene.Object>;

	public function new() {
		var loaded = GeodesicSphere.fromJson(hxd.Res.load(RESOURCE_PATH).toText());
		fineSphere = loaded.sphere;
		fineBoundaries = GeodesicDual.cellBoundaries(fineSphere);
		fineLookup = new GeodesicLookup(fineSphere, loaded.frequency);

		coarseSphere = GeodesicSphere.generate(COARSE_FREQUENCY);
		var coarseLookup = new GeodesicLookup(coarseSphere, COARSE_FREQUENCY);
		fineToCoarse = GeodesicCoarseMaze.fineToCoarse(fineSphere, coarseLookup);
		boundaryEdges = GeodesicCoarseMaze.boundaryEdges(fineSphere, fineToCoarse);
		boundarySegments = GeodesicCoarseMaze.boundarySegmentsByFineNode(fineSphere, fineBoundaries, boundaryEdges, fineToCoarse);

		coarseLayout = MazeCarver.carve(new GeodesicTopology(coarseSphere), RandomizedDfs, 0);
		// captured before anything steps, so the core set really is the carve — see GeodesicReactivity's own doc
		coarseReactivity = new GeodesicReactivity(coarseSphere, coarseLayout);

		state = new GeodesicVentrellaState(fineSphere, GeodesicVentrellaRules.SPHERE_CA);
		gliderSpawner = new GeodesicVentrellaGliderSpawner(fineSphere);
		gliderSpawner.tick(state, generation);
		engraving = new GeodesicPentagonEngraving(fineSphere);
		engravingViewUp = new h3d.Vector(0, 0,
			1); // placeholder — always overwritten by interact() before editingPentagon (and so cameraOverride) is ever non-null
		currentStages = GeodesicLifecycle.stagesOf(state, fineSphere);
		previousStages = currentStages; // nothing to fade in from on first load

		var noOp = GeodesicCoarseMaze.noOpFineMazeLayer(fineSphere);
		noOpFineLayout = noOp.layout;
		noOpFineReactivity = noOp.reactivity;

		spawnNode = firstHexagon(fineSphere);
	}

	public function id():String {
		return ConwayBiome.ID;
	}

	public function gravity():Float {
		return ConwayBiome.GRAVITY;
	}

	public function backgroundColor():Int {
		return ConwayBiome.BACKGROUND_COLOR;
	}

	public function build(parent:h3d.scene.Object):Void {
		container = new h3d.scene.Object(parent);
		rebuildMesh();
		liveCellsContainer = new h3d.scene.Object(parent);
		rebuildLiveCells();
		engravingContainer = new h3d.scene.Object(parent);
	}

	public function spawnPlayer(returning:Bool, fromBiomeId:Null<String>):PlayerModel {
		var spawnPos = worldPositionOf(spawnNode);
		return PlayerModel.spawnAt(SphereMath.thetaOf(spawnPos), SphereMath.phiOf(spawnPos), SPAWN_FACING, GeodesicMesh.RADIUS);
	}

	/**
		An exit painting near spawn, the same "nudge along the surface by a
		fixed arc" idea `ConwayBiome.exitPaintings` uses — except there's no
		`(theta, phi)` formula to nudge here, so this walks to spawn's own
		first neighbor instead and offsets from there, which is the same
		"a short, unambiguous step away" result by construction (adjacent
		fine nodes are on the order of a few world units apart, comparable
		to `EXIT_ARC_OFFSET`).
	**/
	public function exitPaintings():Array<PaintingModel> {
		var neighbor = fineSphere.neighbors[spawnNode][0];
		var exitPos = worldPositionOf(neighbor);
		return [new PaintingModel(exitPos, HubBiome.ID)];
	}

	public function tryMove(player:PlayerModel, direction:h3d.Vector, distance:Float):Void {
		GeodesicCollision.tryMove(player, direction, distance, GeodesicMesh.RADIUS, coarseLayout, fineLookup, fineToCoarse, boundarySegments);
	}

	/** See `biomes.conway.ConwayBiome.applyGravity`'s own doc — same "recompute fresh every tick, never cached" reasoning, over `GeodesicLifecycle.groundHeightOf` instead of `ConwayGrid.groundHeightAt`. Fine-keyed, not coarse: standing on a live block is about the fine Life layer, unrelated to which coarse region the maze puts it in. **/
	public function applyGravity(player:PlayerModel, dt:Float):Void {
		var nodeId = fineLookup.nodeAt(toVec3(player.pos));
		Gravity.fallToSurface(player, ConwayBiome.GRAVITY, dt, GeodesicLifecycle.groundHeightOf(state, nodeId));
	}

	public function tick(player:PlayerModel, dt:Float):Void {
		// The simulation's own generation-advance is skipped entirely while
		// composing — the "freeze while zoomed in" this class's own
		// "Pentagon composing" doc describes. engraving.tickAll below is
		// deliberately NOT inside this guard: a pentagon's own restamp
		// clock runs on real ticks, not generations, so an already-composed
		// pattern keeps reasserting itself on schedule even while the
		// player is off editing a different (or no) pentagon.
		if (editingPentagon == null) {
			accumulator += dt;
			var stepped = false;
			while (accumulator >= STEP_INTERVAL) {
				accumulator -= STEP_INTERVAL;
				state.step(noRandomBirths); // no ambient soup — MUTATION_RATE would otherwise sprout stray life anywhere on the board, not just at gliderSpawner's own launch sites
				generation++;
				gliderSpawner.tick(state, generation);
				var edgeActivityOf = GeodesicCoarseMaze.boundaryActivity(state, boundaryEdges, fineToCoarse);
				var playerFineNode = fineLookup.nodeAt(toVec3(player.pos));
				var playerCoarseNode = fineToCoarse[playerFineNode];
				coarseReactivity.step(coarseLayout, edgeActivityOf, playerCoarseNode);
				previousStages = currentStages;
				currentStages = GeodesicLifecycle.stagesOf(state, fineSphere);
				stepped = true;
			}
			if (stepped && container != null) {
				container.removeChildren();
				rebuildMesh();
			}
		}
		engraving.tickAll(state);
		// every call, not just when stepped — this is what actually animates: accumulator keeps moving between generation boundaries even on frames that don't cross STEP_INTERVAL
		rebuildLiveCells();
	}

	/**
		Enters or exits the pentagon-composing engraving — see this class's
		own "Pentagon composing" doc. Entering only works while standing
		exactly on a pentagon node (`fineSphere.neighbors[nodeId].length == 5`);
		standing anywhere else, or already editing, this only ever exits.
	**/
	public function interact(player:PlayerModel):Void {
		if (editingPentagon != null) {
			exitEngraving();
			return;
		}
		var nodeId = fineLookup.nodeAt(toVec3(player.pos));
		if (fineSphere.neighbors[nodeId].length != 5) {
			return; // not standing on a pentagon — nothing to enter
		}
		editingPentagon = nodeId;
		// Interior "up" (toward the sphere's own center, SphereMath.upVectorAt's
		// own convention) — tangentProject's own result is direction-symmetric
		// (an axis, not a signed direction, changes nothing about the
		// projection either way), but matching the sign every other "up" in
		// this class uses avoids a second, silently-inverted convention.
		var up = worldPositionOf(nodeId).normalized().scaled(-1);
		engravingViewUp = tangentProject(player.forward, up);
		rebuildEngraving();
	}

	/**
		See `biomes.common.Biome.cameraOverride`'s own doc — non-null exactly
		while composing, dollied in toward `editingPentagon`'s own world
		position. **Dollies toward the sphere's own center, not away from
		it (2026-08-10, fixed after "no visual clue whatsoever" turned out
		to mean the engraving wasn't rendering at all, not just wasn't
		legible).** This sphere is walked from the *interior* —
		`SphereMath.upVectorAt`'s own doc: "up" for a point on the surface
		is the direction *back toward the center*, the opposite of the
		plain outward radial `worldPositionOf(pentagonId).normalized()`
		gives. The first version dollied outward, putting the camera on the
		far side of the floor mesh from the hollow interior it should be
		looking out from — and since `ENGRAVING_LIFT` (`0.5`) pulls the
		engraving further toward the center than the floor's own `TILE_LIFT`
		(`0.03`), that misplaced camera had the opaque floor sitting nearer
		it than the engraving on every ray, hiding it completely rather than
		merely dimly. Dollying inward instead puts the camera back on the
		interior side, where `ENGRAVING_LIFT` being the larger offset makes
		the engraving the *nearer* layer, exactly as a raised plaque above
		the floor should read.
	**/
	public function cameraOverride(player:PlayerModel):Null<CameraOverride> {
		var pentagonId = editingPentagon;
		if (pentagonId == null) {
			return null;
		}
		var center = worldPositionOf(pentagonId);
		var inward = center.normalized().scaled(-1);
		var eyePos = center.add(inward.scaled(ENGRAVING_VIEW_HEIGHT));
		return {pos: eyePos, target: center, up: engravingViewUp};
	}

	/**
		Takes the input exactly while a pentagon engraving is open — see
		`biomes.common.Biome.capturesInput`'s own doc, including why this is a
		separate question from `cameraOverride` rather than the same one.
	**/
	public function capturesInput():Bool {
		return editingPentagon != null;
	}

	/**
		See `biomes.common.Biome.onEditClick`'s own doc. Resolves `ray`
		against the sphere itself (`raySphereIntersection`, exact for a
		sphere — no need for the mesh-based picking a less regular surface
		would require), then whichever fine node is nearest the hit point
		(`fineLookup.nodeAt`, the same lookup collision/gravity already use
		for "which cell is a world point in"). A miss, or a hit outside the
		pentagon's own footprint, is silently ignored — not every click
		lands on the engraving.
	**/
	public function onEditClick(ray:h3d.col.Ray):Void {
		var pentagonId = editingPentagon;
		if (pentagonId == null) {
			return;
		}
		var t = raySphereIntersection(ray, GeodesicMesh.RADIUS);
		if (t < 0) {
			return;
		}
		var hit = ray.getPoint(t);
		var nodeId = fineLookup.nodeAt(Vec3Math.make(hit.x, hit.y, hit.z));
		if (!engraving.isInFootprint(pentagonId, nodeId)) {
			return;
		}
		engraving.toggle(pentagonId, nodeId);
		rebuildEngraving();
	}

	/**
		Ray-sphere intersection distance for the sphere of radius `radius`
		centered at the origin — a small replacement for
		`h3d.col.Sphere.rayIntersection` (2026-08-10, found the hard way:
		every click was resolving to the pentagon itself, wherever on
		screen it actually landed). That stock method only ever returns
		the *near* root of the intersection quadratic, which is negative
		whenever the ray's own origin sits inside the sphere — exactly
		true here by construction, since `cameraOverride` dollies the
		composing camera *toward* the sphere's center (radius
		`GeodesicMesh.RADIUS - ENGRAVING_VIEW_HEIGHT`, well inside
		`GeodesicMesh.RADIUS`). Heaps clamps that negative root to `0`, so
		every click's own ray resolved to its own eye position — and
		because the dolly moves straight along the pentagon's own radius,
		that eye position shares the pentagon's own direction from the
		origin, which is why `fineLookup.nodeAt` (direction-only, ignores
		magnitude) always landed back on the pentagon regardless of where
		the click actually was. This picks the *far* root when the origin
		is inside, the near one when it's outside, rather than assuming
		either.
		@param ray the ray to intersect, own direction assumed unit length (matches `h3d.Camera.rayFromScreen`'s own output).
		@param radius the sphere's own radius.
		@return the distance along `ray` to the first real intersection, or `-1` if it misses.
	**/
	static function raySphereIntersection(ray:h3d.col.Ray, radius:Float):Float {
		var b = ray.px * ray.lx + ray.py * ray.ly + ray.pz * ray.lz;
		var c = ray.px * ray.px + ray.py * ray.py + ray.pz * ray.pz - radius * radius;
		var discriminant = b * b - c;
		if (discriminant < 0) {
			return -1;
		}
		var sqrtDiscriminant = Math.sqrt(discriminant);
		var near = -b - sqrtDiscriminant;
		if (near >= 0) {
			return near;
		}
		var far = -b + sqrtDiscriminant;
		return far >= 0 ? far : -1;
	}

	public function timeScale():Float {
		return 1;
	}

	/** See this class's own doc for the four-part shape — the two-sphere-addressed counterpart to `biomes.conway.ConwayBiome.serialize`. **/
	public function serialize():String {
		return haxe.Json.stringify({
			openEdges: [for (key in coarseLayout.openEdges.keys()) key],
			coreEdges: coarseReactivity.coreEdgeKeys(coarseSphere),
			life: state.serialize(),
			generation: generation,
			accumulator: accumulator,
		});
	}

	/**
		Restores `coarseLayout`/`coarseReactivity`/`state`/`accumulator`
		from `serialize`'s own output. `fineSphere`/`coarseSphere`/
		`fineToCoarse`/lookups/`spawnNode` are untouched — derived from the
		checked-in baked asset and `COARSE_FREQUENCY` this instance already
		resolved in its own constructor, not save data. A save missing
		`coreEdges` (from before this format existed, or a malformed
		import) falls back to treating every currently-open coarse edge as
		core — the same "no core info, so protect everything that's
		currently open" reading `ConwayMaze.deserialize` gives an
		old-format save, not a guess this class invented independently.
	**/
	public function restore(json:String):Void {
		var parsed:{
			openEdges:Array<String>,
			coreEdges:Array<String>,
			life:String,
			generation:Int,
			accumulator:Float
		} = haxe.Json.parse(json);

		var openEdges = new haxe.ds.StringMap<Bool>();
		if (parsed.openEdges != null) {
			for (key in parsed.openEdges) {
				openEdges.set(key, true);
			}
		}
		coarseLayout = {openEdges: openEdges};

		coarseReactivity = parsed.coreEdges != null ? GeodesicReactivity.fromCoreKeys(coarseSphere,
			parsed.coreEdges) : new GeodesicReactivity(coarseSphere, coarseLayout);

		var restoredGeneration = Std.parseInt(Std.string(parsed.generation));
		generation = restoredGeneration == null ? 0 : restoredGeneration;

		if (parsed.life != null) {
			state = GeodesicVentrellaState.deserialize(fineSphere, GeodesicVentrellaRules.SPHERE_CA, parsed.life);
		} else {
			// no persisted life state (old-format save, or malformed import) — relaunch every site fresh rather than leave the board dead, matching what a brand-new instance does in its own constructor
			state = new GeodesicVentrellaState(fineSphere, GeodesicVentrellaRules.SPHERE_CA);
			gliderSpawner.tick(state, generation);
		}
		currentStages = GeodesicLifecycle.stagesOf(state, fineSphere);
		previousStages = currentStages; // nothing to fade in from across a restore

		var restoredAccumulator = Std.parseFloat(Std.string(parsed.accumulator));
		accumulator = Math.isNaN(restoredAccumulator) ? 0 : restoredAccumulator;

		if (container != null) {
			container.removeChildren();
			rebuildMesh();
		}
		if (liveCellsContainer != null) {
			rebuildLiveCells();
		}
	}

	/**
		Floor/blocks from `GeodesicMesh.build` (fed the no-op fine layer so
		it draws nothing else), walls from `GeodesicCoarseMaze.wallSegments`
		— the exact same split `GeodesicPreview.rebuild` uses, since this
		is the same rendering, just no longer standalone.
	**/
	function rebuildMesh():Void {
		var parent = container;
		if (parent == null) {
			return;
		}

		GeodesicMesh.build(parent, fineSphere, fineBoundaries, state, noOpFineLayout, noOpFineReactivity);

		var edgeActivityOf = GeodesicCoarseMaze.boundaryActivity(state, boundaryEdges, fineToCoarse);
		var segments = GeodesicCoarseMaze.wallSegments(fineSphere, fineBoundaries, boundaryEdges, fineToCoarse, coarseLayout, coarseReactivity, edgeActivityOf);

		for (wallMesh in GeodesicMesh.buildWallMesh(parent, segments.walls, new ConwayWallGlow(Colours.CONWAY_WALL_PANEL, Colours.CONWAY_WALL_GLOW))) {
			wallMesh.material.mainPass.culling = None;
		}

		for (ghostMesh in GeodesicMesh.buildWallMesh(parent, segments.ghosts,
			new ConwayWallGlow(Colours.CONWAY_WALL_PANEL, Colours.CONWAY_WALL_GLOW, ConwayWallGlow.DEFAULT_SEAM_DENSITY,
				ConwayWallGlow.DEFAULT_REST_BRIGHTNESS, GeodesicMesh.GHOST_WALL_OPACITY))) {
			ghostMesh.material.mainPass.culling = None;
			ghostMesh.material.blendMode = h3d.mat.BlendMode.Alpha; // sets depthWrite = true as a side effect (h3d.mat.Material.set_blendMode) — depthWrite below must come after, not before, or it's silently reset
			ghostMesh.material.mainPass.depthWrite = false;
		}
	}

	/** Rebuilds just the live-cell blocks, height-lerped between `previousStages`/`currentStages` at `accumulator / STEP_INTERVAL` — see this class's own "Smooth live-cell blocks" doc. Called every `tick`, not gated on whether a generation actually stepped this frame. **/
	function rebuildLiveCells():Void {
		var parent = liveCellsContainer;
		if (parent == null) {
			return;
		}
		parent.removeChildren();
		GeodesicMesh.buildLiveCells(parent, fineSphere, fineBoundaries, previousStages, currentStages, accumulator / STEP_INTERVAL);
	}

	/** Clears `editingPentagon` and the engraving mesh — the exit half of `interact`'s own toggle. **/
	function exitEngraving():Void {
		editingPentagon = null;
		if (engravingContainer != null) {
			engravingContainer.removeChildren();
		}
	}

	/** Rebuilds the engraving mesh for `editingPentagon`'s own footprint — called on entry and after every toggle, since a footprint is only 6 cells (cheap regardless of cadence, same reasoning `rebuildMesh` already leans on for the much larger floor/wall mesh). A no-op if not currently editing (defensive; every call site already guards on `editingPentagon != null` itself). **/
	function rebuildEngraving():Void {
		var parent = engravingContainer;
		var pentagonId = editingPentagon;
		if (parent == null || pentagonId == null) {
			return;
		}
		parent.removeChildren();
		GeodesicMesh.buildEngraving(parent, fineBoundaries, engraving.footprintOf(pentagonId), (nodeId) -> engraving.stateAt(pentagonId, nodeId));
	}

	/** The unit component of `vector` lying in the tangent plane at `up` — `vector`'s own radial component (along `up`) discarded. Used once, to capture the composing camera's own screen-up from the player's facing at the moment they enter (see `interact`'s own doc) — the same projection `GeodesicMesh.tangentDirection` performs internally for its own (unrelated) wall-orientation purpose, duplicated here rather than shared since that one is private to a different class and takes a "toward a neighbor" pair rather than an arbitrary vector. **/
	static function tangentProject(vector:h3d.Vector, up:h3d.Vector):h3d.Vector {
		return vector.sub(up.scaled(vector.dot(up))).normalized();
	}

	/** Always above `GeodesicVentrellaState.MUTATION_RATE` — passed to `state.step` so the only cells ever alive are ones `gliderSpawner`'s own launch sites put there, or that the rule's own subrules grow from those, never a random mutation flip. **/
	static function noRandomBirths():Float {
		return 1;
	}

	/** `fineSphere.neighbors.length == 5` never happens for a node the maze carver reaches from a hexagon-degree walk in practice at this frequency, but the search is honest about needing one anyway rather than assuming node `0` isn't a pentagon. **/
	static function firstHexagon(fineSphere:GeodesicSphereData):Int {
		for (id in 0...fineSphere.neighbors.length) {
			if (fineSphere.neighbors[id].length == 6) {
				return id;
			}
		}
		throw "expected at least one hexagon on a geodesic sphere of more than 12 nodes";
	}

	function worldPositionOf(nodeId:Int):h3d.Vector {
		var p = fineSphere.positions[nodeId];
		return new h3d.Vector(p.x, p.y, p.z).scaled(GeodesicMesh.RADIUS);
	}

	static function toVec3(pos:h3d.Vector):Vec3 {
		return Vec3Math.make(pos.x, pos.y, pos.z);
	}
}
