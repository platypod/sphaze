package biomes.mobius;

import utest.Test;
import utest.Assert;

/** Covers MobiusForestGenerator's own RNG-driven scatter and (de)serialization. **/
class MobiusForestGeneratorTest extends Test {
	/**
		A tiny deterministic PRNG (mulberry32) rather than `Math.random` —
		reproducible test failures, and a constant function (`() -> 0.5`,
		the style `TowerGeneratorTest` uses for its own tile-density rolls)
		would make every candidate land at the exact same `(u, v)`, useless
		for testing a spacing/scatter algorithm.
	**/
	static function seededRandom(seed:Int):Void->Float {
		var state = seed;
		return () -> {
			state += 0x6D2B79F5;
			var t = state;
			t = (t ^ (t >>> 15)) * (t | 1);
			t ^= t + (t ^ (t >>> 7)) * (t | 61);
			return ((t ^ (t >>> 14)) >>> 0) / 4294967296.0;
		}
	}

	function testGenerateReachesAReasonableFractionOfTheDefaultTargetCount():Void {
		// At default scale (MobiusModel.TARGET_TREE_COUNT), not the small
		// counts every other test below uses - a convergence sanity check:
		// TREE_SCATTER_MAX_ATTEMPTS should comfortably reach most of the
		// target before giving up, not stall out far short of it.
		var layout = MobiusForestGenerator.generate(3, seededRandom(1));

		Assert.isTrue(layout.trees.length >= Std.int(MobiusModel.TARGET_TREE_COUNT * 0.9));
	}

	function testGenerateNeverPlacesTwoTreesCloserThanMinSpacing():Void {
		// A small count on purpose - the check below is O(n^2) pairs, and
		// the spacing invariant it verifies doesn't depend on how many
		// trees actually get placed.
		var layout = MobiusForestGenerator.generate(3, seededRandom(2), 150);

		for (i in 0...layout.trees.length) {
			for (j in (i + 1)...layout.trees.length) {
				var a = layout.trees[i];
				var b = layout.trees[j];
				var dx = a.x - b.x;
				var dy = a.y - b.y;
				var dz = a.z - b.z;
				var dist = Math.sqrt(dx * dx + dy * dy + dz * dz);
				Assert.isTrue(dist >= MobiusModel.MIN_TREE_SPACING - 1e-9);
			}
		}
	}

	function testGenerateKeepsEveryTreeClearOfTheEntranceSpawn():Void {
		var layout = MobiusForestGenerator.generate(3, seededRandom(3), 150);
		var spawn = MobiusModel.spawnPosition(3);

		for (t in layout.trees) {
			var dx = t.x - spawn.x;
			var dy = t.y - spawn.y;
			var dz = t.z - spawn.z;
			var dist = Math.sqrt(dx * dx + dy * dy + dz * dz);
			Assert.isTrue(dist >= MobiusModel.TREE_SPAWN_CLEARANCE - 1e-9);
		}
	}

	function testGenerateKeepsEveryTreeWithinTheUsableWidth():Void {
		var layout = MobiusForestGenerator.generate(3, seededRandom(4), 150);
		var usableHalfWidth = MobiusModel.HALF_WIDTH - MobiusModel.TREE_EDGE_MARGIN;

		for (t in layout.trees) {
			Assert.isTrue(Math.abs(t.v) <= usableHalfWidth);
		}
	}

	function testGenerateVariesTrunkAndFoliageSizeWithinTheirOwnRanges():Void {
		var layout = MobiusForestGenerator.generate(3, seededRandom(5), 150);

		for (t in layout.trees) {
			Assert.isTrue(t.trunkHeight >= MobiusModel.TRUNK_HEIGHT_MIN && t.trunkHeight <= MobiusModel.TRUNK_HEIGHT_MAX);
			Assert.isTrue(t.trunkRadius >= MobiusModel.TRUNK_RADIUS_MIN && t.trunkRadius <= MobiusModel.TRUNK_RADIUS_MAX);
			Assert.isTrue(t.foliageRadius >= MobiusModel.FOLIAGE_RADIUS_MIN && t.foliageRadius <= MobiusModel.FOLIAGE_RADIUS_MAX);
			Assert.isTrue(t.foliageHeight >= MobiusModel.FOLIAGE_HEIGHT_MIN && t.foliageHeight <= MobiusModel.FOLIAGE_HEIGHT_MAX);
		}
	}

	function testSerializeDeserializeRoundTrips():Void {
		var original = MobiusForestGenerator.generate(3, seededRandom(6), 150);

		var restored = MobiusForestGenerator.deserialize(MobiusForestGenerator.serialize(original));

		Assert.equals(original.trees.length, restored.trees.length);
		for (i in 0...original.trees.length) {
			Assert.floatEquals(original.trees[i].x, restored.trees[i].x);
			Assert.floatEquals(original.trees[i].y, restored.trees[i].y);
			Assert.floatEquals(original.trees[i].z, restored.trees[i].z);
			Assert.floatEquals(original.trees[i].trunkHeight, restored.trees[i].trunkHeight);
			Assert.floatEquals(original.trees[i].foliageRadius, restored.trees[i].foliageRadius);
		}
	}
}
