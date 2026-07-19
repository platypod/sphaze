package biomes.tower;

import utest.Test;
import utest.Assert;
import biomes.tower.TowerModel.TowerData;

/** Covers TowerModel's pure topology/queries — see TowerGeneratorTest for the RNG-driven content those queries read. **/
class TowerModelTest extends Test {
	function testLayerYAtSpawnLayerIsZero():Void {
		Assert.floatEquals(0, TowerModel.layerY(TowerModel.SPAWN_LAYER));
	}

	function testLayerYDecreasesByLayerHeightPerLayerBelowSpawn():Void {
		Assert.floatEquals(-TowerModel.LAYER_HEIGHT * 3, TowerModel.layerY(TowerModel.SPAWN_LAYER + 3));
	}

	function testLayerYIncreasesByLayerHeightPerLayerAboveSpawn():Void {
		Assert.floatEquals(TowerModel.LAYER_HEIGHT * 3, TowerModel.layerY(TowerModel.SPAWN_LAYER - 3));
	}

	function testLayerAtIsInverseOfLayerYWithinRange():Void {
		for (layer in 0...TowerModel.TOTAL_LEVELS) {
			Assert.equals(layer, TowerModel.layerAt(TowerModel.layerY(layer)));
		}
	}

	function testLayerAtClampsAboveTheTop():Void {
		Assert.equals(0, TowerModel.layerAt(1000));
	}

	function testLayerAtClampsBelowTheBottom():Void {
		Assert.equals(TowerModel.TOTAL_LEVELS - 1, TowerModel.layerAt(-1000000));
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
		// ringAngleOffset shears each ring's own tile boundaries - the same
		// world angle should land in a different tile index (relative to
		// its own ring's zero) once the offset is large enough to cross a
		// boundary. Ring 1's own offset is exactly ringAngleOffset(1).
		var halfOffset = TowerModel.ringAngleOffset(1) / 2;
		var x = Math.cos(halfOffset);
		var z = Math.sin(halfOffset);
		Assert.equals(0, TowerModel.tileAt(0, x, z));
		Assert.equals(TowerModel.tilesForRing(1) - 1, TowerModel.tileAt(1, x, z));
	}

	function testAngularSegmentsIsDivisibleByEveryRingsOwnTileCount():Void {
		// The actual invariant TowerMesh relies on to make ring boundaries
		// (and the center disk's own rim) line up with no seam - see
		// ANGULAR_SEGMENTS's own doc. Guards against a future
		// BASE_TILES_PER_RING/RINGS_PER_LAYER change silently breaking it.
		for (ring in 0...TowerModel.RINGS_PER_LAYER) {
			Assert.equals(0, TowerModel.ANGULAR_SEGMENTS % TowerModel.tilesForRing(ring));
		}
	}

	function testTileIndexAtSlotMatchesTileAtForTheSameAngle():Void {
		for (ring in 0...TowerModel.RINGS_PER_LAYER) {
			var slot = 5;
			var angle = slot * TowerModel.SLOT_ANGLE + 0.001; // just past the slot's own start, still inside it
			var x = Math.cos(angle);
			var z = Math.sin(angle);
			Assert.equals(TowerModel.tileAt(ring, x, z), TowerModel.tileIndexAtSlot(ring, slot));
		}
	}

	function testTileIndexAtSlotWrapsAroundTheSharedGrid():Void {
		Assert.equals(TowerModel.tileIndexAtSlot(0, 3), TowerModel.tileIndexAtSlot(0, 3 + TowerModel.ANGULAR_SEGMENTS));
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
		// there rather than running past TOTAL_LEVELS.
		var layout:TowerData = {solidTiles: emptyLayout()};
		var x = TowerModel.CENTER_DISK_RADIUS + 1;

		Assert.equals(TowerModel.TOTAL_LEVELS - 1, TowerModel.floorLayerBelow(layout, 0, x, 0));
	}

	function testEntranceTileIndexIsWithinBoundsOfItsOwnRing():Void {
		var index = TowerModel.entranceTileIndex();
		Assert.isTrue(index >= 0);
		Assert.isTrue(index < TowerModel.tilesForRing(TowerModel.entranceTileRing()));
	}

	function testEntranceSpawnPositionSitsWithinTheEntranceTileAtTheSpawnLayer():Void {
		var pos = TowerModel.entranceSpawnPosition();

		Assert.floatEquals(TowerModel.layerY(TowerModel.SPAWN_LAYER), pos.y);
		Assert.equals(TowerModel.entranceTileRing(), TowerModel.ringAt(pos.x, pos.z));
		Assert.equals(TowerModel.entranceTileIndex(), TowerModel.tileAt(TowerModel.entranceTileRing(), pos.x, pos.z));
	}

	function testEntranceSpawnForwardIsAUnitVectorPointingInwardFromTheWall():Void {
		var forward = TowerModel.entranceSpawnForward();
		var pos = TowerModel.entranceSpawnPosition();
		var outward = new h3d.Vector(pos.x, 0, pos.z).normalized();

		Assert.floatEquals(1, forward.length());
		Assert.isTrue(forward.dot(outward) < 0);
	}

	static function emptyLayout():Array<Array<Array<Bool>>> {
		var layers:Array<Array<Array<Bool>>> = [];
		for (layer in 0...TowerModel.TOTAL_LEVELS) {
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
