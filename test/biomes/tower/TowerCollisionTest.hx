package biomes.tower;

import utest.Test;
import utest.Assert;
import biomes.tower.TowerModel.TowerData;
import entities.player.PlayerModel;

/** Covers TowerCollision's own outer-wall bound and real free-fall physics — see biomes.common.GravityTest for the other biomes' cosmetic-hop rule this contrasts with. **/
class TowerCollisionTest extends Test {
	function testTryMoveAllowsAStepWellWithinTheOuterWall():Void {
		var player = flatPlayer(0, 0, 0);

		TowerCollision.tryMove(player, new h3d.Vector(1, 0, 0), 5);

		Assert.floatEquals(5, player.pos.x);
	}

	function testTryMoveBlocksAStepThatWouldCrossTheOuterWall():Void {
		var player = flatPlayer(TowerModel.OUTER_RADIUS - 2, 0, 0);

		TowerCollision.tryMove(player, new h3d.Vector(1, 0, 0), 10);

		Assert.floatEquals(TowerModel.OUTER_RADIUS - 2, player.pos.x);
	}

	function testIsWithinOuterWallIsTrueAtTheCenter():Void {
		Assert.isTrue(TowerCollision.isWithinOuterWall(new h3d.Vector(0, 0, 0)));
	}

	function testIsWithinOuterWallIsFalseBeyondTheClearance():Void {
		Assert.isFalse(TowerCollision.isWithinOuterWall(new h3d.Vector(TowerModel.OUTER_RADIUS, 0, 0)));
	}

	function testApplyGravityAcceleratesAnAirborneFallWithNoCap():Void {
		var layout = allHolesExceptBottomLayer();
		// Off the always-solid center disk, over an actual hole (see allHolesExceptBottomLayer).
		var player = flatPlayer(TowerModel.CENTER_DISK_RADIUS + 1, TowerModel.layerY(2), 0);
		player.grounded = false;

		TowerCollision.applyGravity(player, 60, layout, 0.1);
		var firstStepSpeed = -player.verticalVelocity;
		TowerCollision.applyGravity(player, 60, layout, 0.1);
		var secondStepSpeed = -player.verticalVelocity;

		Assert.isTrue(secondStepSpeed > firstStepSpeed);
	}

	function testApplyGravitySkipsOverHolesToLandOnTheFirstSolidLayerBelow():Void {
		var layout = allHolesExceptBottomLayer();
		layout.solidTiles[5][0][0] = true; // one solid patch, well before the guaranteed-solid bottom
		var player = flatPlayer(TowerModel.CENTER_DISK_RADIUS + 1, TowerModel.layerY(0), 0);
		player.grounded = false;
		player.verticalVelocity = -100000; // fast enough to cross several layers in a single step

		var landedLayer = TowerCollision.applyGravity(player, 60, layout, 1);

		Assert.equals(5, landedLayer);
		Assert.floatEquals(TowerModel.layerY(5), player.pos.y);
		Assert.floatEquals(0, player.verticalVelocity);
		Assert.isTrue(player.grounded);
	}

	function testApplyGravityKeepsAGroundedPlayerRestingOnASolidFloor():Void {
		var layout = allHolesExceptBottomLayer();
		layout.solidTiles[3][0][0] = true;
		var player = flatPlayer(TowerModel.CENTER_DISK_RADIUS + 1, TowerModel.layerY(3), 0);
		player.grounded = true;
		player.verticalVelocity = 0;

		var landedLayer = TowerCollision.applyGravity(player, 60, layout, 1 / 60);

		Assert.equals(3, landedLayer);
		Assert.floatEquals(TowerModel.layerY(3), player.pos.y);
		Assert.isTrue(player.grounded);
	}

	function testApplyGravityReturnsTheGuaranteedSolidBottomLayerWhenNothingElseCatchesTheFall():Void {
		var layout = allHolesExceptBottomLayer();
		var player = flatPlayer(TowerModel.CENTER_DISK_RADIUS + 1, TowerModel.layerY(0), 0);
		player.grounded = false;
		player.verticalVelocity = -100000;

		var landedLayer = TowerCollision.applyGravity(player, 60, layout, 1);

		Assert.equals(TowerModel.GOAL_LEVELS - 1, landedLayer);
		Assert.floatEquals(TowerModel.layerY(TowerModel.GOAL_LEVELS - 1), player.pos.y);
	}

	function testApplyGravityDoesNotSnapUpwardWhenDriftingBeneathASolidTileAlreadyFallenPast():Void {
		var layout = allHolesExceptBottomLayer();
		layout.solidTiles[2][0][0] = true; // a solid tile at a layer the player has already fallen below
		// Mid-fall strictly between layer 2's and layer 3's own floors -
		// already below layer 2's, not resting on it - at (x, z) that
		// happens to fall under that same solid tile (e.g. after drifting
		// sideways). Landing on layer 2 here would mean rising back up
		// through a floor already left behind.
		var midFallY = (TowerModel.layerY(2) + TowerModel.layerY(3)) / 2;
		var player = flatPlayer(TowerModel.CENTER_DISK_RADIUS + 1, midFallY, 0);
		player.grounded = false;
		player.verticalVelocity = 0;

		TowerCollision.applyGravity(player, 60, layout, 1 / 60);

		Assert.isFalse(player.grounded);
		Assert.isTrue(player.pos.y < midFallY);
	}

	function testApplyGravityDoesNotCancelAJumpFromTheTopmostLayer():Void {
		var layout = allHolesExceptBottomLayer();
		// On the always-solid center disk at layer 0 - the topmost layer,
		// with no layer "above" it for TowerModel.layerAt to represent.
		var player = flatPlayer(0, TowerModel.layerY(0), 0);
		player.grounded = true;
		player.jump(50);

		TowerCollision.applyGravity(player, 60, layout, 1 / 60);

		Assert.isFalse(player.grounded);
		Assert.isTrue(player.pos.y > TowerModel.layerY(0));
	}

	static function flatPlayer(x:Float, y:Float, z:Float):PlayerModel {
		return new PlayerModel(new h3d.Vector(x, y, z), new h3d.Vector(0, 0, 1), 0, biomes.common.space.flat.FlatSpace.INSTANCE);
	}

	static function allHolesExceptBottomLayer():TowerData {
		var layers:Array<Array<Array<Bool>>> = [];
		for (layer in 0...TowerModel.GOAL_LEVELS) {
			var rings:Array<Array<Bool>> = [];
			for (ring in 0...TowerModel.RINGS_PER_LAYER) {
				var tiles:Array<Bool> = [];
				for (_ in 0...TowerModel.tilesForRing(ring)) {
					tiles.push(layer == TowerModel.GOAL_LEVELS - 1);
				}
				rings.push(tiles);
			}
			layers.push(rings);
		}
		return {solidTiles: layers};
	}
}
