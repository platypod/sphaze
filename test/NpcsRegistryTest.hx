import utest.Test;
import utest.Assert;
import entities.registries.NpcsRegistry;

/** Covers NpcsRegistry's location bookkeeping — no scene graph or real NPC content involved. **/
class NpcsRegistryTest extends Test {
	function testLocationOfIsNullForAnNpcNeverPlaced():Void {
		var registry = new NpcsRegistry();

		Assert.isNull(registry.locationOf("raven"));
	}

	function testMoveToPlacesAnNpcAtABiomeAndPosition():Void {
		var registry = new NpcsRegistry();
		var pos = new h3d.Vector(1, 2, 3);

		registry.moveTo("raven", "hub", pos);

		var location = registry.locationOf("raven");
		Assert.notNull(location);
		Assert.equals("hub", location.biomeId);
		Assert.equals(pos, location.pos);
	}

	function testMoveToAgainReplacesThePreviousLocation():Void {
		var registry = new NpcsRegistry();
		registry.moveTo("raven", "hub", new h3d.Vector(0, 0, 0));

		registry.moveTo("raven", "maze", new h3d.Vector(1, 1, 1));

		Assert.equals("maze", registry.locationOf("raven").biomeId);
	}

	function testNpcsInReturnsOnlyNpcsCurrentlyInThatBiome():Void {
		var registry = new NpcsRegistry();
		registry.moveTo("raven", "hub", new h3d.Vector(0, 0, 0));
		registry.moveTo("cat", "maze", new h3d.Vector(0, 0, 0));

		var inHub = registry.npcsIn("hub");

		Assert.equals(1, inHub.length);
		Assert.equals("raven", inHub[0]);
	}

	function testNpcsInReturnsEmptyForABiomeWithNoNpcs():Void {
		var registry = new NpcsRegistry();

		Assert.equals(0, registry.npcsIn("hub").length);
	}
}
