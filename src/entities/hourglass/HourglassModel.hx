package entities.hourglass;

import entities.hourglass.Hourglass.TriggerSide;

/**
	The hub's own tiltable hourglass — pure state/logic, no scene/rendering
	dependency (see `docs/GUIDELINES.md` §1.4/§5.4 for why this is unit-tested
	while `Hourglass`'s own mesh-building isn't): current tilt (in discrete
	steps, see below), how much sand has drained from the top bulb to the
	bottom, and the game-speed multiplier that tilt currently produces
	(`timeScale`, read every tick by `biomes.hub.HubBiome.timeScale`, then
	combined across every registered biome by
	`entities.registries.BiomesRegistry.globalTimeScale` and applied in
	`game.GameLoop.fixedUpdate`).

	This is `docs/game-design.md`'s own backlogged "Hourglass game-speed
	control (hub)" prototype, implemented per direct ask rather than left
	parked. **Triggering a tilt change is still scoped to physically
	standing in the hub** (see `Hourglass.triggerSide`) — nowhere else has
	the sign geometry to walk up to — but the game-speed *effect* that tilt
	produces is global, per a later direct ask ("the speed [e]ffect should
	be global"): once set, it keeps applying everywhere, hub or not, until
	changed again from back inside the hub.

	**Tilt is stepped, not continuous, and player-triggered rather than
	proximity-driven.** The original version read a continuous left/right
	lean from wherever the player happened to be standing; per a later
	direct ask, replaced with `tiltSteps` — an integer from `-MAX_TILT_STEPS`
	to `MAX_TILT_STEPS`, each step `STEP_ANGLE_DEGREES` — that only ever
	changes by exactly one step at a time, and only when `tick`'s own
	`triggerSide` argument *newly* reads `Plus`/`Minus` (see `tick`'s own
	doc for the edge-detection this needs — "walk up to a sign, as close as
	collision permits, to trigger one step; stop and walk in again for
	another"). No smooth interpolation toward the new angle yet either —
	`tiltAngle` snaps straight to `tiltSteps * STEP_ANGLE_DEGREES` the
	instant a step lands; per the same ask, animating that transition (and
	a future spin) is deliberately left for a later pass.

	**Hidden mechanic: pushing past the minus floor, repeatedly, unlocks
	something.** Once `tiltSteps` is already at `-MAX_TILT_STEPS`, further
	`Minus` triggers can't decrement it any further — but they still count,
	via `overdraftCount`. `OVERDRAFT_UNLOCK_COUNT` consecutive over-the-floor
	attempts (a `Plus` trigger, or successfully decrementing off the floor,
	clears the count — it only tracks a *consecutive* run of "still stuck at
	the floor, still trying") snap `tiltSteps` back to `0` and set `unlocked`
	permanently — represented today by `Hourglass.buildSand` swapping the
	sand's own color to gold, per the ask ("represent it by changing the
	colour of the sand to... say, golden"); nothing else in the game reacts
	to `unlocked` yet. This is the same idea `docs/game-design.md`'s own
	"Reverse-time mechanic, hung off the hub hourglass" backlog entry named
	for the hourglass's own earlier `reversing` safety valve (now removed,
	replaced entirely by this) — still unproven what `unlocked` should
	actually *do*, same as that entry always said, just a different trigger
	shape now.

	**Unlike a real hourglass, this one never just sits empty** — per a
	still-earlier direct ask ("when the top is empty, make it turn 180° and
	flow again"), `tick` pings `sandPhase` back and forth between `0` and
	`1` forever on its own, toggling `flipped` at each end, entirely
	independent of `tiltSteps`/the trigger mechanic above. A real hourglass
	needs a hand to turn it back over; this one doesn't wait for the player
	to be standing there at the exact moment it runs out, so it reads as
	always-running ambient scenery rather than something that can be caught
	stopped.
**/
class HourglassModel {
	/** How many steps either direction from neutral — `9 * STEP_ANGLE_DEGREES = 45`, the ask's own stated max. **/
	public static inline final MAX_TILT_STEPS:Int = 9;

	/** Degrees per step — `5`, not the original `10`: reported directly as wanting finer, `5°` steps, alongside the max coming down from `80°` to `45°`. **/
	public static inline final STEP_ANGLE_DEGREES:Float = 5;

	static final STEP_ANGLE_RADIANS:Float = STEP_ANGLE_DEGREES * Math.PI / 180;

	/** Game-speed multiplier at full left tilt — "on the left, it will slow the game," per the ask. **/
	public static inline final MIN_TIME_SCALE:Float = 0.35;

	/** Game-speed multiplier at full right tilt — "on the right, it will accelerate it," per the ask. **/
	public static inline final MAX_TIME_SCALE:Float = 1.8;

	/**
		Fraction of the hourglass drained (or, reversed, refilled) per second
		at `timeScale() == 1` — `0.04`, not the original `0.12`: reported
		directly as flowing too fast for a hub landmark meant to be glanced
		at rather than watched, slowed to roughly a third.
	**/
	static inline final FLOW_RATE:Float = 0.04;

	/** How many consecutive triggers against an already-maxed-out minus side unlock the hidden mechanic — "say 10 for now," per the ask; a first-pass placeholder, not tuned against anything. **/
	public static inline final OVERDRAFT_UNLOCK_COUNT:Int = 10;

	/** Current tilt, in steps of `STEP_ANGLE_DEGREES` — positive tilts toward the `Plus` sign (speeds the game up), negative toward `Minus` (slows it down). See `tiltAngle` for the actual angle this produces. **/
	public var tiltSteps:Int = 0;

	/** 0 = all sand in the top bulb, 1 = fully drained to the bottom. **/
	public var sandPhase:Float = 0;

	/** True after an odd number of full drains — the hourglass currently sits rotated 180° from its rest orientation (see class doc). Read by `Hourglass.tiltedBasis` to add the matching visual rotation; doesn't change how `sandPhase` itself is drawn (`Hourglass.buildSand` never looks at this), only which way the tilted frame it's drawn in currently points. **/
	public var flipped:Bool = false;

	/** How many consecutive `Minus` triggers have landed while `tiltSteps` was already at `-MAX_TILT_STEPS` — the hidden mechanic's own progress counter (see class doc). Reset to `0` the moment `tiltSteps` isn't pinned at the floor anymore, whether from a successful decrement or a `Plus` trigger. **/
	public var overdraftCount:Int = 0;

	/** True once `overdraftCount` has ever reached `OVERDRAFT_UNLOCK_COUNT` — permanent, never cleared again (see class doc). Read by `Hourglass.buildSand` to swap the sand's own color to gold. **/
	public var unlocked:Bool = false;

	/** The trigger side seen last tick — the edge-detection state `tick` needs so a sustained `Plus`/`Minus` (player still standing right at the sign) doesn't keep stepping every tick; see that method's own doc. **/
	var lastTriggerSide:TriggerSide = None;

	public function new() {}

	/**
		Advances the perpetual flip/sand cycle by one fixed step (always, on
		every call), then processes at most one tilt step from `triggerSide`
		— but only if it's `Plus`/`Minus` *and* different from whatever
		`triggerSide` read last tick. That edge-detection is what makes
		"getting there and walking once tilts one step; the player has to
		stop and walk again to trigger it again" (per the ask) actually
		true: `Hourglass.triggerSide` itself is a plain, stateless position
		query — read `Plus` every single tick the player stands there,
		unless something remembers whether it already fired. This method is
		that something. A player has to back off far enough for
		`Hourglass.triggerSide` to read `None` again before walking back in
		can trigger a second step.
		@param dt fixed timestep duration, in seconds — real time, not scaled by `timeScale()`, same reasoning as the sand's own flow rate below.
		@param triggerSide which sign (if any) `Hourglass.triggerSide` currently reads the player as standing in front of.
	**/
	public function tick(dt:Float, triggerSide:TriggerSide):Void {
		var flowSign = flipped ? -1 : 1;
		sandPhase = hxd.Math.clamp(sandPhase + flowSign * FLOW_RATE * timeScale() * dt, 0, 1);
		if ((flowSign > 0 && sandPhase >= 1) || (flowSign < 0 && sandPhase <= 0)) {
			flipped = !flipped;
		}

		var isNewTrigger = triggerSide != None && triggerSide != lastTriggerSide;
		lastTriggerSide = triggerSide;
		if (!isNewTrigger) {
			return;
		}

		if (triggerSide == Plus) {
			if (tiltSteps < MAX_TILT_STEPS) {
				tiltSteps++;
			}
			overdraftCount = 0;
		} else if (tiltSteps > -MAX_TILT_STEPS) {
			tiltSteps--;
			overdraftCount = 0;
		} else {
			overdraftCount++;
			if (overdraftCount >= OVERDRAFT_UNLOCK_COUNT) {
				tiltSteps = 0;
				unlocked = true;
				overdraftCount = 0;
			}
		}
	}

	/**
		The actual tilt angle `tiltSteps` currently produces, radians — a
		plain multiplication, no smoothing (see class doc for why not yet).
		@return the current tilt angle.
	**/
	public function tiltAngle():Float {
		return tiltSteps * STEP_ANGLE_RADIANS;
	}

	/**
		The game-speed multiplier this tilt currently produces — 1 at rest,
		below 1 tilted toward `Minus`, above 1 tilted toward `Plus`.
		@return the current multiplier.
	**/
	public function timeScale():Float {
		var maxAngle = MAX_TILT_STEPS * STEP_ANGLE_RADIANS;
		var t = (tiltAngle() + maxAngle) / (2 * maxAngle);
		return MIN_TIME_SCALE + t * (MAX_TIME_SCALE - MIN_TIME_SCALE);
	}
}
