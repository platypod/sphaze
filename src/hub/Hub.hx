package hub;

import maze.MazeGeometry;
import maze.MazeMesh;

/**
	The hub: a small, hand-authored hexagonal room on the same physical
	sphere biomes use (`MazeGeometry.RADIUS`) — the diegetic menu space
	reached by walking into a painting instead of a UI overlay (see
	`docs/PROJECT_LOG.md`'s 2026-07-17 entry for the decision and its
	rejected alternative).

	Bespoke geometry rather than a tiny `Maze`/`MazeMesh` grid: `Maze.ROWS`/
	`COLS` are baked-in constants throughout that pipeline, not parameters,
	so a differently-sized grid would mean parameterizing the most heavily-
	debugged code in the project for no real benefit here — and
	`MazeMesh.addFloor` renders every one of the grid's ~168 cells
	unconditionally regardless of which edges are open, so even a hand-
	authored small cluster would still render a full-sphere floor and wall
	every other untouched cell on all sides, not the contained room this
	needs. A hexagon is simple enough not to need any of that.
**/
class Hub {
	/** Where the hexagon sits on the shared sphere — arbitrary, just needs to not overlap anything else. **/
	public static final CENTER_THETA:Float = Math.PI / 2;

	public static inline final CENTER_PHI:Float = 0;

	/**
		Angular radius (radians) from the center to each of the hexagon's 6
		corners. Physical footprint is roughly `RADIUS * this` across —
		tuned to feel about as roomy as one biome cell (~9-13 unit half-
		width at the current grid, per `docs/PROJECT_LOG.md`'s reduced-grid
		entry).
	**/
	static inline final ANGULAR_RADIUS:Float = 0.15;

	static inline final WALL_COUNT = 6;

	static inline final FLOOR_COLOR:Int = 0xFF3A3A44;

	/** Which of the hexagon's 6 walls holds the painting back to the one existing biome — arbitrary, just needs to be a real wall index. **/
	static inline final TO_BIOME_WALL_INDEX = 0;

	/**
		Extra margin `isInside` blocks at, short of a wall's actual rendered
		face — same role as `MazeGeometry.COLLISION_CLEARANCE` plays for
		biomes.
	**/
	static inline final COLLISION_CLEARANCE:Float = 1;

	/** The room's center, at floor level — also where the player spawns on entering the hub. **/
	public static function center():h3d.Vector {
		return MazeMesh.cornerAt(CENTER_THETA, CENTER_PHI);
	}

	/** The hexagon's 6 rendered corner points, in order, on the sphere's surface. **/
	public static function corners():Array<h3d.Vector> {
		return cornersAtAngularRadius(ANGULAR_RADIUS);
	}

	/** The hub's one painting back to the existing biome, mounted on `TO_BIOME_WALL_INDEX`. **/
	public static function toBiomePainting():Painting {
		var pts = corners();
		var wallA = pts[TO_BIOME_WALL_INDEX];
		var wallB = pts[(TO_BIOME_WALL_INDEX + 1) % WALL_COUNT];
		return new Painting(Painting.midpointOf(wallA, wallB), ToBiome);
	}

	/**
		Whether `pos` is still within the hexagon, a `COLLISION_CLEARANCE`
		margin short of each wall's actual rendered face — checked per wall
		via the great-circle plane through that wall's two corners and the
		sphere's center (both corners and the center are equidistant from
		the origin, so that plane's normal, `a.cross(b)`, cleanly separates
		"still inside" from "past this wall" for any point on the sphere,
		not just points near the wall itself).
		@param pos the position to check.
		@return true if `pos` hasn't crossed any of the hexagon's 6 walls.
	**/
	public static function isInside(pos:h3d.Vector):Bool {
		var pts = cornersAtAngularRadius(ANGULAR_RADIUS - COLLISION_CLEARANCE / MazeGeometry.RADIUS);
		var centerPos = center();
		for (i in 0...WALL_COUNT) {
			var a = pts[i];
			var b = pts[(i + 1) % WALL_COUNT];
			var normal = a.cross(b);
			if (centerPos.dot(normal) * pos.dot(normal) < 0) {
				return false;
			}
		}
		return true;
	}

	/**
		Builds the hub's floor (a triangle fan from the center) and its 6
		walls (a single quad each — no inner/outer split like `MazeMesh`'s
		biome walls need, since a hub wall is only ever built once, not once
		per side of a shared edge the way a biome cell's wall is).
		@param parent the scene object to attach the meshes under.
	**/
	public static function build(parent:h3d.scene.Object):Void {
		var pts = corners();
		var centerPos = center();

		var floorPoints:Array<h3d.Vector> = [];
		var floorIdx = new hxd.IndexBuffer();
		for (i in 0...WALL_COUNT) {
			addTriangle(floorPoints, floorIdx, centerPos, pts[i], pts[(i + 1) % WALL_COUNT]);
		}
		var floorMesh = new h3d.scene.Mesh(new h3d.prim.Polygon(floorPoints, floorIdx), parent);
		floorMesh.material.mainPass.addShader(new h3d.shader.FixedColor(FLOOR_COLOR));
		floorMesh.material.mainPass.culling = None;

		var wallPoints:Array<h3d.Vector> = [];
		var wallIdx = new hxd.IndexBuffer();
		var uvs:Array<h3d.prim.UV> = [];
		for (i in 0...WALL_COUNT) {
			var a = pts[i];
			var b = pts[(i + 1) % WALL_COUNT];
			var upA = game.SphereMath.upVectorAt(a, new h3d.Vector(0, 0, 0));
			var upB = game.SphereMath.upVectorAt(b, new h3d.Vector(0, 0, 0));
			var topA = a.add(upA.scaled(MazeMesh.WALL_HEIGHT));
			var topB = b.add(upB.scaled(MazeMesh.WALL_HEIGHT));

			var uRepeat = a.sub(b).length() / MazeMesh.WALL_TEXTURE_TILE_SIZE;
			var vHeight = MazeMesh.WALL_HEIGHT / MazeMesh.WALL_TEXTURE_TILE_SIZE;
			MazeMesh.addQuad(wallPoints, wallIdx, a, b, topB, topA);
			uvs.push(new h3d.prim.UV(0, vHeight));
			uvs.push(new h3d.prim.UV(uRepeat, vHeight));
			uvs.push(new h3d.prim.UV(uRepeat, 0));
			uvs.push(new h3d.prim.UV(0, 0));
		}
		var wallPrim = new h3d.prim.Polygon(wallPoints, wallIdx);
		wallPrim.uvs = uvs;
		var wallTexture = hxd.Res.textures.wall_stone.toTexture();
		wallTexture.wrap = Repeat;
		var wallMesh = new h3d.scene.Mesh(wallPrim, parent);
		wallMesh.material.mainPass.addShader(new game.shader.UnlitTexture(wallTexture));
		wallMesh.material.mainPass.culling = None;

		Painting.buildQuad(parent, pts[TO_BIOME_WALL_INDEX], pts[(TO_BIOME_WALL_INDEX + 1) % WALL_COUNT], centerPos, Painting.TO_BIOME_COLOR);
	}

	static function cornersAtAngularRadius(angularRadius:Float):Array<h3d.Vector> {
		var centerPos = center();
		var centerDir = centerPos.normalized();
		var refDir = game.SphereMath.thetaTangentAt(CENTER_THETA, CENTER_PHI);
		var up = game.SphereMath.upVectorAt(centerPos, new h3d.Vector(0, 0, 0));

		var result = [];
		for (i in 0...WALL_COUNT) {
			var angle = i * (2 * Math.PI / WALL_COUNT);
			var dir = game.SphereMath.rotateAroundAxis(refDir, up, angle);
			var axis = centerDir.cross(dir).normalized();
			var cornerDir = game.SphereMath.rotateAroundAxis(centerDir, axis, angularRadius);
			result.push(cornerDir.scaled(MazeGeometry.RADIUS));
		}
		return result;
	}

	static function addTriangle(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, a:h3d.Vector, b:h3d.Vector, c:h3d.Vector):Void {
		var start = points.length;
		points.push(a);
		points.push(b);
		points.push(c);
		idx.push(start);
		idx.push(start + 1);
		idx.push(start + 2);
	}
}
