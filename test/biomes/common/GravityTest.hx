package biomes.common;

import utest.Test;
import utest.Assert;
import entities.player.PlayerModel;

/** Covers Gravity.fallToSurface's integration/landing math — see biomes.tower.TowerCollisionTest for the tower's own, different falling rule. **/
class GravityTest extends Test {
	function testFallToSurfaceAcceleratesAJumpUpward():Void {
		var player = PlayerModel.spawnAt(1, 0, 0, 1);
		player.jump(18);

		Gravity.fallToSurface(player, 60, 0.1);

		Assert.floatEquals(18 - 60 * 0.1, player.verticalVelocity, 1e-9);
		Assert.floatEquals((18 - 60 * 0.1) * 0.1, player.airborneHeight, 1e-9);
		Assert.isFalse(player.grounded);
	}

	function testFallToSurfaceClampsToTheFloorAndZeroesVelocity():Void {
		var player = PlayerModel.spawnAt(1, 0, 0, 1);
		player.jump(1); // a tiny hop, guaranteed to land within one step at this gravity
		player.grounded = false;

		Gravity.fallToSurface(player, 60, 1);

		Assert.floatEquals(0, player.airborneHeight);
		Assert.floatEquals(0, player.verticalVelocity);
		Assert.isTrue(player.grounded);
	}

	function testFallToSurfaceKeepsRisingWhilePastTheFloor():Void {
		var player = PlayerModel.spawnAt(1, 0, 0, 1);
		player.jump(18);

		Gravity.fallToSurface(player, 60, 0.01);

		Assert.isTrue(player.airborneHeight > 0);
		Assert.isFalse(player.grounded);
	}
}
