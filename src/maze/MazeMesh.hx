package maze;

import maze.Maze.MazeNode;
import maze.Maze.MazeData;

/**
	Builds renderable meshes for a generated maze: a floor patch per ring
	cell, and a wall wherever an edge between two grid-adjacent nodes is
	closed.

	Walls are a simplified approximation, not exact cell-boundary geometry: a
	quad perpendicular to the line between the two blocked-adjacent cells,
	centered on their midpoint (projected back onto the sphere) and sized to
	the distance between them. Good enough to read clearly as "this passage
	is blocked" without needing per-edge-type corner math (row-adjacency,
	column-adjacency, and pole-adjacency all go through the same code path);
	revisit if the approximation looks wrong once there's a playable build.

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
	static inline final WALL_HEIGHT:Float = 5;
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

		var wallPoints:Array<h3d.Vector> = [];
		var wallIdx = new hxd.IndexBuffer();
		addWalls(maze, wallPoints, wallIdx);
		asMesh(wallPoints, wallIdx, WALL_COLOR, parent);
	}

	static function asMesh(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, color:Int, parent:h3d.scene.Object):h3d.scene.Mesh {
		var mesh = new h3d.scene.Mesh(new h3d.prim.Polygon(points, idx), parent);
		mesh.material.mainPass.addShader(new h3d.shader.FixedColor(color));
		mesh.material.mainPass.culling = None;
		return mesh;
	}

	static function addFloor(points:Array<h3d.Vector>, idx:hxd.IndexBuffer):Void {
		var thetaStep = Math.PI / (Maze.ROWS - 1);
		var phiStep = 2 * Math.PI / Maze.COLS;

		for (row in 1...(Maze.ROWS - 1)) {
			for (col in 0...Maze.COLS) {
				var theta = Math.PI * row / (Maze.ROWS - 1);
				var phi = 2 * Math.PI * col / Maze.COLS;

				var a = cornerAt(theta - thetaStep / 2, phi - phiStep / 2);
				var b = cornerAt(theta - thetaStep / 2, phi + phiStep / 2);
				var c = cornerAt(theta + thetaStep / 2, phi + phiStep / 2);
				var d = cornerAt(theta + thetaStep / 2, phi - phiStep / 2);

				addQuad(points, idx, a, b, c, d);
			}
		}
	}

	static function cornerAt(theta:Float, phi:Float):h3d.Vector {
		return game.SphereMath.sphericalToCartesian(MazeGeometry.RADIUS, theta, phi);
	}

	static function addWalls(maze:MazeData, points:Array<h3d.Vector>, idx:hxd.IndexBuffer):Void {
		var seen = new haxe.ds.StringMap<Bool>();

		for (node in Maze.allNodes()) {
			for (neighbor in Maze.neighborsOf(node)) {
				if (Maze.isOpen(maze, node, neighbor)) {
					continue;
				}

				var key = undirectedKey(node, neighbor);
				if (seen.exists(key)) {
					continue;
				}
				seen.set(key, true);

				addWall(node, neighbor, points, idx);
			}
		}
	}

	static function undirectedKey(a:MazeNode, b:MazeNode):String {
		var keyA = Maze.nodeKey(a);
		var keyB = Maze.nodeKey(b);
		return keyA < keyB ? '$keyA|$keyB' : '$keyB|$keyA';
	}

	static function addWall(a:MazeNode, b:MazeNode, points:Array<h3d.Vector>, idx:hxd.IndexBuffer):Void {
		var center = new h3d.Vector(0, 0, 0);
		var posA = MazeGeometry.positionOf(a);
		var posB = MazeGeometry.positionOf(b);
		var midpoint = posA.add(posB).scaled(0.5).normalized().scaled(MazeGeometry.RADIUS);

		var up = game.SphereMath.upVectorAt(midpoint, center);
		var along = posB.sub(posA).normalized();
		var across = along.cross(up).normalized();
		var halfWidth = posA.distance(posB) / 2;

		var baseLeft = midpoint.sub(across.scaled(halfWidth));
		var baseRight = midpoint.add(across.scaled(halfWidth));
		var topLeft = baseLeft.add(up.scaled(WALL_HEIGHT));
		var topRight = baseRight.add(up.scaled(WALL_HEIGHT));

		addQuad(points, idx, baseLeft, baseRight, topRight, topLeft);
	}

	static function addQuad(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, a:h3d.Vector, b:h3d.Vector, c:h3d.Vector, d:h3d.Vector):Void {
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
