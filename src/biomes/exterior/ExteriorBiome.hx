package biomes.exterior;

import biomes.common.Biome;
import biomes.common.Gravity;
import biomes.common.grid.GridCollision;
import biomes.common.grid.GridGeometry;
import biomes.common.grid.GridMesh;
import biomes.common.grid.GridModel.GridData;
import biomes.common.maze.MazeStyle;
import biomes.common.space.sphere.SphereExteriorSpace;
import biomes.common.space.sphere.SphereMath;
import biomes.hub.HubBiome;
import biomes.maze.MazeExitWall;
import biomes.maze.MazeExitWall.FoundWall;
import biomes.maze.MazeGenerator;
import entities.painting.PaintingModel;
import entities.player.PlayerModel;

/**
	The same maze, walked on the **outside** of the sphere — the deliberate
	inversion of the game's whole hook. Raise your head here and there is
	nothing to see: the surface curves away below the horizon instead of
	wrapping over you, so the far side is not merely hard to read, it's
	geometrically absent. Everything the player has learned about surveying
	from a distance stops applying, and the maze has to be solved locally.

	That makes it the one biome in this file's family that's worth exactly one
	appearance, used as a revelation rather than developed: a permanent
	"outside" biome would just be a normal maze with a nice skybox. Parked as
	such rather than designed further — see
	`docs/game-design/ideas-backlog.md`.

	Structurally it cost almost nothing, which was the interesting part. It
	reuses `GridModel`/`GridGeometry`/`GridCollision` untouched, because that
	code works in theta/phi and doesn't care which side of the shell the player
	is on; the entire inversion is two sign flips —
	`biomes.common.space.sphere.SphereExteriorSpace`'s own "up", which the
	camera, gravity, turning and strafing all follow automatically, and
	`GridMesh.build`'s own `wallsOutward`, so walls rise away from the centre
	instead of into it.

	Carved with `MazeStyle.RandomizedPrim`: a perfect maze (a dead end still
	*proves* a wrong branch) with many short dead ends, so the player gets
	frequent local feedback — which is the only feedback available in here. A
	braided layout would remove even that, and this biome takes enough away
	already.
**/
class ExteriorBiome implements Biome {
	public static inline final ID:String = "exterior";

	/** Same first-pass value as the maze's own — see `biomes.hub.HubBiome.GRAVITY`'s own doc for why each biome states its own. **/
	static inline final GRAVITY:Float = 60;

	static inline final SPAWN_THETA:Float = 1.2083048667653051;

	static inline final SPAWN_PHI:Float = 0.6;
	static inline final SPAWN_FACING:Float = 0.4;

	/** See `biomes.maze.MazeBiome.RETURN_SPAWN_OFFSET` — same reason, same value. **/
	static inline final RETURN_SPAWN_OFFSET:Float = 6;

	var maze:GridData;
	var exitWall:FoundWall;

	public function new(?random:Void->Float) {
		reload(MazeGenerator.generateWith(MazeStyle.RandomizedPrim, 0, random));
	}

	function reload(maze:GridData):Void {
		this.maze = maze;
		this.exitWall = MazeExitWall.find(maze);
	}

	public function id():String {
		return ID;
	}

	public function gravity():Float {
		return GRAVITY;
	}

	/** Near-black: standing on the outside, everything above the horizon is empty space, and there's no far side lit up to fill it. **/
	public function backgroundColor():Int {
		return 0x05060A;
	}

	public function build(parent:h3d.scene.Object):Void {
		GridMesh.build(maze, parent, true);
		var size = PaintingModel.fillWall(GridMesh.WALL_HEIGHT);
		var mid = PaintingModel.midpointOf(exitWall.a, exitWall.b);
		// The painting's own "up" has to be flipped along with the walls it
		// hangs on, or it mounts upside down and sunk into the shell.
		PaintingModel.buildQuad(parent, exitWall.a, exitWall.b, exitWall.cellCenter, PaintingModel.toHubTexture(), size.baseHeight, size.height,
			SphereExteriorSpace.INSTANCE.upAt(mid));
	}

	/**
		Spawns with the exterior topology rather than through
		`PlayerModel.spawnAt`, which builds its own `SphereSpace` player — the
		one place this biome can't reuse the maze's own code, since "which side
		am I on" is precisely what differs.
	**/
	public function spawnPlayer(returning:Bool, fromBiomeId:Null<String>):PlayerModel {
		return returning ? playerInFrontOfExitWall() : playerAt(SPAWN_THETA, SPAWN_PHI, SPAWN_FACING);
	}

	public function exitPaintings():Array<PaintingModel> {
		return [new PaintingModel(PaintingModel.midpointOf(exitWall.a, exitWall.b), HubBiome.ID)];
	}

	public function tryMove(player:PlayerModel, direction:h3d.Vector, distance:Float):Void {
		GridCollision.tryMove(player, direction, distance, GridGeometry.RADIUS, maze);
	}

	/** Falls back *down* onto the shell's outside — `Gravity` integrates along the player's own `surfaceUp`, which here points away from the centre. **/
	public function applyGravity(player:PlayerModel, dt:Float):Void {
		Gravity.fallToSurface(player, GRAVITY, dt);
	}

	/** Nothing here ticks — see `biomes.common.Biome.tick`'s own doc. **/
	public function tick(player:PlayerModel, dt:Float):Void {}

	/** Nothing to interact with here — see `biomes.common.Biome.interact`'s own doc. **/
	public function interact(player:PlayerModel):Void {}

	/** No camera override here — see `biomes.common.Biome.cameraOverride`'s own doc. **/
	public function cameraOverride(player:PlayerModel):Null<entities.player.Camera.CameraOverride> {
		return null;
	}

	/** Never captures input — see `biomes.common.Biome.capturesInput`'s own doc. **/
	public function capturesInput():Bool {
		return false;
	}

	/** Nothing to click on here — see `biomes.common.Biome.onEditClick`'s own doc. **/
	public function onEditClick(ray:h3d.col.Ray):Void {}

	/** No game-speed control here — see `biomes.common.Biome.timeScale`'s own doc. **/
	public function timeScale():Float {
		return 1;
	}

	public function serialize():String {
		return MazeGenerator.serialize(maze);
	}

	public function restore(json:String):Void {
		reload(MazeGenerator.deserialize(json));
	}

	/**
		A player standing on the shell's outside at a spherical position,
		facing `facing` radians around from `SphereMath.thetaTangentAt` — the
		exterior counterpart of `PlayerModel.spawnAt`, differing only in which
		"up" the facing rotation goes around and which `Space` the player
		carries.
		@param theta polar angle from +Y, in radians.
		@param phi azimuth around Y, in radians.
		@param facing initial look direction, in radians from `thetaTangentAt`.
		@return the spawned player.
	**/
	static function playerAt(theta:Float, phi:Float, facing:Float):PlayerModel {
		var pos = SphereMath.sphericalToCartesian(GridGeometry.RADIUS, theta, phi);
		var up = SphereExteriorSpace.INSTANCE.upAt(pos);
		var forward = SphereMath.rotateAroundAxis(SphereMath.thetaTangentAt(theta, phi), up, facing);
		return new PlayerModel(pos, forward, 0, SphereExteriorSpace.INSTANCE);
	}

	/** See `biomes.maze.MazeBiome.playerInFrontOfExitWall` — same construction, with this biome's own topology. **/
	function playerInFrontOfExitWall():PlayerModel {
		var mid = PaintingModel.midpointOf(exitWall.a, exitWall.b);
		var intoRoom = exitWall.cellCenter.sub(mid).normalized();
		var pos = mid.add(intoRoom.scaled(RETURN_SPAWN_OFFSET)).normalized().scaled(GridGeometry.RADIUS);

		var posDir = pos.normalized();
		var forward = intoRoom.sub(posDir.scaled(intoRoom.dot(posDir))).normalized();
		return new PlayerModel(pos, forward, 0, SphereExteriorSpace.INSTANCE);
	}
}
