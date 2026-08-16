package geometry;

import geometry.Curvature.CurvatureMath;
import geometry.CurvedSpace.ModelPoint;
import utest.Assert;
import utest.Test;

/**
	Verifies that `geometry` is genuinely the three constant-curvature
	geometries and not a plausible-looking approximation of them.

	These tests matter more than their size suggests. The direction proposed
	in `docs/game/` rests on a mathematical claim — that
	in non-amenable space a pattern can be uncaused *without anything being
	erased to balance it* — and the code underneath it therefore has to be
	*actually* hyperbolic, not "bendy". Every test below checks a
	closed-form identity that only holds
	in the real geometry: the three laws of cosines, the sphere's
	three-right-angle triangle, the failure of squares to close under
	curvature, and exponential circumference growth.

	All headless, no renderer, which is the property that makes the
	migration plan in `architecture.md` safe to start with.
**/
class CurvedSpaceTest extends Test {
	static inline final EPSILON:Float = 1e-9;

	static final ALL_CURVATURES:Array<Curvature> = [Spherical, Flat, Hyperbolic];

	/** Walking `d` forward then `d` back is the identity, in every geometry. **/
	function testForwardThenBackReturnsToTheOrigin():Void {
		for (k in ALL_CURVATURES) {
			var there = Isometry.translation(k, 1.3);
			var back = Isometry.translation(k, -1.3);
			var frame = Isometry.compose(there, back);
			var p = Isometry.positionOf(frame);

			assertSamePoint(CurvedSpace.origin(), p, 'round trip in $k');
		}
	}

	/** The distance you travel is the distance you asked for — the metric and the motion agree. **/
	function testTranslationMovesExactlyItsOwnDistance():Void {
		for (k in ALL_CURVATURES) {
			for (d in [0.1, 0.5, 1.0, 1.4]) {
				var p = Isometry.positionOf(Isometry.translation(k, d));
				var measured = CurvedSpace.distance(k, CurvedSpace.origin(), p);

				Assert.floatEquals(d, measured, EPSILON, 'travelled $d in $k but measured $measured');
			}
		}
	}

	/** An isometry is distance-preserving by definition; if this fails, nothing else in the package means anything. **/
	function testIsometriesPreserveDistance():Void {
		for (k in ALL_CURVATURES) {
			var a = Isometry.positionOf(Isometry.translation(k, 0.7));
			var b = Isometry.positionOf(Isometry.compose(Isometry.rotation(0.9), Isometry.translation(k, 1.1)));
			var before = CurvedSpace.distance(k, a, b);

			var move = Isometry.compose(Isometry.translation(k, 0.4), Isometry.rotation(-0.6));
			var after = CurvedSpace.distance(k, Isometry.apply(move, a), Isometry.apply(move, b));

			Assert.floatEquals(before, after, EPSILON, 'distance not preserved in $k');
		}
	}

	/**
		The three laws of cosines — the decisive correctness test.

		Build a triangle by walking `a` in one direction and `b` in a
		direction `angle` away, then measure the closing side. Each geometry
		has its own closed form, and they differ in exactly the way the
		curvature does: the spherical and hyperbolic laws are the same
		expression with one sign flipped, and the Euclidean one is their
		shared limit.
	**/
	function testLawOfCosinesHoldsInEachGeometry():Void {
		var a = 0.6;
		var b = 0.9;
		var angle = 1.1;

		for (k in ALL_CURVATURES) {
			var p = Isometry.positionOf(Isometry.translation(k, a));
			var q = Isometry.positionOf(Isometry.compose(Isometry.rotation(angle), Isometry.translation(k, b)));
			var c = CurvedSpace.distance(k, p, q);

			var expected = switch k {
				case Spherical:
					// cos c = cos a cos b + sin a sin b cos C
					Math.acos(Math.cos(a) * Math.cos(b) + Math.sin(a) * Math.sin(b) * Math.cos(angle));
				case Flat:
					// c² = a² + b² - 2ab cos C
					Math.sqrt(a * a + b * b - 2 * a * b * Math.cos(angle));
				case Hyperbolic:
					// cosh c = cosh a cosh b - sinh a sinh b cos C
					CurvatureMath.hyperbolicAcos(CurvatureMath.hyperbolicCos(a) * CurvatureMath.hyperbolicCos(b)
						- CurvatureMath.hyperbolicSin(a) * CurvatureMath.hyperbolicSin(b) * Math.cos(angle));
			};

			Assert.floatEquals(expected, c, EPSILON, 'law of cosines failed in $k');
		}
	}

	/**
		A square closes in flat space — four right-angle turns and four equal
		sides return you exactly to where and how you started. This is the
		control for the next test.
	**/
	function testASquareClosesInFlatSpace():Void {
		var frame = Isometry.identity();
		for (_ in 0...4) {
			frame = Isometry.compose(frame, Isometry.translation(Flat, 0.8));
			frame = Isometry.compose(frame, Isometry.rotation(Math.PI / 2));
		}

		assertSamePoint(CurvedSpace.origin(), Isometry.positionOf(frame), "flat square should close");
		Assert.floatEquals(0, Math.sin(Isometry.headingOf(frame)), 1e-9, "flat square should restore the original heading");
	}

	/**
		The same walk does **not** close under curvature — the holonomy that
		makes `The Defect` a biome (see
		`docs/game/world.md`). Walk a loop in a
		curved space and you come back turned, having never turned extra:
		parallel transport is path-dependent, which is what curvature *is*.
	**/
	function testASquareFailsToCloseUnderCurvature():Void {
		for (k in [Curvature.Spherical, Curvature.Hyperbolic]) {
			var frame = Isometry.identity();
			for (_ in 0...4) {
				frame = Isometry.compose(frame, Isometry.translation(k, 0.8));
				frame = Isometry.compose(frame, Isometry.rotation(Math.PI / 2));
			}

			var drift = CurvedSpace.distance(k, CurvedSpace.origin(), Isometry.positionOf(frame));
			Assert.isTrue(drift > 1e-3, 'a square should not close in $k, but it drifted only $drift');
		}
	}

	/**
		The sphere's famous triangle with three right angles: three quarter
		great-circles, three right-angle turns, and you are back where you
		started — an octant of the sphere, impossible in flat space, and a
		strong check that the spherical case is the genuine article rather
		than a small-angle approximation.
	**/
	function testThreeRightAnglesCloseATriangleOnTheSphere():Void {
		var frame = Isometry.identity();
		for (_ in 0...3) {
			frame = Isometry.compose(frame, Isometry.translation(Spherical, Math.PI / 2));
			frame = Isometry.compose(frame, Isometry.rotation(Math.PI / 2));
		}

		assertSamePoint(CurvedSpace.origin(), Isometry.positionOf(frame), "three right angles should close on a sphere");
	}

	/**
		**The test the whole direction rests on.** Circle circumference grows
		linearly in flat space, sub-linearly on a sphere (it eventually
		shrinks back to nothing at the antipode) and *exponentially* in
		hyperbolic space.

		That exponential growth is non-amenability made concrete: it is why
		the boundary of a hyperbolic region is as large as its interior, why
		nothing there can be fully accounted for, and therefore — via the
		Garden of Eden theorem — why an uncaused pattern there need not be
		paid for by an erasure, as it must be in amenable space. See
		`docs/game/README.md`.
	**/
	function testCircumferenceGrowsExponentiallyOnlyInHyperbolicSpace():Void {
		var ratioOf = (k:Curvature) -> CurvedSpace.circleCircumference(k, 2.0) / CurvedSpace.circleCircumference(k, 1.0);

		Assert.isTrue(ratioOf(Hyperbolic) > 3.0, "hyperbolic circumference should more than triple from r=1 to r=2");
		Assert.floatEquals(2.0, ratioOf(Flat), EPSILON, "flat circumference should be exactly linear");
		Assert.isTrue(ratioOf(Spherical) < 1.5, "spherical circumference should grow sub-linearly");

		// and the growth really is exponential, not merely fast: e^5 ≈ 148
		var farRatio = CurvedSpace.circleCircumference(Hyperbolic, 10.0) / CurvedSpace.circleCircumference(Hyperbolic, 5.0);
		Assert.isTrue(farRatio > 100, 'hyperbolic growth should be exponential, but r=5→10 only grew by $farRatio');
	}

	/** Normalising returns a point to its own surface, so accumulated drift can always be corrected. **/
	function testNormalizePutsAPointBackOnItsSurface():Void {
		for (k in ALL_CURVATURES) {
			var drifted = Isometry.positionOf(Isometry.translation(k, 1.2));
			drifted = {x: drifted.x * 1.0001, y: drifted.y * 1.0001, z: drifted.z * 1.0001};

			var fixed = CurvedSpace.normalize(k, drifted);
			var expected = switch k {
				case Spherical: 1.0;
				case Flat: 0.0; // the affine model's own form is degenerate; the invariant is z == 1
				case Hyperbolic: -1.0;
			};

			if (k == Flat) {
				Assert.floatEquals(1.0, fixed.z, EPSILON, "flat points live on z = 1");
			} else {
				Assert.floatEquals(expected, CurvedSpace.inner(k, fixed, fixed), 1e-9, 'normalize should restore the quadric in $k');
			}
		}
	}

	function assertSamePoint(expected:ModelPoint, actual:ModelPoint, message:String):Void {
		Assert.floatEquals(expected.x, actual.x, EPSILON, '$message (x)');
		Assert.floatEquals(expected.y, actual.y, EPSILON, '$message (y)');
		Assert.floatEquals(expected.z, actual.z, EPSILON, '$message (z)');
	}
}
