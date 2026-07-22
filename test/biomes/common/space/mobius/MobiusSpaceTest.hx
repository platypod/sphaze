package biomes.common.space.mobius;

import utest.Test;
import utest.Assert;

/** Covers MobiusSpace's own Space contract — see MobiusMathTest for the pure geometry this builds on. **/
class MobiusSpaceTest extends Test {
	static inline final RADIUS:Float = 40;

	function testUpAtIsUnitAndPerpendicularToTheLocalTangentPlane():Void {
		var space = new MobiusSpace(3, RADIUS);
		var pos = MobiusMath.pointAt(1.2, 2.0, 3, RADIUS);

		var up = space.upAt(pos);

		Assert.floatEquals(1, up.length(), 1e-9);
	}

	function testMoveAlongCoversApproximatelyTheRequestedArcDistance():Void {
		var space = new MobiusSpace(3, RADIUS);
		var pos = MobiusMath.pointAt(0, 0, 3, RADIUS);
		var frame = MobiusMath.localFrameAt(0, 0, 3, RADIUS);

		var result = space.moveAlong(pos, frame.tu, frame.tu, 2, RADIUS);

		Assert.floatEquals(2, result.pos.sub(pos).length(), 0.05);
	}

	function testMoveAlongKeepsForwardUnitAndTangent():Void {
		var space = new MobiusSpace(3, RADIUS);
		var pos = MobiusMath.pointAt(0.5, 1.0, 3, RADIUS);
		var frame = MobiusMath.localFrameAt(0.5, 1.0, 3, RADIUS);

		var result = space.moveAlong(pos, frame.tu, frame.tv, 1.5, RADIUS);

		Assert.floatEquals(1, result.forward.length(), 1e-6);
		var newParams = MobiusMath.paramsAt(result.pos, 3, RADIUS);
		var newFrame = MobiusMath.localFrameAt(newParams.u, newParams.v, 3, RADIUS);
		Assert.floatEquals(0, result.forward.dot(newFrame.normal), 1e-6);
	}

	function testMoveAlongIsContinuousAcrossTheLoopSeam():Void {
		var space = new MobiusSpace(3, RADIUS);
		var beforeU = 2 * Math.PI - 0.05;
		var pos = MobiusMath.pointAt(beforeU, 0, 3, RADIUS);
		var frame = MobiusMath.localFrameAt(beforeU, 0, 3, RADIUS);

		// Small step forward, straddling the u=0/2*PI wrap.
		var result = space.moveAlong(pos, frame.tu, frame.tu, 1, RADIUS);

		// The same step, computed by simply continuing u unbounded (never
		// wrapping) - should land on exactly the same world point, since
		// MobiusMath.pointAt is smooth and well-defined for any real u.
		var expected = MobiusMath.pointAt(beforeU + 1 / frame.tuLength, 0, 3, RADIUS);

		Assert.floatEquals(expected.x, result.pos.x, 1e-3);
		Assert.floatEquals(expected.y, result.pos.y, 1e-3);
		Assert.floatEquals(expected.z, result.pos.z, 1e-3);
	}

	function testMoveAlongFlipsVSignExactlyOnceForAnOddTwistWrap():Void {
		var space = new MobiusSpace(3, RADIUS);
		var beforeU = 2 * Math.PI - 0.02;
		var pos = MobiusMath.pointAt(beforeU, 2.0, 3, RADIUS);
		var frame = MobiusMath.localFrameAt(beforeU, 2.0, 3, RADIUS);

		var result = space.moveAlong(pos, frame.tu, frame.tu, 1, RADIUS);
		var newParams = MobiusMath.paramsAt(result.pos, 3, RADIUS);

		Assert.floatEquals(-2.0, newParams.v, 0.05);
	}

	function testMoveAlongPreservesForwardHandednessAcrossTheLoopSeam():Void {
		var space = new MobiusSpace(3, RADIUS);
		var beforeU = 2 * Math.PI - 0.02;
		var startV = 10.0;
		var pos = MobiusMath.pointAt(beforeU, startV, 3, RADIUS);
		var frame = MobiusMath.localFrameAt(beforeU, startV, 3, RADIUS);
		var yaw = 0.35;
		var forward = frame.tu.scaled(Math.cos(yaw)).add(frame.tv.scaled(Math.sin(yaw))).normalized();

		var result = space.moveAlong(pos, forward, frame.tu, 1, RADIUS);
		var expectedU = beforeU + 1 / frame.tuLength;
		var expectedFrame = MobiusMath.localFrameAt(expectedU, startV, 3, RADIUS);
		var expectedForward = expectedFrame.tu.scaled(Math.cos(yaw)).add(expectedFrame.tv.scaled(Math.sin(yaw))).normalized();

		Assert.isTrue(result.forward.dot(expectedForward) > 0.999999);
	}
}
