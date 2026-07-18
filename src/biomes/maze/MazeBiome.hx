package biomes.maze;

import biomes.common.grid.GridCollision;
import biomes.common.grid.GridGeometry;
import biomes.common.grid.GridMesh;
import biomes.common.grid.GridModel.GridData;
import biomes.common.Biome;
import biomes.hub.HubBiome;
import entities.player.PlayerModel;
import entities.painting.PaintingModel;
import graphics.Colours;

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

	public function radius():Float {
		return GridGeometry.RADIUS;
	}

	public function build(parent:h3d.scene.Object):Void {
		GridMesh.build(maze, parent);
		PaintingModel.buildQuad(parent, exitWall.a, exitWall.b, exitWall.cellCenter, Colours.TO_HUB);
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
