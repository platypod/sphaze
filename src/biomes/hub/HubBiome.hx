package biomes.hub;

import biomes.common.Biome;
import biomes.common.Gravity;
import biomes.hub.HubStructure.StructureBasis;
import biomes.maze.MazeBiome;
import biomes.tower.TowerBiome;
import entities.hourglass.Hourglass;
import entities.hourglass.HourglassModel;
import entities.player.PlayerModel;
import entities.painting.PaintingModel;

/**
	The hub — a peer `Biome` like any other (see `biomes.common.Biome`'s own
	class doc), just one that never changes shape and never resumes wherever
	the player left it — a fresh arrival always spawns at the same fixed
	point (see `spawnPlayer`). Coming back in through a biome's own exit
	painting is different: the player reappears just outside that biome's
	own landmark structure (`MazeShrine`/`TowerReplica`), facing *away* from
	it into the open hub — the same direction they'd already be facing had
	they simply kept walking straight through the painting, not turned
	back around to face the thing they just came out of (see either
	structure's own `returnSpawn` for why that distinction actually
	matters) — mirroring how a biome's own return spawn (e.g.
	`biomes.maze.MazeBiome.playerInFrontOfExitWall`) puts them in front of
	*its* exit painting facing into the room, not back at the wall.

	Each structure is anchored at its own fixed `(theta, phi)` — evenly
	spaced around the equator from each other and from `HubModel.SPAWN_PHI`
	(120 degrees apart) so none crowd each other or the player's own fixed
	arrival point; unlike the hub's former central column, neither anchor
	needs any pole-adjacency at all (see `HubModel`'s own class doc), so
	"anywhere reasonably separated" is the whole placement requirement.
	`Hourglass` isn't placed this way — see `HOURGLASS_ARC_OFFSET`'s own doc
	for why.
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

	/**
		Directly ahead of the fixed spawn point (same `phi`, further along
		increasing `theta` — the direction a fresh arrival's own default
		facing points, see `PlayerModel.spawnAt`'s `facing = 0` case) rather
		than another 120-degree slot: unlike `MazeShrine`/`TowerReplica`,
		this isn't a to-biome portal that needs even spacing from the other
		two, just a landmark worth seeing immediately on arrival.
		`HOURGLASS_ARC_OFFSET / RADIUS` converts a plain "how many units
		ahead" distance into the matching `theta` delta.
	**/
	static final HOURGLASS_ARC_OFFSET:Float = 18;

	static final HOURGLASS_THETA:Float = HubModel.SPAWN_THETA + HOURGLASS_ARC_OFFSET / HubModel.RADIUS;

	final mazeShrineBasis:StructureBasis;
	final towerReplicaBasis:StructureBasis;
	final hourglassBasis:StructureBasis;
	final hourglassModel:HourglassModel = new HourglassModel();

	/** Rebuilt every tick by `tick` — see `Hourglass`'s own class doc for why everything above the pedestal rebuilds fresh each time rather than animating in place. **/
	var hourglassContainer:h3d.scene.Object;

	public function new() {
		mazeShrineBasis = HubStructure.anchorAt(HubModel.SPAWN_THETA, MAZE_SHRINE_PHI, HubModel.RADIUS);
		towerReplicaBasis = HubStructure.anchorAt(HubModel.SPAWN_THETA, TOWER_REPLICA_PHI, HubModel.RADIUS);
		hourglassBasis = HubStructure.anchorAt(HOURGLASS_THETA, HubModel.SPAWN_PHI, HubModel.RADIUS);
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

		Hourglass.build(parent, hourglassBasis);
		hourglassContainer = new h3d.scene.Object(parent);
		Hourglass.buildDynamic(hourglassContainer, hourglassBasis, hourglassModel);
	}

	/** Whether `pos` is clear of all three landmark structures — for `HubMesh`'s own grass scatter, so tufts don't grow inside any of them. **/
	function isWalkable(pos:h3d.Vector):Bool {
		return !MazeShrine.blocksMovement(mazeShrineBasis, pos)
			&& !TowerReplica.blocksMovement(towerReplicaBasis, pos)
			&& !Hourglass.blocksMovement(hourglassBasis, pos);
	}

	/**
		A fresh arrival spawns at the hub's own fixed point
		(`HubModel.SPAWN_THETA`/`SPAWN_PHI`). Returning — walking into a
		biome's own exit painting — instead spawns just outside that biome's
		own structure, facing away from it into the open hub.
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
		HubCollision.tryMove(player, direction, distance, mazeShrineBasis, towerReplicaBasis, hourglassBasis);
	}

	public function applyGravity(player:PlayerModel, dt:Float):Void {
		Gravity.fallToSurface(player, GRAVITY, dt);
	}

	/**
		Advances the hourglass by one real (unscaled) tick — see
		`biomes.common.Biome.tick`'s own doc for why `dt` here is never
		scaled by `timeScale()` — then rebuilds its mesh to match (see
		`Hourglass`'s own class doc for why that's a fresh rebuild each
		tick rather than an animated transform).
	**/
	public function tick(player:PlayerModel, dt:Float):Void {
		hourglassModel.tick(dt, Hourglass.triggerSide(hourglassBasis, player.pos));
		hourglassContainer.removeChildren();
		Hourglass.buildDynamic(hourglassContainer, hourglassBasis, hourglassModel);
	}

	/** The hourglass's own current game-speed multiplier — see `HourglassModel.timeScale`'s own doc. **/
	public function timeScale():Float {
		return hourglassModel.timeScale();
	}

	/** Nothing worth saving — the hub never changes shape. **/
	public function serialize():String {
		return "{}";
	}

	/** No-op — see `serialize`. **/
	public function restore(json:String):Void {}
}
