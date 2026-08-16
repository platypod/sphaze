package tools.become;

import tools.become.BecomeModel.BodyKind;
import utest.Assert;
import utest.Test;

/**
	Pins down the *rules* of the `BECOME` bodies, which is as far as tests
	can go here — whether those rules are **fun** is Risk 8's actual
	question and only a person with the harness open can answer it.

	What these do guarantee is that if the glider feels wrong, it is
	because committed-direction movement feels wrong, and not because the
	model quietly let it stop, or turned it mid-beat, or dropped an input.
**/
class BecomeModelTest extends Test {
	static inline final EPSILON:Float = 1e-9;

	/** **The glider's defining property.** A glider that can be stopped is not a glider — it advances with no input at all. **/
	function testTheGliderMovesWithoutAnyInput():Void {
		var model = settledAs(Glider);
		var before = distanceTravelled(model);

		model.update(0.1, 0, 0);

		Assert.isTrue(distanceTravelled(model) > before, "a glider should advance with no input");
	}

	/** And cannot be halted by pushing back, either — there is no input term in its motion at all. **/
	function testTheGliderCannotBeHaltedByInput():Void {
		var model = settledAs(Glider);

		model.update(0.1, -1, 0);

		Assert.floatEquals(BecomeModel.GLIDER_SPEED * 0.1, distanceTravelled(model), EPSILON, "reverse input should not slow a glider");
	}

	/** **Direction changes are held to the beat.** The turn is buffered, not dropped — input is delayed, never ignored. **/
	function testTheGliderTurnsOnlyOnTheBeat():Void {
		var model = settledAs(Glider);
		var heading = model.heading;

		model.queueTurn(1);
		model.update(BecomeModel.BEAT_PERIOD * 0.5, 0, 0);
		Assert.floatEquals(heading, model.heading, EPSILON, "the turn should not have applied mid-beat");

		model.update(BecomeModel.BEAT_PERIOD * 0.6, 0, 0);
		Assert.floatEquals(heading + BecomeModel.TURN_STEP, model.heading, EPSILON, "the turn should land on the beat");
	}

	/** An oscillator is motionless between beats and hops on them — persistence without continuity. **/
	function testTheOscillatorMovesOnlyOnTheBeat():Void {
		var model = settledAs(Oscillator);

		model.update(BecomeModel.BEAT_PERIOD * 0.9, 1, 0);
		Assert.floatEquals(0, distanceTravelled(model), EPSILON, "an oscillator should not drift between beats");

		model.update(BecomeModel.BEAT_PERIOD * 0.2, 0, 0);
		Assert.floatEquals(BecomeModel.HOP_DISTANCE, distanceTravelled(model), EPSILON, "an oscillator should hop on the beat");
	}

	/** A still life cannot translate under any input, on or off the beat. **/
	function testAStillLifeNeverMoves():Void {
		var model = settledAs(StillLife);

		for (_ in 0...20) {
			model.update(0.1, 1, 1);
		}

		Assert.floatEquals(0, distanceTravelled(model), EPSILON, "a still life should never translate");
	}

	/** A still life can still look around — perception is not movement. **/
	function testAStillLifeCanStillLook():Void {
		var model = settledAs(StillLife);
		model.steer(0.4);

		Assert.floatEquals(0.4, model.heading, EPSILON, "a still life should still be able to look around");
	}

	/** The walker is the control: free steering, immediate response, beat ignored entirely. **/
	function testTheWalkerSteersFreelyAndIgnoresTheBeat():Void {
		var model = settledAs(Walker);
		model.steer(0.3);
		Assert.floatEquals(0.3, model.heading, EPSILON, "the walker should steer immediately");

		model.update(0.1, 1, 0);
		Assert.floatEquals(BecomeModel.WALK_SPEED * 0.1, distanceTravelled(model), EPSILON, "the walker should move on input");
	}

	/** Stopping requires *becoming something else* — the design's actual claim, checked end to end. **/
	function testStoppingAGliderMeansChangingBody():Void {
		var model = settledAs(Glider);
		model.requestBody(StillLife);

		// the switch costs a beat, during which nothing moves
		model.update(BecomeModel.BEAT_PERIOD * 0.5, 0, 0);
		var duringSwitch = distanceTravelled(model);
		model.update(BecomeModel.BEAT_PERIOD * 0.6, 0, 0);

		Assert.equals(BodyKind.StillLife, model.body, "the body should have changed on the beat");
		Assert.floatEquals(duringSwitch, distanceTravelled(model), EPSILON, "nothing should move while switching");
	}

	/** Switching is not instant — the cost `systems.md` asks for, modelled rather than skipped. **/
	function testSwitchingCostsABeat():Void {
		var model = settledAs(Walker);
		model.requestBody(Glider);

		Assert.isTrue(model.switching, "requesting a body should begin a switch");
		model.update(BecomeModel.BEAT_PERIOD * 0.4, 0, 0);
		Assert.equals(BodyKind.Walker, model.body, "the body should not change mid-beat");

		model.update(BecomeModel.BEAT_PERIOD * 0.7, 0, 0);
		Assert.equals(BodyKind.Glider, model.body, "the body should change on the beat");
	}

	/** A whole beat elapsing in one long frame must not skip its own boundary work — the update loop drains beats rather than dropping them. **/
	function testALongFrameStillResolvesItsBeats():Void {
		var model = settledAs(Walker);
		model.requestBody(Glider);

		model.update(BecomeModel.BEAT_PERIOD * 3.5, 0, 0);

		Assert.equals(BodyKind.Glider, model.body, "a long frame should still land the switch");
		Assert.isTrue(model.beatCount >= 3, 'a long frame should count its beats, got ${model.beatCount}');
	}

	/**
		**Pins the render handedness**, which nothing else did — the reason
		turning, strafing and mouse-look all came out mirrored and every test
		still passed.

		Heaps' camera is left-handed, so screen-right is `-(forward × up)`.
		This asserts that the direction the model strafes toward (heading +
		90°) really *is* that vector, rather than its negation. Derived
		independently here rather than restating `dirX`/`dirZ`, so it can
		actually fail.
	**/
	function testStrafingGoesToScreenRight():Void {
		for (h in [0.0, 0.7, 2.5, -1.3]) {
			var fx = BecomeModel.dirX(h);
			var fz = BecomeModel.dirZ(h);
			// forward x up, with up = (0,1,0), is (-fz, 0, fx); Heaps' screen right is its negation
			var rightX = fz;
			var rightZ = -fx;

			Assert.floatEquals(rightX, BecomeModel.dirX(h + Math.PI / 2), EPSILON, 'strafe X should be screen-right at heading $h');
			Assert.floatEquals(rightZ, BecomeModel.dirZ(h + Math.PI / 2), EPSILON, 'strafe Z should be screen-right at heading $h');
		}
	}

	/** Settles a model into `kind`, past the switch beat, so a test can start from the body it means to check. **/
	function settledAs(kind:BodyKind):BecomeModel {
		var model = new BecomeModel();
		model.requestBody(kind);
		model.update(BecomeModel.BEAT_PERIOD * 1.01, 0, 0);
		// zero the odometer by rebuilding travel measurement from here
		startX = model.x;
		startZ = model.z;
		return model;
	}

	var startX:Float = 0;
	var startZ:Float = 0;

	function distanceTravelled(model:BecomeModel):Float {
		var dx = model.x - startX;
		var dz = model.z - startZ;
		return Math.sqrt(dx * dx + dz * dz);
	}
}
