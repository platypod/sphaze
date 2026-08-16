package biomes.weft;

import biomes.common.Biome;
import biomes.common.Gravity;
import biomes.common.grid.GridCollision;
import biomes.common.grid.GridGeometry;
import biomes.common.grid.GridModel;
import biomes.common.grid.GridModel.GridData;
import biomes.common.grid.GridModel.GridNode;
import biomes.common.space.sphere.SphereMath;
import biomes.hub.HubBiome;
import biomes.maze.MazeExitWall;
import biomes.maze.MazeExitWall.FoundWall;
import biomes.maze.MazeGenerator;
import entities.painting.PaintingModel;
import entities.player.Camera.CameraOverride;
import entities.player.PlayerModel;

/**
	**The Weft** — an ordinary sphere, wired to itself. See
	[the design](../../../docs/game/world.md)'s
	own entry (`### 2. The Weft`).

	Every wall answers to the wall at its antipode and the two are always
	in opposite states, so **closing the door in front of you opens one on
	the far side of the world** — see `WeftModel`, which holds the rule and
	the geometry that limits where it can apply, including *how* the
	invariant is generated: the northern hemisphere is carved freely and
	the southern hemisphere is forced to its exact opposite, which is what
	makes the far side read as a legible negative rather than an unrelated
	tangle — see `WeftModel.enforceOpposite`'s own doc.

	**Not the Fold's sphere**, despite an earlier version of this comment
	claiming it was: this reuses `biomes.common.grid` and `biomes.maze`,
	the lat/long grid and generic spanning-tree maze that predate
	[the direction](../../../docs/game/world.md) entirely (see that
	document's own note on which biomes are pre-direction) — not
	`biomes.conway`, the icosahedral automaton sphere the numbered Fold
	actually is. Both are κ>0 spheres, which is the sense in which "the
	same sphere" was true; the geometry, generator and (until `WeftMesh`)
	the render were the maze prototype's, not the Fold's.

	**The echo.** The design gives this space a legibility law: look toward
	your own antipode and see a reflection of what is there, so you can
	read the far side of a pairing without walking to it. Here that is a
	pale marker standing at `-pos`, moving as the player moves, passing
	through walls it has no business colliding with — settled as "phase
	through," which is what makes it an image rather than a second body.
	It is the instrument the whole space is read with: act on a wall,
	watch the echo's surroundings change.

	**What this reuses, and what that says.** The grid, the collision and
	the exit painting are the maze prototype's, untouched — this space
	needed no new topology, only a rule laid over an existing one. The
	render is not reused: `WeftMesh` replaces the prototype's grass and
	stone with this space's own flat, hue-correct dialect, once that
	mismatch with [art-and-audio.md](../../../docs/game/art-and-audio.md)
	was flagged directly ("no... coherence with our new Artistic
	Direction"). What is new, in total: `WeftModel` (the pairing rule and
	the hemisphere generation it now performs), `WeftMesh` (the dialect),
	and the echo.

	**Not built yet:** the puzzle. There is no gate that specifically
	requires reaching through the antipode, because that is level design
	and it should be authored against a mechanic already known to read.
	What is here answers the prior question — can a player act on a wall,
	see the consequence at their antipode, and understand what happened.
**/
class WeftBiome implements Biome {
	public static inline final ID:String = "weft";

	/** Same first-pass value as the maze's — see `biomes.hub.HubBiome.GRAVITY`'s own doc for why each biome states its own. **/
	static inline final GRAVITY:Float = 60;

	/** How far above the far surface the echo floats, so it reads against the floor rather than z-fighting with it. **/
	static inline final ECHO_HEIGHT:Float = 4;

	static inline final ECHO_SIZE:Float = 3.2;

	/** Pale, and the brightest thing in the biome — value, not hue, since hue belongs to curvature. **/
	static inline final ECHO_COLOR:Int = 0xF0ECE2;

	static inline final SPAWN_THETA:Float = 1.35;
	static inline final SPAWN_PHI:Float = 2.1;
	static inline final SPAWN_FACING:Float = 0.0;

	/** See `biomes.maze.MazeBiome.RETURN_SPAWN_OFFSET` — same reason, same value. **/
	static inline final RETURN_SPAWN_OFFSET:Float = 6;

	var maze:GridData;
	var exitWall:FoundWall;

	/** The whole rebuildable world — replaced wholesale whenever a wall is toggled, since a flip changes geometry on two sides of the sphere at once. **/
	var world:Null<h3d.scene.Object>;

	var echo:Null<h3d.scene.Object>;

	public function new(?random:Void->Float) {
		reload(MazeGenerator.generate(random));
	}

	/** Adopts a layout, forces the opposite-rule invariant onto it, and re-derives the exit. **/
	function reload(layout:GridData):Void {
		WeftModel.enforceOpposite(layout);
		maze = layout;
		exitWall = MazeExitWall.find(maze);
	}

	public function id():String {
		return ID;
	}

	public function gravity():Float {
		return GRAVITY;
	}

	/** Warm — κ>0, and hue carries only that (see `WeftMesh` for the rest of the palette this sits behind). **/
	public function backgroundColor():Int {
		return 0x1A1512;
	}

	public function build(parent:h3d.scene.Object):Void {
		world = new h3d.scene.Object(parent);
		echo = buildEcho(parent);
		rebuild();
	}

	/** A small pale block standing at the player's antipode — see the class doc on why it is an image and not a body. **/
	function buildEcho(parent:h3d.scene.Object):h3d.scene.Object {
		var container = new h3d.scene.Object(parent);
		var batch = new game.BoxBatch(container, ECHO_COLOR);
		batch.add(0, 0, ECHO_SIZE, ECHO_SIZE, 0, ECHO_SIZE * 2);
		batch.flush();
		return container;
	}

	function rebuild():Void {
		var container = world;
		if (container == null) {
			return; // not built yet
		}
		container.removeChildren();
		WeftMesh.build(maze, container);
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

	/**
		Keeps the echo standing at the player's antipode.

		`-pos` is the antipode of a point on a sphere centred at the
		origin, which is the whole computation — no transform needed,
		because nothing here is glued and the antipode is an ordinary
		place.
		@param player the player to mirror.
		@param dt unused — the echo has no dynamics of its own.
	**/
	public function tick(player:PlayerModel, dt:Float):Void {
		var marker = echo;
		if (marker == null) {
			return;
		}
		var opposite = player.pos.scaled(-1);
		var outward = opposite.normalized();
		var stand = opposite.sub(outward.scaled(ECHO_HEIGHT));
		marker.setPosition(stand.x, stand.y, stand.z);
	}

	/**
		Flips the wall the player is facing, and its partner with it.

		Picks the neighbouring cell whose own direction best matches where
		the player is looking, rather than the nearest wall by distance:
		standing in a corner, "nearest" is ambiguous and "the one I am
		looking at" is not. A wall with no partner (see `WeftModel`) does
		not move — the rule is the only thing that gives the player any
		purchase here, and a wall outside it is simply scenery.
		@param player the player acting.
	**/
	public function interact(player:PlayerModel):Void {
		var here = GridModel.nodeAt(SphereMath.thetaOf(player.pos), SphereMath.phiOf(player.pos));
		var facing = mostFacedNeighbor(player, here);
		if (facing == null) {
			return;
		}
		if (WeftModel.toggle(maze, here, facing)) {
			rebuild();
		}
	}

	/** Which neighbour of `here` the player is looking most directly toward. **/
	function mostFacedNeighbor(player:PlayerModel, here:GridNode):Null<GridNode> {
		var best:Null<GridNode> = null;
		var bestAlignment = 0.0;

		for (neighbor in GridModel.neighborsOf(here)) {
			var centre = GridModel.centerOf(neighbor);
			var towards = SphereMath.sphericalToCartesian(GridGeometry.RADIUS, centre.theta, centre.phi).sub(player.pos);
			var alignment = towards.normalized().dot(player.forward);
			if (alignment > bestAlignment) {
				bestAlignment = alignment;
				best = neighbor;
			}
		}
		return best;
	}

	/** No camera override here — see `biomes.common.Biome.cameraOverride`'s own doc. **/
	public function cameraOverride(player:PlayerModel):Null<CameraOverride> {
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

	/** Restores a layout *and* re-imposes the opposite rule on it — an imported maze has no reason to already satisfy it. **/
	public function restore(json:String):Void {
		reload(MazeGenerator.deserialize(json));
		rebuild();
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
