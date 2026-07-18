package entities.player;

import utest.Test;
import utest.Assert;
import biomes.common.space.sphere.SphereMath;

/** Covers Camera's composition of a PlayerModel's own state into a camera placement. **/
class CameraTest extends Test {
	function testApplyToCameraAtZeroPitchLooksHorizontally():Void {
		var player = PlayerModel.spawnAt(Math.PI / 2, 0, 0, 50);
		var camera = new h3d.Camera();

		Camera.applyTo(camera, player, 50);

		var viewDirection = camera.target.sub(camera.pos).normalized();
		Assert.floatEquals(0, viewDirection.dot(camera.up), 1e-9);
	}

	function testApplyToCameraAtMaxPitchLooksTowardCenter():Void {
		// "Raise your head to see across to the far side": at the pitch
		// clamp, the view direction should be almost exactly toward the
		// sphere's center (SphereMath.upVectorAt) — independent of the
		// camera's own up vector, which tilts too (see the next test).
		var player = PlayerModel.spawnAt(Math.PI / 2, 0, 0, 50);
		player.lookUp(100);
		var camera = new h3d.Camera();

		Camera.applyTo(camera, player, 50);

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
		var player = PlayerModel.spawnAt(Math.PI / 2, 0, 0.6, 50);
		var camera = new h3d.Camera();

		for (pitch in [0.0, 0.5, 1.0, PlayerModel.MAX_PITCH]) {
			player.pitch = pitch;
			Camera.applyTo(camera, player, 50);

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
		var player = PlayerModel.spawnAt(Math.PI / 2, 0, 0, radius);
		var camera = new h3d.Camera();

		Camera.applyTo(camera, player, radius);

		Assert.floatEquals(radius - Camera.EYE_HEIGHT, camera.pos.length(), 1e-9);
	}
}
