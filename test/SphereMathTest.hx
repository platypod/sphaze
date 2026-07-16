import utest.Test;
import utest.Assert;
import game.SphereMath;

/**
	Mirrors old/src/scene/sphereMath.test.ts case for case, for behavioral
	parity with the ported prototype.
**/
class SphereMathTest extends Test {
	function testUpVectorPointsFromSurfaceTowardCenter():Void {
		var center = new h3d.Vector(0, 0, 0);
		var pointOnSphere = new h3d.Vector(10, 0, 0);

		var up = SphereMath.upVectorAt(pointOnSphere, center);

		Assert.floatEquals(-1, up.x);
		Assert.floatEquals(0, up.y);
		Assert.floatEquals(0, up.z);
	}

	function testUpVectorIsUnitLengthRegardlessOfRadius():Void {
		var center = new h3d.Vector(0, 0, 0);
		var pointOnSphere = new h3d.Vector(0, 0, 250);

		var up = SphereMath.upVectorAt(pointOnSphere, center);

		Assert.floatEquals(1, up.length());
	}

	function testRotateAroundAxis90DegreesAroundZ():Void {
		var rotated = SphereMath.rotateAroundAxis(new h3d.Vector(1, 0, 0), new h3d.Vector(0, 0, 1), Math.PI / 2);

		Assert.floatEquals(0, rotated.x, 1e-9);
		Assert.floatEquals(1, rotated.y, 1e-9);
		Assert.floatEquals(0, rotated.z, 1e-9);
	}

	function testRotateAroundAxisZeroAngleLeavesVectorUnchanged():Void {
		var original = new h3d.Vector(3, -2, 5);

		var rotated = SphereMath.rotateAroundAxis(original, new h3d.Vector(0, 1, 0), 0);

		Assert.floatEquals(original.x, rotated.x);
		Assert.floatEquals(original.y, rotated.y);
		Assert.floatEquals(original.z, rotated.z);
	}

	function testRotateAroundAxisPreservesLength():Void {
		var original = new h3d.Vector(2, 3, -1);

		var rotated = SphereMath.rotateAroundAxis(original, new h3d.Vector(0, 1, 0), 1.234);

		Assert.floatEquals(original.length(), rotated.length(), 1e-9);
	}

	function testSphericalToCartesianNorthPole():Void {
		var point = SphereMath.sphericalToCartesian(10, 0, 2.7);

		Assert.floatEquals(0, point.x, 1e-9);
		Assert.floatEquals(10, point.y, 1e-9);
		Assert.floatEquals(0, point.z, 1e-9);
	}

	function testSphericalToCartesianSouthPole():Void {
		var point = SphereMath.sphericalToCartesian(10, Math.PI, 1.1);

		Assert.floatEquals(0, point.x, 1e-9);
		Assert.floatEquals(-10, point.y, 1e-9);
		Assert.floatEquals(0, point.z, 1e-9);
	}

	function testSphericalToCartesianEquator():Void {
		var point = SphereMath.sphericalToCartesian(10, Math.PI / 2, 0);

		Assert.floatEquals(10, point.x, 1e-9);
		Assert.floatEquals(0, point.y, 1e-9);
		Assert.floatEquals(0, point.z, 1e-9);
	}

	function testTangentsAreUnitAndMutuallyPerpendicular():Void {
		var theta = 1.0;
		var phi = 2.3;
		var radial = SphereMath.sphericalToCartesian(1, theta, phi);
		var thetaTangent = SphereMath.thetaTangentAt(theta, phi);
		var phiTangent = SphereMath.phiTangentAt(phi);

		Assert.floatEquals(1, thetaTangent.length(), 1e-9);
		Assert.floatEquals(1, phiTangent.length(), 1e-9);
		Assert.floatEquals(0, thetaTangent.dot(phiTangent), 1e-9);
		Assert.floatEquals(0, thetaTangent.dot(radial), 1e-9);
		Assert.floatEquals(0, phiTangent.dot(radial), 1e-9);
	}

	function testThetaOfAndPhiOfInvertSphericalToCartesian():Void {
		var theta = 1.1;
		var phi = 4.2;
		var point = SphereMath.sphericalToCartesian(50, theta, phi);

		Assert.floatEquals(theta, SphereMath.thetaOf(point), 1e-9);
		Assert.floatEquals(phi, SphereMath.phiOf(point), 1e-9);
	}

	function testThetaOfIgnoresDistanceFromOrigin():Void {
		var point = new h3d.Vector(3, 4, 0); // not on any particular sphere

		Assert.floatEquals(Math.acos(4 / 5), SphereMath.thetaOf(point), 1e-9);
	}

	function testPhiOfNormalizesNegativeAtan2ToPositiveRange():Void {
		var point = new h3d.Vector(0, 1, -10); // atan2(-10, 0) = -pi/2

		Assert.floatEquals(1.5 * Math.PI, SphereMath.phiOf(point), 1e-9);
	}
}
