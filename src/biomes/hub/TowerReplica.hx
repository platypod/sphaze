package biomes.hub;

import biomes.hub.HubStructure.StructureBasis;
import entities.painting.PaintingModel;
import entities.player.PlayerModel;
import game.MeshBuilder;
import graphics.shaders.UnlitTexture;

/**
	A small landmark reminding the player of the tower, standing wherever
	`HubBiome` anchors it: a solid mini-spire, `tower_stone_wall`/
	`tower_stone_floor`-textured, evoking the real shaft's own stacked
	layers (`biomes.tower.TowerModel.LAYER_HEIGHT`) via `FLOORS` purely
	cosmetic belt-course ledges rather than any actual per-floor collision
	or interior space — there's no way up, on purpose (confirmed with
	hooman): unlike the real tower, this is a facade the player walks up
	to and reads from the ground, not something they descend through.

	The painting mounts on the outer wall at ground level (floor 1, the
	lowest), on the same "wall edge either side of a fixed angle" pattern
	`biomes.tower.TowerModel.paintingWallEdge` already uses for the real
	tower's own hub-bound paintings — just anchored in `HubStructure`'s
	local `(u, v)` frame instead of the shaft's own world-space axis.
**/
class TowerReplica {
	/** The spire's own outer wall radius — small next to the real tower's `biomes.tower.TowerModel.OUTER_RADIUS` (40), on purpose: a landmark, not an enterable space. **/
	static inline final OUTER_RADIUS:Float = 7.5;

	/** How many cosmetic floor divisions the spire reads as — "3 or 4" per the ask. **/
	static inline final FLOORS:Int = 4;

	/** Vertical span of one cosmetic floor — unlike the real tower's own `LAYER_HEIGHT`, this never gates anything; it's just how tall each division reads. **/
	static inline final FLOOR_HEIGHT:Float = 3.5;

	/** Segments the spire's circular cross-section is built from — smaller than `biomes.tower.TowerMesh.WALL_SEGMENTS` (32), since this structure's own radius is a fraction of the real shaft's. **/
	static inline final WALL_SEGMENTS:Int = 24;

	/** How far a floor-division ledge steps out from the main wall, before stepping back in — what actually reads as a belt course rather than a texture seam alone. **/
	static inline final LEDGE_PROTRUSION:Float = 0.4;

	/** How tall a ledge's own outward-stepped band is. **/
	static inline final LEDGE_HEIGHT:Float = 0.3;

	/** Fixed local angle the painting mounts at, same role `biomes.tower.TowerModel.PAINTING_ANGLE` plays on the real shaft. **/
	static inline final PAINTING_ANGLE:Float = 0;

	/**
		Half the painting's own mounting arc's angular width. Bounded by the
		wall's own curvature, not just a "how wide should the painting look"
		choice: `paintingWallEdge`'s two points sit on the true circle, but
		`PaintingModel.buildQuad` mounts a *flat* quad, inset `SURFACE_INSET`
		off that flat chord — between the two edges, the actual curved wall
		bulges toward the chord by the arc's own sagitta,
		`OUTER_RADIUS * (1 - cos(PAINTING_HALF_ANGLE))`. An earlier `0.47`
		put that bulge (`0.6`) past `SURFACE_INSET` (`0.4`) entirely: the
		curved wall poked out in front of the recessed painting partway
		along its own width, occluding it in a visible vertical strip
		(reported directly as the painting reading as two separate slivers
		with solid wall between them) — much more visible here than on the
		real tower's own much larger `OUTER_RADIUS`, where the same-order
		absolute bulge is a tiny fraction of the wall's own scale. `0.2`
		keeps the sagitta (`0.15`) comfortably under `SURFACE_INSET`.
	**/
	static inline final PAINTING_HALF_ANGLE:Float = 0.2;

	/** How far beyond `OUTER_RADIUS` collision blocks the player — the spire is solid all the way through, so unlike `MazeShrine`'s per-wall check this is a single circular boundary. **/
	static inline final COLLISION_CLEARANCE:Float = 1.5;

	/** How far past the wall the player reappears when returning from the tower, arc-length in the spire's own local frame — must clear `PaintingModel.TRIGGER_DISTANCE` (4) same as every other biome's own return spawn (see `biomes.maze.MazeBiome.RETURN_SPAWN_OFFSET`'s own doc). **/
	static inline final RETURN_SPAWN_OFFSET:Float = 6;

	/**
		Builds the spire's own wall, floor ledges, roof cap, and the tower's
		painting, anchored at `basis`.
		@param parent the scene object to attach the meshes under.
		@param basis the spire's own local frame (see `HubStructure.anchorAt`).
		@param texture the tower's own painting art.
	**/
	public static function build(parent:h3d.scene.Object, basis:StructureBasis, texture:h3d.mat.Texture):Void {
		var totalHeight = FLOORS * FLOOR_HEIGHT;

		var wallPoints:Array<h3d.Vector> = [];
		var wallIdx = new hxd.IndexBuffer();
		var wallUvs:Array<h3d.prim.UV> = [];
		addFrustumBand(basis, OUTER_RADIUS, 0, OUTER_RADIUS, totalHeight, wallPoints, wallIdx, wallUvs);
		var wallPrim = new h3d.prim.Polygon(wallPoints, wallIdx);
		wallPrim.uvs = wallUvs;
		var wallTexture = hxd.Res.textures.tower_stone_wall.toTexture();
		wallTexture.wrap = Repeat;
		var wallMesh = new h3d.scene.Mesh(wallPrim, parent);
		wallMesh.material.mainPass.addShader(new UnlitTexture(wallTexture));
		wallMesh.material.mainPass.culling = None;

		var stonePoints:Array<h3d.Vector> = [];
		var stoneIdx = new hxd.IndexBuffer();
		var stoneUvs:Array<h3d.prim.UV> = [];
		for (i in 1...FLOORS) {
			addLedge(basis, i * FLOOR_HEIGHT, stonePoints, stoneIdx, stoneUvs);
		}
		addRoofCap(basis, totalHeight, stonePoints, stoneIdx, stoneUvs);
		var stonePrim = new h3d.prim.Polygon(stonePoints, stoneIdx);
		stonePrim.uvs = stoneUvs;
		var floorTexture = hxd.Res.textures.tower_stone_floor.toTexture();
		var stoneMesh = new h3d.scene.Mesh(stonePrim, parent);
		stoneMesh.material.mainPass.addShader(new UnlitTexture(floorTexture));
		stoneMesh.material.mainPass.culling = None;

		buildPainting(parent, basis, texture);
	}

	/** The tower's own painting, mounted on the outer wall at ground level. **/
	static function buildPainting(parent:h3d.scene.Object, basis:StructureBasis, texture:h3d.mat.Texture):Void {
		var wallA = paintingWallEdge(basis, true);
		var wallB = paintingWallEdge(basis, false);
		var roomCenter = ringPoint(basis, OUTER_RADIUS + RETURN_SPAWN_OFFSET, PAINTING_ANGLE, 0);
		var size = PaintingModel.fillWall(FLOOR_HEIGHT);
		PaintingModel.buildQuad(parent, wallA, wallB, roomCenter, texture, size.baseHeight, size.height, basis.up);
	}

	/** One edge of the painting's own mounting segment on the outer wall, at ground level — mirrors `biomes.tower.TowerModel.paintingWallEdge`. **/
	static function paintingWallEdge(basis:StructureBasis, left:Bool):h3d.Vector {
		var angle = PAINTING_ANGLE + (left ? -PAINTING_HALF_ANGLE : PAINTING_HALF_ANGLE);
		return ringPoint(basis, OUTER_RADIUS, angle, 0);
	}

	/**
		A cosmetic floor-division ledge centered at height `y`: steps out to
		`OUTER_RADIUS + LEDGE_PROTRUSION`, runs up `LEDGE_HEIGHT`, then steps
		back in — a belt course, not a texture seam alone, so the division
		actually reads from a distance.
	**/
	static function addLedge(basis:StructureBasis, y:Float, points:Array<h3d.Vector>, idx:hxd.IndexBuffer, uvs:Array<h3d.prim.UV>):Void {
		var ledgeRadius = OUTER_RADIUS + LEDGE_PROTRUSION;
		addFrustumBand(basis, OUTER_RADIUS, y, ledgeRadius, y, points, idx, uvs);
		addFrustumBand(basis, ledgeRadius, y, ledgeRadius, y + LEDGE_HEIGHT, points, idx, uvs);
		addFrustumBand(basis, ledgeRadius, y + LEDGE_HEIGHT, OUTER_RADIUS, y + LEDGE_HEIGHT, points, idx, uvs);
	}

	/** The spire's own flat roof, sealing its top so it doesn't read as hollow. **/
	static function addRoofCap(basis:StructureBasis, y:Float, points:Array<h3d.Vector>, idx:hxd.IndexBuffer, uvs:Array<h3d.prim.UV>):Void {
		var center = HubStructure.worldPoint(basis, 0, 0, y);
		for (i in 0...WALL_SEGMENTS) {
			var angleA = i * (2 * Math.PI / WALL_SEGMENTS);
			var angleB = (i + 1) * (2 * Math.PI / WALL_SEGMENTS);
			var a = ringPoint(basis, OUTER_RADIUS, angleA, y);
			var b = ringPoint(basis, OUTER_RADIUS, angleB, y);
			MeshBuilder.addTriangle(points, idx, center, a, b);
			uvs.push(new h3d.prim.UV(0.5, 0.5));
			uvs.push(new h3d.prim.UV(0.5 + Math.cos(angleA) * 0.5, 0.5 + Math.sin(angleA) * 0.5));
			uvs.push(new h3d.prim.UV(0.5 + Math.cos(angleB) * 0.5, 0.5 + Math.sin(angleB) * 0.5));
		}
	}

	/**
		A ring/frustum band between two (radius, height) circles — the
		spire's own single reusable shape: a plain cylindrical wall
		(`radiusA == radiusB`), or a ledge's own step-out/step-in
		(`heightA == heightB`), or its vertical rise, all the same geometry
		just with different endpoints.
	**/
	static function addFrustumBand(basis:StructureBasis, radiusA:Float, heightA:Float, radiusB:Float, heightB:Float, points:Array<h3d.Vector>,
			idx:hxd.IndexBuffer, uvs:Array<h3d.prim.UV>):Void {
		for (i in 0...WALL_SEGMENTS) {
			var angleA = i * (2 * Math.PI / WALL_SEGMENTS);
			var angleB = (i + 1) * (2 * Math.PI / WALL_SEGMENTS);
			var a = ringPoint(basis, radiusA, angleA, heightA);
			var b = ringPoint(basis, radiusA, angleB, heightA);
			var c = ringPoint(basis, radiusB, angleB, heightB);
			var d = ringPoint(basis, radiusB, angleA, heightB);

			var uRepeat = a.sub(b).length() / MeshBuilder.WALL_TEXTURE_TILE_SIZE;
			var vRepeat = a.sub(d).length() / MeshBuilder.WALL_TEXTURE_TILE_SIZE;
			MeshBuilder.addQuad(points, idx, a, b, c, d);
			uvs.push(new h3d.prim.UV(0, vRepeat));
			uvs.push(new h3d.prim.UV(uRepeat, vRepeat));
			uvs.push(new h3d.prim.UV(uRepeat, 0));
			uvs.push(new h3d.prim.UV(0, 0));
		}
	}

	/** A world point on the spire's own circle at `radius`/`angle`, raised `height` above `basis`'s own ground level. **/
	static function ringPoint(basis:StructureBasis, radius:Float, angle:Float, height:Float):h3d.Vector {
		return HubStructure.worldPoint(basis, radius * Math.cos(angle), radius * Math.sin(angle), height);
	}

	/**
		Whether `worldPos` is too close to the spire — a single circular
		boundary (unlike `MazeShrine`'s per-wall segments), since the spire
		is solid all the way through: there's no wall to walk alongside,
		only an edge to not walk into.
		@param basis the spire's own local frame.
		@param worldPos the position to check — typically the player's own tentative new position.
		@return true if `worldPos` is blocked by the spire.
	**/
	public static function blocksMovement(basis:StructureBasis, worldPos:h3d.Vector):Bool {
		var uv = HubStructure.localUV(basis, worldPos);
		return Math.sqrt(uv.u * uv.u + uv.v * uv.v) < OUTER_RADIUS + COLLISION_CLEARANCE;
	}

	/**
		The tower's own painting as a trigger — floor-level (`midpointOf`),
		matching every other painting in this project.
		@param basis the spire's own local frame.
		@param destinationBiomeId `biomes.tower.TowerBiome.ID`.
		@return the spire's own exit painting.
	**/
	public static function exitPainting(basis:StructureBasis, destinationBiomeId:String):PaintingModel {
		var wallA = paintingWallEdge(basis, true);
		var wallB = paintingWallEdge(basis, false);
		return new PaintingModel(PaintingModel.midpointOf(wallA, wallB), destinationBiomeId);
	}

	/**
		A `PlayerModel` standing `RETURN_SPAWN_OFFSET` past the spire's own
		wall, at the painting's own angle, facing back in toward it — where
		the player reappears coming back out of the tower. Re-projected onto
		the hub's true sphere, same correction `MazeShrine.returnSpawn`
		already makes for the same reason.
		@param basis the spire's own local frame.
		@param radius the hub's own sphere radius.
		@return the spawned player.
	**/
	public static function returnSpawn(basis:StructureBasis, radius:Float):PlayerModel {
		var spawnDistance = OUTER_RADIUS + RETURN_SPAWN_OFFSET;
		var tentativePos = ringPoint(basis, spawnDistance, PAINTING_ANGLE, 0);
		var pos = tentativePos.normalized().scaled(radius);

		var intoSpire = basis.uAxis.scaled(-Math.cos(PAINTING_ANGLE)).add(basis.vAxis.scaled(-Math.sin(PAINTING_ANGLE)));
		var posDir = pos.normalized();
		var forward = intoSpire.sub(posDir.scaled(intoSpire.dot(posDir))).normalized();
		return new PlayerModel(pos, forward);
	}
}
