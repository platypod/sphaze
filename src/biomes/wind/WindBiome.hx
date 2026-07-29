package biomes.wind;

import biomes.common.Biome;
import biomes.common.Gravity;
import biomes.common.grass.GrassMesh;
import biomes.common.grass.GrassModel;
import biomes.common.grid.GridCollision;
import biomes.common.grid.GridGeometry;
import biomes.common.grid.GridMesh;
import biomes.common.grid.GridModel;
import biomes.common.grid.GridModel.GridData;
import biomes.common.grid.GridModel.GridNode;
import biomes.common.space.sphere.SphereMath;
import biomes.hub.HubBiome;
import biomes.maze.MazeExitWall;
import biomes.maze.MazeExitWall.FoundWall;
import biomes.maze.MazeGenerator;
import entities.painting.PaintingModel;
import entities.player.PlayerModel;
import graphics.shaders.GrassWind;

/**
	First prototype of a **perception-rule** biome: the maze is an ordinary
	sphere maze, and what makes it its own place is that the grass tells you
	where the exit is. A draft flows outward from the exit along the corridors
	(`WindField`), every tuft leans downwind, and so the whole sphere's grass —
	seen from across it, which is the only way to see enough of it at once — is
	a flow field with exactly one convergence point. Walk into the wind to
	leave.

	Why this one first, of the ten perception ideas parked in
	`docs/game-design/ideas-backlog.md`: it needs no new mechanism at all. The
	grass, the sway shader, the grid, the collision and the exit-wall painting
	all already exist; what's new is one breadth-first search and a per-blade
	direction. That makes it the cheapest possible answer to the question the
	whole perception axis rests on — *is a cue that's only legible at distance
	actually usable?* — which is what the "prototype unproven mechanics before
	committing" pillar asks for.

	Deliberately shares `GridModel`/`GridGeometry` with `biomes.maze.MazeBiome`
	rather than defining its own grid: this is the same corridors with a
	different rule, and the comparison is the point. It carves with
	`MazeStyle.AxisBiased`, though, so the corridors tend to wind around the
	sphere — which gives the flow field long sweeping curves to be read from,
	instead of the short pole-to-pole zigzags a plain DFS produces.

	Open, and the reason this is called a prototype: nothing yet stops the
	player simply *following the grass at their feet* one tuft at a time, which
	would make the whole distance-legibility idea pointless. If playtesting
	says that's what happens, the fix is to make the local cue ambiguous
	(sway direction jittered per tuft, only the aggregate honest) rather than
	to remove it — but that's a real design decision, not a tuning tweak, and
	it shouldn't be pre-empted before someone has walked this.
**/
class WindBiome implements Biome {
	public static inline final ID:String = "wind";

	/**
		How strongly the carve favors east-west corridors — see
		`biomes.common.maze.MazeStyle.AxisBiased`. Above 1 on purpose (see
		class doc): long corridors circling the sphere give the flow field
		something sweeping to trace.
	**/
	static inline final ALONG_ROW_WEIGHT:Float = 5;

	/** Same first-pass value as the maze's own — see `biomes.hub.HubBiome.GRAVITY`'s own doc for why each biome states its own. **/
	static inline final GRAVITY:Float = 60;

	/** Denser than the maze's own grass: the field *is* the mechanic here, so it needs enough blades to read as a direction rather than as scattered clumps. **/
	static inline final TUFT_MULTIPLIER:Int = 60;

	/** Stronger and slower than the maze's own sway — a lean that reads as a steady draft rather than a breeze. **/
	static inline final SWAY_AMPLITUDE_MULTIPLIER:Float = 2.4;

	static inline final SWAY_FREQUENCY_MULTIPLIER:Float = 0.7;

	/**
		Grass several times the usual size — the finding this prototype was
		built to produce. At the default height, looking across the sphere
		showed the field as *texture*: a blade at that range covers well under
		a pixel, so its lean carries no information, and the whole
		legible-at-distance premise silently failed. Scaling the blades up is
		the cheapest thing that puts the field back in the picture; whether it
		is the *right* answer (versus wind streaks, ribbons, or moving
		something other than grass) is a real design question, not a tuning
		one — see the class doc's open note.

		Tried at 4 first, which read beautifully from across the sphere and was
		unusable up close: blades at the player's own feet stood well above
		`entities.player.Camera.EYE_HEIGHT` and filled the view with green
		shards. 1.8 puts the tallest blades at roughly eye level — which,
		pleasingly, is *on* the see-far-not-near pillar rather than a
		compromise against it: waist-to-shoulder grass hides the corridor you
		are standing in while still combing legibly at distance.
	**/
	static inline final GRASS_HEIGHT_SCALE:Float = 1.8;

	static inline final SPAWN_THETA:Float = 1.2083048667653051;

	static inline final SPAWN_PHI:Float = 0.6;
	static inline final SPAWN_FACING:Float = 0.4;

	/** See `biomes.maze.MazeBiome.RETURN_SPAWN_OFFSET` — same reason, same value. **/
	static inline final RETURN_SPAWN_OFFSET:Float = 6;

	var maze:GridData;
	var exitWall:FoundWall;
	var wind:WindField;

	public function new(?random:Void->Float) {
		reload(MazeGenerator.generateWith(AxisBiased(ALONG_ROW_WEIGHT), 0, random));
	}

	/**
		Adopts a layout and re-derives everything downstream of it — the exit
		wall (a different maze closes different edges) and the wind field
		itself, which is defined relative to that exit.
		@param maze the layout to adopt.
	**/
	function reload(maze:GridData):Void {
		this.maze = maze;
		this.exitWall = MazeExitWall.find(maze);
		this.wind = new WindField(maze, exitNode());
	}

	/** Which cell the draft comes from: the one the exit painting is mounted in. **/
	function exitNode():GridNode {
		return GridModel.nodeAt(SphereMath.thetaOf(exitWall.cellCenter), SphereMath.phiOf(exitWall.cellCenter));
	}

	public function id():String {
		return ID;
	}

	public function gravity():Float {
		return GRAVITY;
	}

	/** A washed-out pale grey, unlike the maze's near-black: an overcast, windy day rather than a dim interior. **/
	public function backgroundColor():Int {
		return 0x2A2E33;
	}

	public function build(parent:h3d.scene.Object):Void {
		GridMesh.build(maze, parent);
		var size = PaintingModel.fillWall(GridMesh.WALL_HEIGHT);
		PaintingModel.buildQuad(parent, exitWall.a, exitWall.b, exitWall.cellCenter, PaintingModel.toHubTexture(), size.baseHeight, size.height);
		GrassMesh.build(parent, GridGeometry.RADIUS, isWalkable, GrassModel.DEFAULT_TUFT_COUNT * TUFT_MULTIPLIER,
			GrassWind.DEFAULT_SWAY_AMPLITUDE * SWAY_AMPLITUDE_MULTIPLIER, GrassWind.DEFAULT_SWAY_FREQUENCY * SWAY_FREQUENCY_MULTIPLIER, null,
			wind.directionAt, GRASS_HEIGHT_SCALE);
	}

	/** Same rule as `biomes.maze.MazeBiome.isWalkable` — grass grows anywhere well clear of this maze's own closed edges. **/
	function isWalkable(pos:h3d.Vector):Bool {
		return GridModel.isWellClearOfWalls(maze, SphereMath.thetaOf(pos), SphereMath.phiOf(pos));
	}

	public function spawnPlayer(returning:Bool, fromBiomeId:Null<String>):PlayerModel {
		return returning ? playerInFrontOfExitWall() : PlayerModel.spawnAt(SPAWN_THETA, SPAWN_PHI, SPAWN_FACING, GridGeometry.RADIUS);
	}

	public function exitPaintings():Array<PaintingModel> {
		return [new PaintingModel(PaintingModel.midpointOf(exitWall.a, exitWall.b), HubBiome.ID)];
	}

	public function tryMove(player:PlayerModel, direction:h3d.Vector, distance:Float):Void {
		GridCollision.tryMove(player, direction, distance, GridGeometry.RADIUS, maze);
	}

	public function applyGravity(player:PlayerModel, dt:Float):Void {
		Gravity.fallToSurface(player, GRAVITY, dt);
	}

	/** The wind is a static field derived from the layout, not an animated system — see `biomes.common.Biome.tick`'s own doc. **/
	public function tick(player:PlayerModel, dt:Float):Void {}

	/** No game-speed control here — see `biomes.common.Biome.timeScale`'s own doc. **/
	public function timeScale():Float {
		return 1;
	}

	public function serialize():String {
		return MazeGenerator.serialize(maze);
	}

	/** Restores a layout *and* the wind field derived from it — see `reload`. **/
	public function restore(json:String):Void {
		reload(MazeGenerator.deserialize(json));
	}

	/** See `biomes.maze.MazeBiome.playerInFrontOfExitWall` — same construction, same reasoning about re-tangenting `forward`. **/
	function playerInFrontOfExitWall():PlayerModel {
		var mid = PaintingModel.midpointOf(exitWall.a, exitWall.b);
		var intoRoom = exitWall.cellCenter.sub(mid).normalized();
		var pos = mid.add(intoRoom.scaled(RETURN_SPAWN_OFFSET)).normalized().scaled(GridGeometry.RADIUS);

		var posDir = pos.normalized();
		var forward = intoRoom.sub(posDir.scaled(intoRoom.dot(posDir))).normalized();
		return new PlayerModel(pos, forward);
	}
}
