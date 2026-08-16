package tools.become;

import game.MeshBuilder;
import tools.become.BecomeModel.BodyKind;

/**
	**Risk 8's harness: three cellular-automaton bodies on flat ground.**

	`docs/game-design/direction/roadmap.md` rates `BECOME` an *existential*
	risk and puts it in Phase 0 alongside the hyperbolic-walking question,
	for one reason: `systems.md` calls it "the core system, and the one that
	makes this a game rather than a walking simulator", six of the nine
	spaces are designed around it, and **no part of it has ever been
	played**. The glider's committed-direction movement is asserted to be
	"genuinely distinctive"; it might equally be infuriating.

	**Flat ground, deliberately.** Curvature is a separate question that has
	now been answered on its own (see `tools.hyperbolic.HyperbolicWalkApp`).
	Testing both at once would make a bad answer ambiguous — "was that the
	glider, or the hyperbolic space?" — so this is an ordinary Euclidean hex
	field with nothing exotic in it at all.

	**What to feel for**, in rough order of what would sink the design:

	1. **The glider.** You cannot stop. Steering is queued and lands on the
	   beat. Is that a *decision* (chess knight, momentum puzzle) or is it
	   laggy controls wearing a costume? This is the question.
	2. **The switch cost.** Changing body takes a beat, during which nothing
	   moves. `systems.md` asks for it; it is also the most likely thing to
	   feel bad, so it is modelled rather than quietly skipped.
	3. **The oscillator.** Hopping only on the beat — rhythm, or stutter?
	4. **Contrast.** Switch to the walker and back. The others only earn
	   their place if being them feels *different* rather than worse.

	Tuning knobs, if something is close but wrong: `BecomeModel.BEAT_PERIOD`
	(the big one), `GLIDER_SPEED`, `TURN_STEP`, `HOP_DISTANCE`.

	Standalone on the same precedent as the hyperbolic harness — no `Biome`,
	no `GameLoop`, nothing the real game depends on.

	**Not verified in this environment.** Compiled and lint-clean, and the
	rules underneath are tested (`tools.become.BecomeModelTest`), but per
	`CLAUDE.md` input does not reach the canvas here so the *feel* — the
	entire point — is unplayed.
**/
class BecomeApp extends hxd.App {
	static inline final FIELD_RADIUS:Int = 14;
	static inline final CELL_SIZE:Float = 1.4;
	static inline final EYE_HEIGHT:Float = 1.7;
	static inline final MOUSE_SENSITIVITY:Float = 0.003;
	static inline final MAX_PITCH:Float = 1.2;
	static inline final COLUMN_EVERY:Int = 5;
	static inline final COLUMN_HEIGHT:Float = 3.2;
	static inline final COLUMN_RADIUS:Float = 0.22;

	/** How far the beat pulse lifts the floor — small, since this is a metronome the player should feel rather than watch. **/
	static inline final PULSE_LIFT:Float = 0.18;

	static inline final FLOOR_COLOR:Int = 0x1B2A38;
	static inline final COLUMN_COLOR:Int = 0x2E5C7A;
	static inline final BACKGROUND_COLOR:Int = 0x080C12;

	var model:BecomeModel;
	var world:h3d.scene.Object;
	var readout:h2d.Text;
	var pitch:Float = 0;

	/** Hex centres in world space, built once — the ground never changes, only the camera over it. **/
	var cells:Array<{x:Float, z:Float, column:Bool}>;

	static function main():Void {
		new BecomeApp();
	}

	override function init():Void {
		hxd.Res.initEmbed();
		engine.backgroundColor = BACKGROUND_COLOR;
		s3d.camera.fovY = 75;
		s3d.camera.zNear = 0.05;
		s3d.camera.zFar = 200;

		model = new BecomeModel();
		buildField();
		world = new h3d.scene.Object(s3d);
		buildGeometry();

		readout = new h2d.Text(hxd.res.DefaultFont.get(), s2d);
		readout.x = 12;
		readout.y = 12;
		readout.textColor = 0xFFD166;

		var window = hxd.Window.getInstance();
		window.mouseMode = Relative(onMouseMove, true);
		window.onMouseModeChange = (from, to) -> to == Absolute ? Relative(onMouseMove, true) : null;
	}

	/** A flat-top hex field in axial coordinates — ordinary Euclidean geometry, no curvature machinery involved. **/
	function buildField():Void {
		cells = [];
		for (q in -FIELD_RADIUS...FIELD_RADIUS + 1) {
			for (r in -FIELD_RADIUS...FIELD_RADIUS + 1) {
				if (Math.abs(q + r) > FIELD_RADIUS) {
					continue; // keeps the field a hexagon rather than a rhombus
				}
				var x = CELL_SIZE * 1.5 * q;
				var z = CELL_SIZE * Math.sqrt(3) * (r + q / 2.0);
				cells.push({x: x, z: z, column: (q * 31 + r * 17) % COLUMN_EVERY == 0 && !(q == 0 && r == 0)});
			}
		}
	}

	/**
		The field is static, so it is built once and simply looked at from a
		moving camera — the opposite of the hyperbolic harness, where the
		world has to be re-projected every frame. Flat space costs nothing,
		which is part of why it is the right place to isolate this question.
	**/
	function buildGeometry():Void {
		var floorPoints:Array<h3d.Vector> = [];
		var floorIdx = new hxd.IndexBuffer();
		var columnPoints:Array<h3d.Vector> = [];
		var columnIdx = new hxd.IndexBuffer();

		for (cell in cells) {
			var corners = [
				for (k in 0...6) {
					var a = k * Math.PI / 3;
					new h3d.Vector(cell.x + Math.cos(a) * CELL_SIZE * 0.92, 0, cell.z + Math.sin(a) * CELL_SIZE * 0.92);
				}
			];
			var hub = new h3d.Vector(cell.x, 0, cell.z);
			for (k in 0...6) {
				MeshBuilder.addTriangle(floorPoints, floorIdx, hub, corners[k], corners[(k + 1) % 6]);
			}

			if (cell.column) {
				addColumn(columnPoints, columnIdx, cell.x, cell.z);
			}
		}

		addMesh(floorPoints, floorIdx, FLOOR_COLOR);
		addMesh(columnPoints, columnIdx, COLUMN_COLOR);
	}

	function addColumn(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, cx:Float, cz:Float):Void {
		var low = [
			for (k in 0...4) {
				var a = k * Math.PI / 2;
				new h3d.Vector(cx + Math.cos(a) * COLUMN_RADIUS, 0, cz + Math.sin(a) * COLUMN_RADIUS);
			}
		];
		var high = [for (p in low) new h3d.Vector(p.x, COLUMN_HEIGHT, p.z)];
		for (k in 0...4) {
			var next = (k + 1) % 4;
			MeshBuilder.addQuad(points, idx, low[k], low[next], high[next], high[k]);
		}
		MeshBuilder.addQuad(points, idx, high[0], high[1], high[2], high[3]);
	}

	function addMesh(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, color:Int):Void {
		if (points.length == 0) {
			return;
		}
		var mesh = new h3d.scene.Mesh(new h3d.prim.Polygon(points, idx), world);
		mesh.material.mainPass.addShader(new h3d.shader.FixedColor(color));
		mesh.material.mainPass.culling = None;
	}

	override function update(dt:Float):Void {
		handleInput();
		var forward = (hxd.Key.isDown(hxd.Key.W) ? 1.0 : 0.0) - (hxd.Key.isDown(hxd.Key.S) ? 1.0 : 0.0);
		var strafe = (hxd.Key.isDown(hxd.Key.D) ? 1.0 : 0.0) - (hxd.Key.isDown(hxd.Key.A) ? 1.0 : 0.0);
		model.update(dt, forward, strafe);
		placeCamera();
		pulseWorld();
		updateReadout();
	}

	function handleInput():Void {
		if (hxd.Key.isPressed(hxd.Key.NUMBER_1)) {
			model.requestBody(Walker);
		}
		if (hxd.Key.isPressed(hxd.Key.NUMBER_2)) {
			model.requestBody(Glider);
		}
		if (hxd.Key.isPressed(hxd.Key.NUMBER_3)) {
			model.requestBody(Oscillator);
		}
		if (hxd.Key.isPressed(hxd.Key.NUMBER_4)) {
			model.requestBody(StillLife);
		}
		// Discrete steering for the bodies that turn on the beat; tapped,
		// not held, so a queued turn is an explicit decision.
		if (hxd.Key.isPressed(hxd.Key.LEFT)) {
			model.queueTurn(-1);
		}
		if (hxd.Key.isPressed(hxd.Key.RIGHT)) {
			model.queueTurn(1);
		}
	}

	function onMouseMove(e:hxd.Event):Void {
		model.steer(e.relX * MOUSE_SENSITIVITY);
		pitch -= e.relY * MOUSE_SENSITIVITY;
		pitch = pitch > MAX_PITCH ? MAX_PITCH : (pitch < -MAX_PITCH ? -MAX_PITCH : pitch);
	}

	function placeCamera():Void {
		var eye = new h3d.Vector(model.x, EYE_HEIGHT, model.z);
		s3d.camera.pos.load(eye);
		s3d.camera.up.set(0, 1, 0);
		s3d.camera.target.load(new h3d.Vector(eye.x
			+ Math.cos(model.heading) * Math.cos(pitch), eye.y
			+ Math.sin(pitch),
			eye.z
			+ Math.sin(model.heading) * Math.cos(pitch)));
	}

	/**
		Lifts the whole field slightly as each beat approaches and drops it
		when the beat lands — so the boundary is something the player can
		*anticipate* rather than be surprised by, which is the difference
		between committed movement reading as rhythm and reading as lag.
	**/
	function pulseWorld():Void {
		world.y = PULSE_LIFT * model.beatPhase * model.beatPhase;
	}

	function updateReadout():Void {
		var name = switch model.body {
			case Walker: "1 WALKER — free movement (the control)";
			case Glider: "2 GLIDER — cannot stop; turns land on the beat";
			case Oscillator: "3 OSCILLATOR — hops on the beat only";
			case StillLife: "4 STILL LIFE — rooted; can still look";
		};
		var lines = ["1/2/3/4 change body   left/right queue a turn   WASD walker only   mouse looks",
			"",
			model.switching ? ">>> SWITCHING (costs one beat) <<<" : name,
			"",
			"beat "
			+ model.beatCount
			+ "   phase "
			+ hxd.Math.fmt(model.beatPhase),
			"fps " + hxd.Math.fmt(hxd.Timer.fps()),
		];
		readout.text = lines.join("\n");
	}
}
