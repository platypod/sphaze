package biomes.common.space.hyperbolic;

import utest.Assert;
import utest.Test;

/**
	Checks that `HyperbolicSpace` satisfies the `Space` contract *and* is
	genuinely hyperbolic — the second being the part that matters, since a
	subtly-wrong implementation would still move the player around
	plausibly and only reveal itself as a world whose geometry does not
	close the way it should.

	Cross-checked against `geometry.CurvedSpace` wherever possible: that
	package is independently tested against closed-form identities, so
	agreement between two implementations written on different days is
	worth more than either alone.
**/
class HyperbolicSpaceTest extends Test {
	static inline final EPSILON:Float = 1e-9;
	static inline final RADIUS:Float = 40.0;

	function origin():h3d.Vector {
		return new h3d.Vector(0, 0, RADIUS);
	}

	function eastward():h3d.Vector {
		return new h3d.Vector(1, 0, 0);
	}

	/** A point that starts on the hyperboloid stays on it, however far it walks — the invariant every other result depends on. **/
	function testMovingKeepsThePointOnTheHyperboloid():Void {
		var space = new HyperbolicSpace(RADIUS);
		var pos = origin();
		var forward = eastward();

		for (_ in 0...40) {
			var moved = space.moveAlong(pos, forward, forward, 3.0, RADIUS);
			pos = moved.pos;
			forward = moved.forward;

			var unit = pos.scaled(1 / RADIUS);
			Assert.floatEquals(-1, HyperbolicSpace.inner(unit, unit), 1e-6, "position drifted off the hyperboloid");
		}
	}

	/** Walking out and back returns exactly. **/
	function testOutAndBackReturns():Void {
		var space = new HyperbolicSpace(RADIUS);
		var there = space.moveAlong(origin(), eastward(), eastward(), 25.0, RADIUS);
		var back = space.moveAlong(there.pos, there.forward, there.forward.scaled(-1), 25.0, RADIUS);

		Assert.floatEquals(0, space.distance(origin(), back.pos), 1e-6, "out and back should return to the start");
	}

	/** The distance travelled is the distance asked for — the metric and the motion agree. **/
	function testDistanceMatchesTheDistanceWalked():Void {
		var space = new HyperbolicSpace(RADIUS);

		for (d in [1.0, 10.0, 55.0]) {
			var moved = space.moveAlong(origin(), eastward(), eastward(), d, RADIUS);
			Assert.floatEquals(d, space.distance(origin(), moved.pos), 1e-6, 'walked $d but measured otherwise');
		}
	}

	/** `forward` stays a unit tangent — Minkowski-orthogonal to position, Minkowski-unit length — after arbitrarily many steps. **/
	function testForwardStaysAUnitTangent():Void {
		var space = new HyperbolicSpace(RADIUS);
		var pos = origin();
		var forward = eastward();

		for (i in 0...30) {
			var moved = space.moveAlong(pos, forward, forward, 2.0, RADIUS);
			pos = moved.pos;
			forward = moved.forward;

			var unit = pos.scaled(1 / RADIUS);
			Assert.floatEquals(1, HyperbolicSpace.inner(forward, forward), 1e-6, 'forward stopped being unit at step $i');
			Assert.floatEquals(0, HyperbolicSpace.inner(unit, forward), 1e-6, 'forward stopped being tangent at step $i');
		}
	}

	/**
		**Agrees with `geometry.CurvedSpace`**, which is independently tested
		against the hyperbolic law of cosines. Two implementations written
		days apart landing on the same number is much stronger evidence than
		either passing its own tests.
	**/
	function testAgreesWithTheIndependentlyTestedCurvedSpace():Void {
		var space = new HyperbolicSpace(1.0);
		var moved = space.moveAlong(new h3d.Vector(0, 0, 1), eastward(), eastward(), 1.3, 1.0);

		var reference = geometry.Isometry.positionOf(geometry.Isometry.translation(Hyperbolic, 1.3));

		Assert.floatEquals(reference.x, moved.pos.x, 1e-9, "x disagrees with CurvedSpace");
		Assert.floatEquals(reference.y, moved.pos.y, 1e-9, "y disagrees with CurvedSpace");
		Assert.floatEquals(reference.z, moved.pos.z, 1e-9, "z disagrees with CurvedSpace");
	}

	/**
		**The world does not close.** Four equal sides and four right-angle
		turns bring you back to the start in flat space and demonstrably do
		not here — the same holonomy `geometry.CurvedSpaceTest` proves, checked
		again through the `Space` interface so a bug in *this* implementation
		cannot hide behind correct primitives elsewhere.
	**/
	function testASquareDoesNotClose():Void {
		var space = new HyperbolicSpace(RADIUS);
		var pos = origin();
		var forward = eastward();

		for (_ in 0...4) {
			var moved = space.moveAlong(pos, forward, forward, 30.0, RADIUS);
			pos = moved.pos;
			// turn 90 degrees: rotate forward within the tangent plane at pos
			forward = turnInPlace(pos, moved.forward, Math.PI / 2);
		}

		Assert.isTrue(space.distance(origin(), pos) > 1.0, "a square should not close in hyperbolic space");
	}

	/** Height is not in these coordinates at all, so "up" is the render-space constant — see the class doc on product geometries. **/
	function testUpIsTheRenderSpaceConstant():Void {
		var space = new HyperbolicSpace(RADIUS);
		var up = space.upAt(new h3d.Vector(3, 4, Math.sqrt(1 + 9 + 16) * RADIUS));

		Assert.floatEquals(0, up.x, EPSILON);
		Assert.floatEquals(1, up.y, EPSILON);
		Assert.floatEquals(0, up.z, EPSILON);
	}

	/** Rotates a tangent within the tangent plane at `pos`, for building test paths that turn. **/
	function turnInPlace(pos:h3d.Vector, forward:h3d.Vector, angle:Float):h3d.Vector {
		var unit = pos.scaled(1 / RADIUS);
		// a second tangent, Minkowski-orthogonal to both unit and forward
		var side = new h3d.Vector(unit.y * forward.z - unit.z * forward.y, unit.z * forward.x - unit.x * forward.z, -(unit.x * forward.y - unit.y * forward.x));
		var norm = Math.sqrt(HyperbolicSpace.inner(side, side));
		side = side.scaled(1 / norm);
		return forward.scaled(Math.cos(angle)).add(side.scaled(Math.sin(angle)));
	}
}
