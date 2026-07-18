package world;

/** Where a traveling NPC currently is — which biome, and where within it. **/
typedef NpcLocation = {
	biomeId:String,
	pos:h3d.Vector
}

/**
	Tracks each traveling NPC's current location — see docs/game-design.md's
	backlog ("cute characters... noir") for the eventual content this is
	for. Fixed/triggered-location only, no background simulation: an NPC's
	location changes only when something explicitly calls `moveTo` (a
	story/quest trigger), never on its own over time — the decision made
	when this restructuring was planned (see the plan discussed with
	hooman).
**/
class NpcRegistry {
	final locations:Map<String, NpcLocation> = [];

	public function new() {}

	/**
		Places (or moves) `npcId` at `biomeId`/`pos`.
		@param npcId the NPC to place.
		@param biomeId the biome it's now in.
		@param pos its position within that biome.
	**/
	public function moveTo(npcId:String, biomeId:String, pos:h3d.Vector):Void {
		locations.set(npcId, {biomeId: biomeId, pos: pos});
	}

	/**
		Where `npcId` currently is.
		@param npcId the NPC to look up.
		@return its current location, or null if it's never been placed.
	**/
	public function locationOf(npcId:String):Null<NpcLocation> {
		return locations.get(npcId);
	}

	/**
		Every NPC currently located in `biomeId` — what a biome's own
		`build()` would use to instantiate the NPCs that belong there, once a
		real NPC `Entity` type exists.
		@param biomeId the biome to find NPCs in.
		@return the ids of every NPC currently placed there.
	**/
	public function npcsIn(biomeId:String):Array<String> {
		return [for (npcId => location in locations) if (location.biomeId == biomeId) npcId];
	}
}
