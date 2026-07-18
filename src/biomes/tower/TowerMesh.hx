package biomes.tower;

import biomes.tower.TowerModel.TowerData;
import entities.painting.PaintingModel;
import game.MeshBuilder;
import graphics.shaders.UnlitTexture;

/**
	Builds the tower's own scene-graph meshes: a floor patch per solid tile
	per layer (the always-solid center disk, plus whichever ring tiles
	`TowerGenerator` made solid), extruded down by `TowerModel.TILE_THICKNESS` rather
	than a bare flat plane, and one continuous cylindrical outer wall
	spanning the whole shaft.

	Every ring boundary (and the center disk's own rim) is sampled at the
	shared `TowerModel.ANGULAR_SEGMENTS` grid rather than each ring's own
	tile count, so adjacent rings — which almost always have *different*
	tile counts — meet at exactly the same points instead of each
	approximating the shared boundary circle with a different-sided
	polygon (see `TowerModel.ANGULAR_SEGMENTS`'s own doc). A tile's relief
	side wall (`addReliefWalls`/`addRingTileWalls`) only gets built where
	the neighboring tile/ring/disk *isn't* itself solid — same "don't render a face two
	solid pieces would share, invisible either way" discipline
	`biomes.common.grid.GridMesh`'s own `WallBuilder` already established,
	and for the same reason: an unconditional face there would sit exactly
	coincident with its solid neighbor's own face, the flickering z-fight
	that project history already ran into once.

	Floor (top/bottom faces) and the relief side walls/outer wall use two
	different textures, so two separate meshes, same split
	`biomes.common.grid.GridMesh` keeps for its own floor/wall. The floor
	is one large medallion decal (absolute-position UVs, no tiling — see
	`floorUv`) rather than a repeating pattern, so its own baked-in ring
	art can actually line up with the real geometry sitting on top of it;
	the walls tile normally (arc-length/height-based UVs, same convention
	`biomes.hub.HubMesh.buildColumn` already uses).
**/
class TowerMesh {
	/** Segments the outer wall's circular cross-section is built from — smooth enough not to read as faceted, unlike `biomes.hub.HubMesh`'s deliberately 8-sided column. **/
	static inline final WALL_SEGMENTS:Int = 32;

	/** How far the outer wall extends above the topmost layer and below the bottom-most one — just enough that the shaft reads as fully enclosed from any reachable camera angle, never needing to see past either end. **/
	static inline final WALL_MARGIN:Float = TowerModel.LAYER_HEIGHT;

	/**
		@param layout the tower's own generated layout.
		@param parent the scene object to attach the meshes under.
	**/
	public static function build(layout:TowerData, parent:h3d.scene.Object):Void {
		var floorPoints:Array<h3d.Vector> = [];
		var floorIdx = new hxd.IndexBuffer();
		var floorUvs:Array<h3d.prim.UV> = [];
		addFloors(layout, floorPoints, floorIdx, floorUvs);
		var floorPrim = new h3d.prim.Polygon(floorPoints, floorIdx);
		floorPrim.uvs = floorUvs;
		var floorMesh = new h3d.scene.Mesh(floorPrim, parent);
		var floorTexture = hxd.Res.textures.tower_stone_floor.toTexture();
		floorMesh.material.mainPass.addShader(new UnlitTexture(floorTexture));
		floorMesh.material.mainPass.culling = None;

		var wallPoints:Array<h3d.Vector> = [];
		var wallIdx = new hxd.IndexBuffer();
		var wallUvs:Array<h3d.prim.UV> = [];
		addReliefWalls(layout, wallPoints, wallIdx, wallUvs);
		addOuterWall(wallPoints, wallIdx, wallUvs);
		var wallPrim = new h3d.prim.Polygon(wallPoints, wallIdx);
		wallPrim.uvs = wallUvs;
		var wallTexture = hxd.Res.textures.tower_stone_wall.toTexture();
		wallTexture.wrap = Repeat;
		var wallMesh = new h3d.scene.Mesh(wallPrim, parent);
		wallMesh.material.mainPass.addShader(new UnlitTexture(wallTexture));
		wallMesh.material.mainPass.culling = None;

		buildHubPaintingQuad(parent, 0);
		buildHubPaintingQuad(parent, TowerModel.GOAL_LEVELS - 1);
	}

	/**
		The visual for a hub-bound painting mounted at `layer`'s own height
		— built unconditionally for both the entrance (layer 0) and goal
		(bottom) layers regardless of whether `TowerBiome.exitPaintings`
		actually makes the goal one triggerable yet: it sits at the very
		bottom of the shaft, physically unreachable until the player has
		already fallen all the way down, so rendering it early is never
		actually visible ahead of time.
	**/
	static function buildHubPaintingQuad(parent:h3d.scene.Object, layer:Int):Void {
		var left = TowerModel.paintingWallEdge(layer, true);
		var right = TowerModel.paintingWallEdge(layer, false);
		var roomCenter = new h3d.Vector(0, left.y, 0);
		var size = PaintingModel.fillWall(TowerModel.LAYER_HEIGHT - TowerModel.TILE_THICKNESS);
		PaintingModel.buildQuad(parent, left, right, roomCenter, PaintingModel.toHubTexture(), size.baseHeight, size.height, new h3d.Vector(0, 1, 0));
	}

	/** Every layer's own center disk plus whichever ring tiles are solid there — top/bottom faces only; see `addReliefWalls` for the sides. **/
	static function addFloors(layout:TowerData, points:Array<h3d.Vector>, idx:hxd.IndexBuffer, uvs:Array<h3d.prim.UV>):Void {
		for (layer in 0...TowerModel.GOAL_LEVELS) {
			var y = TowerModel.layerY(layer);
			addCenterDiskFaces(y, points, idx, uvs);

			for (ring in 0...TowerModel.RINGS_PER_LAYER) {
				for (tile in 0...TowerModel.tilesForRing(ring)) {
					if (layout.solidTiles[layer][ring][tile]) {
						addRingTileFaces(y, ring, tile, points, idx, uvs);
					}
				}
			}
		}
	}

	/** The always-solid center disk's top and bottom faces at height `y`, as matching triangle fans `TowerModel.TILE_THICKNESS` apart. **/
	static function addCenterDiskFaces(y:Float, points:Array<h3d.Vector>, idx:hxd.IndexBuffer, uvs:Array<h3d.prim.UV>):Void {
		var top = new h3d.Vector(0, y, 0);
		var bottom = new h3d.Vector(0, y - TowerModel.TILE_THICKNESS, 0);
		for (s in 0...TowerModel.ANGULAR_SEGMENTS) {
			var a = slotPoint(TowerModel.CENTER_DISK_RADIUS, s, y);
			var b = slotPoint(TowerModel.CENTER_DISK_RADIUS, s + 1, y);
			var aBottom = slotPoint(TowerModel.CENTER_DISK_RADIUS, s, y - TowerModel.TILE_THICKNESS);
			var bBottom = slotPoint(TowerModel.CENTER_DISK_RADIUS, s + 1, y - TowerModel.TILE_THICKNESS);
			addFloorTriangle(top, a, b, points, idx, uvs);
			addFloorTriangle(bottom, aBottom, bBottom, points, idx, uvs);
		}
	}

	/** One solid ring tile's top and bottom faces, subdivided at the shared angular grid so its curved edges actually meet its neighbors' (see class doc). **/
	static function addRingTileFaces(y:Float, ring:Int, tile:Int, points:Array<h3d.Vector>, idx:hxd.IndexBuffer, uvs:Array<h3d.prim.UV>):Void {
		var innerR = TowerModel.CENTER_DISK_RADIUS + ring * TowerModel.ringWidth();
		var outerR = innerR + TowerModel.ringWidth();
		var slotsPerTile = TowerModel.slotsPerTile(ring);
		var startSlot = TowerModel.ringOffsetSlots(ring) + tile * slotsPerTile;

		for (i in 0...slotsPerTile) {
			var s = startSlot + i;
			var innerA = slotPoint(innerR, s, y);
			var innerB = slotPoint(innerR, s + 1, y);
			var outerA = slotPoint(outerR, s, y);
			var outerB = slotPoint(outerR, s + 1, y);
			addFloorQuad(innerA, outerA, outerB, innerB, points, idx, uvs);

			var innerABottom = slotPoint(innerR, s, y - TowerModel.TILE_THICKNESS);
			var innerBBottom = slotPoint(innerR, s + 1, y - TowerModel.TILE_THICKNESS);
			var outerABottom = slotPoint(outerR, s, y - TowerModel.TILE_THICKNESS);
			var outerBBottom = slotPoint(outerR, s + 1, y - TowerModel.TILE_THICKNESS);
			addFloorQuad(innerABottom, outerABottom, outerBBottom, innerBBottom, points, idx, uvs);
		}
	}

	/**
		Every relief side wall: the center disk's own rim, and each solid
		ring tile's inner/outer arc and two radial ends — only where the
		neighboring tile/ring/disk isn't itself solid (see class doc for
		why an unconditional wall there would z-fight).
	**/
	static function addReliefWalls(layout:TowerData, points:Array<h3d.Vector>, idx:hxd.IndexBuffer, uvs:Array<h3d.prim.UV>):Void {
		for (layer in 0...TowerModel.GOAL_LEVELS) {
			var y = TowerModel.layerY(layer);

			for (s in 0...TowerModel.ANGULAR_SEGMENTS) {
				if (!isSolidAtSlot(layout, layer, 0, s)) {
					addWallQuadAtSlot(TowerModel.CENTER_DISK_RADIUS, s, y, points, idx, uvs);
				}
			}

			for (ring in 0...TowerModel.RINGS_PER_LAYER) {
				for (tile in 0...TowerModel.tilesForRing(ring)) {
					if (!layout.solidTiles[layer][ring][tile]) {
						continue;
					}
					addRingTileWalls(layout, layer, y, ring, tile, points, idx, uvs);
				}
			}
		}
	}

	static function addRingTileWalls(layout:TowerData, layer:Int, y:Float, ring:Int, tile:Int, points:Array<h3d.Vector>, idx:hxd.IndexBuffer,
			uvs:Array<h3d.prim.UV>):Void {
		var innerR = TowerModel.CENTER_DISK_RADIUS + ring * TowerModel.ringWidth();
		var outerR = innerR + TowerModel.ringWidth();
		var slotsPerTile = TowerModel.slotsPerTile(ring);
		var startSlot = TowerModel.ringOffsetSlots(ring) + tile * slotsPerTile;

		for (i in 0...slotsPerTile) {
			var s = startSlot + i;
			if (!isSolidAtSlot(layout, layer, ring - 1, s)) {
				addWallQuadAtSlot(innerR, s, y, points, idx, uvs);
			}
			if (!isSolidAtSlot(layout, layer, ring + 1, s)) {
				addWallQuadAtSlot(outerR, s, y, points, idx, uvs);
			}
		}

		var tileCount = TowerModel.tilesForRing(ring);
		var prevTile = (tile - 1 + tileCount) % tileCount;
		var nextTile = (tile + 1) % tileCount;
		if (!layout.solidTiles[layer][ring][prevTile]) {
			addRadialEndCap(innerR, outerR, startSlot, y, points, idx, uvs);
		}
		if (!layout.solidTiles[layer][ring][nextTile]) {
			addRadialEndCap(innerR, outerR, startSlot + slotsPerTile, y, points, idx, uvs);
		}
	}

	/**
		Whether `ring`'s tile at shared-grid slot `s` is solid, at `layer` —
		`ring < 0` (the center disk) and `ring >= TowerModel.RINGS_PER_LAYER`
		(past the outermost ring, i.e. the tower's own outer wall) both
		read as unconditionally solid, so a tile bordering either of them
		never gets a redundant relief wall built against something already
		solid there.
	**/
	static function isSolidAtSlot(layout:TowerData, layer:Int, ring:Int, s:Int):Bool {
		if (ring < 0 || ring >= TowerModel.RINGS_PER_LAYER) {
			return true;
		}
		return layout.solidTiles[layer][ring][TowerModel.tileIndexAtSlot(ring, s)];
	}

	/** A radial (tile-to-tile) end cap wall at shared-grid slot boundary `slot`, spanning `innerR` to `outerR` and `y` down to `y - TowerModel.TILE_THICKNESS`. **/
	static function addRadialEndCap(innerR:Float, outerR:Float, slot:Int, y:Float, points:Array<h3d.Vector>, idx:hxd.IndexBuffer, uvs:Array<h3d.prim.UV>):Void {
		var inner = slotPoint(innerR, slot, y);
		var outer = slotPoint(outerR, slot, y);
		var innerBottom = slotPoint(innerR, slot, y - TowerModel.TILE_THICKNESS);
		var outerBottom = slotPoint(outerR, slot, y - TowerModel.TILE_THICKNESS);
		addWallQuad(inner, outer, outerBottom, innerBottom, points, idx, uvs);
	}

	/** A relief side wall's own single shared-grid segment, at radius `radius`, from slot `s` to `s + 1`, `y` down to `y - TowerModel.TILE_THICKNESS`. **/
	static function addWallQuadAtSlot(radius:Float, s:Int, y:Float, points:Array<h3d.Vector>, idx:hxd.IndexBuffer, uvs:Array<h3d.prim.UV>):Void {
		var a = slotPoint(radius, s, y);
		var b = slotPoint(radius, s + 1, y);
		var aBottom = slotPoint(radius, s, y - TowerModel.TILE_THICKNESS);
		var bBottom = slotPoint(radius, s + 1, y - TowerModel.TILE_THICKNESS);
		addWallQuad(a, b, bBottom, aBottom, points, idx, uvs);
	}

	/** One continuous cylindrical wall around the whole shaft, `WALL_MARGIN` past its top and bottom layers. **/
	static function addOuterWall(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, uvs:Array<h3d.prim.UV>):Void {
		var top = TowerModel.layerY(0) + WALL_MARGIN;
		var bottom = TowerModel.layerY(TowerModel.GOAL_LEVELS - 1) - WALL_MARGIN;

		for (i in 0...WALL_SEGMENTS) {
			var a = i * (2 * Math.PI / WALL_SEGMENTS);
			var b = (i + 1) * (2 * Math.PI / WALL_SEGMENTS);
			var topA = angledPoint(TowerModel.OUTER_RADIUS, a, top);
			var topB = angledPoint(TowerModel.OUTER_RADIUS, b, top);
			var bottomA = angledPoint(TowerModel.OUTER_RADIUS, a, bottom);
			var bottomB = angledPoint(TowerModel.OUTER_RADIUS, b, bottom);
			addWallQuad(topA, topB, bottomB, bottomA, points, idx, uvs);
		}
	}

	/**
		Appends a floor-textured triangle — UVs from `floorUv`, the shared
		medallion decal mapping (see class doc), not a per-triangle repeat.
	**/
	static function addFloorTriangle(a:h3d.Vector, b:h3d.Vector, c:h3d.Vector, points:Array<h3d.Vector>, idx:hxd.IndexBuffer, uvs:Array<h3d.prim.UV>):Void {
		MeshBuilder.addTriangle(points, idx, a, b, c);
		uvs.push(floorUv(a));
		uvs.push(floorUv(b));
		uvs.push(floorUv(c));
	}

	/** Appends a floor-textured quad — see `addFloorTriangle`. **/
	static function addFloorQuad(a:h3d.Vector, b:h3d.Vector, c:h3d.Vector, d:h3d.Vector, points:Array<h3d.Vector>, idx:hxd.IndexBuffer,
			uvs:Array<h3d.prim.UV>):Void {
		MeshBuilder.addQuad(points, idx, a, b, c, d);
		uvs.push(floorUv(a));
		uvs.push(floorUv(b));
		uvs.push(floorUv(c));
		uvs.push(floorUv(d));
	}

	/** The floor medallion decal's own UV for a world point — absolute position within the whole shaft's cross-section, normalized to [0, 1] over its full diameter, so the baked-in texture art lines up with the real ring geometry sitting on it rather than repeating per tile. **/
	static function floorUv(p:h3d.Vector):h3d.prim.UV {
		return new h3d.prim.UV(p.x / (2 * TowerModel.OUTER_RADIUS) + 0.5, p.z / (2 * TowerModel.OUTER_RADIUS) + 0.5);
	}

	/** Appends a wall-textured quad — `a`/`d` at u=0, `b`/`c` at u=uRepeat (arc length between `a` and `b`, tiled), `a`/`b` at v=vRepeat (the quad's own height, tiled), `c`/`d` at v=0. Same convention `biomes.hub.HubMesh.buildColumn` already uses. **/
	static function addWallQuad(a:h3d.Vector, b:h3d.Vector, c:h3d.Vector, d:h3d.Vector, points:Array<h3d.Vector>, idx:hxd.IndexBuffer,
			uvs:Array<h3d.prim.UV>):Void {
		var uRepeat = a.sub(b).length() / MeshBuilder.WALL_TEXTURE_TILE_SIZE;
		var vRepeat = a.sub(d).length() / MeshBuilder.WALL_TEXTURE_TILE_SIZE;
		MeshBuilder.addQuad(points, idx, a, b, c, d);
		uvs.push(new h3d.prim.UV(0, vRepeat));
		uvs.push(new h3d.prim.UV(uRepeat, vRepeat));
		uvs.push(new h3d.prim.UV(uRepeat, 0));
		uvs.push(new h3d.prim.UV(0, 0));
	}

	/** A point at `radius`/`y`, at shared-grid slot `s`'s own angle (see `TowerModel.SLOT_ANGLE`) — wraps automatically, since angle itself is periodic. **/
	static inline function slotPoint(radius:Float, s:Int, y:Float):h3d.Vector {
		return angledPoint(radius, s * TowerModel.SLOT_ANGLE, y);
	}

	static inline function angledPoint(radius:Float, angle:Float, y:Float):h3d.Vector {
		return new h3d.Vector(radius * Math.cos(angle), y, radius * Math.sin(angle));
	}
}
