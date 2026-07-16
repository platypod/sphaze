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
	size, same as before thickness existed — except at a doubling boundary,
	where it also picks up its neighbor's own split points along that edge
	(see `addFloor`) so the two sides tessellate identically instead of
	leaving a crack. Walls are drawn *per cell, per side* rather than once
	per shared edge: each cell also has its own inner
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

	Each piece is up to 4 quads: the inner face (visible to a player standing
	in the cell), the top cap (visible once pitching up puts a wall's top
	edge in view — the "see across the sphere" mechanic), and up to two end
	caps sealing the piece where it's a genuine free-standing end — skipped
	wherever the wall meeting it there is also closed, so a plain corner
	stays a plain rectangular corner rather than getting chamfered by two
	overlapping diagonal cap faces (see `maybeAddPiece`'s own doc). No outer
	face: it would sit exactly where the neighboring cell's own piece for
	the same edge begins, so it's never actually visible from either side,
	only wasted overlapping geometry.

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

	/**
		Builds one cell's floor patch as a fan from `nw`, rather than always a
		single quad: at a row boundary where the neighboring row has *more*
		columns (a doubling boundary, moving away from a pole), this cell's
		north or south edge is one straight chord while that neighbor renders
		it as several — the two don't tessellate the same way, leaving a
		sliver-shaped gap (or overlap) right at the seam, confirmed
		in-browser as a crack in the floor at exactly those latitudes. Fixed
		by inserting this cell's own vertex at each interior split point
		(`Maze.rowBoundaryNeighbors`'s own boundaries, at this cell's own
		theta) — the same point the finer neighbor already has on its side —
		so both sides of the seam share identical vertices instead of a
		coarse straight edge cutting across a finer bent one.
	**/
	static function addFloor(points:Array<h3d.Vector>, idx:hxd.IndexBuffer):Void {
		eachCell((row, col) -> {
			var corners = cornersOf(row, col);
			var theta = Math.PI * row / (Maze.ROWS - 1);
			var halfTheta = Math.PI / (Maze.ROWS - 1) / 2;

			var perimeter = [corners.nw];
			if (row > 1) {
				var northEntries = Maze.rowBoundaryNeighbors(row, col, row - 1);
				for (i in 0...northEntries.length - 1) {
					perimeter.push(cornerAt(theta - halfTheta, northEntries[i].phiEnd));
				}
			}
			perimeter.push(corners.ne);
			perimeter.push(corners.se);
			if (row < Maze.ROWS - 2) {
				var southEntries = Maze.rowBoundaryNeighbors(row, col, row + 1);
				var i = southEntries.length - 2;
				while (i >= 0) {
					perimeter.push(cornerAt(theta + halfTheta, southEntries[i].phiEnd));
					i--;
				}
			}
			perimeter.push(corners.sw);

			for (i in 1...perimeter.length - 1) {
				addTriangle(points, idx, perimeter[0], perimeter[i], perimeter[i + 1]);
			}
		});
	}

	/** A point on the maze's sphere at the given spherical coordinates. Public so `WallBuilder` can build split boundary pieces from it directly. **/
	public static function cornerAt(theta:Float, phi:Float):h3d.Vector {
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
		@param col the cell's column (0 to Maze.colsForRow(row) - 1).
		@return the cell's four outer corners.
	**/
	public static function cornersOf(row:Int, col:Int):CellCorners {
		var halfTheta = Math.PI / (Maze.ROWS - 1) / 2;
		var cols = Maze.colsForRow(row);
		var halfPhi = Math.PI / cols;
		var theta = Math.PI * row / (Maze.ROWS - 1);
		var phi = 2 * Math.PI * (col + 0.5) / cols;

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
		pole, where a column could otherwise be physically narrower than
		WALL_THICKNESS itself — much less likely now that `Maze.colsForRow`
		reduces column count near the poles specifically to keep cell width
		from collapsing there, but still a real possibility for a small or
		oddly-tuned `WALL_THICKNESS`, so the clamp stays.
		@param row the cell's row (1 to Maze.ROWS - 2).
		@param col the cell's column (0 to Maze.colsForRow(row) - 1).
		@return the cell's four inner corners.
	**/
	public static function innerCornersOf(row:Int, col:Int):CellCorners {
		var halfTheta = Math.PI / (Maze.ROWS - 1) / 2;
		var cols = Maze.colsForRow(row);
		var halfPhi = Math.PI / cols;
		var theta = Math.PI * row / (Maze.ROWS - 1);
		var phi = 2 * Math.PI * (col + 0.5) / cols;

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
			for (col in 0...Maze.colsForRow(row)) {
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

	/**
		Appends a triangle to `points`/`idx` — used for a floor cell's fan
		triangulation (`addFloor`), which needs a variable vertex count per
		cell rather than `addQuad`'s fixed four.
		@param points vertex buffer to append to.
		@param idx index buffer to append to.
		@param a first corner.
		@param b second corner.
		@param c third corner.
	**/
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

	/**
		Adds this cell's own piece for each of its closed sides. West/east
		are always exactly one piece (column count never changes within a
		row); north/south go through `addRowBoundaryPieces` instead of a
		single `maybeAddPiece` call, since a row boundary where column count
		doubles moving away from a pole means more than one piece — see its
		own doc comment.

		Each piece's end caps are skipped wherever the *other* wall meeting
		that corner is also closed (see `maybeAddPiece`'s doc) — otherwise
		every closed corner grows a redundant diagonal cap face from each of
		its two walls, chamfering what should be a plain rectangular corner
		into a hexagon. `northWestClosed`/`northEastClosed`/etc. below are
		this cell's own west/east walls checked against whichever of the
		north/south side's (possibly split) pieces actually reaches that
		corner — the *nearest* `rowBoundaryNeighbors` entry, not necessarily
		the whole side.
	**/
	public function addWallsAround(row:Int, col:Int):Void {
		var outer = MazeMesh.cornersOf(row, col);
		var inner = MazeMesh.innerCornersOf(row, col);
		var here = RingNode(row, col);
		var cols = Maze.colsForRow(row);
		var west = RingNode(row, (col - 1 + cols) % cols);
		var east = RingNode(row, (col + 1) % cols);
		var westClosed = !Maze.isOpen(maze, here, west);
		var eastClosed = !Maze.isOpen(maze, here, east);

		var northEntries = row == 1 ? null : Maze.rowBoundaryNeighbors(row, col, row - 1);
		var southEntries = row == Maze.ROWS - 2 ? null : Maze.rowBoundaryNeighbors(row, col, row + 1);
		var northWestClosed = !Maze.isOpen(maze, here, row == 1 ? PoleNode(North) : northEntries[0].node);
		var northEastClosed = !Maze.isOpen(maze, here, row == 1 ? PoleNode(North) : northEntries[northEntries.length - 1].node);
		var southWestClosed = !Maze.isOpen(maze, here, row == Maze.ROWS - 2 ? PoleNode(South) : southEntries[0].node);
		var southEastClosed = !Maze.isOpen(maze, here, row == Maze.ROWS - 2 ? PoleNode(South) : southEntries[southEntries.length - 1].node);

		maybeAddPiece(here, west, outer.nw, outer.sw, inner.nw, inner.sw, !northWestClosed, !southWestClosed);
		maybeAddPiece(here, east, outer.se, outer.ne, inner.se, inner.ne, !southEastClosed, !northEastClosed);

		if (row == 1) {
			maybeAddPiece(here, PoleNode(North), outer.ne, outer.nw, inner.ne, inner.nw, !eastClosed, !westClosed);
		} else {
			addRowBoundaryPieces(here, row, col, row - 1, true, westClosed, eastClosed);
		}
		if (row == Maze.ROWS - 2) {
			maybeAddPiece(here, PoleNode(South), outer.sw, outer.se, inner.sw, inner.se, !westClosed, !eastClosed);
		} else {
			addRowBoundaryPieces(here, row, col, row + 1, false, westClosed, eastClosed);
		}
	}

	/**
		Adds this cell's piece(s) for its north (`towardNorth = true`) or
		south side, toward `otherRow` — one piece per
		`Maze.rowBoundaryNeighbors` entry, each spanning only that entry's
		own fraction of this cell's phi width (matching whichever of
		`otherRow`'s cells actually borders it there), rather than assuming
		a single neighbor spans the whole side the way west/east always do.

		An entry's `phiStart`/`phiEnd` are already this cell's true *outer*
		boundary phi for that fraction (`Maze.rowBoundaryNeighbors` computes
		them the same way `cornersOf` does) — used directly for the outer
		corners. The matching *inner* corners need the same fraction
		applied to this cell's own (narrower) inset phi range instead, so a
		split piece still tapers the same way a whole one does — computed
		by re-deriving each entry's fraction of the *outer* range and
		applying it to the *inner* one.
		Each entry's end caps are skipped wherever whatever's adjacent to it
		there is also closed (see `maybeAddPiece`'s doc): its outermost
		(westmost/eastmost) end against this cell's own west/east wall, and
		— when this side is itself split into more than one entry — each
		interior end against its neighboring entry, so two closed sub-pieces
		of the *same* logical side connect plainly too, not just a whole
		side against a perpendicular one.
		@param here this cell's own node.
		@param row this cell's row.
		@param col this cell's column.
		@param otherRow the row on the other side of this side — row - 1 or row + 1.
		@param towardNorth whether this is the north (smaller theta) side or the south (larger theta) one.
		@param westClosed whether this cell's own west side is closed.
		@param eastClosed whether this cell's own east side is closed.
	**/
	function addRowBoundaryPieces(here:MazeNode, row:Int, col:Int, otherRow:Int, towardNorth:Bool, westClosed:Bool, eastClosed:Bool):Void {
		var theta = Math.PI * row / (Maze.ROWS - 1);
		var halfTheta = Math.PI / (Maze.ROWS - 1) / 2;
		var cols = Maze.colsForRow(row);
		var centerPhi = 2 * Math.PI * (col + 0.5) / cols;
		var halfPhi = Math.PI / cols;
		var insetTheta = Math.min(halfTheta, MazeGeometry.WALL_THICKNESS / MazeGeometry.RADIUS);
		var insetPhi = Math.min(halfPhi, MazeGeometry.WALL_THICKNESS / (MazeGeometry.RADIUS * Math.sin(theta)));
		var innerHalfPhi = halfPhi - insetPhi;

		var outerTheta = towardNorth ? theta - halfTheta : theta + halfTheta;
		var innerTheta = towardNorth ? theta - (halfTheta - insetTheta) : theta + (halfTheta - insetTheta);
		var outerRangeStart = centerPhi - halfPhi;
		var innerRangeStart = centerPhi - innerHalfPhi;

		var entries = Maze.rowBoundaryNeighbors(row, col, otherRow);
		for (i in 0...entries.length) {
			var entry = entries[i];
			var fractionStart = (entry.phiStart - outerRangeStart) / (2 * halfPhi);
			var fractionEnd = (entry.phiEnd - outerRangeStart) / (2 * halfPhi);
			var innerPhiStart = innerRangeStart + fractionStart * (2 * innerHalfPhi);
			var innerPhiEnd = innerRangeStart + fractionEnd * (2 * innerHalfPhi);

			// North orders its two corners (east, west); south orders them
			// (west, east) — matches cornersOf/innerCornersOf's own nw/ne
			// vs sw/se ordering for a whole (unsplit) piece.
			var outerA = MazeMesh.cornerAt(outerTheta, towardNorth ? entry.phiEnd : entry.phiStart);
			var outerB = MazeMesh.cornerAt(outerTheta, towardNorth ? entry.phiStart : entry.phiEnd);
			var innerA = MazeMesh.cornerAt(innerTheta, towardNorth ? innerPhiEnd : innerPhiStart);
			var innerB = MazeMesh.cornerAt(innerTheta, towardNorth ? innerPhiStart : innerPhiEnd);

			var westEndOpen = i == 0 ? !westClosed : Maze.isOpen(maze, here, entries[i - 1].node);
			var eastEndOpen = i == entries.length - 1 ? !eastClosed : Maze.isOpen(maze, here, entries[i + 1].node);
			var capA = towardNorth ? eastEndOpen : westEndOpen;
			var capB = towardNorth ? westEndOpen : eastEndOpen;

			maybeAddPiece(here, entry.node, outerA, outerB, innerA, innerB, capA, capB);
		}
	}

	/**
		Builds this cell's own wall piece for one side, if that side's edge
		is closed — a box spanning `outerA`/`outerB` (the true, shared
		boundary) to `innerA`/`innerB` (this cell's own inset corners),
		extruded up by WALL_HEIGHT.

		`capA`/`capB` control whether the end cap at that end is built at
		all: an end cap seals the piece's cut face where nothing continues
		it, needed at a genuine free-standing end (the adjacent side there is
		open). Where the adjacent side is instead *also* closed — a plain
		corner, or a doubling boundary's own split pieces meeting each other
		— that neighboring piece's own inner face already reaches the exact
		same edge, so the cap becomes a redundant face buried inside the now-
		solid corner, invisible from any angle a player can reach (same
		reasoning as never building an outer face at all — see class doc).
		Skipping it there is what keeps a corner a plain rectangular corner
		instead of a hexagonal one, chamfered by two overlapping diagonal cap
		faces.
	**/
	function maybeAddPiece(a:MazeNode, b:MazeNode, outerA:h3d.Vector, outerB:h3d.Vector, innerA:h3d.Vector, innerB:h3d.Vector, capA:Bool, capB:Bool):Void {
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
		// End caps — only where that end is actually free-standing (see doc above).
		if (capA) {
			addTexturedQuad(outerA, innerA, topInnerA, topOuterA, vThickness, vHeight);
		}
		if (capB) {
			addTexturedQuad(innerB, outerB, topOuterB, topInnerB, vThickness, vHeight);
		}
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
