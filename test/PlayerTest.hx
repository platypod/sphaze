import utest.Test;
import utest.Assert;
import biomes.common.space.sphere.SphereMath;
import entities.Player;

/** Covers Player's pure movement/pitch math and its composition into applyToCamera. **/
class PlayerTest extends Test {
	function testTurnRotatesForwardByDeltaAngle():Void {
		var player = Player.spawnAt(1, 0, 0, 1);
		var oldForward = player.forward;

		player.turn(0.5);

		Assert.floatEquals(Math.cos(0.5), oldForward.dot(player.forward), 1e-9);
		Assert.floatEquals(1, player.forward.length(), 1e-9);
		Assert.floatEquals(0, player.pos.normalized().dot(player.forward), 1e-9);
	}

	function testRightVectorIsUnitAndPerpendicularToForwardAndUp():Void {
		var radius = 50.0;
		var player = Player.spawnAt(1.1, 2.2, 0.7, radius);

		var right = player.rightVector();

		Assert.floatEquals(1, right.length(), 1e-9);
		Assert.floatEquals(0, right.dot(player.forward), 1e-9);
		Assert.floatEquals(0, player.pos.normalized().dot(right), 1e-9);
	}

	function testMoveForwardAlongAMeridianMatchesArcLength():Void {
		// facing 0 at any point looks toward increasing theta (see
		// Player.spawnAt's doc comment), so from the equator this walks a
		// meridian — an exact great circle — where arc length is just
		// radius*angle.
		var radius = 1.0;
		var player = Player.spawnAt(Math.PI / 2, 0, 0, radius);

		player.moveForward(0.3, radius);

		var theta = Math.acos(player.pos.y / radius);
		var phi = Math.atan2(player.pos.z, player.pos.x);
		Assert.floatEquals(Math.PI / 2 + 0.3, theta, 1e-9);
		Assert.floatEquals(0, phi, 1e-9);
	}

	function testMoveBackwardDecreasesTheta():Void {
		var radius = 1.0;
		var player = Player.spawnAt(Math.PI / 2, 0, 0, radius);

		player.moveForward(-0.3, radius);

		var theta = Math.acos(player.pos.y / radius);
		Assert.floatEquals(Math.PI / 2 - 0.3, theta, 1e-9);
	}

	function testMoveForwardStaysOnTheSphereAndTangent():Void {
		var radius = 50.0;
		var player = Player.spawnAt(1.1, 2.2, 0.7, radius);

		player.moveForward(4, radius);

		Assert.floatEquals(radius, player.pos.length(), 1e-9);
		Assert.floatEquals(1, player.forward.length(), 1e-9);
		Assert.floatEquals(0, player.pos.normalized().dot(player.forward), 1e-9);
	}

	function testMoveAlongMatchesArcLength():Void {
		var radius = 50.0;
		var player = Player.spawnAt(1.1, 2.2, 0.7, radius);
		var oldPosDir = player.pos.normalized();
		var direction = SphereMath.upVectorAt(player.pos, new h3d.Vector(0, 0, 0)).cross(player.forward).normalized();

		player.moveAlong(direction, 4, radius);

		Assert.floatEquals(radius, player.pos.length(), 1e-9);
		var angle = Math.acos(hxd.Math.clamp(oldPosDir.dot(player.pos.normalized()), -1, 1));
		Assert.floatEquals(4 / radius, angle, 1e-9);
	}

	function testMoveAlongKeepsForwardTangent():Void {
		// forward isn't left untouched — it's parallel-transported by the
		// same rotation as pos, same as moveForward does for its own
		// direction. That's what keeps it a valid tangent after the move
		// (skipping this let forward drift out of the tangent plane over
		// repeated slides, breaking movement after a few ticks — see
		// Player.moveAlong's doc comment).
		var radius = 50.0;
		var player = Player.spawnAt(1.1, 2.2, 0.7, radius);
		var direction = SphereMath.upVectorAt(player.pos, new h3d.Vector(0, 0, 0)).cross(player.forward).normalized();

		player.moveAlong(direction, 4, radius);

		Assert.floatEquals(1, player.forward.length(), 1e-9);
		Assert.floatEquals(0, player.pos.normalized().dot(player.forward), 1e-9);
	}

	function testMoveAlongStaysTangentAfterManyConsecutiveSlides():Void {
		// The exact reported bug: repeated sliding (many fixed-timestep
		// ticks in a row, same shape as Collision calling moveAlong every
		// frame while a player holds into a wall at an angle) used to drift
		// forward out of the tangent plane, since nothing ever re-aligned it
		// as the tangent plane itself rotated out from under a frozen
		// forward. 50 consecutive slides is well past where that drift
		// became visible in practice.
		var radius = 50.0;
		var player = Player.spawnAt(1.1, 2.2, 0.7, radius);

		for (_ in 0...50) {
			var direction = SphereMath.upVectorAt(player.pos, new h3d.Vector(0, 0, 0)).cross(player.forward).normalized();
			player.moveAlong(direction, 2, radius);
		}

		Assert.floatEquals(1, player.forward.length(), 1e-6);
		Assert.floatEquals(0, player.pos.normalized().dot(player.forward), 1e-6);
	}

	function testMoveForwardIgnoresPitch():Void {
		// WASD-style movement stays on the ground regardless of where the
		// camera is looking — same as any FPS.
		var radius = 1.0;
		var level = Player.spawnAt(Math.PI / 2, 0, 0, radius);
		var lookingUp = Player.spawnAt(Math.PI / 2, 0, 0, radius);
		lookingUp.lookUp(1.0);

		level.moveForward(0.3, radius);
		lookingUp.moveForward(0.3, radius);

		Assert.floatEquals(level.pos.x, lookingUp.pos.x, 1e-9);
		Assert.floatEquals(level.pos.y, lookingUp.pos.y, 1e-9);
		Assert.floatEquals(level.pos.z, lookingUp.pos.z, 1e-9);
	}

	function testMoveForwardNearPoleDoesNotSpin():Void {
		// The reported bug: (theta, phi) is singular at the poles — a tiny
		// physical step near one used to correspond to a huge change in
		// phi, and since the old "facing" was measured against a tangent
		// basis derived fresh from phi every frame, that instability showed
		// up as the view spinning wildly ("mach-speed... like a spinner")
		// while walking through a pole. This representation never touches
		// theta/phi, so forward should rotate by exactly the arc angle
		// traveled, pole or not — no more, no less.
		var radius = 50.0;
		var player = Player.spawnAt(0.05, 0.7, Math.PI, radius); // facing toward the north pole
		var oldForward = player.forward;

		var distance = 3.0; // crosses right through theta=0
		player.moveForward(distance, radius);

		var angle = distance / radius;
		Assert.floatEquals(Math.cos(angle), oldForward.dot(player.forward), 1e-9);
		Assert.floatEquals(1, player.forward.length(), 1e-9);
		Assert.floatEquals(radius, player.pos.length(), 1e-9);
		Assert.floatEquals(0, player.pos.normalized().dot(player.forward), 1e-9);
	}

	function testLookUpClampsToMaxPitch():Void {
		var player = Player.spawnAt(1, 0, 0, 1);

		player.lookUp(100);

		Assert.floatEquals(Player.MAX_PITCH, player.pitch);
	}

	function testLookDownClampsToMinusMaxPitch():Void {
		var player = Player.spawnAt(1, 0, 0, 1);

		player.lookUp(-100);

		Assert.floatEquals(-Player.MAX_PITCH, player.pitch);
	}

	function testApplyToCameraAtZeroPitchLooksHorizontally():Void {
		var player = Player.spawnAt(Math.PI / 2, 0, 0, 50);
		var camera = new h3d.Camera();

		player.applyToCamera(camera, 50);

		var viewDirection = camera.target.sub(camera.pos).normalized();
		Assert.floatEquals(0, viewDirection.dot(camera.up), 1e-9);
	}

	function testApplyToCameraAtMaxPitchLooksTowardCenter():Void {
		// "Raise your head to see across to the far side": at the pitch
		// clamp, the view direction should be almost exactly toward the
		// sphere's center (SphereMath.upVectorAt) — independent of the
		// camera's own up vector, which tilts too (see the next test).
		var player = Player.spawnAt(Math.PI / 2, 0, 0, 50);
		player.lookUp(100);
		var camera = new h3d.Camera();

		player.applyToCamera(camera, 50);

		var viewDirection = camera.target.sub(camera.pos).normalized();
		var towardCenter = SphereMath.upVectorAt(camera.pos, new h3d.Vector(0, 0, 0));
		Assert.isTrue(viewDirection.dot(towardCenter) > 0.999);
	}

	function testApplyToCameraKeepsUpPerpendicularToViewAtAnyPitch():Void {
		// Regression guard: camera.up must tilt along with the view
		// direction, not stay fixed at the sphere-relative "up" — a fixed
		// up drifts toward parallel with the view as pitch increases,
		// collapsing the camera's effective horizontal FOV toward zero well
		// before the pitch clamp (this is exactly the bug that made the far
		// side unreachable — see docs/PROJECT_LOG.md).
		var player = Player.spawnAt(Math.PI / 2, 0, 0.6, 50);
		var camera = new h3d.Camera();

		for (pitch in [0.0, 0.5, 1.0, Player.MAX_PITCH]) {
			player.pitch = pitch;
			player.applyToCamera(camera, 50);

			var viewDirection = camera.target.sub(camera.pos).normalized();
			Assert.floatEquals(0, viewDirection.dot(camera.up), 1e-6);
		}
	}

	function testApplyToCameraOffsetsEyeHeightAboveTheFloor():Void {
		// Without this, the camera sits exactly on the floor mesh —
		// pitching up then grazes along/through the floor it's embedded in
		// instead of clearing it, so raising your head never actually
		// reveals the far side (see docs/PROJECT_LOG.md). "Up" here means
		// toward the sphere's center, so the eye is closer to the center
		// than the floor is — a *smaller* radius, not a larger one.
		var radius = 50.0;
		var player = Player.spawnAt(Math.PI / 2, 0, 0, radius);
		var camera = new h3d.Camera();

		player.applyToCamera(camera, radius);

		Assert.floatEquals(radius - Player.EYE_HEIGHT, camera.pos.length(), 1e-9);
	}
}
