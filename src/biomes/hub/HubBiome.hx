package biomes.hub;

import biomes.common.Biome;
import biomes.maze.MazeBiome;
import entities.player.PlayerModel;
import world.Painting;

/**
	The hub — a peer `Biome` like any other (see `biomes.common.Biome`'s own
	class doc), just one that never changes shape and always spawns at the
	same fixed point rather than resuming wherever the player left it.
**/
class HubBiome implements Biome {
	public static inline final ID:String = "hub";

	public function new() {}

	public function id():String {
		return ID;
	}

	public function radius():Float {
		return HubModel.RADIUS;
	}

	public function build(parent:h3d.scene.Object):Void {
		HubMesh.build(parent);
	}

	public function spawnPlayer(returning:Bool):PlayerModel {
		return PlayerModel.spawnAt(HubModel.SPAWN_THETA, HubModel.SPAWN_PHI, 0, HubModel.RADIUS);
	}

	public function exitPainting():Painting {
		return HubModel.toBiomePainting(MazeBiome.ID);
	}

	public function tryMove(player:PlayerModel, direction:h3d.Vector, distance:Float):Void {
		HubCollision.tryMove(player, direction, distance);
	}

	/** Nothing worth saving — the hub never changes shape. **/
	public function serialize():String {
		return "{}";
	}

	/** No-op — see `serialize`. **/
	public function restore(json:String):Void {}
}
