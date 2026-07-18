package biomes.tower;

import utest.Test;
import utest.Assert;
import biomes.tower.TowerModel.TowerData;

/** Covers TowerModel's pure topology/queries — see TowerGeneratorTest for the RNG-driven content those queries read. **/
class TowerModelTest extends Test {
	function testLayerYAtZeroIsZero():Void {
		Assert.floatEquals(0, TowerModel.layerY(0));
	}

	function testLayerYDecreasesByLayerHeightPerLayer():Void {
		Assert.floatEquals(-TowerModel.LAYER_HEIGHT * 3, TowerModel.layerY(3));
	}

	function testLayerAtIsInverseOfLayerYWithinRange():Void {
		for (layer in 0...TowerModel.GOAL_LEVELS) {
			Assert.equals(layer, TowerModel.layerAt(TowerModel.layerY(layer)));
		}
	}

	function testLayerAtClampsAboveTheTop():Void {
		Assert.equals(0, TowerModel.layerAt(1000));
	}

	function testLayerAtClampsBelowTheBottom():Void {
		Assert.equals(TowerModel.GOAL_LEVELS - 1, TowerModel.layerAt(-1000000));
	}

	function testRingAtIsMinusOneWithinTheCenterDisk():Void {
		Assert.equals(-1, TowerModel.ringAt(1, 0));
	}

	function testRingAtIsZeroJustOutsideTheCenterDisk():Void {
		Assert.equals(0, TowerModel.ringAt(TowerModel.CENTER_DISK_RADIUS + 0.1, 0));
	}

	function testRingAtIncreasesOutward():Void {
		var innerRing = TowerModel.ringAt(TowerModel.CENTER_DISK_RADIUS + 0.1, 0);
		var outerRing = TowerModel.ringAt(TowerModel.OUTER_RADIUS - 0.1, 0);
		Assert.isTrue(outerRing > innerRing);
	}

	function testRingAtClampsAtTheOuterWall():Void {
		Assert.equals(TowerModel.RINGS_PER_LAYER - 1, TowerModel.ringAt(TowerModel.OUTER_RADIUS - 0.1, 0));
	}

	function testTileAtWrapsAroundAFullCircle():Void {
		// Angle 0 and angle 2*pi are the same tile.
		var atZero = TowerModel.tileAt(0, 1, 0);
		var wrapped = TowerModel.tileAt(0, Math.cos(2 * Math.PI), Math.sin(2 * Math.PI));
		Assert.equals(atZero, wrapped);
	}

	function testTileAtDiffersAcrossRingsAtTheSameAngleDueToTheAngleOffset():Void {
		// RING_ANGLE_STEP shears each ring's own tile boundaries - the same
		// world angle should land in a different tile index (relative to
		// its own ring's zero) once the offset is large enough to cross a
		// boundary. Ring 1's own offset is exactly RING_ANGLE_STEP.
		var x = Math.cos(TowerModel.RING_ANGLE_STEP / 2);
		var z = Math.sin(TowerModel.RING_ANGLE_STEP / 2);
		Assert.equals(0, TowerModel.tileAt(0, x, z));
		Assert.equals(TowerModel.tilesForRing(1) - 1, TowerModel.tileAt(1, x, z));
	}

	function testIsSolidIsAlwaysTrueWithinTheCenterDiskRegardlessOfLayout():Void {
		var layout:TowerData = {solidTiles: emptyLayout()};

		Assert.isTrue(TowerModel.isSolid(layout, 0, 0, 0));
	}

	function testIsSolidReadsTheGeneratedTileAtThatRing():Void {
		var layout:TowerData = {solidTiles: emptyLayout()};
		var ring = 0;
		var tile = TowerModel.tileAt(ring, TowerModel.CENTER_DISK_RADIUS + 1, 0);
		layout.solidTiles[0][ring][tile] = true;

		Assert.isTrue(TowerModel.isSolid(layout, 0, TowerModel.CENTER_DISK_RADIUS + 1, 0));
	}

	function testFloorLayerBelowReturnsFromLayerWhenAlreadySolid():Void {
		var layout:TowerData = {solidTiles: emptyLayout()};
		layout.solidTiles[2][0][0] = true;
		var x = TowerModel.CENTER_DISK_RADIUS + 1;

		Assert.equals(2, TowerModel.floorLayerBelow(layout, 2, x, 0));
	}

	function testFloorLayerBelowScansDownwardThroughHoles():Void {
		var layout:TowerData = {solidTiles: emptyLayout()};
		layout.solidTiles[5][0][0] = true;
		var x = TowerModel.CENTER_DISK_RADIUS + 1;

		Assert.equals(5, TowerModel.floorLayerBelow(layout, 2, x, 0));
	}

	function testFloorLayerBelowNeverExceedsTheBottomLayer():Void {
		// Every ring tile empty everywhere - the bottom layer's own
		// guaranteed-solid floor (TowerGenerator.generate) is what real
		// layouts rely on; this just confirms the scan itself terminates
		// there rather than running past GOAL_LEVELS.
		var layout:TowerData = {solidTiles: emptyLayout()};
		var x = TowerModel.CENTER_DISK_RADIUS + 1;

		Assert.equals(TowerModel.GOAL_LEVELS - 1, TowerModel.floorLayerBelow(layout, 0, x, 0));
	}

	static function emptyLayout():Array<Array<Array<Bool>>> {
		var layers:Array<Array<Array<Bool>>> = [];
		for (layer in 0...TowerModel.GOAL_LEVELS) {
			var rings:Array<Array<Bool>> = [];
			for (ring in 0...TowerModel.RINGS_PER_LAYER) {
				var tiles:Array<Bool> = [];
				for (_ in 0...TowerModel.tilesForRing(ring)) {
					tiles.push(false);
				}
				rings.push(tiles);
			}
			layers.push(rings);
		}
		return layers;
	}
}
