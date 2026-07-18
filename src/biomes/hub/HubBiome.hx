package biomes.hub;

import biomes.common.Biome;
import biomes.common.Gravity;
import biomes.hub.HubStructure.StructureBasis;
import biomes.maze.MazeBiome;
import biomes.tower.TowerBiome;
import entities.player.PlayerModel;
import entities.painting.PaintingModel;

/**
	The hub — a peer `Biome` like any other (see `biomes.common.Biome`'s own
	class doc), just one that never changes shape and never resumes wherever
	the player left it — a fresh arrival always spawns at the same fixed
	point (see `spawnPlayer`). Coming back in through a biome's own exit
	painting is different: the player reappears just outside that biome's
	own landmark structure (`MazeShrine`/`TowerReplica`), facing back toward
	its painting, mirroring how a biome's own return spawn (e.g.
	`biomes.maze.MazeBiome.playerInFrontOfExitWall`) puts them in front of
	*its* exit painting rather than back at its own fixed entry point.

	Each structure is anchored at its own fixed `(theta, phi)` — evenly
	spaced around the equator from each other and from `HubModel.SPAWN_PHI`
	(120 degrees apart) so none crowd each other or the player's own fixed
	arrival point; unlike the hub's former central column, neither anchor
	needs any pole-adjacency at all (see `HubModel`'s own class doc), so
	"anywhere reasonably separated" is the whole placement requirement.
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

	static final MAZE_SHRINE_PHI:Float = 2 * Math.PI / 3;

	static final TOWER_REPLICA_PHI:Float = -2 * Math.PI / 3;

	final mazeShrineBasis:StructureBasis;
	final towerReplicaBasis:StructureBasis;

	public function new() {
		mazeShrineBasis = HubStructure.anchorAt(HubModel.SPAWN_THETA, MAZE_SHRINE_PHI, HubModel.RADIUS);
		towerReplicaBasis = HubStructure.anchorAt(HubModel.SPAWN_THETA, TOWER_REPLICA_PHI, HubModel.RADIUS);
	}

	public function id():String {
		return ID;
	}

	public function gravity():Float {
		return GRAVITY;
	}

	public function build(parent:h3d.scene.Object):Void {
		HubMesh.build(parent, isWalkable);
		MazeShrine.build(parent, mazeShrineBasis, hxd.Res.sprites.painting__biome_maze_01.toTexture());
		TowerReplica.build(parent, towerReplicaBasis, hxd.Res.sprites.painting__biome_tower_01.toTexture());
	}

	/** Whether `pos` is clear of both landmark structures — for `HubMesh`'s own grass scatter, so tufts don't grow inside either one. **/
	function isWalkable(pos:h3d.Vector):Bool {
		return !MazeShrine.blocksMovement(mazeShrineBasis, pos) && !TowerReplica.blocksMovement(towerReplicaBasis, pos);
	}

	/**
		A fresh arrival spawns at the hub's own fixed point
		(`HubModel.SPAWN_THETA`/`SPAWN_PHI`). Returning — walking into a
		biome's own exit painting — instead spawns just outside that biome's
		own structure, facing back toward its painting.
	**/
	public function spawnPlayer(returning:Bool, fromBiomeId:Null<String>):PlayerModel {
		if (!returning) {
			return PlayerModel.spawnAt(HubModel.SPAWN_THETA, HubModel.SPAWN_PHI, 0, HubModel.RADIUS);
		}
		return switch (fromBiomeId) {
			case MazeBiome.ID: MazeShrine.returnSpawn(mazeShrineBasis, HubModel.RADIUS);
			case TowerBiome.ID: TowerReplica.returnSpawn(towerReplicaBasis, HubModel.RADIUS);
			default: throw 'unreachable: no hub structure registered for biome "$fromBiomeId"';
		}
	}

	public function exitPaintings():Array<PaintingModel> {
		return [
			MazeShrine.exitPainting(mazeShrineBasis, MazeBiome.ID),
			TowerReplica.exitPainting(towerReplicaBasis, TowerBiome.ID)
		];
	}

	public function tryMove(player:PlayerModel, direction:h3d.Vector, distance:Float):Void {
		HubCollision.tryMove(player, direction, distance, mazeShrineBasis, towerReplicaBasis);
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
