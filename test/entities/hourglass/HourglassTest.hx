package entities.hourglass;

import utest.Test;
import utest.Assert;
import biomes.common.space.sphere.SphereMath;
import biomes.hub.HubStructure;
import entities.hourglass.Hourglass.TriggerSide;

/** Covers Hourglass's own pure collision/trigger queries — not `build`/`buildDynamic`'s own scene/rendering side (see docs/GUIDELINES.md §1.4/§5.4). **/
class HourglassTest extends Test {
	static inline final RADIUS:Float = 70;

	static final THETA:Float = Math.PI / 2;

	static final PHI:Float = 0.3;

	static final BASIS = HubStructure.anchorAt(THETA, PHI, RADIUS);

	/** A point at local `(u, v) = (distance * cos(angle), distance * sin(angle))`, ground level — matches `triggerSide`'s own angle convention (`0` = `Plus`'s own bearing, `Math.PI` = `Minus`'s). **/
	static function pointAt(distance:Float, angle:Float):h3d.Vector {
		return HubStructure.worldPoint(BASIS, distance * Math.cos(angle), distance * Math.sin(angle), 0);
	}

	function testBlocksMovementRightAtTheAnchorItself():Void {
		// The pedestal is solid all the way through, so its own local origin
		// - dead center - is well inside its collision boundary.
		Assert.isTrue(Hourglass.blocksMovement(BASIS, BASIS.origin));
	}

	function testBlocksMovementIsFalseWellClearOfThePedestal():Void {
		var farPoint = HubStructure.worldPoint(BASIS, 1000, 1000, 0);
		Assert.isFalse(Hourglass.blocksMovement(BASIS, farPoint));
	}

	function testBlocksMovementIsFalseAtTheAntipodalPointOnTheRealSphere():Void {
		// Regression test: the point diametrically opposite the anchor
		// projects to local (u, v) = (0, 0) unless height is also checked -
		// see HubStructure.localUV's own class doc.
		var antipode = SphereMath.sphericalToCartesian(RADIUS, Math.PI - THETA, PHI + Math.PI);
		Assert.isFalse(Hourglass.blocksMovement(BASIS, antipode));
	}

	function testTriggerSideIsNoneAtTheAntipodalPointOnTheRealSphere():Void {
		var antipode = SphereMath.sphericalToCartesian(RADIUS, Math.PI - THETA, PHI + Math.PI);
		Assert.equals(None, Hourglass.triggerSide(BASIS, antipode));
	}

	function testTriggerSideIsPlusCloseInAndLinedUpWithTheEastSign():Void {
		Assert.equals(Plus, Hourglass.triggerSide(BASIS, pointAt(4, 0)));
	}

	function testTriggerSideIsMinusCloseInAndLinedUpWithTheWestSign():Void {
		Assert.equals(Minus, Hourglass.triggerSide(BASIS, pointAt(4, Math.PI)));
	}

	function testTriggerSideIsNoneWhenFarAway():Void {
		Assert.equals(None, Hourglass.triggerSide(BASIS, pointAt(1000, 0)));
	}

	function testTriggerSideIsNoneWhenCloseButOffToTheSide():Void {
		// 90 degrees off either sign's own bearing - close enough, but not
		// lined up with either one.
		Assert.equals(None, Hourglass.triggerSide(BASIS, pointAt(4, Math.PI / 2)));
	}

	function testTriggerSideIsPlusJustInsideTheAngleTolerance():Void {
		var angle = Hourglass.SIGN_ANGLE_TOLERANCE * 0.9;
		Assert.equals(Plus, Hourglass.triggerSide(BASIS, pointAt(4, angle)));
	}

	function testTriggerSideIsNoneJustOutsideTheAngleTolerance():Void {
		var angle = Hourglass.SIGN_ANGLE_TOLERANCE * 1.1;
		Assert.equals(None, Hourglass.triggerSide(BASIS, pointAt(4, angle)));
	}

	static inline final SIGN_MIDPOINT_INTENSITY:Float = (Hourglass.SIGN_MIN_INTENSITY + 1) / 2;

	function testSignIntensityIsTheMidpointForBothSignsAtNeutralTilt():Void {
		var model = new HourglassModel();
		Assert.floatEquals(SIGN_MIDPOINT_INTENSITY, Hourglass.signIntensity(model, true), 1e-9);
		Assert.floatEquals(SIGN_MIDPOINT_INTENSITY, Hourglass.signIntensity(model, false), 1e-9);
	}

	function testSignIntensityScalesProportionallyToTiltTowardEachSide():Void {
		var model = new HourglassModel();
		model.tiltSteps = 3;
		var t = 3 / HourglassModel.MAX_TILT_STEPS;
		Assert.floatEquals(hxd.Math.lerp(Hourglass.SIGN_MIN_INTENSITY, 1, (1 + t) / 2), Hourglass.signIntensity(model, true), 1e-9);
		Assert.floatEquals(hxd.Math.lerp(Hourglass.SIGN_MIN_INTENSITY, 1, (1 - t) / 2), Hourglass.signIntensity(model, false), 1e-9);
	}

	function testSignIntensityIsFullyBrightOnOneSideAndAtTheFloorOnTheOtherAtMaxTilt():Void {
		var model = new HourglassModel();
		model.tiltSteps = HourglassModel.MAX_TILT_STEPS;
		Assert.floatEquals(1, Hourglass.signIntensity(model, true), 1e-9);
		Assert.floatEquals(Hourglass.SIGN_MIN_INTENSITY, Hourglass.signIntensity(model, false), 1e-9);
	}

	function testSignIntensityIsFullyBrightTheOtherWayAtMaxTiltTowardMinus():Void {
		var model = new HourglassModel();
		model.tiltSteps = -HourglassModel.MAX_TILT_STEPS;
		Assert.floatEquals(Hourglass.SIGN_MIN_INTENSITY, Hourglass.signIntensity(model, true), 1e-9);
		Assert.floatEquals(1, Hourglass.signIntensity(model, false), 1e-9);
	}

	function testSignIntensityNeverReachesFullyInvisible():Void {
		var model = new HourglassModel();
		model.tiltSteps = -HourglassModel.MAX_TILT_STEPS;
		Assert.isTrue(Hourglass.signIntensity(model, true) > 0);
	}
}
