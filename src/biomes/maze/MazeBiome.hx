package biomes.maze;

import biomes.common.grass.GrassMesh;
import biomes.common.grass.GrassModel;
import biomes.common.grid.GridCollision;
import biomes.common.grid.GridGeometry;
import biomes.common.grid.GridMesh;
import biomes.common.grid.GridModel;
import biomes.common.grid.GridModel.GridData;
import biomes.common.space.sphere.SphereMath;
import biomes.common.Biome;
import biomes.common.Gravity;
import biomes.hub.HubBiome;
import entities.player.PlayerModel;
import entities.painting.PaintingModel;
import graphics.Colours;
import graphics.shaders.GrassWind;

/**
	The one generated-maze biome that exists today — wraps `GridModel`/
	`GridMesh`/`GridCollision` behind the `Biome` contract, plus its own
	`MazeGenerator` for the spanning-tree layout that's specifically what
	makes this a *maze*. Its own maze data can be swapped out via `reload`
	(see `GameLoop`'s E/L export/import dev tooling) without losing its place in
	whichever biome-id slot it's registered under.
**/
class MazeBiome implements Biome {
	public static inline final ID:String = "maze";

	/**
		Fixed spawn spherical coordinates — chosen to sit well clear of row
		5's own boundaries (its cell's center theta), not just "somewhere in
		the maze": the old `SPAWN_THETA` (1.3) landed only ~2.53 units from
		the row 5/6 boundary, just barely outside the
		`GridGeometry.WALL_THICKNESS + GridGeometry.COLLISION_CLEARANCE`
		(2.5) zone `GridModel.wallZoneNeighbor` otherwise guarantees a player can
		never get closer than. Centering on row 5 instead gives every
		direction a comfortable margin. `Math.PI * 5 / (GridModel.ROWS - 1)` —
		row 5's own center theta — spelled out as a literal since a `static
		inline final` can't initialize from another class's constant.
	**/
	static inline final SPAWN_THETA:Float = 1.2083048667653051;

	static inline final SPAWN_PHI:Float = 0.6;
	static inline final SPAWN_FACING:Float = 0.4;

	/**
		How far in front of the exit-painting wall the player reappears when
		coming back into this biome from the hub — must clear
		`PaintingModel.TRIGGER_DISTANCE` (4), or they'd step right back into the
		painting's trigger radius and immediately bounce right back out.
	**/
	static inline final RETURN_SPAWN_OFFSET:Float = 6;

	/** Same first-pass value as the hub's own — see `biomes.hub.HubBiome.GRAVITY`'s own doc for why this is its own constant rather than shared. **/
	static inline final GRAVITY:Float = 60;

	var maze:GridData;
	var exitWall:MazeExitWall.FoundWall;

	public function new(maze:GridData) {
		reload(maze);
	}

	/**
		Swaps this biome's own maze data — the guts of `restore`. Re-derives
		the exit wall since a different maze closes different edges.
		@param maze the maze data to adopt.
	**/
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

	public function build(parent:h3d.scene.Object):Void {
		GridMesh.build(maze, parent);
		PaintingModel.buildQuad(parent, exitWall.a, exitWall.b, exitWall.cellCenter, Colours.TO_HUB);
		// Windier and thicker than the hub's own grass: open corridors
		// stretching across the sphere read as more exposed than the hub's
		// small enclosed room, and a sparser hub floor already reads as
		// "the calm room" by contrast — the maze is where the weather is.
		GrassMesh.build(parent, GridGeometry.RADIUS, isWalkable, GrassModel.DEFAULT_TUFT_COUNT * 40, GrassWind.DEFAULT_SWAY_AMPLITUDE * 1.8,
			GrassWind.DEFAULT_SWAY_FREQUENCY * 1.2);
	}

	/**
		Whether `pos` is a valid place to grow a grass tuft — well clear of
		every *closed* edge of its own ring cell (see
		`GridModel.isWellClearOfWalls`), open ones included so grass grows
		flush to a doorway instead of leaving a gap there for no in-world
		reason. Not `static`: it needs this specific maze's own `maze` data
		to know which edges are actually open.
		@param pos the candidate world position.
		@return true if `pos` is well clear of its own cell's walls.
	**/
	function isWalkable(pos:h3d.Vector):Bool {
		return GridModel.isWellClearOfWalls(maze, SphereMath.thetaOf(pos), SphereMath.phiOf(pos));
	}

	public function spawnPlayer(returning:Bool):PlayerModel {
		return returning ? playerInFrontOfExitWall() : PlayerModel.spawnAt(SPAWN_THETA, SPAWN_PHI, SPAWN_FACING, GridGeometry.RADIUS);
	}

	public function exitPainting():PaintingModel {
		return new PaintingModel(PaintingModel.midpointOf(exitWall.a, exitWall.b), HubBiome.ID);
	}

	public function tryMove(player:PlayerModel, direction:h3d.Vector, distance:Float):Void {
		GridCollision.tryMove(player, direction, distance, GridGeometry.RADIUS, maze);
	}

	public function applyGravity(player:PlayerModel, dt:Float):Void {
		Gravity.fallToSurface(player, GRAVITY, dt);
	}

	public function serialize():String {
		return MazeGenerator.serialize(maze);
	}

	public function restore(json:String):Void {
		reload(MazeGenerator.deserialize(json));
	}

	/**
		A `PlayerModel` standing `RETURN_SPAWN_OFFSET` units in front of the exit
		wall's midpoint, facing into the room — where the player reappears
		coming back out of the hub. `exitWall.cellCenter.sub(mid)` isn't
		exactly tangent to the sphere at `mid` (two points on a curved
		surface never are, strictly), so `forward` gets re-projected onto the
		tangent plane at the final spawn position — the same approximation
		`PaintingModel`'s own wall-mounting math already relies on, just also
		re-tangented here since `PlayerModel` depends on `forward` actually being
		one.
		@return the spawned player.
	**/
	function playerInFrontOfExitWall():PlayerModel {
		var mid = PaintingModel.midpointOf(exitWall.a, exitWall.b);
		var intoRoom = exitWall.cellCenter.sub(mid).normalized();
		var pos = mid.add(intoRoom.scaled(RETURN_SPAWN_OFFSET)).normalized().scaled(GridGeometry.RADIUS);

		var posDir = pos.normalized();
		var forward = intoRoom.sub(posDir.scaled(intoRoom.dot(posDir))).normalized();
		return new PlayerModel(pos, forward);
	}
}
