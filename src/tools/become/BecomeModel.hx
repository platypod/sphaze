package tools.become;

/**
	Which cellular-automaton body the player is currently wearing — the
	`BECOME` moveset from `docs/game-design/direction/systems.md`, reduced
	to the three that have a distinct *feel* plus a plain walker to compare
	against.

	`Spaceship` and `Gun` are deliberately absent: the first is a glider
	with different numbers, the second is about acting at a distance rather
	than about locomotion, and neither would tell us anything the three
	below don't.
**/
enum BodyKind {
	/** Not a cellular-automaton body at all — ordinary first-person movement, present only as the control to judge the others against. **/
	Walker;

	/** Translates continuously and **cannot stop**; may only change direction on a beat. The one genuinely novel control scheme in the design, and the whole reason this spike exists. **/
	Glider;

	/** Moves only *on* the beat, in discrete hops, and is motionless between them. Persistence without continuity. **/
	Oscillator;

	/** Cannot translate at all. Can still look around — perception is not movement. **/
	StillLife;
}

/**
	The `BECOME` locomotion model, headless and pure — **Risk 8's spike**
	(`docs/game-design/direction/roadmap.md`).

	That risk exists because `systems.md` calls `BECOME` "the core system,
	and the one that makes this a game rather than a walking simulator",
	asserts that a glider's committed-direction movement is "a genuinely
	distinctive movement mode… closer to a chess knight or a
	momentum-puzzle than to a shooter" — and **nobody has ever played it**.
	It might equally be infuriating. This class is the smallest thing that
	can answer that, on flat ground, deliberately away from any curvature
	so the two open questions cannot confound each other.

	**Flat and 2D on purpose.** Position is a plain `(x, z)` pair with a
	heading, not a `CurvedSpace` frame. Curvature is a solved and separately
	validated question; mixing it in here would only make a bad answer
	ambiguous.

	**The beat is the spine.** A global clock ticks every `BEAT_PERIOD`
	seconds and every body reads it differently: the glider may only turn on
	it, the oscillator may only move on it, the walker ignores it entirely.
	Switching bodies also costs a beat — taken straight from `systems.md`
	("switching takes one generation") and included precisely because it is
	the part most likely to feel bad, which is worth finding out now rather
	than in year two.
**/
class BecomeModel {
	/** Seconds per beat. The single most important feel constant here — too fast and the glider is twitchy, too slow and it is unresponsive. **/
	public static inline final BEAT_PERIOD:Float = 0.7;

	/** Walker speed, world units per second. **/
	public static inline final WALK_SPEED:Float = 4.0;

	/** Glider speed. Slower than walking on purpose: the glider's advantage is meant to be commitment and reach, never raw pace. **/
	public static inline final GLIDER_SPEED:Float = 3.2;

	/** How far one oscillator hop covers — roughly a cell, so a hop reads as moving one square rather than teleporting. **/
	public static inline final HOP_DISTANCE:Float = 2.4;

	/** How far a glider or oscillator turns per queued step. 60° matches the hex ground, so headings stay aligned to the tiling the player can see. Not `inline`: `Math.PI` is not a compile-time constant, same as `GeodesicMesh.HEX_FACE_PERIOD`. **/
	public static final TURN_STEP:Float = Math.PI / 3;

	public var body(default, null):BodyKind = Walker;
	public var x(default, null):Float = 0;
	public var z(default, null):Float = 0;

	/** Radians; `0` faces `+x`. **/
	public var heading(default, null):Float = 0;

	/** How far through the current beat, `0` to `1` — what the harness pulses the world on so the player can anticipate the boundary rather than being surprised by it. **/
	public var beatPhase(default, null):Float = 0;

	public var beatCount(default, null):Int = 0;

	/** True while a body switch is still waiting for the next beat to land. Movement is suspended throughout — see this class's own doc for why that cost is modelled rather than skipped. **/
	public var switching(default, null):Bool = false;

	var pendingBody:BodyKind = Walker;

	/** Turn steps queued during the current beat, applied when it ends. Buffered rather than dropped, so input never feels ignored — only *delayed*, which is the intended sensation. **/
	var queuedTurn:Int = 0;

	public function new() {}

	/**
		Requests a body change. It does not take effect until the next beat —
		the deliberate cost from `systems.md`.
		@param kind the body to become.
	**/
	public function requestBody(kind:BodyKind):Void {
		if (kind == body && !switching) {
			return;
		}
		pendingBody = kind;
		switching = true;
	}

	/**
		Queues a turn. For the walker this applies immediately; for the
		glider and oscillator it is held until the beat lands.
		@param steps how many `TURN_STEP` increments, signed.
	**/
	public function queueTurn(steps:Int):Void {
		if (body == Walker) {
			heading += steps * TURN_STEP;
			return;
		}
		queuedTurn += steps;
	}

	/**
		Free-look steering, walker only — the others steer in discrete steps
		on the beat, which is the point of them.
		@param delta radians to turn by.
	**/
	public function steer(delta:Float):Void {
		if (body == Walker || body == StillLife) {
			heading += delta;
		}
	}

	/**
		Advances one frame.
		@param dt seconds elapsed.
		@param forward walker input, `-1` to `1`; ignored by every other body, since a glider's motion is not something the player chooses moment to moment.
		@param strafe walker input, `-1` to `1`.
	**/
	public function update(dt:Float, forward:Float, strafe:Float):Void {
		beatPhase += dt / BEAT_PERIOD;
		while (beatPhase >= 1) {
			beatPhase -= 1;
			beatCount++;
			onBeat();
		}

		if (switching) {
			return; // mid-change: no body's rules apply yet
		}

		switch body {
			case Walker:
				moveBy(Math.cos(heading) * forward + Math.cos(heading + Math.PI / 2) * strafe,
					Math.sin(heading) * forward + Math.sin(heading + Math.PI / 2) * strafe, WALK_SPEED * dt);
			case Glider:
				// no input term at all: a glider that can be stopped is not a glider
				moveBy(Math.cos(heading), Math.sin(heading), GLIDER_SPEED * dt);
			case Oscillator | StillLife:
				// motionless between beats; the oscillator's own movement happens in onBeat
		}
	}

	/** Everything that only happens on the beat: the pending body lands, queued turns apply, an oscillator hops. **/
	function onBeat():Void {
		if (switching) {
			body = pendingBody;
			switching = false;
			queuedTurn = 0;
			return; // the beat that completes a switch is spent doing only that
		}

		if (queuedTurn != 0) {
			heading += queuedTurn * TURN_STEP;
			queuedTurn = 0;
		}
		if (body == Oscillator) {
			moveBy(Math.cos(heading), Math.sin(heading), HOP_DISTANCE);
		}
	}

	function moveBy(dirX:Float, dirZ:Float, distance:Float):Void {
		x += dirX * distance;
		z += dirZ * distance;
	}
}
