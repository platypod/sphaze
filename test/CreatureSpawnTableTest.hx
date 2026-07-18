import utest.Test;
import utest.Assert;
import entities.CreatureSpawnTable;

/** Covers CreatureSpawnTable's JSON parsing — see docs/GUIDELINES.md §1.4/§5.4 (data parsing, not rendering, is the testable target here). **/
class CreatureSpawnTableTest extends Test {
	function testParsesEntriesInFileOrder():Void {
		var entries = CreatureSpawnTable.parse('{"creatures": [{"creatureType": "raven", "count": 3}, {"creatureType": "cat", "count": 1}]}');

		Assert.equals(2, entries.length);
		Assert.equals("raven", entries[0].creatureType);
		Assert.equals(3, entries[0].count);
		Assert.equals("cat", entries[1].creatureType);
		Assert.equals(1, entries[1].count);
	}

	function testParsesAnEmptyTable():Void {
		var entries = CreatureSpawnTable.parse('{"creatures": []}');

		Assert.equals(0, entries.length);
	}
}
