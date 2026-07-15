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

	Unlit and double-sided (so the sphere's inward-facing geometry doesn't get
	backface-culled away). Flat color comes from an h3d.shader.FixedColor pass
	rather than material.color + enableLights=false — the latter still let
	the PBR technique's other lighting/falloff terms through (no scene light,
	but every face's shading still depended on its normal, which the Polygon
	primitive never had set, producing a smooth gradient and half-dark faces
	instead of a flat color). FixedColor just overwrites the fragment output,
	sidestepping the whole PBR pipeline — the same trick h3d.scene.Graphics
	uses for the debug wireframe, which never had this problem.
**/
class MazeMesh {
	// Cells are roughly RADIUS * (grid step) apart (~10 units at RADIUS=50),
	// so a wall directly across a cell is only ~5 units away — at the 70deg
	// vertical FOV (see Main.CAMERA_FOV_Y), a wall taller than ~7 units
	// already subtends the entire frame from that distance (12 subtends
	// ~100deg, overfilling it, which is what "walls are too big" was:
	// reported directly after the previous height increase).
	public static inline final WALL_HEIGHT:Float = 5;
	static inline final FLOOR_COLOR:Int = 0xFF444444;
	static inline final WALL_COLOR:Int = 0xFFAA8855;

	/**
		@param maze the generated maze to build meshes for.
		@param parent the scene object to attach the meshes under.
	**/
	public static function build(maze:MazeData, parent:h3d.scene.Object):Void {
		var floorPoints:Array<h3d.Vector> = [];
		var floorIdx = new hxd.IndexBuffer();
		addFloor(floorPoints, floorIdx);
		asMesh(floorPoints, floorIdx, FLOOR_COLOR, parent);

		var wallBuilder = new WallBuilder(maze);
		eachCell((row, col, corners) -> wallBuilder.addWallsAround(row, col, corners));
		asMesh(wallBuilder.points, wallBuilder.idx, WALL_COLOR, parent);
	}

	static function asMesh(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, color:Int, parent:h3d.scene.Object):h3d.scene.Mesh {
		var mesh = new h3d.scene.Mesh(new h3d.prim.Polygon(points, idx), parent);
		mesh.material.mainPass.addShader(new h3d.shader.FixedColor(color));
		mesh.material.mainPass.culling = None;
		return mesh;
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

	final maze:MazeData;
	final seen:haxe.ds.StringMap<Bool> = new haxe.ds.StringMap();

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
		var top1 = corner1.add(game.SphereMath.upVectorAt(corner1, center).scaled(MazeMesh.WALL_HEIGHT));
		var top2 = corner2.add(game.SphereMath.upVectorAt(corner2, center).scaled(MazeMesh.WALL_HEIGHT));
		MazeMesh.addQuad(points, idx, corner1, corner2, top2, top1);
	}

	function undirectedKey(a:MazeNode, b:MazeNode):String {
		var keyA = Maze.nodeKey(a);
		var keyB = Maze.nodeKey(b);
		return keyA < keyB ? '$keyA|$keyB' : '$keyB|$keyA';
	}
}
