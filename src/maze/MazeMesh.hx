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

	The floor uses each cell's outer corners (`cornersOf`) unchanged — full
	size, same as before thickness existed. Walls are drawn *per cell, per
	side* rather than once per shared edge: each cell also has its own inner
	corners (`innerCornersOf`, inset from the outer ones by WALL_THICKNESS),
	and a closed side draws a piece spanning outer-to-inner on *that cell's
	own* territory only. A closed edge between cells A and B is therefore two
	pieces, one from each side, meeting exactly at the shared outer boundary
	— never overlapping, since neither extends past it, and the floor
	underneath simply goes unseen in the strip a wall covers (no need to
	inset the floor to match).

	This replaced an earlier version that built one box per closed *edge*,
	offset outward from the boundary along that edge's own length direction.
	Independent per-edge offsets meant two edges meeting at a shared corner
	(a plain corner, or worse, three-plus edges at a pole-adjacent junction)
	computed *different* offset points for what was nominally the same
	corner — visible overlap between the resulting boxes, confirmed
	in-browser as a shaky/flickering seam wherever two textured, overlapping
	faces fought over the same depth. A follow-up patch tried patching this
	with a corner post at every wall endpoint (sized to the wall thickness,
	filling whatever gap or overlap was there) — better, but the post itself
	still overlapped every wall piece meeting it, same shakiness at smaller
	scale. Building per-cell from each cell's own two consistent corner sets
	(used by all four of that cell's potential sides) removes the overlap at
	the source instead of patching over it: within one cell, adjacent sides
	share the exact same inner/outer corner, so they meet edge-to-edge, and
	between cells, both sides' pieces stop exactly at the shared outer
	boundary they're built from.

	Each piece is 4 quads: the inner face (visible to a player standing in
	the cell), the top cap (visible once pitching up puts a wall's top edge
	in view — the "see across the sphere" mechanic), and two end caps
	sealing the piece regardless of what, if anything, is next to it at
	either end. No outer face: it would sit exactly where the neighboring
	cell's own piece for the same edge begins, so it's never actually
	visible from either side, only wasted overlapping geometry.

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
	// Doubled from 6 on request, for taller, more prominent walls — a
	// deliberate departure from the earlier "present but not dominant" FOV-
	// subtense tuning noted in prior sessions (see docs/PROJECT_LOG.md),
	// not an oversight to reconcile back to that ratio later.
	public static inline final WALL_HEIGHT:Float = 12;

	/** World units per repeat of the wall texture — matches WALL_HEIGHT so a tile reads roughly square rather than stretched. **/
	public static inline final WALL_TEXTURE_TILE_SIZE:Float = 12;

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
		eachCell((row, col) -> wallBuilder.addWallsAround(row, col));
		var wallPrim = new h3d.prim.Polygon(wallBuilder.points, wallBuilder.idx);
		wallPrim.uvs = wallBuilder.uvs;
		var wallTexture = hxd.Res.textures.wall_stone.toTexture();
		wallTexture.wrap = Repeat;
		var wallMesh = new h3d.scene.Mesh(wallPrim, parent);
		wallMesh.material.mainPass.addShader(new game.shader.UnlitTexture(wallTexture));
		wallMesh.material.mainPass.culling = None;
	}

	static function addFloor(points:Array<h3d.Vector>, idx:hxd.IndexBuffer):Void {
		eachCell((row, col) -> {
			var corners = cornersOf(row, col);
			addQuad(points, idx, corners.nw, corners.ne, corners.se, corners.sw);
		});
	}

	static function cornerAt(theta:Float, phi:Float):h3d.Vector {
		return game.SphereMath.sphericalToCartesian(MazeGeometry.RADIUS, theta, phi);
	}

	/**
		A ring cell's four outer corners — the true grid boundary, shared
		exactly with its neighbors. Public so adjacency can be checked
		directly (see test/MazeMeshTest.hx): neighboring cells must compute
		matching points for their shared edge, which is what makes the floor
		— and each side's wall piece, built from these same points — connect
		seamlessly to each other.
		@param row the cell's row (1 to Maze.ROWS - 2).
		@param col the cell's column (0 to Maze.COLS - 1).
		@return the cell's four outer corners.
	**/
	public static function cornersOf(row:Int, col:Int):CellCorners {
		var halfTheta = Math.PI / (Maze.ROWS - 1) / 2;
		var halfPhi = Math.PI / Maze.COLS;
		var theta = Math.PI * row / (Maze.ROWS - 1);
		var phi = 2 * Math.PI * (col + 0.5) / Maze.COLS;

		return {
			nw: cornerAt(theta - halfTheta, phi - halfPhi),
			ne: cornerAt(theta - halfTheta, phi + halfPhi),
			se: cornerAt(theta + halfTheta, phi + halfPhi),
			sw: cornerAt(theta + halfTheta, phi - halfPhi)
		};
	}

	/**
		A ring cell's four *inner* corners — each outer corner (`cornersOf`)
		moved toward this cell's own center by WALL_THICKNESS, along both the
		theta and phi axes independently. Unlike outer corners, these belong
		to this cell alone: the neighboring cell across any given side has
		its own, different inner corners, inset from the *same* outer
		boundary in the opposite direction — that's what a wall's thickness
		actually is, split between the two cells it separates.

		The phi inset accounts for the sphere's curvature (a cell's
		circumference shrinks toward the poles at fixed angular width, same
		distortion `cornersOf`'s fixed `halfPhi` already has) so it's a
		consistent linear WALL_THICKNESS at any latitude, not a fixed angle.
		Clamped to the cell's own half-width so a cell doesn't invert near a
		pole, where a few columns can physically be narrower than
		WALL_THICKNESS itself — the ring row nearest either pole is the
		tightest fit by construction, a pre-existing distortion of the
		lat/long grid this doesn't attempt to fix.
		@param row the cell's row (1 to Maze.ROWS - 2).
		@param col the cell's column (0 to Maze.COLS - 1).
		@return the cell's four inner corners.
	**/
	public static function innerCornersOf(row:Int, col:Int):CellCorners {
		var halfTheta = Math.PI / (Maze.ROWS - 1) / 2;
		var halfPhi = Math.PI / Maze.COLS;
		var theta = Math.PI * row / (Maze.ROWS - 1);
		var phi = 2 * Math.PI * (col + 0.5) / Maze.COLS;

		var insetTheta = Math.min(halfTheta, MazeGeometry.WALL_THICKNESS / MazeGeometry.RADIUS);
		var insetPhi = Math.min(halfPhi, MazeGeometry.WALL_THICKNESS / (MazeGeometry.RADIUS * Math.sin(theta)));
		var innerHalfTheta = halfTheta - insetTheta;
		var innerHalfPhi = halfPhi - insetPhi;

		return {
			nw: cornerAt(theta - innerHalfTheta, phi - innerHalfPhi),
			ne: cornerAt(theta - innerHalfTheta, phi + innerHalfPhi),
			se: cornerAt(theta + innerHalfTheta, phi + innerHalfPhi),
			sw: cornerAt(theta + innerHalfTheta, phi - innerHalfPhi)
		};
	}

	/** Walks every ring cell, calling `f` with its row/col. **/
	static function eachCell(f:(row:Int, col:Int) -> Void):Void {
		for (row in 1...(Maze.ROWS - 1)) {
			for (col in 0...Maze.COLS) {
				f(row, col);
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

/** Accumulates wall geometry across cells — one piece per cell per closed side (see class doc), no cross-cell deduplication needed. **/
private class WallBuilder {
	/** Wall vertex buffer, appended to as cells are visited. **/
	public final points:Array<h3d.Vector> = [];

	/** Wall index buffer, appended to as cells are visited. **/
	public final idx:hxd.IndexBuffer = new hxd.IndexBuffer();

	/** Wall UV buffer, parallel to `points` — one entry per vertex, in the same push order. **/
	public final uvs:Array<h3d.prim.UV> = [];

	final maze:MazeData;

	public function new(maze:MazeData) {
		this.maze = maze;
	}

	/** Adds this cell's own piece for each of its closed sides. **/
	public function addWallsAround(row:Int, col:Int):Void {
		var outer = MazeMesh.cornersOf(row, col);
		var inner = MazeMesh.innerCornersOf(row, col);
		var here = RingNode(row, col);

		maybeAddPiece(here, RingNode(row, (col - 1 + Maze.COLS) % Maze.COLS), outer.nw, outer.sw, inner.nw, inner.sw);
		maybeAddPiece(here, RingNode(row, (col + 1) % Maze.COLS), outer.se, outer.ne, inner.se, inner.ne);
		maybeAddPiece(here, row == 1 ? PoleNode(North) : RingNode(row - 1, col), outer.ne, outer.nw, inner.ne, inner.nw);
		maybeAddPiece(here, row == Maze.ROWS - 2 ? PoleNode(South) : RingNode(row + 1, col), outer.sw, outer.se, inner.sw, inner.se);
	}

	/**
		Builds this cell's own wall piece for one side, if that side's edge
		is closed — a box spanning `outerA`/`outerB` (the true, shared
		boundary) to `innerA`/`innerB` (this cell's own inset corners),
		extruded up by WALL_HEIGHT.
	**/
	function maybeAddPiece(a:MazeNode, b:MazeNode, outerA:h3d.Vector, outerB:h3d.Vector, innerA:h3d.Vector, innerB:h3d.Vector):Void {
		if (Maze.isOpen(maze, a, b)) {
			return;
		}

		var center = new h3d.Vector(0, 0, 0);
		var upA = game.SphereMath.upVectorAt(outerA, center);
		var upB = game.SphereMath.upVectorAt(outerB, center);
		var topOuterA = outerA.add(upA.scaled(MazeMesh.WALL_HEIGHT));
		var topOuterB = outerB.add(upB.scaled(MazeMesh.WALL_HEIGHT));
		var topInnerA = innerA.add(upA.scaled(MazeMesh.WALL_HEIGHT));
		var topInnerB = innerB.add(upB.scaled(MazeMesh.WALL_HEIGHT));

		// Chord length as a stand-in for arc length (cells are small relative
		// to the sphere, so the two are close enough for texture tiling) —
		// repeats the texture across the wall's length rather than stretching
		// one tile to fit, so differently-sized walls read at a consistent
		// texel density.
		var uRepeat = outerA.sub(outerB).length() / MazeMesh.WALL_TEXTURE_TILE_SIZE;
		var vHeight = MazeMesh.WALL_HEIGHT / MazeMesh.WALL_TEXTURE_TILE_SIZE;
		var vThickness = MazeGeometry.WALL_THICKNESS / MazeMesh.WALL_TEXTURE_TILE_SIZE;

		// Inner face — visible to a player standing in this cell.
		addTexturedQuad(innerA, innerB, topInnerB, topInnerA, uRepeat, vHeight);
		// Top cap — visible once pitching up puts this wall's top edge in view.
		addTexturedQuad(topOuterA, topOuterB, topInnerB, topInnerA, uRepeat, vThickness);
		// End caps, sealing this piece regardless of what's next to it at either end.
		addTexturedQuad(outerA, innerA, topInnerA, topOuterA, vThickness, vHeight);
		addTexturedQuad(innerB, outerB, topOuterB, topInnerB, vThickness, vHeight);
	}

	/** Appends a quad plus matching UVs — `a`/`d` at u=0, `b`/`c` at u=uRepeat, `a`/`b` at v=vSpan, `c`/`d` at v=0. **/
	function addTexturedQuad(a:h3d.Vector, b:h3d.Vector, c:h3d.Vector, d:h3d.Vector, uRepeat:Float, vSpan:Float):Void {
		MazeMesh.addQuad(points, idx, a, b, c, d);
		uvs.push(new h3d.prim.UV(0, vSpan));
		uvs.push(new h3d.prim.UV(uRepeat, vSpan));
		uvs.push(new h3d.prim.UV(uRepeat, 0));
		uvs.push(new h3d.prim.UV(0, 0));
	}
}
