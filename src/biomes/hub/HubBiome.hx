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

	/**
		Every biome reachable from the hub, and which of the column's own
		faces each one mounts its painting on — the one place that actually
		knows which face leads where; `HubModel`/`HubMesh` just take a face
		index or a list of them, staying biome-agnostic (see their own
		class docs). Face indices are arbitrary, just distinct.
	**/
	static final DESTINATIONS:Array<{faceIndex:Int, biomeId:String}> = [{faceIndex: 0, biomeId: MazeBiome.ID}];

	public function new() {}

	public function id():String {
		return ID;
	}

	public function gravity():Float {
		return GRAVITY;
	}

	public function build(parent:h3d.scene.Object):Void {
		HubMesh.build(parent, [for (destination in DESTINATIONS) destination.faceIndex]);
	}

	/**
		A fresh arrival spawns at the hub's own fixed point
		(`HubModel.SPAWN_THETA`/`SPAWN_PHI`). Returning — walking into a
		biome's own exit painting — instead spawns in front of *that*
		biome's own face on the column (`fromBiomeId` picks which one via
		`DESTINATIONS`), facing away from the column (`facing = 0` is already
		"away from the pole/column" — see `PlayerModel.spawnAt`'s own doc on
		`thetaTangentAt`), so the player's back is turned to the painting
		they just stepped out of rather than reappearing clear across the
		room.
	**/
	public function spawnPlayer(returning:Bool, fromBiomeId:Null<String>):PlayerModel {
		if (!returning) {
			return PlayerModel.spawnAt(HubModel.SPAWN_THETA, HubModel.SPAWN_PHI, 0, HubModel.RADIUS);
		}
		if (fromBiomeId == null) {
			throw "unreachable: fromBiomeId is always non-null when returning is true (see Biome.spawnPlayer's own doc)";
		}
		var faceIndex = faceIndexFor(fromBiomeId);
		return PlayerModel.spawnAt(HubModel.returnSpawnTheta(), HubModel.toBiomeFaceAzimuth(faceIndex), 0, HubModel.RADIUS);
	}

	public function exitPaintings():Array<PaintingModel> {
		return [
			for (destination in DESTINATIONS) HubModel.toBiomePainting(destination.faceIndex, destination.biomeId)
		];
	}

	/**
		Which column face `biomeId` mounts its painting on, per `DESTINATIONS`.
		@param biomeId the `Biome.id()` to look up.
		@return that biome's own face index.
	**/
	static function faceIndexFor(biomeId:String):Int {
		for (destination in DESTINATIONS) {
			if (destination.biomeId == biomeId) {
				return destination.faceIndex;
			}
		}
		throw 'unreachable: no hub face registered for biome "$biomeId"';
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
