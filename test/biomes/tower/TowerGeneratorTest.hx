package biomes.tower;

import utest.Test;
import utest.Assert;

/** Covers TowerGenerator's own RNG-driven content and (de)serialization — see TowerModelTest for the pure topology it fills in. **/
class TowerGeneratorTest extends Test {
	function testDensityAtStartsAtFloorDensityStartAtTheSpawnLayer():Void {
		Assert.floatEquals(TowerModel.FLOOR_DENSITY_START, TowerGenerator.densityAt(TowerModel.SPAWN_LAYER));
	}

	function testDensityAtReadsTheSameFloorDensityStartAboveTheSpawnLayer():Void {
		// Layers above spawn aren't part of the descent's own difficulty
		// curve at all - see densityAt's own doc.
		for (layer in 0...TowerModel.SPAWN_LAYER) {
			Assert.floatEquals(TowerModel.FLOOR_DENSITY_START, TowerGenerator.densityAt(layer));
		}
	}

	function testDensityAtReachesFloorDensityEndAtTheGoalLevel():Void {
		Assert.floatEquals(TowerModel.FLOOR_DENSITY_END, TowerGenerator.densityAt(TowerModel.TOTAL_LEVELS - 1));
	}

	function testDensityAtDecreasesMonotonically():Void {
		var previous = TowerGenerator.densityAt(0);
		for (layer in 1...TowerModel.TOTAL_LEVELS) {
			var density = TowerGenerator.densityAt(layer);
			Assert.isTrue(density <= previous);
			previous = density;
		}
	}

	function testGenerateProducesTheRightShapedLayout():Void {
		var layout = TowerGenerator.generate(() -> 0.5);

		Assert.equals(TowerModel.TOTAL_LEVELS, layout.solidTiles.length);
		for (layer in 0...TowerModel.TOTAL_LEVELS) {
			Assert.equals(TowerModel.RINGS_PER_LAYER, layout.solidTiles[layer].length);
			for (ring in 0...TowerModel.RINGS_PER_LAYER) {
				Assert.equals(TowerModel.tilesForRing(ring), layout.solidTiles[layer][ring].length);
			}
		}
	}

	function testGenerateAlwaysMakesTheBottomLayerFullySolid():Void {
		// rng() < density is never true for density < 1, so every non-forced
		// tile comes out a hole - isolating the bottom layer's own forcing.
		var layout = TowerGenerator.generate(() -> 1.0);

		for (ring in 0...TowerModel.RINGS_PER_LAYER) {
			for (tile in layout.solidTiles[TowerModel.TOTAL_LEVELS - 1][ring]) {
				Assert.isTrue(tile);
			}
		}
	}

	function testGenerateAlwaysForcesTheEntranceTileSolidAtTheSpawnLayer():Void {
		// Same isolation trick as testGenerateAlwaysMakesTheBottomLayerFullySolid:
		// rng() < density is never true for density < 1, so only forced tiles come out solid.
		var layout = TowerGenerator.generate(() -> 1.0);

		Assert.isTrue(layout.solidTiles[TowerModel.SPAWN_LAYER][TowerModel.entranceTileRing()][TowerModel.entranceTileIndex()]);
	}

	function testSerializeDeserializeRoundTrips():Void {
		var original = TowerGenerator.generate(() -> 0.5);

		var restored = TowerGenerator.deserialize(TowerGenerator.serialize(original));

		Assert.equals(original.solidTiles.length, restored.solidTiles.length);
		for (layer in 0...original.solidTiles.length) {
			for (ring in 0...original.solidTiles[layer].length) {
				for (tile in 0...original.solidTiles[layer][ring].length) {
					Assert.equals(original.solidTiles[layer][ring][tile], restored.solidTiles[layer][ring][tile]);
				}
			}
		}
	}
}
