package entities.registries;

import utest.Test;
import utest.Assert;

/** Covers CreaturesRegistry's location bookkeeping — no scene graph or real creature content involved. **/
class CreaturesRegistryTest extends Test {
	function testLocationOfIsNullForACreatureNeverSpawned():Void {
		var registry = new CreaturesRegistry();

		Assert.isNull(registry.locationOf("cat-1"));
	}

	function testSpawnPlacesACreatureAtABiomeAndPosition():Void {
		var registry = new CreaturesRegistry();
		var pos = new h3d.Vector(1, 2, 3);

		registry.spawn("cat-1", "hub", pos);

		var location = registry.locationOf("cat-1");
		Assert.notNull(location);
		Assert.equals("hub", location.biomeId);
		Assert.equals(pos, location.pos);
	}

	function testSpawnAgainReplacesThePreviousLocation():Void {
		var registry = new CreaturesRegistry();
		registry.spawn("cat-1", "hub", new h3d.Vector(0, 0, 0));

		registry.spawn("cat-1", "maze", new h3d.Vector(1, 1, 1));

		Assert.equals("maze", registry.locationOf("cat-1").biomeId);
	}

	function testCreaturesInReturnsOnlyCreaturesCurrentlyInThatBiome():Void {
		var registry = new CreaturesRegistry();
		registry.spawn("cat-1", "hub", new h3d.Vector(0, 0, 0));
		registry.spawn("cat-2", "maze", new h3d.Vector(0, 0, 0));

		var inHub = registry.creaturesIn("hub");

		Assert.equals(1, inHub.length);
		Assert.equals("cat-1", inHub[0]);
	}

	function testCreaturesInReturnsEmptyForABiomeWithNoCreatures():Void {
		var registry = new CreaturesRegistry();

		Assert.equals(0, registry.creaturesIn("hub").length);
	}

	function testRemoveDeletesTheCreatureEntirely():Void {
		var registry = new CreaturesRegistry();
		registry.spawn("cat-1", "hub", new h3d.Vector(0, 0, 0));

		registry.remove("cat-1");

		Assert.isNull(registry.locationOf("cat-1"));
		Assert.equals(0, registry.creaturesIn("hub").length);
	}
}
