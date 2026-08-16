package geometry;

import utest.Assert;
import utest.Test;

/**
	Covers `HyperbolicWalker` — specifically the left-composed, inverted
	bookkeeping that lets it track the *view* isometry without ever
	inverting a matrix. That inversion is exactly where precision would go
	(hyperbolic boost entries grow exponentially with distance), so the
	trick is worth having, and worth pinning down with tests that would
	catch it being subtly backwards.
**/
class HyperbolicWalkerTest extends Test {
	static inline final EPSILON:Float = 1e-9;

	/**
		A looser tolerance, used **only** for "did we get back to where we
		started" assertions — and it is a real numerical fact, not a fudge.

		`distanceFromOrigin` measures through `arccosh`, which is
		ill-conditioned near its own argument of `1`: for `z = 1 + ε` it
		behaves like `√(2ε)`, so ordinary double-precision noise
		(`ε ≈ 2.2e-16`) surfaces as a distance of roughly `2e-8`. Anything
		tighter than that is asserting below the noise floor and will flake.
		Distances comfortably away from zero keep the strict `EPSILON`, where
		`arccosh` is perfectly well behaved.
	**/
	static inline final ZERO_DISTANCE_EPSILON:Float = 1e-7;

	/** Walking out and back returns the view to identity — the basic sanity of the inverted composition. **/
	function testWalkingOutAndBackRestoresTheView():Void {
		var walker = new HyperbolicWalker();
		walker.moveForward(2.1);
		walker.moveForward(-2.1);

		Assert.floatEquals(0, walker.distanceFromOrigin(), ZERO_DISTANCE_EPSILON, "out and back should return to the origin");
	}

	/** Walking `d` puts the origin `d` behind you — the view really is tracking distance travelled, not something proportional to it. **/
	function testWalkingMovesTheOriginTheRightDistanceAway():Void {
		for (d in [0.3, 1.0, 3.7]) {
			var walker = new HyperbolicWalker();
			walker.moveForward(d);

			Assert.floatEquals(d, walker.distanceFromOrigin(), EPSILON, 'after walking $d the origin should be $d away');
		}
	}

	/** Turning in place moves you nowhere. Trivial, and the first thing a sign error breaks. **/
	function testTurningDoesNotMoveYou():Void {
		var walker = new HyperbolicWalker();
		walker.turn(1.1);

		Assert.floatEquals(0, walker.distanceFromOrigin(), ZERO_DISTANCE_EPSILON, "turning should not move the camera");
	}

	/** Strafing is a genuine sideways step: it covers the distance asked for, and it is reversible. **/
	function testStrafingMovesSidewaysAndIsReversible():Void {
		var walker = new HyperbolicWalker();
		walker.strafe(1.4);
		Assert.floatEquals(1.4, walker.distanceFromOrigin(), EPSILON, "strafing should cover the distance asked for");

		walker.strafe(-1.4);
		Assert.floatEquals(0, walker.distanceFromOrigin(), ZERO_DISTANCE_EPSILON, "strafing back should return to the origin");
	}

	/**
		Strafing is *perpendicular* to facing, not parallel — checked by
		bearing rather than by distance, since a walker that strafed forwards
		by mistake would pass every distance-only test above.
	**/
	function testStrafingIsPerpendicularToFacing():Void {
		var walker = new HyperbolicWalker();
		walker.strafe(1.0);

		// where the origin now sits, seen from the camera: dead abeam, not ahead
		var k = HyperbolicProjection.klein(walker.toCameraFrame(CurvedSpace.origin()));
		Assert.floatEquals(0, k.u, EPSILON, "after strafing, the origin should be abeam (u = 0), not ahead");
		Assert.isTrue(Math.abs(k.v) > 0.1, "after strafing, the origin should be off to one side");
	}

	/**
		**A square does not close** — the same holonomy `CurvedSpaceTest`
		proves on raw isometries, re-checked through the walker's own API so
		a bug in its composition order cannot hide behind correct primitives.
		This is also the first thing that will look *wrong* to a player who
		expects Euclidean space, so it is worth knowing it is real.
	**/
	function testASquareWalkDoesNotCloseForTheWalker():Void {
		var walker = new HyperbolicWalker();
		for (_ in 0...4) {
			walker.moveForward(0.9);
			walker.turn(Math.PI / 2);
		}

		Assert.isTrue(walker.distanceFromOrigin() > 1e-3, "a square should not close in hyperbolic space");
	}

	/**
		**Turning right sweeps the world left**, which is the invariant that
		was silently broken and that no existing test could catch — every
		one of them was sign-agnostic.

		Heaps' camera is left-handed and looks down `+x`, so screen-right is
		`-z`. An object dead ahead must therefore move to `+z` when the
		player turns right.
	**/
	function testTurningRightSweepsTheWorldToScreenLeft():Void {
		var walker = new HyperbolicWalker();
		var ahead = Isometry.positionOf(Isometry.translation(Hyperbolic, 1.0));

		var before = HyperbolicProjection.toWorld(walker.toCameraFrame(ahead), 0);
		Assert.floatEquals(0, before.z, EPSILON, "something dead ahead should render dead ahead");

		walker.turn(0.4);
		var after = HyperbolicProjection.toWorld(walker.toCameraFrame(ahead), 0);
		Assert.isTrue(after.z > 0, 'turning right should sweep the world to screen left, got z=${after.z}');
	}

	/** Strafing right leaves what you were standing on to your left — the same convention, checked through the other verb. **/
	function testStrafingRightLeavesTheOriginOnYourLeft():Void {
		var walker = new HyperbolicWalker();
		walker.strafe(1.0);

		var origin = HyperbolicProjection.toWorld(walker.toCameraFrame(CurvedSpace.origin()), 0);
		Assert.isTrue(origin.z > 0, 'after strafing right the origin should be on the left, got z=${origin.z}');
	}

	/** Many small steps equal one big step — what makes per-frame movement at a variable frame rate safe. **/
	function testManySmallStepsMatchOneLargeStep():Void {
		var stepped = new HyperbolicWalker();
		for (_ in 0...100) {
			stepped.moveForward(0.03);
		}
		var direct = new HyperbolicWalker();
		direct.moveForward(3.0);

		Assert.floatEquals(direct.distanceFromOrigin(), stepped.distanceFromOrigin(), 1e-9, "100 small steps should equal one 3.0 step");
	}
}
