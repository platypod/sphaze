import utest.Test;
import utest.Assert;
import entities.Player;

/** Covers Player's pure movement/pitch math and its composition into applyToCamera. **/
class PlayerTest extends Test {
	function testTurnAddsToFacing():Void {
		var player = new Player(1, 0, 0);

		player.turn(0.5);

		Assert.floatEquals(0.5, player.facing);
	}

	function testMoveForwardAlongAMeridianMatchesArcLength():Void {
		// facing 0 at any point looks toward increasing theta (see
		// Player's doc comment), so from the equator this walks a meridian
		// — an exact great circle — where arc length is just radius*angle.
		var radius = 1.0;
		var player = new Player(Math.PI / 2, 0, 0);

		player.moveForward(0.3, radius);

		Assert.floatEquals(Math.PI / 2 + 0.3, player.theta, 1e-9);
		Assert.floatEquals(0, player.phi, 1e-9);
	}

	function testMoveBackwardDecreasesTheta():Void {
		var radius = 1.0;
		var player = new Player(Math.PI / 2, 0, 0);

		player.moveForward(-0.3, radius);

		Assert.floatEquals(Math.PI / 2 - 0.3, player.theta, 1e-9);
	}

	function testMoveForwardStaysOnTheSphere():Void {
		var radius = 50.0;
		var player = new Player(1.1, 2.2, 0.7);

		player.moveForward(4, radius);

		var pos = game.SphereMath.sphericalToCartesian(radius, player.theta, player.phi);
		Assert.floatEquals(radius, pos.length(), 1e-9);
	}

	function testMoveForwardIgnoresPitch():Void {
		// WASD-style movement stays on the ground regardless of where the
		// camera is looking — same as any FPS.
		var radius = 1.0;
		var level = new Player(Math.PI / 2, 0, 0);
		var lookingUp = new Player(Math.PI / 2, 0, 0);
		lookingUp.lookUp(1.0);

		level.moveForward(0.3, radius);
		lookingUp.moveForward(0.3, radius);

		Assert.floatEquals(level.theta, lookingUp.theta, 1e-9);
		Assert.floatEquals(level.phi, lookingUp.phi, 1e-9);
	}

	function testLookUpClampsToMaxPitch():Void {
		var player = new Player(1, 0, 0);

		player.lookUp(100);

		Assert.floatEquals(Player.MAX_PITCH, player.pitch);
	}

	function testLookDownClampsToMinusMaxPitch():Void {
		var player = new Player(1, 0, 0);

		player.lookUp(-100);

		Assert.floatEquals(-Player.MAX_PITCH, player.pitch);
	}

	function testApplyToCameraOffsetsEyeHeightAboveTheFloor():Void {
		// Without this, the camera sits exactly on the floor mesh —
		// pitching up then grazes along/through the floor it's embedded in
		// instead of clearing it, so raising your head never actually
		// reveals the far side (see docs/PROJECT_LOG.md). "Up" here means
		// toward the sphere's center, so the eye is closer to the center
		// than the floor is — a *smaller* radius, not a larger one.
		var radius = 50.0;
		var player = new Player(Math.PI / 2, 0, 0);
		var camera = new h3d.Camera();

		player.applyToCamera(camera, radius);

		Assert.floatEquals(radius - Player.EYE_HEIGHT, camera.pos.length(), 1e-9);
	}

	function testApplyToCameraAtZeroPitchLooksHorizontally():Void {
		var player = new Player(Math.PI / 2, 0, 0);
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
		var player = new Player(Math.PI / 2, 0, 0);
		player.lookUp(100);
		var camera = new h3d.Camera();

		player.applyToCamera(camera, 50);

		var viewDirection = camera.target.sub(camera.pos).normalized();
		var towardCenter = game.SphereMath.upVectorAt(camera.pos, new h3d.Vector(0, 0, 0));
		Assert.isTrue(viewDirection.dot(towardCenter) > 0.999);
	}

	function testApplyToCameraKeepsUpPerpendicularToViewAtAnyPitch():Void {
		// Regression guard: camera.up must tilt along with the view
		// direction, not stay fixed at the sphere-relative "up" — a fixed
		// up drifts toward parallel with the view as pitch increases,
		// collapsing the camera's effective horizontal FOV toward zero well
		// before the pitch clamp (this is exactly the bug that made the far
		// side unreachable — see docs/PROJECT_LOG.md).
		var player = new Player(Math.PI / 2, 0, 0.6);
		var camera = new h3d.Camera();

		for (pitch in [0.0, 0.5, 1.0, Player.MAX_PITCH]) {
			player.pitch = pitch;
			player.applyToCamera(camera, 50);

			var viewDirection = camera.target.sub(camera.pos).normalized();
			Assert.floatEquals(0, viewDirection.dot(camera.up), 1e-6);
		}
	}
}
