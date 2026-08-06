package biomes.conway;

import utest.Assert;
import utest.Test;

class ConwaySeedLibraryTest extends Test {
	function testRotatedPreservesCellCount():Void {
		for (pattern in ConwaySeedLibrary.ALL) {
			for (turns in 0...4) {
				Assert.equals(pattern.length, ConwaySeedLibrary.rotated(pattern, turns).length);
			}
		}
	}

	function testRotatedFourTimesReturnsToTheOriginalShape():Void {
		for (pattern in ConwaySeedLibrary.ALL) {
			Assert.same(normalized(pattern), normalized(ConwaySeedLibrary.rotated(pattern, 4)));
		}
	}

	/** Every rotation's own top-left corner sits back at (0, 0) — no cell should end up at a negative offset. **/
	function testRotatedStaysNormalizedToItsOwnTopLeftCorner():Void {
		for (pattern in ConwaySeedLibrary.ALL) {
			for (turns in 0...4) {
				var rotated = ConwaySeedLibrary.rotated(pattern, turns);
				var minRow = 0;
				var minCol = 0;
				for (cell in rotated) {
					if (cell.row < minRow) {
						minRow = cell.row;
					}
					if (cell.col < minCol) {
						minCol = cell.col;
					}
				}
				Assert.equals(0, minRow);
				Assert.equals(0, minCol);
			}
		}
	}

	function testRotatedByANegativeCountMatchesItsPositiveEquivalent():Void {
		for (pattern in ConwaySeedLibrary.ALL) {
			Assert.same(normalized(ConwaySeedLibrary.rotated(pattern, -1)), normalized(ConwaySeedLibrary.rotated(pattern, 3)));
		}
	}

	static function normalized(cells:Array<{row:Int, col:Int}>):Array<String> {
		var keys = [for (cell in cells) '${cell.row}:${cell.col}'];
		keys.sort(Reflect.compare);
		return keys;
	}
}
