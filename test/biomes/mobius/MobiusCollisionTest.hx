package biomes.mobius;

import utest.Test;
import utest.Assert;
import biomes.common.space.mobius.MobiusMath;
import biomes.common.space.mobius.MobiusSpace;
import biomes.mobius.MobiusForestGenerator.ForestLayout;
import entities.player.PlayerModel;

/** Covers MobiusCollision's own edge boundary and trunk hitbox — see MobiusForestGeneratorTest for the forest's own placement invariants this builds on. **/
class MobiusCollisionTest extends Test {
	static inline final TWISTS:Int = 3;

	function emptyForest():ForestLayout {
		return {trees: []};
	}

	function testTryMoveAllowsAStepWellWithinTheEdge():Void {
		var pos = MobiusMath.pointAt(0, 0, TWISTS, MobiusModel.RADIUS);
		var frame = MobiusMath.localFrameAt(0, 0, TWISTS, MobiusModel.RADIUS);
		var player = new PlayerModel(pos, frame.tu, 0, new MobiusSpace(TWISTS, MobiusModel.RADIUS));

		MobiusCollision.tryMove(player, frame.tv, 5, TWISTS, MobiusModel.RADIUS, emptyForest());

		var params = MobiusMath.paramsAt(player.pos, TWISTS, MobiusModel.RADIUS);
		Assert.floatEquals(5, params.v, 1e-6);
	}

	function testTryMoveBlocksAStepThatWouldCrossTheEdge():Void {
		var startV = MobiusModel.HALF_WIDTH - 2;
		var pos = MobiusMath.pointAt(0, startV, TWISTS, MobiusModel.RADIUS);
		var frame = MobiusMath.localFrameAt(0, startV, TWISTS, MobiusModel.RADIUS);
		var player = new PlayerModel(pos, frame.tu, 0, new MobiusSpace(TWISTS, MobiusModel.RADIUS));

		MobiusCollision.tryMove(player, frame.tv, 10, TWISTS, MobiusModel.RADIUS, emptyForest());

		var params = MobiusMath.paramsAt(player.pos, TWISTS, MobiusModel.RADIUS);
		Assert.floatEquals(startV, params.v, 1e-6);
	}

	function testTryMoveBlocksAStepThatWouldWalkIntoATrunk():Void {
		var pos = MobiusMath.pointAt(0, 0, TWISTS, MobiusModel.RADIUS);
		var frame = MobiusMath.localFrameAt(0, 0, TWISTS, MobiusModel.RADIUS);
		var player = new PlayerModel(pos, frame.tu, 0, new MobiusSpace(TWISTS, MobiusModel.RADIUS));

		// A trunk sitting exactly where a 5-unit step along tv would land.
		var trunkPos = MobiusMath.pointAt(0, 5, TWISTS, MobiusModel.RADIUS);
		var forest:ForestLayout = {
			trees: [
				{
					u: 0,
					v: 5,
					x: trunkPos.x,
					y: trunkPos.y,
					z: trunkPos.z,
					species: MobiusForestGenerator.SPECIES_CONIFER,
					rotation: 0,
					trunkHeight: 10,
					trunkRadius: 2,
					foliageRadius: 4,
					foliageHeight: 8
				}
			]
		};

		MobiusCollision.tryMove(player, frame.tv, 5, TWISTS, MobiusModel.RADIUS, forest);

		var params = MobiusMath.paramsAt(player.pos, TWISTS, MobiusModel.RADIUS);
		Assert.floatEquals(0, params.v, 1e-6);
	}

	function testTryMoveRestoresSurfaceUpWhenABlockedStepGetsReverted():Void {
		var startV = MobiusModel.HALF_WIDTH - 2;
		var pos = MobiusMath.pointAt(2 * Math.PI - 0.02, startV, TWISTS, MobiusModel.RADIUS);
		var frame = MobiusMath.localFrameAt(2 * Math.PI - 0.02, startV, TWISTS, MobiusModel.RADIUS);
		var player = new PlayerModel(pos, frame.tu, 0, new MobiusSpace(TWISTS, MobiusModel.RADIUS));
		var oldSurfaceUp = player.surfaceUp;
		var blockedResult = player.space.moveAlong(pos, frame.tu, frame.tu, 20, MobiusModel.RADIUS);
		var forest:ForestLayout = {
			trees: [
				{
					u: 0,
					v: 0,
					x: blockedResult.pos.x,
					y: blockedResult.pos.y,
					z: blockedResult.pos.z,
					species: MobiusForestGenerator.SPECIES_CONIFER,
					rotation: 0,
					trunkHeight: 10,
					trunkRadius: 2,
					foliageRadius: 4,
					foliageHeight: 8
				}
			]
		};

		MobiusCollision.tryMove(player, frame.tu, 20, TWISTS, MobiusModel.RADIUS, forest);

		Assert.isTrue(oldSurfaceUp.dot(player.surfaceUp) > 0.999);
	}

	function testIsBlockedByATrunkIsTrueWithinTrunkRadiusPlusClearance():Void {
		var forest:ForestLayout = {
			trees: [
				{
					u: 0,
					v: 0,
					x: 0,
					y: 0,
					z: 0,
					species: MobiusForestGenerator.SPECIES_CONIFER,
					rotation: 0,
					trunkHeight: 10,
					trunkRadius: 2,
					foliageRadius: 4,
					foliageHeight: 8
				}
			]
		};

		Assert.isTrue(MobiusCollision.isBlockedByATrunk(new h3d.Vector(1, 0, 0), forest));
	}

	function testIsBlockedByATrunkIsFalseJustOutsideTrunkRadiusPlusClearance():Void {
		var forest:ForestLayout = {
			trees: [
				{
					u: 0,
					v: 0,
					x: 0,
					y: 0,
					z: 0,
					species: MobiusForestGenerator.SPECIES_CONIFER,
					rotation: 0,
					trunkHeight: 10,
					trunkRadius: 2,
					foliageRadius: 4,
					foliageHeight: 8
				}
			]
		};

		Assert.isFalse(MobiusCollision.isBlockedByATrunk(new h3d.Vector(4, 0, 0), forest));
	}

	function testIsBlockedByATrunkIsFalseForAnEmptyForest():Void {
		Assert.isFalse(MobiusCollision.isBlockedByATrunk(new h3d.Vector(0, 0, 0), emptyForest()));
	}
}
