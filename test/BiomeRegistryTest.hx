import utest.Test;
import utest.Assert;
import world.BiomeRegistry;
import world.Painting;
import entities.Player;
import game.Biome;

/** Covers BiomeRegistry's lookup/discovery bookkeeping — a stub Biome, not a real one, since none of this depends on rendering/collision. **/
class BiomeRegistryTest extends Test {
	function testGetReturnsTheRegisteredBiome():Void {
		var registry = new BiomeRegistry();
		var biome = new StubBiome("stub");

		registry.register(biome);

		Assert.equals(biome, registry.get("stub"));
	}

	function testGetReturnsNullForAnUnregisteredId():Void {
		var registry = new BiomeRegistry();

		Assert.isNull(registry.get("nope"));
	}

	function testRegisteredBiomeStartsUndiscoveredByDefault():Void {
		var registry = new BiomeRegistry();
		registry.register(new StubBiome("stub"));

		Assert.isFalse(registry.isDiscovered("stub"));
	}

	function testRegisterCanStartABiomeAlreadyDiscovered():Void {
		// The hub's own case: always known, not something to stumble into.
		var registry = new BiomeRegistry();
		registry.register(new StubBiome("hub"), true);

		Assert.isTrue(registry.isDiscovered("hub"));
	}

	function testMarkDiscoveredFlipsAnUndiscoveredBiome():Void {
		var registry = new BiomeRegistry();
		registry.register(new StubBiome("stub"));

		registry.markDiscovered("stub");

		Assert.isTrue(registry.isDiscovered("stub"));
	}

	function testIsDiscoveredIsFalseForAnUnregisteredId():Void {
		var registry = new BiomeRegistry();

		Assert.isFalse(registry.isDiscovered("nope"));
	}
}

/** Minimal Biome stand-in — BiomeRegistry only cares about id()/storage, never the scene/collision methods. **/
private class StubBiome implements Biome {
	final biomeId:String;

	public function new(biomeId:String) {
		this.biomeId = biomeId;
	}

	public function id():String {
		return biomeId;
	}

	public function radius():Float {
		return 1;
	}

	public function build(parent:h3d.scene.Object):Void {}

	public function spawnPlayer(returning:Bool):Player {
		return Player.spawnAt(0, 0, 0, 1);
	}

	public function exitPainting():Painting {
		return new Painting(new h3d.Vector(0, 0, 0), "nowhere");
	}

	public function tryMove(player:Player, direction:h3d.Vector, distance:Float):Void {}
}
