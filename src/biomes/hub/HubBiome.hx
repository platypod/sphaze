package biomes.hub;

import biomes.maze.MazeBiome;
import entities.Player;
import game.Biome;
import world.Painting;

/**
	The hub — a peer `Biome` like any other (see `game.Biome`'s own class
	doc), just one that never changes shape and always spawns at the same
	fixed point rather than resuming wherever the player left it.
**/
class HubBiome implements Biome {
	public static inline final ID:String = "hub";

	public function new() {}

	public function id():String {
		return ID;
	}

	public function radius():Float {
		return Hub.RADIUS;
	}

	public function build(parent:h3d.scene.Object):Void {
		Hub.build(parent);
	}

	public function spawnPlayer(returning:Bool):Player {
		return Player.spawnAt(Hub.SPAWN_THETA, Hub.SPAWN_PHI, 0, Hub.RADIUS);
	}

	public function exitPainting():Painting {
		return Hub.toBiomePainting(MazeBiome.ID);
	}

	public function tryMove(player:Player, direction:h3d.Vector, distance:Float):Void {
		HubCollision.tryMove(player, direction, distance);
	}
}
