package biomes.common.space.mobius;

import utest.Test;
import utest.Assert;

class MobiusMathTest extends Test {
	static inline final RADIUS:Float = 40;

	function testFlipIdentityForOddTwistsMirrorsVOnceAroundTheLoop():Void {
		var twists = 3;
		var samples = [[0.3, 2.0], [1.7, -4.5], [4.9, 0.0], [6.0, 5.9]];
		for (sample in samples) {
			var u = sample[0];
			var v = sample[1];
			var wrapped = MobiusMath.pointAt(u + 2 * Math.PI, v, twists, RADIUS);
			var mirrored = MobiusMath.pointAt(u, -v, twists, RADIUS);
			Assert.floatEquals(mirrored.x, wrapped.x, 1e-9);
			Assert.floatEquals(mirrored.y, wrapped.y, 1e-9);
			Assert.floatEquals(mirrored.z, wrapped.z, 1e-9);
		}
	}

	function testEvenTwistsHaveNoFlipAfterOneLoop():Void {
		var twists = 2;
		var u = 2.2;
		var v = 3.3;
		var wrapped = MobiusMath.pointAt(u + 2 * Math.PI, v, twists, RADIUS);
		var same = MobiusMath.pointAt(u, v, twists, RADIUS);
		Assert.floatEquals(same.x, wrapped.x, 1e-9);
		Assert.floatEquals(same.y, wrapped.y, 1e-9);
		Assert.floatEquals(same.z, wrapped.z, 1e-9);
	}

	function testParamsAtRoundTripsPointAt():Void {
		var twists = 3;
		var samples = [[0.001, 0.0], [1.0, 5.9], [3.14159, -5.9], [5.5, 2.1], [6.28, 0.0]];
		for (sample in samples) {
			var u = sample[0];
			var v = sample[1];
			var pos = MobiusMath.pointAt(u, v, twists, RADIUS);
			var params = MobiusMath.paramsAt(pos, twists, RADIUS);
			Assert.floatEquals(u, params.u, 1e-6);
			Assert.floatEquals(v, params.v, 1e-6);
		}
	}

	function testLocalFrameIsOrthonormalEverywhereNotJustAtTheCenterline():Void {
		var twists = 3;
		var samples = [[0.0, 0.0], [0.7, 4.0], [2.5, -5.5], [4.4, 5.9], [5.99, -2.0]];
		for (sample in samples) {
			var frame = MobiusMath.localFrameAt(sample[0], sample[1], twists, RADIUS);
			Assert.floatEquals(1, frame.tu.length(), 1e-9);
			Assert.floatEquals(1, frame.tv.length(), 1e-9);
			Assert.floatEquals(1, frame.normal.length(), 1e-9);
			Assert.floatEquals(0, frame.tu.dot(frame.tv), 1e-9);
			Assert.floatEquals(0, frame.tu.dot(frame.normal), 1e-9);
			Assert.floatEquals(0, frame.tv.dot(frame.normal), 1e-9);
		}
	}

	function testLocalFrameAtCenterlineOriginPointsStraightUp():Void {
		var frame = MobiusMath.localFrameAt(0, 0, 3, RADIUS);

		Assert.floatEquals(0, frame.tu.x, 1e-9);
		Assert.floatEquals(0, frame.tu.y, 1e-9);
		Assert.floatEquals(1, frame.tu.z, 1e-9);
		Assert.floatEquals(0, frame.normal.x, 1e-9);
		Assert.floatEquals(1, frame.normal.y, 1e-9);
		Assert.floatEquals(0, frame.normal.z, 1e-9);
		Assert.floatEquals(RADIUS, frame.tuLength, 1e-9);
	}
}
