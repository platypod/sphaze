package biomes.hub;

/**
	The hub's own tiltable hourglass — pure state/logic, no scene/rendering
	dependency (see `docs/GUIDELINES.md` §1.4/§5.4 for why this is unit-tested
	while `Hourglass`'s own mesh-building isn't): current tilt, how much sand
	has drained from the top bulb to the bottom, and the game-speed
	multiplier that tilt currently produces (`timeScale`, read every tick by
	`HubBiome.timeScale` and applied in `game.GameLoop.fixedUpdate`).

	This is `docs/game-design.md`'s own backlogged "Hourglass game-speed
	control (hub)" prototype, implemented per direct ask rather than left
	parked — still exactly as unproven as that entry says: the effect is
	scoped to "standing near the hourglass, in the hub" only (see
	`Hourglass.lean`), not "current/next biome" or anything global beyond
	that, simply because that's the smallest thing that matches the ask, not
	a considered design call between the two.

	**The reverse-and-reset (`reversing`) is a self-correcting safety valve,
	not a real mechanic yet.** Tilt it far enough left (slow enough) for long
	enough and the hourglass forces its own tilt back to neutral while its
	sand visibly drains backward (`sandPhase` decreasing) — per the ask,
	"if the player slows time enough, reverse the animation and get back to
	normal speed." Nothing else in the game reacts to this today. The intent
	(per the same ask) is for a fully-reversed hourglass to eventually read
	as "time is flowing backward" and hang a real mechanic off that
	elsewhere — tracked as a follow-up in `docs/game-design.md`'s backlog,
	deliberately not built here.
**/
class HourglassModel {
	/** Maximum tilt either direction, radians (~20 degrees) — enough to read clearly without looking like it's about to topple off its pedestal. **/
	public static inline final MAX_TILT:Float = 0.35;

	/** How fast `tiltAngle` approaches its target lean, radians/second — fast enough to feel responsive to someone walking past, not instant. **/
	static inline final TILT_APPROACH_RATE:Float = 1.2;

	/** Game-speed multiplier at full left tilt — "on the left, it will slow the game," per the ask. **/
	public static inline final MIN_TIME_SCALE:Float = 0.35;

	/** Game-speed multiplier at full right tilt — "on the right, it will accelerate it," per the ask. **/
	public static inline final MAX_TIME_SCALE:Float = 1.8;

	/**
		How close to `MIN_TIME_SCALE` counts as "slowed enough" to trigger
		`reversing` — a little above the true minimum, so a player has to
		hold a strong left tilt rather than just graze it.
	**/
	static inline final REVERSE_TRIGGER_SCALE:Float = MIN_TIME_SCALE + 0.05;

	/** Fraction of the hourglass drained (or, reversed, refilled) per second at `timeScale() == 1`. **/
	static inline final FLOW_RATE:Float = 0.12;

	/** How fast `tiltAngle` is forced back to neutral while `reversing` — slower than `TILT_APPROACH_RATE`, so the snap-back reads as its own deliberate beat rather than a twitch. **/
	static inline final RESET_RATE:Float = 0.5;

	/** Current tilt, radians — positive tilts right, negative tilts left (see `Hourglass.lean`'s own doc for what "right" means against the hourglass's fixed anchor). **/
	public var tiltAngle:Float = 0;

	/** 0 = all sand in the top bulb, 1 = fully drained to the bottom. **/
	public var sandPhase:Float = 0;

	/** True while the hourglass is forcing itself back to neutral after being tilted too far left for too long (see class doc). **/
	public var reversing:Bool = false;

	public function new() {}

	/**
		Advances tilt, sand, and the reverse-and-reset state by one fixed
		step. Driven by real elapsed time (`dt`), not by `timeScale()` — the
		multiplier this same tick produces: letting the effect it causes also
		govern its own rate would be a feedback loop (the hourglass slowing
		itself down as it slows the game), not "walk up to it, tilt it."
		@param dt fixed timestep duration, in seconds — real time, not scaled.
		@param lean how far left (-1) or right (+1) of the hourglass the player currently stands, 0 dead-center or out of range — see `Hourglass.lean`.
	**/
	public function tick(dt:Float, lean:Float):Void {
		if (reversing) {
			tiltAngle = approach(tiltAngle, 0, RESET_RATE * dt);
			sandPhase = hxd.Math.clamp(sandPhase - FLOW_RATE * dt, 0, 1);
			if (Math.abs(tiltAngle) < 1e-3) {
				tiltAngle = 0;
				reversing = false;
			}
			return;
		}

		var target = -hxd.Math.clamp(lean, -1, 1) * MAX_TILT;
		tiltAngle = approach(tiltAngle, target, TILT_APPROACH_RATE * dt);
		sandPhase = hxd.Math.clamp(sandPhase + FLOW_RATE * timeScale() * dt, 0, 1);

		if (timeScale() <= REVERSE_TRIGGER_SCALE) {
			reversing = true;
		}
	}

	/**
		The game-speed multiplier this tilt currently produces — 1 at rest,
		below 1 tilted left, above 1 tilted right.
		@return the current multiplier.
	**/
	public function timeScale():Float {
		var t = (tiltAngle + MAX_TILT) / (2 * MAX_TILT);
		return MIN_TIME_SCALE + t * (MAX_TIME_SCALE - MIN_TIME_SCALE);
	}

	/** Moves `current` toward `target` by at most `maxDelta`, never overshooting it. **/
	static function approach(current:Float, target:Float, maxDelta:Float):Float {
		var delta = target - current;
		if (Math.abs(delta) <= maxDelta) {
			return target;
		}
		return current + maxDelta * (delta > 0 ? 1 : -1);
	}
}
