package biomes.twosided;

import biomes.common.Biome;
import biomes.common.Gravity;
import biomes.common.grid.GridCollision;
import biomes.common.grid.GridGeometry;
import biomes.common.grid.GridMesh;
import biomes.common.grid.GridModel;
import biomes.common.grid.GridModel.GridData;
import biomes.common.grid.GridModel.GridNode;
import biomes.common.maze.MazeStyle;
import biomes.common.space.sphere.SphereExteriorSpace;
import biomes.common.space.sphere.SphereMath;
import biomes.common.space.sphere.SphereSpace;
import biomes.hub.HubBiome;
import biomes.maze.MazeExitWall;
import biomes.maze.MazeExitWall.FoundWall;
import biomes.maze.MazeGenerator;
import entities.painting.PaintingModel;
import entities.player.PlayerModel;
import game.MeshBuilder;
import graphics.Colours;
import graphics.shaders.UnlitTexture;

/** Which side of the shell the player is currently walking on. **/
enum Face {
	Inside;
	Outside;
}

/**
	**One maze, both faces.** The same layout is walked from the inside — where
	gravity is ordinary and walls are walls — and from the outside, where
	gravity is weak enough to jump clear over three walls at once. The point is
	not two levels sharing a file: it's that the *same* corridors mean different
	things depending which side of the shell you stand on, and that what you
	learn on one side is only usable on the other.

	Why the two faces are genuinely complementary rather than just different:

	- **Inside you can see, but not move freely.** The sphere's interior is the
	  game's whole hook — raise your head and the far side is laid out in front
	  of you — but gravity pins you into the corridors.
	- **Outside you can move, but not see.** The surface curves away below the
	  horizon (the finding from `biomes.exterior.ExteriorBiome`), so surveying is
	  impossible; but a jump clears three wall heights, which buys a few seconds
	  of altitude — a *local* vantage, gained by leaping, over a face where no
	  global one exists.

	So the loop the design is reaching for: spot something from across the
	sphere on the inside, **mark** it (`MarkModel`, and marks pierce the shell
	so they show on both faces), cross over, and use the mark to find on the
	outside what you could only see from the inside. Nothing else in the game
	carries information between two viewpoints.

	**What's a placeholder, and knowingly so:** crossing sides happens at the
	two poles, which are open. That was picked as the cheapest thing that gets
	both faces reachable — the poles are already the grid's own degenerate
	merged cells (`GridModel`'s `PoleNode`), so a hole on the axis needs no new
	geometry and is trivially findable — and it is explicitly *not* the answer
	to "how should crossing work". A warp, a shell opening, a flip mechanism:
	all still open, per hooman's own framing. Keeping the crossing dumb also
	keeps this prototype honest about what it's testing, which is the
	see-then-mark-then-cross loop and the two-gravity contrast, not the door.

	**Also open:** a mark says only "here" (no direction, no annotation),
	because the backlog is explicit that what a mark should *say* is unproven;
	nothing yet makes the marks load-bearing (no lock a mark is the key to), so
	right now they're a tool without a puzzle; and the player can't stand on
	wall tops after a jump — collision is simply skipped above wall height (see
	`tryMove`), so a leap over a wall always lands in a corridor.
**/
class TwoSidedBiome implements Biome {
	public static inline final ID:String = "two-sided";

	/** Ordinary gravity on the inside — the same first-pass value every other sphere biome uses. **/
	static inline final GRAVITY_INSIDE:Float = 60;

	/**
		Outside gravity, derived rather than guessed: a jump reaches
		`GameLoop.JUMP_IMPULSE^2 / (2 * g)`, so `18^2 / (2 * 4.5) = 36` — exactly
		three times `GridMesh.WALL_HEIGHT`, which is the "jump three walls high"
		this biome was asked for. Change either constant and this needs
		recomputing; that's the intended coupling, not an accident.
	**/
	static inline final GRAVITY_OUTSIDE:Float = 4.5;

	/**
		How far above the floor the player has to be for walls to stop blocking
		them — `WALL_HEIGHT` plus a little, so clipping a wall's very top edge
		on the way past doesn't count as clearing it.
	**/
	static inline final CLEARS_WALLS_ABOVE:Float = GridMesh.WALL_HEIGHT + 1;

	/**
		How close to a pole (in radians of polar angle) counts as standing in
		the crossing. Matches `GridModel.nodeAt`'s own pole snapping — half a
		row — so the trigger is exactly the merged pole cell, not an invented
		radius.
	**/
	static final CROSSING_THETA:Float = Math.PI / (GridModel.ROWS - 1) / 2;

	/** Radius of the disc marking each pole crossing on the floor. **/
	static inline final CROSSING_MARKER_RADIUS:Float = 10;

	static inline final CROSSING_MARKER_SEGMENTS:Int = 24;

	static inline final SPAWN_THETA:Float = 1.2083048667653051;

	static inline final SPAWN_PHI:Float = 0.6;
	static inline final SPAWN_FACING:Float = 0.4;

	/** See `biomes.maze.MazeBiome.RETURN_SPAWN_OFFSET` — same reason, same value. **/
	static inline final RETURN_SPAWN_OFFSET:Float = 6;

	var maze:GridData;
	var exitWall:FoundWall;

	/** Which side the player is on. Owned by the biome, not the player: it's a fact about this place's own geography, and `PlayerModel` already carries the consequence (its `space`). **/
	var face:Face = Inside;

	final marks:Array<MarkModel> = [];

	/** Marks are placed at runtime, so they live in their own container that gets rebuilt on change — same pattern as the hub's own hourglass. **/
	var marksContainer:Null<h3d.scene.Object>;

	/**
		Whether the player has been inside the crossing zone since the last
		flip. Without this latch, standing on a pole would flip the player every
		single tick — they'd have to be *thrown* out of it rather than walk out.
	**/
	var insideCrossing:Bool = false;

	public function new(?random:Void->Float) {
		reload(MazeGenerator.generateWith(MazeStyle.RandomizedDfs, 0, random));
	}

	function reload(maze:GridData):Void {
		this.maze = maze;
		this.exitWall = MazeExitWall.find(maze);
	}

	public function id():String {
		return ID;
	}

	/** Whichever face the player is on — the contract's one gravity value, answered per side (see `GRAVITY_OUTSIDE`). **/
	public function gravity():Float {
		return face == Inside ? GRAVITY_INSIDE : GRAVITY_OUTSIDE;
	}

	/** Dark, but not the exterior biome's near-black: both faces share one backdrop here, since the player crosses between them without a reload. **/
	public function backgroundColor():Int {
		return 0x101418;
	}

	public function build(parent:h3d.scene.Object):Void {
		// One floor shell, two sets of walls on it — the whole conceit, in
		// three lines. `buildWalls` exists precisely so the floor isn't built
		// twice at the same radius (see its own doc).
		GridMesh.build(maze, parent);
		GridMesh.buildWalls(maze, parent, true);

		var size = PaintingModel.fillWall(GridMesh.WALL_HEIGHT);
		PaintingModel.buildQuad(parent, exitWall.a, exitWall.b, exitWall.cellCenter, PaintingModel.toHubTexture(), size.baseHeight, size.height);

		buildCrossingMarkers(parent);

		marksContainer = new h3d.scene.Object(parent);
		MarkModel.build(marksContainer, marks);
	}

	public function spawnPlayer(returning:Bool, fromBiomeId:Null<String>):PlayerModel {
		// Always arrive on the inside: it's the face that can see, so it's
		// where the loop this biome is testing starts.
		face = Inside;
		insideCrossing = false;
		return returning ? playerInFrontOfExitWall() : PlayerModel.spawnAt(SPAWN_THETA, SPAWN_PHI, SPAWN_FACING, GridGeometry.RADIUS);
	}

	public function exitPaintings():Array<PaintingModel> {
		// Only from the inside: the painting hangs on an inner wall face, and
		// warping out of the middle of a wall from the far side would be a
		// glitch rather than a door.
		return face == Inside ? [new PaintingModel(PaintingModel.midpointOf(exitWall.a, exitWall.b), HubBiome.ID)] : [];
	}

	/**
		Walls block, unless the player is high enough to clear them — which
		only ever happens on the outside, where gravity is weak enough for a
		jump to reach three wall heights. Above that line, movement is free
		tangent motion with no collision at all: the maze is briefly not a maze,
		which is exactly the difference between the two faces.

		The simplification to know about (see the class doc): there's no landing
		*on* a wall. Passing over one and coming down where a wall stands drops
		the player into that corridor instead of onto the top.
	**/
	public function tryMove(player:PlayerModel, direction:h3d.Vector, distance:Float):Void {
		if (player.airborneHeight > CLEARS_WALLS_ABOVE) {
			player.moveAlong(direction, distance, GridGeometry.RADIUS);
			return;
		}
		GridCollision.tryMove(player, direction, distance, GridGeometry.RADIUS, maze);
	}

	public function applyGravity(player:PlayerModel, dt:Float):Void {
		Gravity.fallToSurface(player, gravity(), dt);
	}

	/**
		Watches for the player entering either pole crossing and flips them to
		the other face when they do — the placeholder crossing mechanism (see
		the class doc). The flip is deliberately nothing but a change of "up":
		position and facing are preserved, because the player hasn't moved —
		the shell has simply become their ceiling instead of their floor, or
		the reverse.
	**/
	public function tick(player:PlayerModel, dt:Float):Void {
		var atCrossing = isAtCrossing(player.pos);
		if (atCrossing && !insideCrossing) {
			flip(player);
		}
		insideCrossing = atCrossing;
	}

	/** Drops a mark where the player stands — see `MarkModel` for why a mark is a post through the shell. **/
	public function interact(player:PlayerModel):Void {
		marks.push(new MarkModel(player.pos.clone()));
		rebuildMarks();
	}

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

	/** The layout *and* the marks: a mark the player left is exactly the kind of state a saved maze should come back with. **/
	public function serialize():String {
		var markPositions = [for (mark in marks) {x: mark.pos.x, y: mark.pos.y, z: mark.pos.z}];
		return haxe.Json.stringify({maze: MazeGenerator.serialize(maze), marks: markPositions});
	}

	public function restore(json:String):Void {
		var parsed:{maze:String, marks:Array<{x:Float, y:Float, z:Float}>} = haxe.Json.parse(json);
		reload(MazeGenerator.deserialize(parsed.maze));
		marks.resize(0);
		if (parsed.marks != null) {
			for (position in parsed.marks) {
				marks.push(new MarkModel(new h3d.Vector(position.x, position.y, position.z)));
			}
		}
	}

	/**
		Moves the player to the other face: swap which topology they walk (see
		`PlayerModel.switchSpace`), and reset the vertical state, since
		"falling" now means the opposite direction and carrying a velocity
		across would fling them off the surface they just arrived on.
		@param player the player to flip.
	**/
	function flip(player:PlayerModel):Void {
		face = face == Inside ? Outside : Inside;
		player.switchSpace(face == Inside ? SphereSpace.INSTANCE : SphereExteriorSpace.INSTANCE);
		player.airborneHeight = 0;
		player.verticalVelocity = 0;
		player.grounded = true;
	}

	/**
		Whether `pos` is within either pole's own crossing zone.
		@param pos the position to test.
		@return true if the player is standing in a crossing.
	**/
	function isAtCrossing(pos:h3d.Vector):Bool {
		var theta = SphereMath.thetaOf(pos);
		return theta < CROSSING_THETA || theta > Math.PI - CROSSING_THETA;
	}

	/** Rebuilds the marks mesh after the set changes — a full rebuild rather than an incremental append, same reasoning as the hourglass's own per-tick rebuild (a mark is placed rarely; simplicity wins). **/
	function rebuildMarks():Void {
		var container = marksContainer;
		if (container == null) {
			return;
		}
		container.removeChildren();
		MarkModel.build(container, marks);
	}

	/**
		A flat disc on the floor at each pole, so the crossings can be found at
		all — without them the one mechanism that makes this biome two-sided is
		invisible. Placeholder signage for a placeholder mechanism, deliberately
		matched: when crossing gets designed properly, this goes with it.
		@param parent the scene object to attach the markers under.
	**/
	function buildCrossingMarkers(parent:h3d.scene.Object):Void {
		var points:Array<h3d.Vector> = [];
		var idx = new hxd.IndexBuffer();
		var uvs:Array<h3d.prim.UV> = [];
		for (pole in [PoleNode(North), PoleNode(South)]) {
			addCrossingDisc(points, idx, uvs, pole);
		}

		var prim = new h3d.prim.Polygon(points, idx);
		prim.uvs = uvs;
		var mesh = new h3d.scene.Mesh(prim, parent);
		mesh.material.mainPass.addShader(new UnlitTexture(h3d.mat.Texture.fromColor(Colours.CROSSING_MARKER)));
		mesh.material.mainPass.culling = None;
	}

	/**
		One crossing disc, as a triangle fan around a pole's own apex, lifted a
		hair off the shell so it doesn't z-fight the floor it sits on.
		@param points vertex buffer to append to.
		@param idx index buffer to append to.
		@param uvs UV buffer to append to.
		@param pole which pole to draw at.
	**/
	function addCrossingDisc(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, uvs:Array<h3d.prim.UV>, pole:GridNode):Void {
		var centre = GridModel.centerOf(pole);
		var apex = SphereMath.sphericalToCartesian(GridGeometry.RADIUS, centre.theta, centre.phi);
		var ringTheta = centre.theta == 0 ? CROSSING_MARKER_RADIUS / GridGeometry.RADIUS : Math.PI - CROSSING_MARKER_RADIUS / GridGeometry.RADIUS;

		for (segment in 0...CROSSING_MARKER_SEGMENTS) {
			var phiA = 2 * Math.PI * segment / CROSSING_MARKER_SEGMENTS;
			var phiB = 2 * Math.PI * (segment + 1) / CROSSING_MARKER_SEGMENTS;
			MeshBuilder.addTriangle(points, idx, apex, SphereMath.sphericalToCartesian(GridGeometry.RADIUS, ringTheta, phiA),
				SphereMath.sphericalToCartesian(GridGeometry.RADIUS, ringTheta, phiB));
			uvs.push(new h3d.prim.UV(0.5, 0.5));
			uvs.push(new h3d.prim.UV(0, 1));
			uvs.push(new h3d.prim.UV(1, 1));
		}
	}

	/** See `biomes.maze.MazeBiome.playerInFrontOfExitWall` — same construction; this biome always returns to its inside face (see `spawnPlayer`). **/
	function playerInFrontOfExitWall():PlayerModel {
		var mid = PaintingModel.midpointOf(exitWall.a, exitWall.b);
		var intoRoom = exitWall.cellCenter.sub(mid).normalized();
		var pos = mid.add(intoRoom.scaled(RETURN_SPAWN_OFFSET)).normalized().scaled(GridGeometry.RADIUS);

		var posDir = pos.normalized();
		var forward = intoRoom.sub(posDir.scaled(intoRoom.dot(posDir))).normalized();
		return new PlayerModel(pos, forward);
	}
}
