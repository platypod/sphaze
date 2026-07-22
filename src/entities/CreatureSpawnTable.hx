package entities;

/**
	Parses a biome's own creature spawn table — which creature types spawn
	there, and how many of each (see docs/GUIDELINES.md §1.4: gameplay
	content lives in external data, not hardcoded in classes). Engine-
	agnostic — a plain JSON string in, parsed entries out, same shape as
	`biomes.maze.MazeGenerator.serialize`/`deserialize` — so it stays testable without
	`hxd.Res` or a scene graph.

	Deliberately not wired into any biome's `build()` yet: there's no actual
	creature `Entity` type to instantiate from an entry, so wiring this in
	now would just be an inert loop with nothing to do. Wire it in once a
	real creature type exists (see docs/game-design/ideas-backlog.md's backlog — "cute
	characters" isn't designed yet) — that's also when this needs an actual
	`res/data/` file and `hxd.Res` loading, not just this parser.
**/
class CreatureSpawnTable {
	/**
		Parses a spawn table from JSON: `{"creatures": [{"creatureType": "...", "count": N}, ...]}`.
		@param json a JSON string in the spawn-table format.
		@return the parsed entries, in file order.
	**/
	public static function parse(json:String):Array<CreatureSpawnEntry> {
		var parsed:{creatures:Array<CreatureSpawnEntry>} = haxe.Json.parse(json);
		return parsed.creatures;
	}
}
