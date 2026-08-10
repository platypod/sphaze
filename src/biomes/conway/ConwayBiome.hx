package biomes.conway;

import biomes.common.Biome;
import biomes.common.Gravity;
import biomes.common.space.sphere.SphereMath;
import biomes.conway.ConwayMaze.ConwayMazeData;
import biomes.hub.HubBiome;
import entities.painting.PaintingModel;
import entities.player.PlayerModel;

/**
	Spherical biome with a live Conway simulation: dead cells are bare tiles,
	alive cells are raised blocks. The maze underneath isn't static either —
	see `ConwayMazeReactivity`: its spanning tree stays fixed, but population
	activity opens and closes the shortcut edges around it every generation.
**/
class ConwayBiome implements Biome {
	public static inline final ID:String = "conway";

	/**
		Lowered from the hub/maze's shared `60` (hooman, directly: "add a
		hitbox to the cells, so the player can jump on a cell, and from
		there, jump over a wall") — a jump's own apex is
		`game.GameLoop.JUMP_IMPULSE² / (2 * GRAVITY)` (same formula
		`biomes.hub.MazeShrine`'s own doc cites), `18² / (2 * 28) ≈ 5.8` at
		this value. A second jump from a freshly-born cell's own top
		(`ConwayGrid.YOUNG_BLOCK_HEIGHT`, `2`) reaches `2 + 5.8 ≈ 7.8`,
		just over `ConwayGrid.WALL_HEIGHT` (`7.5`) — see that constant's
		own doc for why that margin is thinner than it'd ideally be. An
		aged cell's own `ConwayGrid.AGED_BLOCK_HEIGHT` (`1.5`) deliberately
		falls short of the same clearance (`1.5 + 5.8 ≈ 7.3 < 7.5`). `60`
		alone only reaches `2.7` —
		nowhere near a block's own top, let alone a wall's. Public so
		`tools.geodesic.GeodesicConwayBiome` can reuse this exact derivation
		rather than re-deriving the same jump-clearance math against its own
		`GeodesicLifecycle.WALL_HEIGHT` (identical numeric value, ported
		directly — see that constant's own doc).
	**/
	public static inline final GRAVITY:Float = 28;

	/** Public for the same reason `GRAVITY` is — `GeodesicConwayBiome` reuses this rather than re-hardcoding the same literal a second place. **/
	public static inline final BACKGROUND_COLOR:Int = 0x05070D;

	static inline final STEP_INTERVAL:Float = 0.75;
	static inline final EXIT_ARC_OFFSET:Float = 16;

	static final SPAWN_THETA:Float = Math.PI / 2;
	static final SPAWN_PHI:Float = Math.PI / 3;
	static final SPAWN_FACING:Float = 0.0;

	var state:ConwayState;
	var maze:ConwayMazeData;
	var accumulator:Float = 0;
	var container:Null<h3d.scene.Object>;

	public function new() {
		maze = ConwayMaze.generate();
		state = new ConwayState();
	}

	public function id():String {
		return ID;
	}

	public function gravity():Float {
		return GRAVITY;
	}

	public function backgroundColor():Int {
		return BACKGROUND_COLOR;
	}

	public function build(parent:h3d.scene.Object):Void {
		container = new h3d.scene.Object(parent);
		ConwayMesh.build(container, state, maze);
	}

	public function spawnPlayer(returning:Bool, fromBiomeId:Null<String>):PlayerModel {
		return PlayerModel.spawnAt(SPAWN_THETA, SPAWN_PHI, SPAWN_FACING, ConwayGrid.RADIUS);
	}

	public function exitPaintings():Array<PaintingModel> {
		var exitTheta = SPAWN_THETA + EXIT_ARC_OFFSET / ConwayGrid.RADIUS;
		var exitPos = ConwayGrid.cornerAt(exitTheta, SPAWN_PHI);
		return [new PaintingModel(exitPos, HubBiome.ID)];
	}

	public function tryMove(player:PlayerModel, direction:h3d.Vector, distance:Float):Void {
		ConwayCollision.tryMove(player, direction, distance, ConwayGrid.RADIUS, maze);
	}

	/**
		Falls toward whatever's directly below `player` — the bare surface
		everywhere except over a currently-alive cell, where it's that
		cell's own top (`ConwayGrid.groundHeightAt`) instead, so a player
		who's jumped up there actually lands and stands rather than falling
		straight through. Recomputed fresh every tick from `player.pos`
		alone (never cached): a cell dying out from under a standing player
		drops them, same as the hub's own `MazeShrine.wallTopHeightAt`
		pattern this mirrors, just over a live cell instead of a fixed wall.
	**/
	public function applyGravity(player:PlayerModel, dt:Float):Void {
		var groundHeight = ConwayGrid.groundHeightAt(state, SphereMath.thetaOf(player.pos), SphereMath.phiOf(player.pos));
		Gravity.fallToSurface(player, GRAVITY, dt, groundHeight);
	}

	public function tick(player:PlayerModel, dt:Float):Void {
		accumulator += dt;
		var stepped = false;
		while (accumulator >= STEP_INTERVAL) {
			accumulator -= STEP_INTERVAL;
			state.step(maze);
			var playerNode = ConwayGrid.nodeAt(SphereMath.thetaOf(player.pos), SphereMath.phiOf(player.pos));
			ConwayMazeReactivity.step(maze, state, playerNode);
			stepped = true;
		}
		if (!stepped || container == null) {
			return;
		}
		container.removeChildren();
		ConwayMesh.build(container, state, maze);
	}

	/** Nothing to interact with here — see `biomes.common.Biome.interact`'s own doc. **/
	public function interact(player:PlayerModel):Void {}

	/** No camera override here — see `biomes.common.Biome.cameraOverride`'s own doc. **/
	public function cameraOverride(player:PlayerModel):Null<entities.player.Camera.CameraOverride> {
		return null;
	}

	/** Nothing to click on here — see `biomes.common.Biome.onEditClick`'s own doc. **/
	public function onEditClick(ray:h3d.col.Ray):Void {}

	public function timeScale():Float {
		return 1;
	}

	public function serialize():String {
		return haxe.Json.stringify({
			maze: ConwayMaze.serialize(maze),
			state: state.serialize(),
			accumulator: accumulator,
		});
	}

	public function restore(json:String):Void {
		var parsed:Dynamic = haxe.Json.parse(json);
		maze = parsed.maze == null ? ConwayMaze.generate() : ConwayMaze.deserialize(Std.string(parsed.maze));
		state = ConwayState.deserialize(Std.string(parsed.state));
		var restoredAccumulator = Std.parseFloat(Std.string(parsed.accumulator));
		accumulator = Math.isNaN(restoredAccumulator) ? 0 : restoredAccumulator;
		if (container != null) {
			container.removeChildren();
			ConwayMesh.build(container, state, maze);
		}
	}
}
