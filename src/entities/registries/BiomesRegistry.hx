package entities.registries;

import biomes.common.Biome;

/**
	Every biome that exists, keyed by `Biome.id()`, plus whether the player
	has discovered it yet — closes the "discovered biomes" gap
	`docs/PROJECT_LOG.md`'s 2026-07-17 entry already flagged. A single
	shared instance per biome id, not one per player/party: a world has
	exactly one hub, one maze, etc., not a regenerated-per-visitor copy (see
	the restructuring plan discussed with hooman).
**/
class BiomesRegistry {
	final biomes:Map<String, Biome> = [];
	final discovered:Map<String, Bool> = [];

	public function new() {}

	/**
		Registers `biome` under its own id.
		@param biome the biome to register.
		@param alreadyDiscovered whether this biome starts out already discovered — true for the hub (it's home, not something to stumble into), false for everything else by default.
	**/
	public function register(biome:Biome, alreadyDiscovered:Bool = false):Void {
		biomes.set(biome.id(), biome);
		discovered.set(biome.id(), alreadyDiscovered);
	}

	/**
		The biome registered under `id`.
		@param id the biome id to look up.
		@return the biome, or null if nothing is registered under that id.
	**/
	public function get(id:String):Null<Biome> {
		return biomes.get(id);
	}

	/**
		Marks `id` as discovered — called whenever the player actually enters
		a biome (see `GameLoop.enterBiome`), not at registration time, so a
		freshly-registered biome (other than the hub) starts undiscovered.
		@param id the biome id to mark discovered.
	**/
	public function markDiscovered(id:String):Void {
		discovered.set(id, true);
	}

	/**
		Whether `id` has been discovered yet.
		@param id the biome id to check.
		@return true if `id` was registered already-discovered, or has been entered at least once since.
	**/
	public function isDiscovered(id:String):Bool {
		return discovered.get(id) == true;
	}
}
