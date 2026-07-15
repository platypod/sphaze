import utest.Test;
import utest.Assert;
import entities.Player;

/** Covers Player's pure geometric movement — not applyToCamera, which just composes already-tested SphereMath calls. **/
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
}
