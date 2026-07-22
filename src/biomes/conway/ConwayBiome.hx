package biomes.conway;

import biomes.common.Biome;
import biomes.common.Gravity;
import biomes.common.grid.GridCollision;
import biomes.common.grid.GridGeometry;
import biomes.common.grid.GridMesh;
import biomes.common.grid.GridModel;
import biomes.common.grid.GridModel.GridData;
import biomes.hub.HubBiome;
import entities.painting.PaintingModel;
import entities.player.PlayerModel;

/**
	Spherical biome with a live Conway simulation:
	dead cells are bare tiles, alive cells are raised blocks.
**/
class ConwayBiome implements Biome {
	public static inline final ID:String = "conway";

	static inline final GRAVITY:Float = 60;
	static inline final STEP_INTERVAL:Float = 0.75;
	static inline final EXIT_ARC_OFFSET:Float = 8;

	static final SPAWN_THETA:Float = Math.PI / 2;
	static final SPAWN_PHI:Float = Math.PI / 3;
	static final SPAWN_FACING:Float = 0.0;

	final openGrid:GridData;
	var state:ConwayState;
	var accumulator:Float = 0;
	var container:Null<h3d.scene.Object>;

	public function new() {
		state = new ConwayState();
		openGrid = buildOpenGrid();
	}

	public function id():String {
		return ID;
	}

	public function gravity():Float {
		return GRAVITY;
	}

	public function backgroundColor():Int {
		return 0x05070D;
	}

	public function build(parent:h3d.scene.Object):Void {
		container = new h3d.scene.Object(parent);
		ConwayMesh.build(container, state);
	}

	public function spawnPlayer(returning:Bool, fromBiomeId:Null<String>):PlayerModel {
		return PlayerModel.spawnAt(SPAWN_THETA, SPAWN_PHI, SPAWN_FACING, GridGeometry.RADIUS);
	}

	public function exitPaintings():Array<PaintingModel> {
		var exitTheta = SPAWN_THETA + EXIT_ARC_OFFSET / GridGeometry.RADIUS;
		var exitPos = GridMesh.cornerAt(exitTheta, SPAWN_PHI);
		return [new PaintingModel(exitPos, HubBiome.ID)];
	}

	public function tryMove(player:PlayerModel, direction:h3d.Vector, distance:Float):Void {
		GridCollision.tryMove(player, direction, distance, GridGeometry.RADIUS, openGrid);
	}

	public function applyGravity(player:PlayerModel, dt:Float):Void {
		Gravity.fallToSurface(player, GRAVITY, dt);
	}

	public function tick(player:PlayerModel, dt:Float):Void {
		accumulator += dt;
		var stepped = false;
		while (accumulator >= STEP_INTERVAL) {
			accumulator -= STEP_INTERVAL;
			state.step();
			stepped = true;
		}
		if (!stepped || container == null) {
			return;
		}
		container.removeChildren();
		ConwayMesh.build(container, state);
	}

	public function timeScale():Float {
		return 1;
	}

	public function serialize():String {
		return haxe.Json.stringify({
			state: state.serialize(),
			accumulator: accumulator,
		});
	}

	public function restore(json:String):Void {
		var parsed:Dynamic = haxe.Json.parse(json);
		state = ConwayState.deserialize(Std.string(parsed.state));
		var restoredAccumulator = Std.parseFloat(Std.string(parsed.accumulator));
		accumulator = Math.isNaN(restoredAccumulator) ? 0 : restoredAccumulator;
		if (container != null) {
			container.removeChildren();
			ConwayMesh.build(container, state);
		}
	}

	static function buildOpenGrid():GridData {
		var edges = new haxe.ds.StringMap<Bool>();
		for (node in GridModel.allNodes()) {
			for (neighbor in GridModel.neighborsOf(node)) {
				edges.set(GridModel.edgeKey(node, neighbor), true);
			}
		}
		return {openEdges: edges};
	}
}
