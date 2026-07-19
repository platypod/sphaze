package biomes.tower;

import biomes.tower.TowerModel.TowerData;
import entities.painting.PaintingModel;
import game.MeshBuilder;
import graphics.shaders.Dim;
import graphics.shaders.TileRingGlow;
import graphics.shaders.UnlitTexture;

/**
	The floor's own ring-glow shader param `build` hands back to
	`TowerBiome`, so it can grow it as its own fall counter climbs
	(`setFallGlow`) without this module holding onto `TowerBiome`'s own
	state, or `TowerBiome` holding onto meshes that are really this module's
	concern. Floor only — see `TileRingGlow`'s own class doc for why this
	replaced an earlier attempt at tinting the *wall*'s own bricks instead.
**/
typedef TowerVisuals = {
	var floorGlow:TileRingGlow;
}

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
		How much the floor/wall's own base stone texture is darkened (see
		`graphics.shaders.Dim`) — direct ask: "tackle the base ambient
		lighting reduction in the tower... let's see where it gets us," so
		the fall counter's own floor glow (`TileRingGlow`, added to the same
		mesh *after* this in the shader list, so it isn't dimmed along with
		the base it sits on) reads with more contrast against a darker
		stone. First-pass value, tune by feel once playable.
	**/
	static inline final AMBIENT_BRIGHTNESS:Float = 0.5;

	/**
		How many layers' worth of floor/relief-wall geometry go into one
		mesh — `addQuad`/`addTriangle` (`game.MeshBuilder`) never share or
		reuse a vertex, so a single mesh spanning the whole, now much taller
		shaft can rack up more distinct vertices than `hxd.IndexBuffer` can
		actually index (an `Array<UInt16>` under the hood, so indices past
		`65536` silently wrap back to `0` instead of erroring) — reported
		directly as the bottom five or so layers reading with missing floor
		texture, since geometry appended after the wraparound point ends up
		referencing the *wrong* (much earlier) vertices instead of its own.
		`15` keeps every chunk's own worst-case vertex count comfortably
		under the limit regardless of how a given layout's own random tiles
		actually turn out, not just usually: a relief-wall layer's own
		absolute ceiling — every ring boundary and every radial end
		simultaneously needing a wall, an alternating solid/hole checkerboard
		— works out to `3072` vertices (`addReliefWalls`); `15 * 3072 =
		46080` stays well clear of `65536` even then. The floor's own
		per-layer ceiling (`2736`, every tile solid) is lower still, so the
		same chunk size covers it with room to spare too.
	**/
	static inline final LAYERS_PER_CHUNK:Int = 15;

	/**
		@param layout the tower's own generated layout.
		@param parent the scene object to attach the meshes under.
		@return the floor's own ring-glow shader param `TowerBiome` grows as its own fall counter climbs — see `setFallGlow`.
	**/
	public static function build(layout:TowerData, parent:h3d.scene.Object):TowerVisuals {
		var floorTexture = hxd.Res.textures.tower_stone_floor.toTexture();
		var wallTexture = hxd.Res.textures.tower_stone_wall.toTexture();
		wallTexture.wrap = Repeat;

		// One shared shader instance (not one per chunk) - TowerBiome.setFallGlow
		// sets its params once and every floor chunk mesh it's attached to
		// picks up the change, same as any other shared hxsl.Shader instance.
		var floorGlow = new TileRingGlow(TowerModel.CENTER_DISK_RADIUS, TowerModel.ringWidth(), 2 * TowerModel.OUTER_RADIUS);

		var fromLayer = 0;
		while (fromLayer < TowerModel.TOTAL_LEVELS) {
			var toLayer = hxd.Math.imin(fromLayer + LAYERS_PER_CHUNK, TowerModel.TOTAL_LEVELS);
			buildFloorChunk(layout, parent, fromLayer, toLayer, floorTexture, floorGlow);
			buildWallChunk(layout, parent, fromLayer, toLayer, wallTexture);
			fromLayer = toLayer;
		}

		// Fixed 32-segment cylinder regardless of the shaft's own depth - never
		// at risk of the same overflow, so it stays its own single mesh rather
		// than chunked alongside the relief walls above.
		var outerWallPoints:Array<h3d.Vector> = [];
		var outerWallIdx = new hxd.IndexBuffer();
		var outerWallUvs:Array<h3d.prim.UV> = [];
		addOuterWall(outerWallPoints, outerWallIdx, outerWallUvs);
		var outerWallPrim = new h3d.prim.Polygon(outerWallPoints, outerWallIdx);
		outerWallPrim.uvs = outerWallUvs;
		var outerWallMesh = new h3d.scene.Mesh(outerWallPrim, parent);
		outerWallMesh.material.mainPass.addShader(new UnlitTexture(wallTexture));
		outerWallMesh.material.mainPass.addShader(new Dim(AMBIENT_BRIGHTNESS));
		outerWallMesh.material.mainPass.culling = None;

		buildHubPaintingQuad(parent, TowerModel.SPAWN_LAYER);
		buildHubPaintingQuad(parent, TowerModel.TOTAL_LEVELS - 1);

		return {floorGlow: floorGlow};
	}

	/** One floor chunk mesh, covering layers `fromLayer` (inclusive) to `toLayer` (exclusive) — see `LAYERS_PER_CHUNK`'s own doc. **/
	static function buildFloorChunk(layout:TowerData, parent:h3d.scene.Object, fromLayer:Int, toLayer:Int, texture:h3d.mat.Texture,
			floorGlow:TileRingGlow):Void {
		var points:Array<h3d.Vector> = [];
		var idx = new hxd.IndexBuffer();
		var uvs:Array<h3d.prim.UV> = [];
		addFloors(layout, fromLayer, toLayer, points, idx, uvs);
		var prim = new h3d.prim.Polygon(points, idx);
		prim.uvs = uvs;
		var mesh = new h3d.scene.Mesh(prim, parent);
		mesh.material.mainPass.addShader(new UnlitTexture(texture));
		mesh.material.mainPass.addShader(new Dim(AMBIENT_BRIGHTNESS));
		mesh.material.mainPass.addShader(floorGlow);
		mesh.material.mainPass.culling = None;
	}

	/** One relief-wall chunk mesh, covering layers `fromLayer` (inclusive) to `toLayer` (exclusive) — see `LAYERS_PER_CHUNK`'s own doc. **/
	static function buildWallChunk(layout:TowerData, parent:h3d.scene.Object, fromLayer:Int, toLayer:Int, texture:h3d.mat.Texture):Void {
		var points:Array<h3d.Vector> = [];
		var idx = new hxd.IndexBuffer();
		var uvs:Array<h3d.prim.UV> = [];
		addReliefWalls(layout, fromLayer, toLayer, points, idx, uvs);
		var prim = new h3d.prim.Polygon(points, idx);
		prim.uvs = uvs;
		var mesh = new h3d.scene.Mesh(prim, parent);
		mesh.material.mainPass.addShader(new UnlitTexture(texture));
		mesh.material.mainPass.addShader(new Dim(AMBIENT_BRIGHTNESS));
		mesh.material.mainPass.culling = None;
	}

	/**
		Sets the floor's own ring-glow reach/strength to `intensity` (see
		`TowerModel.fallGlowIntensity`) and its tint to `color` — `TowerBiome`
		calls this every time its own fall counter changes, not per-frame,
		since the counter only ever changes on a landing event, plus once
		more, unconditionally, if the hourglass secret was already unlocked
		by the time this visit's own `build()` ran (see that method's own
		doc).
		@param visuals the handle returned by `build`.
		@param intensity glow strength, 0 (none) to 1 (every ring boundary lit) — see `TileRingGlow.intensity`.
		@param color the glow's own tint — plain white for the ordinary fall counter, gold once the hourglass secret's unlocked (see `graphics.Colours.TOWER_SECRET_GLOW`).
	**/
	public static function setFallGlow(visuals:TowerVisuals, intensity:Float, color:Int = 0xFFFFFFFF):Void {
		visuals.floorGlow.intensity = intensity;
		visuals.floorGlow.glowColor.setColor(color);
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

	/**
		`fromLayer` (inclusive) to `toLayer` (exclusive)'s own center disk
		plus whichever ring tiles are solid there — top/bottom faces only;
		see `addReliefWalls` for the sides. A sub-range, not always the
		whole shaft, so `build` can chunk it across several meshes — see
		`LAYERS_PER_CHUNK`'s own doc.
	**/
	static function addFloors(layout:TowerData, fromLayer:Int, toLayer:Int, points:Array<h3d.Vector>, idx:hxd.IndexBuffer, uvs:Array<h3d.prim.UV>):Void {
		for (layer in fromLayer...toLayer) {
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
		`fromLayer` (inclusive) to `toLayer` (exclusive)'s own relief side
		walls: the center disk's own rim, and each solid ring tile's
		inner/outer arc and two radial ends — only where the neighboring
		tile/ring/disk isn't itself solid (see class doc for why an
		unconditional wall there would z-fight). A sub-range, not always the
		whole shaft — see `addFloors`'s own doc for why.
	**/
	static function addReliefWalls(layout:TowerData, fromLayer:Int, toLayer:Int, points:Array<h3d.Vector>, idx:hxd.IndexBuffer, uvs:Array<h3d.prim.UV>):Void {
		for (layer in fromLayer...toLayer) {
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
		var bottom = TowerModel.layerY(TowerModel.TOTAL_LEVELS - 1) - WALL_MARGIN;

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
