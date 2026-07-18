package biomes.common;

import entities.player.PlayerModel;
import world.Painting;

/**
	Contract every biome instance implements — the hub included. `Main`
	talks to whichever biome is current only through this interface, never
	by biome type name: the hub used to be a special-cased second scene kind
	alongside "the maze," even though it already had everything a biome has
	(its own build, its own collision, its own spawn point, its own
	painting) — see docs/PROJECT_LOG.md's restructuring entry. It's a
	particular biome (the always-present navigation hub), not a different
	kind of thing.
**/
interface Biome {
	/** This biome's own registry id (e.g. `"hub"`, `"maze"`) — how paintings and the biome registry refer to it. **/
	function id():String;

	/** This biome's own physical sphere radius — must match whatever this biome's own `Space`/collision math was built against. **/
	function radius():Float;

	/** (Re)builds this biome's meshes under `parent`. Called each time the biome is entered. **/
	function build(parent:h3d.scene.Object):Void;

	/**
		A PlayerModel standing at this biome's own entry point.
		@param returning true if the player is coming back into a biome they
		already visited (e.g. from the hub) rather than a fresh visit — a
		biome may resume near wherever they left, or ignore this and always
		use a fixed spawn (see `biomes.HubBiome`).
		@return the spawned player.
	**/
	function spawnPlayer(returning:Bool):PlayerModel;

	/** This biome's own exit painting, checked each tick against the player's position (see `Main.checkPaintingTrigger`). **/
	function exitPainting():Painting;

	/**
		Attempts to move `player` by `distance` along `direction` through this biome's own collision rule.
		@param player the player to move.
		@param direction unit tangent at `player.pos` to move along.
		@param distance arc length to move; negative moves the opposite way.
	**/
	function tryMove(player:PlayerModel, direction:h3d.Vector, distance:Float):Void;

	/**
		This biome's own state as a JSON string, for `Main`'s E (export) dev
		tool — part of the contract rather than something `Main` reaches for
		via a type-specific downcast, so a future stateful biome doesn't need
		its own special case there. A biome with nothing worth saving (e.g.
		the hub) can just return `"{}"`.
		@return this biome's state as JSON.
	**/
	function serialize():String;

	/**
		Restores this biome's state from JSON produced by `serialize` — the
		inverse, used by `Main`'s L (import) dev tool. A no-op for a biome
		with nothing worth restoring.
		@param json a JSON string produced by `serialize`.
	**/
	function restore(json:String):Void;
}
