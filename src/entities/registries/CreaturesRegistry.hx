package entities.registries;

/** Where a spawned creature instance currently is — mirrors NpcsRegistry's own shape (see its doc), for creature instances rather than named NPCs. **/
typedef CreatureLocation = {
	biomeId:String,
	pos:h3d.Vector
}

/**
	Tracks currently-spawned creature instances — the runtime counterpart to
	`entities.CreatureSpawnTable`'s config (which creature types *can* spawn
	where, and how many). Not wired to anything yet: there's no real
	creature `Entity` type to instantiate from a spawn-table entry, so this
	stays empty bookkeeping until one exists (see `CreatureSpawnTable`'s own
	doc for the same reasoning).

	Unlike `NpcsRegistry` (persistent named individuals), a spawned creature
	can be removed entirely — defeated, or collected — rather than just
	relocated, hence `remove` existing here with no `NpcsRegistry` analog.
**/
class CreaturesRegistry {
	final locations:Map<String, CreatureLocation> = [];

	public function new() {}

	/**
		Places (or moves) `creatureId` at `biomeId`/`pos`.
		@param creatureId the creature instance to place.
		@param biomeId the biome it's now in.
		@param pos its position within that biome.
	**/
	public function spawn(creatureId:String, biomeId:String, pos:h3d.Vector):Void {
		locations.set(creatureId, {biomeId: biomeId, pos: pos});
	}

	/**
		Where `creatureId` currently is.
		@param creatureId the creature instance to look up.
		@return its current location, or null if it's never been spawned (or has been removed).
	**/
	public function locationOf(creatureId:String):Null<CreatureLocation> {
		return locations.get(creatureId);
	}

	/**
		Every creature instance currently located in `biomeId` — what a
		biome's own `build()` would use to instantiate the creatures that
		belong there, once a real creature `Entity` type exists.
		@param biomeId the biome to find creature instances in.
		@return the ids of every creature instance currently placed there.
	**/
	public function creaturesIn(biomeId:String):Array<String> {
		return [
			for (creatureId => location in locations)
				if (location.biomeId == biomeId) creatureId
		];
	}

	/**
		Removes `creatureId` entirely — defeated, or collected — rather than
		relocating it.
		@param creatureId the creature instance to remove.
	**/
	public function remove(creatureId:String):Void {
		locations.remove(creatureId);
	}
}
