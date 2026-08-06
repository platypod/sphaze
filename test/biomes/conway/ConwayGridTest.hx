package biomes.conway;

import utest.Assert;
import utest.Test;

class ConwayGridTest extends Test {
	static inline final ROW:Int = 5;
	static inline final COL:Int = 10;

	function testGroundHeightAtIsZeroOverADeadCell():Void {
		var state = ConwayState.deserialize(haxe.Json.stringify({live: [], activity: []}));

		Assert.floatEquals(0, ConwayGrid.groundHeightAt(state, cellTheta(), cellPhi()));
	}

	/** No `age` entry at all (fresh soup, never stepped) reads as age `0` — within `YOUNG_AGE_THRESHOLD`, so it's still the tall block. **/
	function testGroundHeightAtIsTheYoungBlockHeightOverAFreshlyAliveCell():Void {
		var state = ConwayState.deserialize(haxe.Json.stringify({live: [ConwayGrid.keyOf(ROW, COL)], activity: []}));

		Assert.floatEquals(ConwayGrid.YOUNG_BLOCK_HEIGHT, ConwayGrid.groundHeightAt(state, cellTheta(), cellPhi()));
	}

	function testGroundHeightAtIsTheYoungBlockHeightOverAFreshlyAlivePole():Void {
		var state = ConwayState.deserialize(haxe.Json.stringify({live: [ConwayGrid.keyOfPole(North)], activity: []}));

		Assert.floatEquals(ConwayGrid.YOUNG_BLOCK_HEIGHT, ConwayGrid.groundHeightAt(state, 0, 0));
	}

	function testGroundHeightAtIsTheAgedBlockHeightOnceACellIsPastTheYoungAgeThreshold():Void {
		var state = ConwayState.deserialize(haxe.Json.stringify({
			live: [ConwayGrid.keyOf(ROW, COL)],
			activity: [],
			age: [{k: ConwayGrid.keyOf(ROW, COL), v: ConwayGrid.YOUNG_AGE_THRESHOLD + 1}]
		}));

		Assert.floatEquals(ConwayGrid.AGED_BLOCK_HEIGHT, ConwayGrid.groundHeightAt(state, cellTheta(), cellPhi()));
	}

	/** A jump's own apex (`ConwayBiome.GRAVITY`'s own doc, `~5.8`) plus `AGED_BLOCK_HEIGHT` should stay short of `WALL_HEIGHT` — the whole point of an aged cell's own shorter block. **/
	function testAgedBlockHeightPlusAJumpsApexStaysUnderWallHeight():Void {
		var jumpApex = 5.8;

		Assert.isTrue(ConwayGrid.AGED_BLOCK_HEIGHT + jumpApex < ConwayGrid.WALL_HEIGHT,
			'expected AGED_BLOCK_HEIGHT (${ConwayGrid.AGED_BLOCK_HEIGHT}) + a jump\'s apex ($jumpApex) to stay under WALL_HEIGHT (${ConwayGrid.WALL_HEIGHT})');
	}

	/**
		The flip side of the aged check above: `YOUNG_BLOCK_HEIGHT` plus a
		jump's own apex has to actually *clear* `WALL_HEIGHT`, or the whole
		jump-on-a-cell mechanic silently stops working. The margin here is
		deliberately thin (`ConwayGrid.YOUNG_BLOCK_HEIGHT`'s own doc) — this
		is the regression check that would catch it going negative.
	**/
	function testYoungBlockHeightPlusAJumpsApexClearsWallHeight():Void {
		var jumpApex = 5.8;

		Assert.isTrue(ConwayGrid.YOUNG_BLOCK_HEIGHT + jumpApex >= ConwayGrid.WALL_HEIGHT,
			'expected YOUNG_BLOCK_HEIGHT (${ConwayGrid.YOUNG_BLOCK_HEIGHT}) + a jump\'s apex ($jumpApex) to clear WALL_HEIGHT (${ConwayGrid.WALL_HEIGHT})');
	}

	static function cellTheta():Float {
		return Math.PI * (ROW + 1.5) / ConwayGrid.LAT_BANDS;
	}

	static function cellPhi():Float {
		return 2 * Math.PI * (COL + 0.5) / ConwayGrid.COLS;
	}
}
