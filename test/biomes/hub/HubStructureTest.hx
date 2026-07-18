package biomes.hub;

import utest.Test;
import utest.Assert;
import biomes.common.space.sphere.SphereMath;

/** Covers HubStructure's own local tangent-plane math — see MazeShrineTest/TowerReplicaTest for what each structure builds on top of it. **/
class HubStructureTest extends Test {
	static inline final RADIUS:Float = 70;

	static inline final THETA:Float = 1.2;

	static inline final PHI:Float = 0.7;

	function testAnchorAtOriginMatchesSphericalToCartesian():Void {
		var basis = HubStructure.anchorAt(THETA, PHI, RADIUS);
		var expected = SphereMath.sphericalToCartesian(RADIUS, THETA, PHI);
		Assert.floatEquals(expected.x, basis.origin.x, 1e-9);
		Assert.floatEquals(expected.y, basis.origin.y, 1e-9);
		Assert.floatEquals(expected.z, basis.origin.z, 1e-9);
	}

	function testWorldPointAtZeroOffsetIsTheOriginItself():Void {
		var basis = HubStructure.anchorAt(THETA, PHI, RADIUS);
		var p = HubStructure.worldPoint(basis, 0, 0, 0);
		Assert.floatEquals(0, p.sub(basis.origin).length(), 1e-9);
	}

	function testWorldPointRaisedByHeightMovesAlongUp():Void {
		var basis = HubStructure.anchorAt(THETA, PHI, RADIUS);
		var p = HubStructure.worldPoint(basis, 0, 0, 5);
		var expected = basis.origin.add(basis.up.scaled(5));
		Assert.floatEquals(0, p.sub(expected).length(), 1e-9);
	}

	function testLocalUVIsTheInverseOfWorldPoint():Void {
		var basis = HubStructure.anchorAt(THETA, PHI, RADIUS);
		var p = HubStructure.worldPoint(basis, 3, -2, 0);
		var uv = HubStructure.localUV(basis, p);
		Assert.floatEquals(3, uv.u, 1e-9);
		Assert.floatEquals(-2, uv.v, 1e-9);
	}

	function testLocalUVIgnoresHeightSinceUpIsPerpendicularToTheTangentPlane():Void {
		var basis = HubStructure.anchorAt(THETA, PHI, RADIUS);
		var p = HubStructure.worldPoint(basis, 3, -2, 8);
		var uv = HubStructure.localUV(basis, p);
		Assert.floatEquals(3, uv.u, 1e-9);
		Assert.floatEquals(-2, uv.v, 1e-9);
	}

	function testDistanceToSegmentIsZeroAtItsOwnMidpoint():Void {
		var d = HubStructure.distanceToSegment(5, 0, 0, 0, 10, 0);
		Assert.floatEquals(0, d, 1e-9);
	}

	function testDistanceToSegmentIsThePerpendicularDistanceOffASideOfIt():Void {
		var d = HubStructure.distanceToSegment(3, 5, 0, 0, 0, 10);
		Assert.floatEquals(3, d, 1e-9);
	}

	function testDistanceToSegmentClampsToTheNearestEndpointPastEitherEnd():Void {
		var d = HubStructure.distanceToSegment(0, 15, 0, 0, 0, 10);
		Assert.floatEquals(5, d, 1e-9);
	}
}
