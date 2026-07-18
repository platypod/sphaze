package biomes.hub;

import utest.Test;
import utest.Assert;
import biomes.common.space.sphere.SphereMath;
import entities.player.PlayerModel;

/** Covers HubModel's pure geometry queries — not HubMesh's scene/rendering side (see docs/GUIDELINES.md §1.4/§5.4). **/
class HubModelTest extends Test {
	function testToBiomeFaceAzimuthMatchesTheFacesOwnMidAngle():Void {
		// TO_BIOME_FACE_INDEX is face 0 of COLUMN_SIDES (8): its left/right
		// edges sit at 0 and 2*pi/8, so the face's own azimuth is the
		// midpoint of those, pi/8.
		Assert.floatEquals(Math.PI / HubModel.COLUMN_SIDES, HubModel.toBiomeFaceAzimuth(), 1e-9);
	}

	function testReturnSpawnThetaIsOnTheWalkableSideOfTheColumn():Void {
		var theta = HubModel.returnSpawnTheta();
		var pos = SphereMath.sphericalToCartesian(HubModel.RADIUS, theta, HubModel.toBiomeFaceAzimuth());

		Assert.isTrue(HubModel.isInside(pos));
	}

	function testReturnSpawnPointDoesNotImmediatelyRetriggerTheToBiomePainting():Void {
		var theta = HubModel.returnSpawnTheta();
		var phi = HubModel.toBiomeFaceAzimuth();
		var pos = SphereMath.sphericalToCartesian(HubModel.RADIUS, theta, phi);

		var painting = HubModel.toBiomePainting("maze");

		Assert.isFalse(painting.triggeredBy(pos));
	}

	function testReturnSpawnPlayerFacesAwayFromTheColumnAxis():Void {
		var theta = HubModel.returnSpawnTheta();
		var phi = HubModel.toBiomeFaceAzimuth();
		var player = PlayerModel.spawnAt(theta, phi, 0, HubModel.RADIUS);

		// "Away from the column" is the same as "away from the nearest
		// pole": increasing distance from the Y axis. Moving a little
		// further along `forward` should end up strictly farther from the
		// axis than `player.pos` itself — i.e. the player's back is turned
		// to the column (and the painting mounted on it), not facing it.
		var ahead = player.pos.add(player.forward.scaled(0.01));
		var axisDistanceNow = Math.sqrt(player.pos.x * player.pos.x + player.pos.z * player.pos.z);
		var axisDistanceAhead = Math.sqrt(ahead.x * ahead.x + ahead.z * ahead.z);

		Assert.isTrue(axisDistanceAhead > axisDistanceNow);
	}
}
