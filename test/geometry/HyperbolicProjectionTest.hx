package geometry;

import geometry.Curvature.CurvatureMath;
import utest.Assert;
import utest.Test;

/**
	Covers the projection and the walker — the two pieces of Phase 0 that
	*can* be verified without a renderer.

	This matters more than usual. Phase 0's real question ("is walking in
	hyperbolic space pleasant or nauseating?") is a playtest question, and
	per `CLAUDE.md` this environment cannot answer it. What these tests can
	do is guarantee that if the answer comes back "nauseating", it is
	because hyperbolic space *is* nauseating — not because the maths under
	it was wrong. Every property below is a closed-form fact about the
	Beltrami-Klein projection, not a plausibility check.
**/
class HyperbolicProjectionTest extends Test {
	static inline final EPSILON:Float = 1e-9;

	/** The camera sees itself at the centre of its own view. **/
	function testTheCameraProjectsToTheOrigin():Void {
		var k = HyperbolicProjection.klein(CurvedSpace.origin());

		Assert.floatEquals(0, k.u, EPSILON, "camera should project to u = 0");
		Assert.floatEquals(0, k.v, EPSILON, "camera should project to v = 0");
	}

	/**
		**Klein radius is exactly `tanh(distance)`** — the compression law
		that puts the whole infinite plane inside a unit disk, and the reason
		the Sprawl's "see near, not far" falls out of correct rendering
		rather than having to be authored.
	**/
	function testKleinRadiusIsTanhOfDistance():Void {
		for (d in [0.25, 1.0, 2.5, 5.0]) {
			var p = Isometry.positionOf(Isometry.translation(Hyperbolic, d));
			var k = HyperbolicProjection.klein(p);
			var radius = Math.sqrt(k.u * k.u + k.v * k.v);

			var tanh = CurvatureMath.hyperbolicSin(d) / CurvatureMath.hyperbolicCos(d);
			Assert.floatEquals(tanh, radius, EPSILON, 'at distance $d the Klein radius should be tanh(d) = $tanh');
		}
	}

	/** However far away a point is, it never reaches the horizon — the projection has no singularity to render through. **/
	function testEverythingStaysStrictlyInsideTheUnitDisk():Void {
		for (d in [0.1, 3.0, 12.0, 40.0]) {
			var p = Isometry.positionOf(Isometry.translation(Hyperbolic, d));
			var k = HyperbolicProjection.klein(p);
			var radius = Math.sqrt(k.u * k.u + k.v * k.v);

			Assert.isTrue(radius < 1, 'distance $d projected to radius $radius, which is not inside the disk');
		}
	}

	/**
		**Bearing is preserved exactly.** This is the property that makes the
		result read as a first-person view at all: angles measured at the
		viewer are correct, even though distances are compressed.
	**/
	function testBearingIsPreservedExactly():Void {
		for (bearing in [0.3, 1.2, 2.9, -1.7]) {
			var p = Isometry.positionOf(Isometry.compose(Isometry.rotation(bearing), Isometry.translation(Hyperbolic, 1.5)));
			var k = HyperbolicProjection.klein(p);

			Assert.floatEquals(bearing, Math.atan2(k.v, k.u), EPSILON, 'bearing $bearing was not preserved');
		}
	}

	/** Depth ordering survives compression — `tanh` is monotonic, so the z-buffer still sorts correctly by real distance. **/
	function testFartherPointsProjectFarther():Void {
		var previous = -1.0;
		for (d in [0.5, 1.0, 2.0, 4.0, 8.0]) {
			var p = Isometry.positionOf(Isometry.translation(Hyperbolic, d));
			var k = HyperbolicProjection.klein(p);
			var radius = Math.sqrt(k.u * k.u + k.v * k.v);

			Assert.isTrue(radius > previous, 'distance $d should project farther than the previous step');
			previous = radius;
		}
	}

	/** Height passes through untouched — the surface is a product geometry H²×ℝ and the height factor is Euclidean. **/
	function testHeightIsUntouchedByTheProjection():Void {
		var p = Isometry.positionOf(Isometry.translation(Hyperbolic, 2.0));

		Assert.floatEquals(7.5, HyperbolicProjection.toWorld(p, 7.5).y, EPSILON, "height should pass straight through");
	}

	/** `distanceFromCamera` inverts the projection's own input — a round-trip check on the metric. **/
	function testDistanceFromCameraRecoversTheDistanceWalked():Void {
		for (d in [0.4, 1.6, 3.3]) {
			var p = Isometry.positionOf(Isometry.translation(Hyperbolic, d));

			Assert.floatEquals(d, HyperbolicProjection.distanceFromCamera(p), EPSILON, 'walked $d but measured otherwise');
		}
	}
}
