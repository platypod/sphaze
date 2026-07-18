package biomes.hub;

import biomes.common.grid.GridMesh;
import biomes.hub.HubStructure.StructureBasis;
import entities.painting.PaintingModel;
import entities.player.PlayerModel;
import game.MeshBuilder;
import graphics.shaders.UnlitTexture;

/**
	A small landmark reminding the player of the maze, standing wherever
	`HubBiome` anchors it: seven straight `wall_stone` walls, the same
	`biomes.common.grid.GridMesh.WALL_HEIGHT` as the real thing, laid out as
	a single continuous square spiral (each wall longer than the last,
	turning the same way every time) rather than the maze's own lat/long
	grid — that grid exists to wrap a whole biome around a sphere; a
	decorative structure this size doesn't need it, just something that
	reads as "a maze" at a glance.

	Built and collided against entirely in `HubStructure`'s own local
	`(u, v)` frame — see its class doc for why that's a reasonable
	approximation at this scale. Wall 1 (the shortest, drawn first) sits
	right at the local origin; each numbered wall after it is one arm
	further out. The player walks in from the wide-open end of wall 7 and
	follows the spiral inward to wall 2, where the maze's own painting
	mounts on the inner face — matching "the second from the center."
**/
class MazeShrine {
	/** How much longer each successive wall is than the last — also the spiral's own radial growth per arm. Tripled from an initial `2.4` (hooman: "still much too small... make them thrice bigger") — the wall height/texture stay matched to the real maze regardless (`GridMesh.WALL_HEIGHT`), only the spiral's own footprint scales. **/
	static inline final ARM_UNIT:Float = 7.2;

	/** Half the wall's own thickness, plus clearance — collision blocks within this distance of any wall segment's own centerline, since the walls themselves are built as flat (zero-thickness) quads. **/
	static inline final WALL_CLEARANCE:Float = 1.2;

	/** How far past wall 7's own tip the player reappears when returning from the maze, arc-length in the spiral's own local frame — mirrors `biomes.maze.MazeBiome.RETURN_SPAWN_OFFSET`'s own role. **/
	static inline final RETURN_SPAWN_OFFSET:Float = 4;

	/** One local `(u, v)` per turn: east, south, west, north, repeating — the spiral always turns the same way. **/
	static final DIRECTIONS:Array<{u:Float, v:Float}> = [{u: 0, v: 1}, {u: 1, v: 0}, {u: 0, v: -1}, {u: -1, v: 0}];

	/**
		The spiral's own 7 wall segments, in local `(u, v)`, walked once from
		the center outward — wall `i` (1-indexed here via the returned
		array's own index) is `i * ARM_UNIT` long. Pure geometry, shared by
		`build` and `blocksMovement` so rendering and collision can never
		disagree about where a wall actually is.
		@return each wall's own two endpoints, center-out.
	**/
	static function wallSegments():Array<{
		aU:Float,
		aV:Float,
		bU:Float,
		bV:Float
	}> {
		var segments = [];
		var u = 0.0;
		var v = 0.0;
		for (i in 0...7) {
			var dir = DIRECTIONS[i % DIRECTIONS.length];
			var length = (i + 1) * ARM_UNIT;
			var nextU = u + dir.u * length;
			var nextV = v + dir.v * length;
			segments.push({
				aU: u,
				aV: v,
				bU: nextU,
				bV: nextV
			});
			u = nextU;
			v = nextV;
		}
		return segments;
	}

	/**
		Builds the shrine's own 7 walls plus the maze's painting, anchored
		at `basis`.
		@param parent the scene object to attach the meshes under.
		@param basis the shrine's own local frame (see `HubStructure.anchorAt`).
		@param texture the maze's own painting art.
	**/
	public static function build(parent:h3d.scene.Object, basis:StructureBasis, texture:h3d.mat.Texture):Void {
		var points:Array<h3d.Vector> = [];
		var idx = new hxd.IndexBuffer();
		var uvs:Array<h3d.prim.UV> = [];

		for (segment in wallSegments()) {
			var bottomA = HubStructure.worldPoint(basis, segment.aU, segment.aV, 0);
			var bottomB = HubStructure.worldPoint(basis, segment.bU, segment.bV, 0);
			var topA = bottomA.add(basis.up.scaled(GridMesh.WALL_HEIGHT));
			var topB = bottomB.add(basis.up.scaled(GridMesh.WALL_HEIGHT));

			var uRepeat = bottomA.sub(bottomB).length() / MeshBuilder.WALL_TEXTURE_TILE_SIZE;
			var vRepeat = GridMesh.WALL_HEIGHT / MeshBuilder.WALL_TEXTURE_TILE_SIZE;
			MeshBuilder.addQuad(points, idx, bottomA, bottomB, topB, topA);
			uvs.push(new h3d.prim.UV(0, vRepeat));
			uvs.push(new h3d.prim.UV(uRepeat, vRepeat));
			uvs.push(new h3d.prim.UV(uRepeat, 0));
			uvs.push(new h3d.prim.UV(0, 0));
		}

		var prim = new h3d.prim.Polygon(points, idx);
		prim.uvs = uvs;
		var wallTexture = hxd.Res.textures.wall_stone.toTexture();
		wallTexture.wrap = Repeat;
		var mesh = new h3d.scene.Mesh(prim, parent);
		mesh.material.mainPass.addShader(new UnlitTexture(wallTexture));
		mesh.material.mainPass.culling = None;

		buildPainting(parent, basis, texture);
	}

	/** The maze's own painting, mounted on wall 2's inner (center-facing) side. **/
	static function buildPainting(parent:h3d.scene.Object, basis:StructureBasis, texture:h3d.mat.Texture):Void {
		var wall2 = wallSegments()[1];
		var wallA = HubStructure.worldPoint(basis, wall2.aU, wall2.aV, 0);
		var wallB = HubStructure.worldPoint(basis, wall2.bU, wall2.bV, 0);
		var roomCenter = basis.origin;
		var size = PaintingModel.fillWall(GridMesh.WALL_HEIGHT);
		PaintingModel.buildQuad(parent, wallA, wallB, roomCenter, texture, size.baseHeight, size.height, basis.up);
	}

	/**
		Whether `worldPos` is too close to any of the shrine's own 7 walls
		to be walked into — a flat clearance check per segment
		(`HubStructure.distanceToSegment`), same discipline
		`biomes.hub.HubCollision` already uses for the (now-removed) column.
		@param basis the shrine's own local frame.
		@param worldPos the position to check — typically the player's own tentative new position.
		@return true if `worldPos` is blocked by a wall.
	**/
	public static function blocksMovement(basis:StructureBasis, worldPos:h3d.Vector):Bool {
		var uv = HubStructure.localUV(basis, worldPos);
		for (segment in wallSegments()) {
			if (HubStructure.distanceToSegment(uv.u, uv.v, segment.aU, segment.aV, segment.bU, segment.bV) < WALL_CLEARANCE) {
				return true;
			}
		}
		return false;
	}

	/**
		The maze's own painting as a trigger — floor-level (`midpointOf`),
		matching every other painting in this project (see
		`docs/PROJECT_LOG.md`'s own entry on why the hub's former column-face
		paintings didn't, until fixed).
		@param basis the shrine's own local frame.
		@param destinationBiomeId `biomes.maze.MazeBiome.ID`.
		@return the shrine's own exit painting.
	**/
	public static function exitPainting(basis:StructureBasis, destinationBiomeId:String):PaintingModel {
		var wall2 = wallSegments()[1];
		var wallA = HubStructure.worldPoint(basis, wall2.aU, wall2.aV, 0);
		var wallB = HubStructure.worldPoint(basis, wall2.bU, wall2.bV, 0);
		return new PaintingModel(PaintingModel.midpointOf(wallA, wallB), destinationBiomeId);
	}

	/**
		A `PlayerModel` standing `RETURN_SPAWN_OFFSET` past wall 7's own
		tip, facing back in along the spiral — where the player reappears
		coming back out of the maze. Re-projected onto the hub's true
		sphere (`normalized().scaled(radius)`) since `HubStructure`'s own
		flat local frame is only an approximation away from the anchor
		itself — same correction `biomes.maze.MazeBiome.playerInFrontOfExitWall`
		already makes for the same reason.
		@param basis the shrine's own local frame.
		@param radius the hub's own sphere radius.
		@return the spawned player.
	**/
	public static function returnSpawn(basis:StructureBasis, radius:Float):PlayerModel {
		var outermost = wallSegments()[6];
		var tipU = outermost.bU;
		var tipV = outermost.bV;
		var outDir = DIRECTIONS[6 % DIRECTIONS.length];
		var spawnU = tipU + outDir.u * RETURN_SPAWN_OFFSET;
		var spawnV = tipV + outDir.v * RETURN_SPAWN_OFFSET;

		var tentativePos = HubStructure.worldPoint(basis, spawnU, spawnV, 0);
		var pos = tentativePos.normalized().scaled(radius);

		var intoSpiral = basis.uAxis.scaled(-outDir.u).add(basis.vAxis.scaled(-outDir.v));
		var posDir = pos.normalized();
		var forward = intoSpiral.sub(posDir.scaled(intoSpiral.dot(posDir))).normalized();
		return new PlayerModel(pos, forward);
	}
}
