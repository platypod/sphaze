package tools.hyperbolic;

import game.MeshBuilder;
import game.PhysicalKeys;
import geometry.CurvedSpace;
import geometry.CurvedSpace.ModelPoint;
import geometry.HyperbolicProjection;
import geometry.HyperbolicTiling;
import geometry.HyperbolicWalker;
import geometry.Isometry;

/**
	**Phase 0's kill-criterion harness: a bare `{7,3}` room you can walk.**

	`docs/building/roadmap.md` names exactly one existential
	risk for the whole direction — *is walking in hyperbolic space pleasant,
	or is it nauseating?* — and states that nothing else should be built
	until that has been answered by *playing* it. This is the thing to play.

	Deliberately **standalone**, with its own `walk.hxml` and `make walk`,
	following the precedent `GeodesicPreview` set (a visual harness outside
	the game proper, retired once it had nothing left to prove). It shares
	no code path with `Main`/`GameLoop`, implements no `Biome`, and touches
	nothing the real game depends on — so a Phase 0 answer of "no" costs
	only this file, and a working game is never at risk while the question
	is open.

	**What is deliberately absent.** No art, no simulation, no cellular
	automaton, no maze, no goal. Adding any of it would make a bad answer
	ambiguous ("was that nausea, or just an ugly room?"). What is here is
	the minimum that makes motion legible: a tiled floor to see passing
	underfoot, columns for parallax, one distinctly-coloured home cell to
	try navigating back to, and a numeric readout.

	**What to look for while playing**, per the roadmap's own criteria:

	- Ten minutes without discomfort → proceed, treating comfort as a
	  standing design constraint.
	- Nausea that no amount of speed/FOV/turn-rate tuning fixes → the
	  direction changes; hyperbolic spaces become things you look at and
	  manipulate rather than walk through.
	- Get other people to try it. Motion tolerance varies enormously and a
	  sample of one is not a sample.

	**Not verified in this environment.** Per `CLAUDE.md`, keyboard/mouse
	input does not reliably reach the canvas here, so this has been
	compiled and lint-checked but never played. The *mathematics* underneath
	it is separately tested and green (`geometry.HyperbolicProjectionTest`,
	`HyperbolicWalkerTest`, `CurvedSpaceTest`, `HyperbolicTilingTest`) — so
	if the room looks wrong, suspect this file's own plumbing, not the
	geometry.
**/
class HyperbolicWalkApp extends hxd.App {
	/** Rings of `{7,3}` generated. Six is already 1625 faces; distant ones cost nothing since `DRAW_DISTANCE` culls them. **/
	static inline final RINGS:Int = 6;

	/** Cull faces beyond this hyperbolic distance. Past ~4 everything is inside the last 2% of the Klein disk and contributes nothing but vertices. **/
	static inline final DRAW_DISTANCE:Float = 4.0;

	/** Hyperbolic units per second. One cell step is `≈1.09`, so this crosses about one cell a second. **/
	static inline final WALK_SPEED:Float = 1.1;

	static inline final TURN_SPEED:Float = 2.0;
	static inline final MOUSE_SENSITIVITY:Float = 0.003;
	static inline final MAX_PITCH:Float = 1.2;
	static inline final EYE_HEIGHT:Float = 1.7;
	static inline final COLUMN_HEIGHT:Float = 4.0;

	/** Column half-width, in *hyperbolic* units — so a column is the same real size everywhere, rather than shrinking with the projection. **/
	static inline final COLUMN_RADIUS:Float = 0.10;

	/** Floor tiles drawn slightly inside their true boundary, so the tiling's own grid is visible as gaps rather than having to be outlined. **/
	static inline final TILE_INSET:Float = 0.92;

	/** Every Nth face gets a column — dense enough for continuous parallax, sparse enough to see past. **/
	static inline final COLUMN_EVERY:Int = 3;

	/**
		How far back from the origin the player starts, in hyperbolic units
		(two cell steps).

		The home spire stands *at* the origin, so spawning at the origin puts
		the camera inside it — which is exactly what the first render of this
		harness did, filling the screen with flat orange. Backing off two
		cells makes the spire a landmark to navigate toward instead of a
		blindfold, and keeps `distanceFromOrigin` meaningful as "how far am I
		from the thing I can see".
	**/
	static inline final SPAWN_DISTANCE:Float = 2.2;

	static inline final FLOOR_COLOR:Int = 0x1B2A38;
	static inline final COLUMN_COLOR:Int = 0x2E5C7A;
	static inline final HOME_COLOR:Int = 0xFFB627;
	static inline final BACKGROUND_COLOR:Int = 0x080C12;

	var tiling:HyperbolicTiling;
	var walker:HyperbolicWalker;
	var world:h3d.scene.Object;
	var readout:h2d.Text;
	var pitch:Float = 0;

	/** Every face's own corner points, in world hyperbolic coordinates — static, so computed once rather than per frame. **/
	var faceCorners:Array<Array<ModelPoint>>;

	/** Base corners of each column, or null for faces without one. Same reasoning: static geometry, precomputed. **/
	var columnCorners:Array<Null<Array<ModelPoint>>>;

	static function main():Void {
		new HyperbolicWalkApp();
	}

	override function init():Void {
		hxd.Res.initEmbed();
		engine.backgroundColor = BACKGROUND_COLOR;
		s3d.camera.fovY = 75;
		s3d.camera.zNear = 0.05;
		s3d.camera.zFar = HyperbolicProjection.HORIZON * 3;

		tiling = new HyperbolicTiling(7, 3, RINGS);
		walker = new HyperbolicWalker();
		walker.moveForward(-SPAWN_DISTANCE); // stand back from the home spire, facing it
		world = new h3d.scene.Object(s3d);

		precomputeGeometry();

		readout = new h2d.Text(hxd.res.DefaultFont.get(), s2d);
		readout.x = 12;
		readout.y = 12;
		readout.textColor = 0xFFD166;

		var window = hxd.Window.getInstance();
		window.mouseMode = Relative(onMouseMove, true);
		window.onMouseModeChange = (from, to) -> to == Absolute ? Relative(onMouseMove, true) : null;
	}

	/**
		Works out every face's corners and every column's base once, in world
		hyperbolic coordinates. Nothing here changes as the player moves —
		only the *view* does — so per-frame work reduces to transforming
		these by one isometry and projecting.
	**/
	function precomputeGeometry():Void {
		var circumradius = HyperbolicTiling.circumradiusOf(7, 3) * TILE_INSET;

		// Corners sit half a step around from the edge midpoints the
		// generators point at, hence the extra pi/7.
		var cornerOffsets = [
			for (k in 0...7)
				Isometry.compose(Isometry.rotation(k * 2 * Math.PI / 7 + Math.PI / 7), Isometry.translation(Hyperbolic, circumradius))
		];
		var columnOffsets = [
			for (k in 0...4)
				Isometry.compose(Isometry.rotation(k * Math.PI / 2), Isometry.translation(Hyperbolic, COLUMN_RADIUS))
		];

		faceCorners = [];
		columnCorners = [];
		for (id in 0...tiling.centers.length) {
			var frame = tiling.frames[id];
			faceCorners.push([
				for (offset in cornerOffsets)
					Isometry.positionOf(Isometry.compose(frame, offset))
			]);
			var hasColumn = id == 0 || id % COLUMN_EVERY == 1;
			columnCorners.push(hasColumn ? [
				for (offset in columnOffsets)
					Isometry.positionOf(Isometry.compose(frame, offset))
			] : null);
		}
	}

	override function update(dt:Float):Void {
		handleInput(dt);
		rebuildWorld();
		placeCamera();
		updateReadout();
	}

	/**
		Physical `KeyboardEvent.code` throughout (`game.PhysicalKeys`) rather
		than `hxd.Key`'s layout-labelled codes, so this works on AZERTY and
		QWERTY alike — the same reason `game.Keybinds` already binds the
		game's own movement that way, and a bug this file originally had.
	**/
	function handleInput(dt:Float):Void {
		if (PhysicalKeys.isDown("KeyW") || PhysicalKeys.isDown("ArrowUp")) {
			walker.moveForward(WALK_SPEED * dt);
		}
		if (PhysicalKeys.isDown("KeyS") || PhysicalKeys.isDown("ArrowDown")) {
			walker.moveForward(-WALK_SPEED * dt);
		}
		if (PhysicalKeys.isDown("KeyA")) {
			walker.strafe(-WALK_SPEED * dt);
		}
		if (PhysicalKeys.isDown("KeyD")) {
			walker.strafe(WALK_SPEED * dt);
		}
		if (PhysicalKeys.isDown("ArrowLeft")) {
			walker.turn(-TURN_SPEED * dt);
		}
		if (PhysicalKeys.isDown("ArrowRight")) {
			walker.turn(TURN_SPEED * dt);
		}
		if (PhysicalKeys.isPressed("KeyR")) {
			walker = new HyperbolicWalker();
			walker.moveForward(-SPAWN_DISTANCE);
			pitch = 0;
		}
	}

	function onMouseMove(e:hxd.Event):Void {
		walker.turn(e.relX * MOUSE_SENSITIVITY);
		pitch -= e.relY * MOUSE_SENSITIVITY;
		pitch = pitch > MAX_PITCH ? MAX_PITCH : (pitch < -MAX_PITCH ? -MAX_PITCH : pitch);
	}

	/**
		Rebuilds every visible face and column from scratch each frame.

		Wasteful on purpose: the alternative is putting the projection in an
		HxSL vertex shader (what `architecture.md` recommends for the real
		renderer) and leaving the geometry static — which is faster, and
		which cannot be *verified* in this environment at all. Doing it
		CPU-side keeps the arithmetic in tested Haxe, so a wrong-looking room
		is a plumbing bug rather than an unverifiable shader. Port to HxSL
		once the room is confirmed to look right.
	**/
	function rebuildWorld():Void {
		world.removeChildren();

		var floorPoints:Array<h3d.Vector> = [];
		var floorIdx = new hxd.IndexBuffer();
		var columnPoints:Array<h3d.Vector> = [];
		var columnIdx = new hxd.IndexBuffer();
		var homePoints:Array<h3d.Vector> = [];
		var homeIdx = new hxd.IndexBuffer();

		for (id in 0...tiling.centers.length) {
			var center = walker.toCameraFrame(tiling.centers[id]);
			if (HyperbolicProjection.distanceFromCamera(center) > DRAW_DISTANCE) {
				continue;
			}

			var corners = [
				for (p in faceCorners[id])
					HyperbolicProjection.toWorld(walker.toCameraFrame(p), 0)
			];
			var hub = HyperbolicProjection.toWorld(center, 0);
			for (k in 0...corners.length) {
				MeshBuilder.addTriangle(floorPoints, floorIdx, hub, corners[k], corners[(k + 1) % corners.length]);
			}

			var base = columnCorners[id];
			if (base != null) {
				var isHome = id == 0;
				addColumn(isHome ? homePoints : columnPoints, isHome ? homeIdx : columnIdx, base, isHome ? COLUMN_HEIGHT * 2 : COLUMN_HEIGHT);
			}
		}

		addMesh(floorPoints, floorIdx, FLOOR_COLOR);
		addMesh(columnPoints, columnIdx, COLUMN_COLOR);
		addMesh(homePoints, homeIdx, HOME_COLOR);
	}

	/** One column: four side quads plus a cap, from precomputed hyperbolic base corners. **/
	function addColumn(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, base:Array<ModelPoint>, height:Float):Void {
		var low = [for (p in base) HyperbolicProjection.toWorld(walker.toCameraFrame(p), 0)];
		var high = [for (p in base) HyperbolicProjection.toWorld(walker.toCameraFrame(p), height)];

		for (k in 0...4) {
			var next = (k + 1) % 4;
			MeshBuilder.addQuad(points, idx, low[k], low[next], high[next], high[k]);
		}
		MeshBuilder.addQuad(points, idx, high[0], high[1], high[2], high[3]);
	}

	function addMesh(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, color:Int):Void {
		if (points.length == 0) {
			return; // Polygon rejects an empty vertex list, and a fully-culled bucket legitimately produces one
		}
		var mesh = new h3d.scene.Mesh(new h3d.prim.Polygon(points, idx), world);
		mesh.material.mainPass.addShader(new h3d.shader.FixedColor(color));
		mesh.material.mainPass.culling = None;
	}

	/**
		The camera never moves. In hyperbolic rendering the world is
		transformed around a camera pinned at the origin — which is why
		`HyperbolicWalker` tracks the *view* isometry, and why turning is a
		property of the world here rather than of the camera. Only pitch is
		an actual camera rotation, because height is the Euclidean factor of
		H²×ℝ and behaves normally.
	**/
	function placeCamera():Void {
		var eye = new h3d.Vector(0, EYE_HEIGHT, 0);
		s3d.camera.pos.load(eye);
		s3d.camera.up.set(0, 1, 0);
		s3d.camera.target.load(new h3d.Vector(eye.x + Math.cos(pitch), eye.y + Math.sin(pitch), eye.z));
	}

	function updateReadout():Void {
		var lines = [
			"WASD (ZQSD) / arrows move, mouse looks, R resets",
			"",
			"distance from home: " + hxd.Math.fmt(walker.distanceFromOrigin()),
			"fps: " + hxd.Math.fmt(hxd.Timer.fps()),
		];
		readout.text = lines.join("\n");
	}
}
