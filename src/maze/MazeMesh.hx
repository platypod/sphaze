package maze;

import maze.Maze.MazeNode;
import maze.Maze.MazeData;

/** A ring cell's four corners — "N"/"S" for the smaller/larger theta edge, "W"/"E" for the smaller/larger phi edge. **/
typedef CellCorners = {
	nw:h3d.Vector,
	ne:h3d.Vector,
	se:h3d.Vector,
	sw:h3d.Vector
}

/**
	Builds renderable meshes for a generated maze: a floor patch per ring
	cell, and a wall wherever an edge between two grid-adjacent nodes is
	closed.

	Walls are built from the same corner points as the floor cells they sit
	between (each cell's corners come from the same `cornerAt` calls
	`addFloor` uses), extruded upward along each corner's own local "up" —
	not a single shared frame per wall. That's what makes them connect
	seamlessly: adjacent walls sharing a base corner extrude that corner
	through the exact same function, so their top corners coincide too, and
	a wall's base always matches the floor boundary it's replacing. An
	earlier version built each wall from the straight-line distance between
	two cell *centers* instead, independent of neighboring walls or the
	floor's actual corners — visibly disconnected/seamed on the sphere's
	curvature, reported directly ("not seamlessly connecting... not fit for
	a sphere").

	Each wall segment is its own front/back/top box straddling that
	boundary line (see WallBuilder.maybeAdd), not a zero-thickness plane —
	real thickness reads better with a stone texture than an infinitely
	thin sheet, especially once pitching up (the "see across the sphere"
	mechanic) can put a wall's top edge in view.

	Each segment's box is offset independently along *its own* length
	direction, so its short ends are open — fine where another wall's box
	happens to cover that same point, but visibly hollow wherever nothing
	else does (a dead-end stub with open space beyond it) or where two
	segments meet at enough of an angle that their independently-offset
	boxes don't fully cover each other (confirmed in-browser: gaps showed
	up at exactly those two cases). Rather than mitering every junction
	(computing each shared vertex from the intersection of both segments'
	offset planes — real work for a purely cosmetic gain), WallBuilder
	instead drops a small square corner post at *every* point where a wall
	segment ends (`ensurePost`, deduplicated so shared corners only get one),
	sized to the same thickness as the walls themselves. A post fully seals
	whatever it's sitting on regardless of how many segments meet there or
	at what angle, which a per-junction special case wouldn't generalize as
	easily.

	Unlit and double-sided (so the sphere's inward-facing geometry doesn't get
	backface-culled away). The floor stays a flat color via an
	h3d.shader.FixedColor pass rather than material.color + enableLights=false
	— the latter still let the PBR technique's other lighting/falloff terms
	through (no scene light, but every face's shading still depended on its
	normal, which the Polygon primitive never had set, producing a smooth
	gradient and half-dark faces instead of a flat color). Walls use the same
	unlit trick but sample a stone texture instead of one flat color — see
	game.shader.UnlitTexture — while staying just as immune to that PBR
	pitfall, since it never touches the lighting pipeline either.
**/
class MazeMesh {
	// Cells are roughly RADIUS * (grid step) apart (~12 units at RADIUS=58),
	// so a wall directly across a cell is only ~6 units away — at the 70deg
	// vertical FOV (see Main.CAMERA_FOV_Y), that keeps a wall's angular size
	// at ~53deg from one cell away, same ratio as the previous RADIUS=50/
	// WALL_HEIGHT=5 tuning (both scaled up together on purpose, to leave that
	// already-tuned "present but not dominant" balance alone).
	public static inline final WALL_HEIGHT:Float = 6;

	/** How far a wall extends to each side of the floor-cell boundary it sits on (see class doc) — total thickness is twice this. **/
	public static inline final WALL_THICKNESS:Float = 1.5;

	/** World units per repeat of the wall texture — matches WALL_HEIGHT so a tile reads roughly square rather than stretched. **/
	public static inline final WALL_TEXTURE_TILE_SIZE:Float = 6;

	static inline final FLOOR_COLOR:Int = 0xFF444444;

	/**
		@param maze the generated maze to build meshes for.
		@param parent the scene object to attach the meshes under.
	**/
	public static function build(maze:MazeData, parent:h3d.scene.Object):Void {
		var floorPoints:Array<h3d.Vector> = [];
		var floorIdx = new hxd.IndexBuffer();
		addFloor(floorPoints, floorIdx);
		var floorMesh = new h3d.scene.Mesh(new h3d.prim.Polygon(floorPoints, floorIdx), parent);
		floorMesh.material.mainPass.addShader(new h3d.shader.FixedColor(FLOOR_COLOR));
		floorMesh.material.mainPass.culling = None;

		var wallBuilder = new WallBuilder(maze);
		eachCell((row, col, corners) -> wallBuilder.addWallsAround(row, col, corners));
		var wallPrim = new h3d.prim.Polygon(wallBuilder.points, wallBuilder.idx);
		wallPrim.uvs = wallBuilder.uvs;
		var wallTexture = hxd.Res.textures.wall_stone.toTexture();
		wallTexture.wrap = Repeat;
		var wallMesh = new h3d.scene.Mesh(wallPrim, parent);
		wallMesh.material.mainPass.addShader(new game.shader.UnlitTexture(wallTexture));
		wallMesh.material.mainPass.culling = None;
	}

	static function addFloor(points:Array<h3d.Vector>, idx:hxd.IndexBuffer):Void {
		eachCell((row, col, corners) -> addQuad(points, idx, corners.nw, corners.ne, corners.se, corners.sw));
	}

	static function cornerAt(theta:Float, phi:Float):h3d.Vector {
		return game.SphereMath.sphericalToCartesian(MazeGeometry.RADIUS, theta, phi);
	}

	/**
		A ring cell's four corners. Public so adjacency can be checked
		directly (see test/MazeMeshTest.hx): neighboring cells must compute
		matching points for their shared edge, which is what makes walls
		connect seamlessly to each other and to the floor.
		@param row the cell's row (1 to Maze.ROWS - 2).
		@param col the cell's column (0 to Maze.COLS - 1).
		@return the cell's four corners.
	**/
	public static function cornersOf(row:Int, col:Int):CellCorners {
		var halfTheta = Math.PI / (Maze.ROWS - 1) / 2;
		var halfPhi = Math.PI / Maze.COLS;
		var theta = Math.PI * row / (Maze.ROWS - 1);
		var phi = 2 * Math.PI * col / Maze.COLS;

		return {
			nw: cornerAt(theta - halfTheta, phi - halfPhi),
			ne: cornerAt(theta - halfTheta, phi + halfPhi),
			se: cornerAt(theta + halfTheta, phi + halfPhi),
			sw: cornerAt(theta + halfTheta, phi - halfPhi)
		};
	}

	/** Walks every ring cell, calling `f` with its row/col and its corners (see `cornersOf`). **/
	static function eachCell(f:(row:Int, col:Int, corners:CellCorners) -> Void):Void {
		for (row in 1...(Maze.ROWS - 1)) {
			for (col in 0...Maze.COLS) {
				f(row, col, cornersOf(row, col));
			}
		}
	}

	/**
		Appends a quad (as two triangles) to `points`/`idx`. Public so
		`WallBuilder` — a separate class — can share it.
		@param points vertex buffer to append to.
		@param idx index buffer to append to.
		@param a first corner, in perimeter order.
		@param b second corner, in perimeter order.
		@param c third corner, in perimeter order.
		@param d fourth corner, in perimeter order.
	**/
	public static function addQuad(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, a:h3d.Vector, b:h3d.Vector, c:h3d.Vector, d:h3d.Vector):Void {
		var start = points.length;
		points.push(a);
		points.push(b);
		points.push(c);
		points.push(d);

		idx.push(start);
		idx.push(start + 1);
		idx.push(start + 2);
		idx.push(start);
		idx.push(start + 2);
		idx.push(start + 3);
	}
}

/** Accumulates wall geometry across cells, de-duplicating each shared edge (visited once from each side) as it goes. **/
private class WallBuilder {
	/** Wall vertex buffer, appended to as cells are visited. **/
	public final points:Array<h3d.Vector> = [];

	/** Wall index buffer, appended to as cells are visited. **/
	public final idx:hxd.IndexBuffer = new hxd.IndexBuffer();

	/** Wall UV buffer, parallel to `points` — one entry per vertex, in the same push order. **/
	public final uvs:Array<h3d.prim.UV> = [];

	final maze:MazeData;
	final seen:haxe.ds.StringMap<Bool> = new haxe.ds.StringMap();
	final postsSeen:haxe.ds.StringMap<Bool> = new haxe.ds.StringMap();

	public function new(maze:MazeData) {
		this.maze = maze;
	}

	/** Adds a wall for each closed edge around the cell at (row, col), skipping edges already added from the neighboring side. **/
	public function addWallsAround(row:Int, col:Int, corners:CellCorners):Void {
		var here = RingNode(row, col);
		maybeAdd(here, RingNode(row, (col - 1 + Maze.COLS) % Maze.COLS), corners.nw, corners.sw);
		maybeAdd(here, RingNode(row, (col + 1) % Maze.COLS), corners.se, corners.ne);
		maybeAdd(here, row == 1 ? PoleNode(North) : RingNode(row - 1, col), corners.ne, corners.nw);
		maybeAdd(here, row == Maze.ROWS - 2 ? PoleNode(South) : RingNode(row + 1, col), corners.sw, corners.se);
	}

	function maybeAdd(a:MazeNode, b:MazeNode, corner1:h3d.Vector, corner2:h3d.Vector):Void {
		if (Maze.isOpen(maze, a, b)) {
			return;
		}

		var key = undirectedKey(a, b);
		if (seen.exists(key)) {
			return;
		}
		seen.set(key, true);

		var center = new h3d.Vector(0, 0, 0);
		var up1 = game.SphereMath.upVectorAt(corner1, center);
		var up2 = game.SphereMath.upVectorAt(corner2, center);
		// Perpendicular to both the wall's length and its (per-corner) local
		// up — the axis the wall's thickness straddles the boundary line
		// along. Computed per-corner, same as up1/up2, for the same reason
		// the rest of this file does: it's what let the zero-thickness
		// version connect seamlessly in the first place.
		var lengthDir = corner2.sub(corner1).normalized();
		var depth1 = lengthDir.cross(up1).normalized().scaled(MazeMesh.WALL_THICKNESS);
		var depth2 = lengthDir.cross(up2).normalized().scaled(MazeMesh.WALL_THICKNESS);

		var frontBase1 = corner1.add(depth1);
		var frontBase2 = corner2.add(depth2);
		var backBase1 = corner1.sub(depth1);
		var backBase2 = corner2.sub(depth2);
		var frontTop1 = frontBase1.add(up1.scaled(MazeMesh.WALL_HEIGHT));
		var frontTop2 = frontBase2.add(up2.scaled(MazeMesh.WALL_HEIGHT));
		var backTop1 = backBase1.add(up1.scaled(MazeMesh.WALL_HEIGHT));
		var backTop2 = backBase2.add(up2.scaled(MazeMesh.WALL_HEIGHT));

		// Chord length as a stand-in for arc length (cells are small relative
		// to the sphere, so the two are close enough for texture tiling) —
		// repeats the texture across the wall's length rather than stretching
		// one tile to fit, so differently-sized walls read at a consistent
		// texel density.
		var uRepeat = corner1.sub(corner2).length() / MazeMesh.WALL_TEXTURE_TILE_SIZE;
		var vHeight = MazeMesh.WALL_HEIGHT / MazeMesh.WALL_TEXTURE_TILE_SIZE;
		var vThickness = 2 * MazeMesh.WALL_THICKNESS / MazeMesh.WALL_TEXTURE_TILE_SIZE;

		addTexturedQuad(frontBase1, frontBase2, frontTop2, frontTop1, uRepeat, vHeight);
		addTexturedQuad(backBase1, backBase2, backTop2, backTop1, uRepeat, vHeight);
		addTexturedQuad(frontTop1, frontTop2, backTop2, backTop1, uRepeat, vThickness);

		ensurePost(corner1);
		ensurePost(corner2);
	}

	/**
		Drops a small square post at `corner` — same height as a wall, footprint
		sized to the wall thickness — the first time this exact point is seen.
		Fully seals whatever wall segments end there (see class doc), regardless
		of how many or at what angle, without needing per-junction logic.
	**/
	function ensurePost(corner:h3d.Vector):Void {
		// Points shared between cells are always bit-for-bit identical (same
		// cornerAt call, same inputs — verified by test/MazeMeshTest.hx), so a
		// plain coordinate key needs no rounding/tolerance to dedupe correctly.
		var key = '${corner.x},${corner.y},${corner.z}';
		if (postsSeen.exists(key)) {
			return;
		}
		postsSeen.set(key, true);

		var theta = game.SphereMath.thetaOf(corner);
		var phi = game.SphereMath.phiOf(corner);
		var axisA = game.SphereMath.thetaTangentAt(theta, phi).scaled(MazeMesh.WALL_THICKNESS);
		var axisB = game.SphereMath.phiTangentAt(phi).scaled(MazeMesh.WALL_THICKNESS);
		var up = game.SphereMath.upVectorAt(corner, new h3d.Vector(0, 0, 0));
		var top = up.scaled(MazeMesh.WALL_HEIGHT);

		var base00 = corner.sub(axisA).sub(axisB);
		var base10 = corner.add(axisA).sub(axisB);
		var base11 = corner.add(axisA).add(axisB);
		var base01 = corner.sub(axisA).add(axisB);
		var top00 = base00.add(top);
		var top10 = base10.add(top);
		var top11 = base11.add(top);
		var top01 = base01.add(top);

		var vHeight = MazeMesh.WALL_HEIGHT / MazeMesh.WALL_TEXTURE_TILE_SIZE;
		var side = 2 * MazeMesh.WALL_THICKNESS / MazeMesh.WALL_TEXTURE_TILE_SIZE;

		addTexturedQuad(base00, base10, top10, top00, side, vHeight);
		addTexturedQuad(base10, base11, top11, top10, side, vHeight);
		addTexturedQuad(base11, base01, top01, top11, side, vHeight);
		addTexturedQuad(base01, base00, top00, top01, side, vHeight);
		addTexturedQuad(top00, top10, top11, top01, side, side);
	}

	/** Appends a quad plus matching UVs — `a`/`d` at u=0, `b`/`c` at u=uRepeat, `a`/`b` at v=vSpan, `c`/`d` at v=0. **/
	function addTexturedQuad(a:h3d.Vector, b:h3d.Vector, c:h3d.Vector, d:h3d.Vector, uRepeat:Float, vSpan:Float):Void {
		MazeMesh.addQuad(points, idx, a, b, c, d);
		uvs.push(new h3d.prim.UV(0, vSpan));
		uvs.push(new h3d.prim.UV(uRepeat, vSpan));
		uvs.push(new h3d.prim.UV(uRepeat, 0));
		uvs.push(new h3d.prim.UV(0, 0));
	}

	function undirectedKey(a:MazeNode, b:MazeNode):String {
		var keyA = Maze.nodeKey(a);
		var keyB = Maze.nodeKey(b);
		return keyA < keyB ? '$keyA|$keyB' : '$keyB|$keyA';
	}
}
