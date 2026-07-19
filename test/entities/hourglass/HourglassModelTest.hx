package entities.hourglass;

import utest.Test;
import utest.Assert;
import entities.hourglass.Hourglass.TriggerSide;

/** Covers HourglassModel's own pure tilt/sand/time-scale state — see docs/GUIDELINES.md §1.4/§5.4 for why this is unit-tested while Hourglass's own mesh-building isn't. **/
class HourglassModelTest extends Test {
	static inline final MID_TIME_SCALE:Float = (HourglassModel.MIN_TIME_SCALE + HourglassModel.MAX_TIME_SCALE) / 2;

	static inline final DT:Float = 0.1;

	/**
		One trigger, then a `None` tick to clear the edge — the shape every
		real trigger takes per `HourglassModel.tick`'s own doc (arrive,
		step, leave before it'll step again). Lets tests drive several
		consecutive steps without each one needing its own explicit
		"walk away first" tick.
	**/
	static function triggerOnce(model:HourglassModel, side:TriggerSide):Void {
		model.tick(DT, side);
		model.tick(DT, None);
	}

	function testStartsAtNeutralTilt():Void {
		Assert.equals(0, new HourglassModel().tiltSteps);
	}

	function testStartsWithNoSandDrained():Void {
		Assert.equals(0, new HourglassModel().sandPhase);
	}

	function testTimeScaleAtRestIsTheMidpointOfItsRange():Void {
		Assert.floatEquals(MID_TIME_SCALE, new HourglassModel().timeScale(), 1e-9);
	}

	function testPlusTriggerIncrementsTiltStepsByOne():Void {
		var model = new HourglassModel();
		model.tick(DT, Plus);
		Assert.equals(1, model.tiltSteps);
	}

	function testMinusTriggerDecrementsTiltStepsByOne():Void {
		var model = new HourglassModel();
		model.tick(DT, Minus);
		Assert.equals(-1, model.tiltSteps);
	}

	function testTiltAngleMatchesStepsTimesTheStepAngle():Void {
		var model = new HourglassModel();
		model.tick(DT, Plus);
		model.tick(DT, Plus); // sustained, no None between - shouldn't step again
		Assert.equals(1, model.tiltSteps);
		var expectedRadians = HourglassModel.STEP_ANGLE_DEGREES * Math.PI / 180;
		Assert.floatEquals(expectedRadians, model.tiltAngle(), 1e-9);
	}

	function testSustainedTriggerWithoutLeavingDoesNotStepAgain():Void {
		// Per the ask: "the player has to stop and walk again to trigger it
		// again" - holding position (Plus every tick, no None between)
		// should not keep incrementing.
		var model = new HourglassModel();
		for (i in 0...20) {
			model.tick(DT, Plus);
		}
		Assert.equals(1, model.tiltSteps);
	}

	function testLeavingAndRetriggeringStepsAgain():Void {
		var model = new HourglassModel();
		triggerOnce(model, Plus);
		triggerOnce(model, Plus);
		Assert.equals(2, model.tiltSteps);
	}

	function testTiltStepsClampAtMaxTiltSteps():Void {
		var model = new HourglassModel();
		for (i in 0...(HourglassModel.MAX_TILT_STEPS + 5)) {
			triggerOnce(model, Plus);
		}
		Assert.equals(HourglassModel.MAX_TILT_STEPS, model.tiltSteps);
	}

	function testTiltStepsClampAtMinusMaxTiltSteps():Void {
		var model = new HourglassModel();
		for (i in 0...(HourglassModel.MAX_TILT_STEPS + 5)) {
			triggerOnce(model, Minus);
		}
		Assert.equals(-HourglassModel.MAX_TILT_STEPS, model.tiltSteps);
	}

	function testTimeScaleIsAboveMidpointWhenTiltedTowardPlus():Void {
		var model = new HourglassModel();
		for (i in 0...HourglassModel.MAX_TILT_STEPS) {
			triggerOnce(model, Plus);
		}
		Assert.isTrue(model.timeScale() > MID_TIME_SCALE);
	}

	function testTimeScaleIsBelowMidpointWhenTiltedTowardMinus():Void {
		var model = new HourglassModel();
		for (i in 0...HourglassModel.MAX_TILT_STEPS) {
			triggerOnce(model, Minus);
		}
		Assert.isTrue(model.timeScale() < MID_TIME_SCALE);
	}

	function testSandPhaseIncreasesUnderOrdinaryTicking():Void {
		var model = new HourglassModel();
		model.tick(DT, None);
		Assert.isTrue(model.sandPhase > 0);
	}

	function testSandPhaseNeverLeavesTheZeroToOneRange():Void {
		var model = new HourglassModel();
		for (i in 0...HourglassModel.MAX_TILT_STEPS) {
			triggerOnce(model, Plus); // fastest flow, per timeScale()
		}
		for (i in 0...500) {
			// Sustained fast flow - long enough to cross a full drain (and
			// flip, per the perpetual cycle below) more than once, so this
			// also guards the flip's own boundary handling, not just the
			// plain clamp.
			model.tick(DT, None);
			Assert.isTrue(model.sandPhase >= 0 && model.sandPhase <= 1);
		}
	}

	function testSandPhaseReachingFullTogglesFlippedAndHoldsAtOne():Void {
		var model = new HourglassModel();
		var flippedOnce = false;
		for (i in 0...1000) {
			model.tick(DT, None);
			if (model.flipped) {
				flippedOnce = true;
				break;
			}
		}
		Assert.isTrue(flippedOnce);
		// The flip itself doesn't touch sandPhase - see HourglassModel.flipped's
		// own doc - so it should still read as fully drained the instant it flips.
		Assert.floatEquals(1, model.sandPhase, 1e-6);
	}

	function testSandPhaseDrainsBackDownOnceFlipped():Void {
		var model = new HourglassModel();
		for (i in 0...1000) {
			model.tick(DT, None);
			if (model.flipped) {
				break;
			}
		}
		Assert.isTrue(model.flipped);
		var phaseAtFlip = model.sandPhase;
		model.tick(DT, None);
		Assert.isTrue(model.sandPhase < phaseAtFlip);
	}

	function testAFullRoundTripReturnsToUnflippedWithSandPhaseBackAtZero():Void {
		var model = new HourglassModel();
		for (i in 0...1000) {
			model.tick(DT, None);
			if (model.flipped) {
				break;
			}
		}
		Assert.isTrue(model.flipped);
		for (i in 0...1000) {
			model.tick(DT, None);
			if (!model.flipped) {
				break;
			}
		}
		Assert.isFalse(model.flipped);
		Assert.floatEquals(0, model.sandPhase, 1e-6);
	}

	function testOverdraftCountStaysZeroWhileNotAtTheMinusFloor():Void {
		var model = new HourglassModel();
		triggerOnce(model, Minus); // -1, nowhere near the floor yet
		Assert.equals(0, model.overdraftCount);
	}

	function testOverdraftCountIncrementsOnceAtTheMinusFloor():Void {
		var model = new HourglassModel();
		for (i in 0...HourglassModel.MAX_TILT_STEPS) {
			triggerOnce(model, Minus);
		}
		Assert.equals(-HourglassModel.MAX_TILT_STEPS, model.tiltSteps);
		triggerOnce(model, Minus); // one more, already at the floor
		Assert.equals(1, model.overdraftCount);
		Assert.isFalse(model.unlocked);
	}

	function testOverdraftCountResetsOnLeavingTheFloor():Void {
		var model = new HourglassModel();
		for (i in 0...HourglassModel.MAX_TILT_STEPS) {
			triggerOnce(model, Minus);
		}
		triggerOnce(model, Minus);
		triggerOnce(model, Minus);
		Assert.isTrue(model.overdraftCount > 0);
		triggerOnce(model, Plus); // steps off the floor
		Assert.equals(0, model.overdraftCount);
	}

	function testEnoughConsecutiveOverdraftsUnlocksAndResetsTilt():Void {
		var model = new HourglassModel();
		for (i in 0...HourglassModel.MAX_TILT_STEPS) {
			triggerOnce(model, Minus);
		}
		for (i in 0...HourglassModel.OVERDRAFT_UNLOCK_COUNT) {
			triggerOnce(model, Minus);
		}
		Assert.isTrue(model.unlocked);
		Assert.equals(0, model.tiltSteps);
		Assert.equals(0, model.overdraftCount);
	}
}
