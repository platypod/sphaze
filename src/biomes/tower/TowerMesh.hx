package biomes.tower;

import biomes.tower.TowerModel.TowerData;
import entities.painting.PaintingModel;
import game.MeshBuilder;
import graphics.Colours;

/**
	Builds the tower's own scene-graph meshes: a floor patch per solid tile
	per layer (the always-solid center disk, plus whichever ring tiles
	`TowerGenerator` made solid), and one continuous cylindrical outer wall
	spanning the whole shaft. Flat-colored placeholders (`h3d.shader.FixedColor`,
	no lights, double-sided, per `graphics.Colours`) — the floor/walls
	themselves aren't textured yet, unlike `biomes.common.grid.GridMesh`/
	`biomes.hub.HubMesh`; the return painting mounted here, however, *is*
	real art (see `entities.painting.PaintingModel.buildQuad`).

	Each ring tile is a single flat quad spanning its own inner/outer radius
	and start/end angle — a straight-edged approximation of its true arc,
	same tolerance for flat approximation over exact curved geometry
	`biomes.maze.MazeMesh`'s own walls already accept.

	Also mounts the return painting on the outer wall at the goal layer's
	own height, unconditionally — `biomes.tower.TowerBiome.exitPaintings`
	gates whether it actually *triggers*, but the quad itself can just
	always be there: it sits at the very bottom of the shaft, physically
	unreachable until the player has already fallen all the way down, so
	rendering it early is never actually visible ahead of time.
**/
class TowerMesh {
	/** Segments the always-solid center disk is built from — its own fixed roundness, independent of any ring's own tile count. **/
	static inline final CENTER_DISK_SEGMENTS:Int = 16;

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
		addFloors(layout, floorPoints, floorIdx);
		var floorMesh = new h3d.scene.Mesh(new h3d.prim.Polygon(floorPoints, floorIdx), parent);
		floorMesh.material.mainPass.addShader(new h3d.shader.FixedColor(Colours.TOWER_FLOOR));
		floorMesh.material.mainPass.culling = None;

		var wallPoints:Array<h3d.Vector> = [];
		var wallIdx = new hxd.IndexBuffer();
		addOuterWall(wallPoints, wallIdx);
		var wallMesh = new h3d.scene.Mesh(new h3d.prim.Polygon(wallPoints, wallIdx), parent);
		wallMesh.material.mainPass.addShader(new h3d.shader.FixedColor(Colours.TOWER_WALL));
		wallMesh.material.mainPass.culling = None;

		var left = TowerModel.returnPaintingWallEdge(true);
		var right = TowerModel.returnPaintingWallEdge(false);
		var roomCenter = new h3d.Vector(0, left.y, 0);
		PaintingModel.buildQuad(parent, left, right, roomCenter, PaintingModel.toHubTexture(), new h3d.Vector(0, 1, 0));
	}

	/** Every layer's own center disk plus whichever ring tiles are solid there. **/
	static function addFloors(layout:TowerData, points:Array<h3d.Vector>, idx:hxd.IndexBuffer):Void {
		for (layer in 0...TowerModel.GOAL_LEVELS) {
			var y = TowerModel.layerY(layer);
			addCenterDisk(y, points, idx);

			for (ring in 0...TowerModel.RINGS_PER_LAYER) {
				for (tile in 0...TowerModel.tilesForRing(ring)) {
					if (layout.solidTiles[layer][ring][tile]) {
						addRingTile(y, ring, tile, points, idx);
					}
				}
			}
		}
	}

	/** The always-solid center disk at height `y`, as a triangle fan. **/
	static function addCenterDisk(y:Float, points:Array<h3d.Vector>, idx:hxd.IndexBuffer):Void {
		var center = new h3d.Vector(0, y, 0);
		for (i in 0...CENTER_DISK_SEGMENTS) {
			var a = diskPoint(TowerModel.CENTER_DISK_RADIUS, angleAt(i, CENTER_DISK_SEGMENTS), y);
			var b = diskPoint(TowerModel.CENTER_DISK_RADIUS, angleAt(i + 1, CENTER_DISK_SEGMENTS), y);
			MeshBuilder.addTriangle(points, idx, center, a, b);
		}
	}

	/** One ring tile at height `y` — see class doc for why this is a flat quad, not a true arc. **/
	static function addRingTile(y:Float, ring:Int, tile:Int, points:Array<h3d.Vector>, idx:hxd.IndexBuffer):Void {
		var innerR = TowerModel.CENTER_DISK_RADIUS + ring * TowerModel.ringWidth();
		var outerR = innerR + TowerModel.ringWidth();
		var tileWidth = 2 * Math.PI / TowerModel.tilesForRing(ring);
		var angleStart = TowerModel.ringAngleOffset(ring) + tile * tileWidth;
		var angleEnd = angleStart + tileWidth;

		var innerStart = diskPoint(innerR, angleStart, y);
		var outerStart = diskPoint(outerR, angleStart, y);
		var outerEnd = diskPoint(outerR, angleEnd, y);
		var innerEnd = diskPoint(innerR, angleEnd, y);
		MeshBuilder.addQuad(points, idx, innerStart, outerStart, outerEnd, innerEnd);
	}

	/** One continuous cylindrical wall around the whole shaft, `WALL_MARGIN` past its top and bottom layers. **/
	static function addOuterWall(points:Array<h3d.Vector>, idx:hxd.IndexBuffer):Void {
		var top = TowerModel.layerY(0) + WALL_MARGIN;
		var bottom = TowerModel.layerY(TowerModel.GOAL_LEVELS - 1) - WALL_MARGIN;

		for (i in 0...WALL_SEGMENTS) {
			var a = angleAt(i, WALL_SEGMENTS);
			var b = angleAt(i + 1, WALL_SEGMENTS);
			var topA = diskPoint(TowerModel.OUTER_RADIUS, a, top);
			var topB = diskPoint(TowerModel.OUTER_RADIUS, b, top);
			var bottomA = diskPoint(TowerModel.OUTER_RADIUS, a, bottom);
			var bottomB = diskPoint(TowerModel.OUTER_RADIUS, b, bottom);
			MeshBuilder.addQuad(points, idx, topA, topB, bottomB, bottomA);
		}
	}

	static inline function angleAt(i:Int, segments:Int):Float {
		return i * (2 * Math.PI / segments);
	}

	static inline function diskPoint(radius:Float, angle:Float, y:Float):h3d.Vector {
		return new h3d.Vector(radius * Math.cos(angle), y, radius * Math.sin(angle));
	}
}
