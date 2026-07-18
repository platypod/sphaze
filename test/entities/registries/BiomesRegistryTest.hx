package entities.registries;

import utest.Test;
import utest.Assert;
import entities.painting.PaintingModel;
import entities.player.PlayerModel;
import biomes.common.Biome;

/** Covers BiomesRegistry's lookup/discovery bookkeeping — a stub Biome, not a real one, since none of this depends on rendering/collision. **/
class BiomesRegistryTest extends Test {
	function testGetReturnsTheRegisteredBiome():Void {
		var registry = new BiomesRegistry();
		var biome = new StubBiome("stub");

		registry.register(biome);

		Assert.equals(biome, registry.get("stub"));
	}

	function testGetReturnsNullForAnUnregisteredId():Void {
		var registry = new BiomesRegistry();

		Assert.isNull(registry.get("nope"));
	}

	function testRegisteredBiomeStartsUndiscoveredByDefault():Void {
		var registry = new BiomesRegistry();
		registry.register(new StubBiome("stub"));

		Assert.isFalse(registry.isDiscovered("stub"));
	}

	function testRegisterCanStartABiomeAlreadyDiscovered():Void {
		// The hub's own case: always known, not something to stumble into.
		var registry = new BiomesRegistry();
		registry.register(new StubBiome("hub"), true);

		Assert.isTrue(registry.isDiscovered("hub"));
	}

	function testMarkDiscoveredFlipsAnUndiscoveredBiome():Void {
		var registry = new BiomesRegistry();
		registry.register(new StubBiome("stub"));

		registry.markDiscovered("stub");

		Assert.isTrue(registry.isDiscovered("stub"));
	}

	function testIsDiscoveredIsFalseForAnUnregisteredId():Void {
		var registry = new BiomesRegistry();

		Assert.isFalse(registry.isDiscovered("nope"));
	}
}

/** Minimal Biome stand-in — BiomesRegistry only cares about id()/storage, never the scene/collision methods. **/
private class StubBiome implements Biome {
	final biomeId:String;

	public function new(biomeId:String) {
		this.biomeId = biomeId;
	}

	public function id():String {
		return biomeId;
	}

	public function gravity():Float {
		return 60;
	}

	public function build(parent:h3d.scene.Object):Void {}

	public function spawnPlayer(returning:Bool, fromBiomeId:Null<String>):PlayerModel {
		return PlayerModel.spawnAt(0, 0, 0, 1);
	}

	public function exitPaintings():Array<PaintingModel> {
		return [new PaintingModel(new h3d.Vector(0, 0, 0), "nowhere")];
	}

	public function tryMove(player:PlayerModel, direction:h3d.Vector, distance:Float):Void {}

	public function applyGravity(player:PlayerModel, dt:Float):Void {}

	public function serialize():String {
		return "{}";
	}

	public function restore(json:String):Void {}
}
