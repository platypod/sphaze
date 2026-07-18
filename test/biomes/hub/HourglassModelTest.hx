package biomes.hub;

import utest.Test;
import utest.Assert;

/** Covers HourglassModel's own pure tilt/sand/time-scale state — see docs/GUIDELINES.md §1.4/§5.4 for why this is unit-tested while Hourglass's own mesh-building isn't. **/
class HourglassModelTest extends Test {
	static inline final MID_TIME_SCALE:Float = (HourglassModel.MIN_TIME_SCALE + HourglassModel.MAX_TIME_SCALE) / 2;

	function testStartsAtNeutralTilt():Void {
		Assert.equals(0, new HourglassModel().tiltAngle);
	}

	function testStartsWithNoSandDrained():Void {
		Assert.equals(0, new HourglassModel().sandPhase);
	}

	function testTimeScaleAtRestIsTheMidpointOfItsRange():Void {
		Assert.floatEquals(MID_TIME_SCALE, new HourglassModel().timeScale(), 1e-9);
	}

	function testFullLeftLeanTiltsTowardPositive():Void {
		// Per the ask: approaching from the left tilts the hourglass right.
		var model = new HourglassModel();
		model.tick(0.1, -1);
		Assert.isTrue(model.tiltAngle > 0);
	}

	function testFullRightLeanTiltsTowardNegative():Void {
		var model = new HourglassModel();
		model.tick(0.1, 1);
		Assert.isTrue(model.tiltAngle < 0);
	}

	function testSustainedLeftLeanConvergesToMaxRightTilt():Void {
		var model = new HourglassModel();
		for (i in 0...200) {
			model.tick(0.05, -1);
		}
		Assert.floatEquals(HourglassModel.MAX_TILT, model.tiltAngle, 1e-3);
	}

	function testTimeScaleIsAboveMidpointWhenTiltedRight():Void {
		var model = new HourglassModel();
		for (i in 0...200) {
			model.tick(0.05, -1);
		}
		Assert.isTrue(model.timeScale() > MID_TIME_SCALE);
	}

	function testSandPhaseIncreasesUnderOrdinaryTicking():Void {
		var model = new HourglassModel();
		model.tick(0.1, 0);
		Assert.isTrue(model.sandPhase > 0);
	}

	function testSandPhaseClampsAtOneRatherThanOverflowing():Void {
		var model = new HourglassModel();
		for (i in 0...500) {
			// Sustained fast (right-tilt) draining, long past a full drain.
			model.tick(0.1, -1);
		}
		Assert.floatEquals(1, model.sandPhase, 1e-6);
	}

	function testSustainedRightLeanEventuallyTriggersReversing():Void {
		var model = new HourglassModel();
		var everReversed = false;
		for (i in 0...5000) {
			model.tick(0.02, 1);
			if (model.reversing) {
				everReversed = true;
				break;
			}
		}
		Assert.isTrue(everReversed);
	}

	function testTimeScaleIsBelowMidpointRightWhenReversingTriggers():Void {
		var model = new HourglassModel();
		for (i in 0...5000) {
			model.tick(0.02, 1);
			if (model.reversing) {
				break;
			}
		}
		Assert.isTrue(model.reversing);
		Assert.isTrue(model.timeScale() < MID_TIME_SCALE);
	}

	function testSandPhaseDecreasesWhileReversing():Void {
		var model = new HourglassModel();
		for (i in 0...5000) {
			model.tick(0.02, 1);
			if (model.reversing) {
				break;
			}
		}
		Assert.isTrue(model.reversing);
		var phaseBefore = model.sandPhase;
		model.tick(0.02, 1);
		Assert.isTrue(model.sandPhase < phaseBefore);
	}

	function testReversingEventuallyReturnsTiltToNeutralAndClearsItself():Void {
		var model = new HourglassModel();
		for (i in 0...5000) {
			model.tick(0.02, 1);
			if (model.reversing) {
				break;
			}
		}
		Assert.isTrue(model.reversing);
		for (i in 0...5000) {
			// Lean no longer matters once reversing - it ignores it entirely
			// until tiltAngle is back at neutral.
			model.tick(0.02, 1);
			if (!model.reversing) {
				break;
			}
		}
		Assert.isFalse(model.reversing);
		Assert.equals(0, model.tiltAngle);
	}
}
