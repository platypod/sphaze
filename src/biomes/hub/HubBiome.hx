package biomes.hub;

import biomes.common.Biome;
import biomes.common.Gravity;
import biomes.maze.MazeBiome;
import entities.player.PlayerModel;
import entities.painting.PaintingModel;

/**
	The hub — a peer `Biome` like any other (see `biomes.common.Biome`'s own
	class doc), just one that never changes shape and never resumes wherever
	the player left it — a fresh arrival always spawns at the same fixed
	point (see `spawnPlayer`), same as any biome's own non-returning spawn.
	Coming back in through a biome's own exit painting is different: the
	player reappears in front of the hub's own to-biome painting, back
	turned to it, mirroring how a biome's own return spawn (e.g.
	`biomes.maze.MazeBiome.playerInFrontOfExitWall`) puts them in front of
	*its* exit painting rather than back at its own fixed entry point.
**/
class HubBiome implements Biome {
	public static inline final ID:String = "hub";

	/**
		Same first-pass value as the maze's own — kept as its own constant
		rather than a shared one since gravity is deliberately a per-biome
		property (see `biomes.common.Biome.gravity`'s own doc), not shared
		plumbing that happens to read the same today.
	**/
	static inline final GRAVITY:Float = 60;

	public function new() {}

	public function id():String {
		return ID;
	}

	public function gravity():Float {
		return GRAVITY;
	}

	public function build(parent:h3d.scene.Object):Void {
		HubMesh.build(parent);
	}

	/**
		A fresh arrival spawns at the hub's own fixed point
		(`HubModel.SPAWN_THETA`/`SPAWN_PHI`). Returning — walking into a
		biome's own exit painting — instead spawns in front of the hub's own
		to-biome painting, facing away from the column (`facing = 0` is
		already "away from the pole/column" — see `PlayerModel.spawnAt`'s
		own doc on `thetaTangentAt`), so the player's back is turned to the
		painting they just stepped out of rather than reappearing clear
		across the room.
	**/
	public function spawnPlayer(returning:Bool):PlayerModel {
		return returning ? PlayerModel.spawnAt(HubModel.returnSpawnTheta(), HubModel.toBiomeFaceAzimuth(), 0,
			HubModel.RADIUS) : PlayerModel.spawnAt(HubModel.SPAWN_THETA, HubModel.SPAWN_PHI, 0, HubModel.RADIUS);
	}

	public function exitPainting():PaintingModel {
		return HubModel.toBiomePainting(MazeBiome.ID);
	}

	public function tryMove(player:PlayerModel, direction:h3d.Vector, distance:Float):Void {
		HubCollision.tryMove(player, direction, distance);
	}

	public function applyGravity(player:PlayerModel, dt:Float):Void {
		Gravity.fallToSurface(player, GRAVITY, dt);
	}

	/** Nothing worth saving — the hub never changes shape. **/
	public function serialize():String {
		return "{}";
	}

	/** No-op — see `serialize`. **/
	public function restore(json:String):Void {}
}
