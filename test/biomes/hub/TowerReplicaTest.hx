package biomes.hub;

import utest.Test;
import utest.Assert;
import biomes.common.space.sphere.SphereMath;
import biomes.tower.TowerBiome;

/** Covers TowerReplica's own pure collision/painting-placement queries — not `build`'s own scene/rendering side (see docs/GUIDELINES.md §1.4/§5.4). **/
class TowerReplicaTest extends Test {
	static inline final RADIUS:Float = 70;

	static final THETA:Float = Math.PI / 2;

	static final PHI:Float = -1.0;

	static final BASIS = HubStructure.anchorAt(THETA, PHI, RADIUS);

	function testBlocksMovementRightAtTheAnchorItself():Void {
		// The spire is solid all the way through, so its own local origin -
		// dead center - is well inside its collision boundary.
		Assert.isTrue(TowerReplica.blocksMovement(BASIS, BASIS.origin));
	}

	function testBlocksMovementIsFalseWellClearOfTheSpire():Void {
		var farPoint = HubStructure.worldPoint(BASIS, 1000, 1000, 0);
		Assert.isFalse(TowerReplica.blocksMovement(BASIS, farPoint));
	}

	function testBlocksMovementIsFalseAtTheAntipodalPointOnTheRealSphere():Void {
		// Regression test: the point diametrically opposite the anchor
		// projects to local (u, v) = (0, 0) unless height is also checked -
		// see HubStructure.localUV's own class doc.
		var antipode = SphereMath.sphericalToCartesian(RADIUS, Math.PI - THETA, PHI + Math.PI);
		Assert.isFalse(TowerReplica.blocksMovement(BASIS, antipode));
	}

	function testExitPaintingTriggersAtItsOwnPosition():Void {
		var painting = TowerReplica.exitPainting(BASIS, TowerBiome.ID);
		Assert.isTrue(painting.triggeredBy(painting.position));
	}

	function testExitPaintingDoesNotTriggerWellClearOfTheSpire():Void {
		var painting = TowerReplica.exitPainting(BASIS, TowerBiome.ID);
		var farPoint = HubStructure.worldPoint(BASIS, 1000, 1000, 0);
		Assert.isFalse(painting.triggeredBy(farPoint));
	}

	function testReturnSpawnPositionLiesOnTheHubSphere():Void {
		var player = TowerReplica.returnSpawn(BASIS, RADIUS);
		Assert.floatEquals(RADIUS, player.pos.length(), 1e-6);
	}

	function testReturnSpawnForwardIsAUnitVector():Void {
		var player = TowerReplica.returnSpawn(BASIS, RADIUS);
		Assert.floatEquals(1, player.forward.length(), 1e-6);
	}

	function testReturnSpawnForwardIsTangentToTheSphereAtItsOwnPosition():Void {
		var player = TowerReplica.returnSpawn(BASIS, RADIUS);
		Assert.floatEquals(0, player.forward.dot(player.pos.normalized()), 1e-6);
	}

	function testReturnSpawnDoesNotImmediatelyRetriggerTheExitPainting():Void {
		var painting = TowerReplica.exitPainting(BASIS, TowerBiome.ID);
		var player = TowerReplica.returnSpawn(BASIS, RADIUS);
		Assert.isFalse(painting.triggeredBy(player.pos));
	}

	function testReturnSpawnFacesAwayFromTheSpireNotBackTowardIt():Void {
		// Walking into the tower's own painting to get here is itself a walk
		// toward the spire - facing that same way again on arrival would
		// retrace those steps rather than continuing out into the hub.
		var player = TowerReplica.returnSpawn(BASIS, RADIUS);
		var outward = player.pos.sub(BASIS.origin).normalized();
		Assert.isTrue(player.forward.dot(outward) > 0);
	}
}
