package biomes.common.grid;

import biomes.common.grid.GridModel.GridData;
import biomes.common.grid.GridModel.GridNode;
import biomes.common.space.sphere.SphereMath;
import game.MeshBuilder;
import graphics.Colours;
import graphics.shaders.UnlitTexture;

/** A ring cell's four corners — "N"/"S" for the smaller/larger theta edge, "W"/"E" for the smaller/larger phi edge. **/
typedef CellCorners = {
	nw:h3d.Vector,
	ne:h3d.Vector,
	se:h3d.Vector,
	sw:h3d.Vector
}

/**
	Builds renderable meshes for a grid-based biome's own layout: a floor
	patch per ring cell, and a wall wherever an edge between two
	grid-adjacent nodes is closed.

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
	graphics.shaders.UnlitTexture — while staying just as immune to that PBR
	pitfall, since it never touches the lighting pipeline either.
**/
class GridMesh {
	// Doubled from 6 on request, for taller, more prominent walls — a
	// deliberate departure from the earlier "present but not dominant" FOV-
	// subtense tuning noted in prior sessions (see docs/PROJECT_LOG.md),
	// not an oversight to reconcile back to that ratio later.
	public static inline final WALL_HEIGHT:Float = 12;

	/**
		@param maze the biome's generated layout to build meshes for.
		@param parent the scene object to attach the meshes under.
	**/
	public static function build(maze:GridData, parent:h3d.scene.Object):Void {
		var floorPoints:Array<h3d.Vector> = [];
		var floorIdx = new hxd.IndexBuffer();
		addFloor(floorPoints, floorIdx);
		var floorMesh = new h3d.scene.Mesh(new h3d.prim.Polygon(floorPoints, floorIdx), parent);
		floorMesh.material.mainPass.addShader(new h3d.shader.FixedColor(Colours.GRID_FLOOR));
		floorMesh.material.mainPass.culling = None;

		var wallBuilder = new WallBuilder(maze);
		eachCell((row, col) -> wallBuilder.addWallsAround(row, col));
		var wallPrim = new h3d.prim.Polygon(wallBuilder.points, wallBuilder.idx);
		wallPrim.uvs = wallBuilder.uvs;
		var wallTexture = hxd.Res.textures.wall_stone.toTexture();
		wallTexture.wrap = Repeat;
		var wallMesh = new h3d.scene.Mesh(wallPrim, parent);
		wallMesh.material.mainPass.addShader(new UnlitTexture(wallTexture));
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
		(`GridModel.rowBoundaryNeighbors`'s own boundaries, at this cell's own
		theta) — the same point the finer neighbor already has on its side —
		so both sides of the seam share identical vertices instead of a
		coarse straight edge cutting across a finer bent one.
	**/
	static function addFloor(points:Array<h3d.Vector>, idx:hxd.IndexBuffer):Void {
		eachCell((row, col) -> {
			var corners = cornersOf(row, col);
			var theta = Math.PI * row / (GridModel.ROWS - 1);
			var halfTheta = Math.PI / (GridModel.ROWS - 1) / 2;

			var perimeter = [corners.nw];
			if (row > 1) {
				var northEntries = GridModel.rowBoundaryNeighbors(row, col, row - 1);
				for (i in 0...northEntries.length - 1) {
					perimeter.push(cornerAt(theta - halfTheta, northEntries[i].phiEnd));
				}
			}
			perimeter.push(corners.ne);
			perimeter.push(corners.se);
			if (row < GridModel.ROWS - 2) {
				var southEntries = GridModel.rowBoundaryNeighbors(row, col, row + 1);
				var i = southEntries.length - 2;
				while (i >= 0) {
					perimeter.push(cornerAt(theta + halfTheta, southEntries[i].phiEnd));
					i--;
				}
			}
			perimeter.push(corners.sw);

			for (i in 1...perimeter.length - 1) {
				MeshBuilder.addTriangle(points, idx, perimeter[0], perimeter[i], perimeter[i + 1]);
			}
		});
	}

	/** A point on the grid's sphere at the given spherical coordinates. Public so `WallBuilder` can build split boundary pieces from it directly. **/
	public static function cornerAt(theta:Float, phi:Float):h3d.Vector {
		return SphereMath.sphericalToCartesian(GridGeometry.RADIUS, theta, phi);
	}

	/**
		A ring cell's four outer corners — the true grid boundary, shared
		exactly with its neighbors. Public so adjacency can be checked
		directly (see test/GridMeshTest.hx): neighboring cells must compute
		matching points for their shared edge, which is what makes the floor
		— and each side's wall piece, built from these same points — connect
		seamlessly to each other.
		@param row the cell's row (1 to GridModel.ROWS - 2).
		@param col the cell's column (0 to GridModel.colsForRow(row) - 1).
		@return the cell's four outer corners.
	**/
	public static function cornersOf(row:Int, col:Int):CellCorners {
		var halfTheta = Math.PI / (GridModel.ROWS - 1) / 2;
		var cols = GridModel.colsForRow(row);
		var halfPhi = Math.PI / cols;
		var theta = Math.PI * row / (GridModel.ROWS - 1);
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
		consistent linear WALL_THICKNESS at any latitude, not a fixed angle —
		computed separately for the north pair and the south pair, each at
		*that edge's own* theta (`theta -/+ halfTheta`), not this cell's
		center theta. Using center theta for all four corners was the
		original approach, and is wrong: a west/east wall's own north and
		south ends sit at the row's actual boundaries, not its center, so the
		curvature correction there needs the boundary's own sine, not the
		center's. Using the center's sine instead made a west/east piece's
		north-end inner corner land at a different phi than the next row's
		own south-end inner corner for that exact same boundary — each row
		computing the correction from its own center rather than the shared
		latitude — so adjacent rows' walls shared their outer edge exactly
		but diverged on the inner edge, a visible seam (in cross-section, two
		wedges joined only along the outer line) at every row boundary.
		Computing each pair from its own true theta makes both sides of a
		boundary agree, since `row`'s own south theta (`theta + halfTheta`)
		is bit-identical to `row + 1`'s own north theta (`theta - halfTheta`
		there) — same latitude, same formula, same result.

		Clamped to the cell's own half-width so a cell doesn't invert near a
		pole, where a column could otherwise be physically narrower than
		WALL_THICKNESS itself — much less likely now that `GridModel.colsForRow`
		reduces column count near the poles specifically to keep cell width
		from collapsing there, but still a real possibility for a small or
		oddly-tuned `WALL_THICKNESS`, so the clamp stays.

		`retreatNorth`/`retreatSouth` control whether the *theta* axis
		retreats from that end at all — a west/east wall only needs room
		there when something is actually using it: a real corner (the
		perpendicular side is closed) or a genuine dead end. When the same
		west/east wall instead runs straight through into the next row
		(nothing perpendicular there, and the next row's own matching side
		is also closed), retreating anyway pinches the piece into a wedge
		that only touches its neighbor along the outer edge — see
		`WallBuilder.continuesAcrossRowBoundary`. Passing `false` there
		keeps that end at the *full* outer theta instead, flush with
		whatever continues it. The phi inset is unaffected either way —
		it's the wall's thickness, not conditional on what's next door.
		@param row the cell's row (1 to GridModel.ROWS - 2).
		@param col the cell's column (0 to GridModel.colsForRow(row) - 1).
		@param retreatNorth whether the north end retreats along theta (default true).
		@param retreatSouth whether the south end retreats along theta (default true).
		@return the cell's four inner corners.
	**/
	public static function innerCornersOf(row:Int, col:Int, ?retreatNorth:Bool, ?retreatSouth:Bool):CellCorners {
		var doRetreatNorth = retreatNorth == null ? true : retreatNorth;
		var doRetreatSouth = retreatSouth == null ? true : retreatSouth;
		var halfTheta = Math.PI / (GridModel.ROWS - 1) / 2;
		var cols = GridModel.colsForRow(row);
		var halfPhi = Math.PI / cols;
		var theta = Math.PI * row / (GridModel.ROWS - 1);
		var phi = 2 * Math.PI * (col + 0.5) / cols;

		var insetTheta = Math.min(halfTheta, GridGeometry.WALL_THICKNESS / GridGeometry.RADIUS);
		var innerHalfThetaNorth = doRetreatNorth ? halfTheta - insetTheta : halfTheta;
		var innerHalfThetaSouth = doRetreatSouth ? halfTheta - insetTheta : halfTheta;

		var northTheta = theta - halfTheta;
		var southTheta = theta + halfTheta;
		var insetPhiNorth = Math.min(halfPhi, GridGeometry.WALL_THICKNESS / (GridGeometry.RADIUS * Math.sin(northTheta)));
		var insetPhiSouth = Math.min(halfPhi, GridGeometry.WALL_THICKNESS / (GridGeometry.RADIUS * Math.sin(southTheta)));
		var innerHalfPhiNorth = halfPhi - insetPhiNorth;
		var innerHalfPhiSouth = halfPhi - insetPhiSouth;

		return {
			nw: cornerAt(theta - innerHalfThetaNorth, phi - innerHalfPhiNorth),
			ne: cornerAt(theta - innerHalfThetaNorth, phi + innerHalfPhiNorth),
			se: cornerAt(theta + innerHalfThetaSouth, phi + innerHalfPhiSouth),
			sw: cornerAt(theta + innerHalfThetaSouth, phi - innerHalfPhiSouth)
		};
	}

	/** Walks every ring cell, calling `f` with its row/col. **/
	static function eachCell(f:(row:Int, col:Int) -> Void):Void {
		for (row in 1...(GridModel.ROWS - 1)) {
			for (col in 0...GridModel.colsForRow(row)) {
				f(row, col);
			}
		}
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

	final maze:GridData;

	public function new(maze:GridData) {
		this.maze = maze;
	}

	/**
		Adds this cell's own piece for each of its closed sides. West/east
		are always exactly one piece (column count never changes within a
		row); north/south go through `addRowBoundaryPieces` instead of a
		single `maybeAddPiece` call, since a row boundary where column count
		doubles moving away from a pole means more than one piece — see its
		own doc comment.

		A west/east piece's north/south end is *flush* — no theta retreat,
		no cap — when this cell's own corner there is open (no perpendicular
		wall) *and* the wall genuinely continues into the next row (that
		row's own matching west/east side is also closed): see
		`continuesAcrossRowBoundary`. Otherwise the end either retreats to
		make room for a real perpendicular wall (a corner, cap skipped since
		that wall's own inner face covers it — see `maybeAddPiece`'s doc) or
		retreats and gets its own cap (a genuine dead end, nothing to
		connect to). Without distinguishing "continues" from "corner", every
		west/east wall pinches at *every* row boundary it crosses, even
		where it's just running straight through several rows — a wedge
		shape in cross-section rather than a plain rectangular wall.

		At a doubling boundary specifically, "continues" only makes sense
		for whichever of this cell's two corners actually lands on a real
		cell-to-cell boundary in the coarser row — see
		`isGenuineRowBoundaryCorner`. The other corner sits partway through
		that single coarser neighbor's own solid, undivided interior, where
		nothing could ever continue into regardless of what's open or
		closed; skipping that corner's cap on the mistaken belief that
		something else covers it left a genuine hole in the wall — no cap,
		nothing else there either — reported directly as a wall's near face
		reading as missing texture, seeing straight through it, specifically
		on the far side of a doubling boundary from wherever the report
		happened to be taken (confirmed by an exhaustive sweep: 3430 such
		holes across 200 generated mazes, every one on a row adjacent to a
		doubling boundary, zero elsewhere).
	**/
	public function addWallsAround(row:Int, col:Int):Void {
		var outer = GridMesh.cornersOf(row, col);
		var here = RingNode(row, col);
		var cols = GridModel.colsForRow(row);
		var west = RingNode(row, (col - 1 + cols) % cols);
		var east = RingNode(row, (col + 1) % cols);
		var westClosed = !GridModel.isOpen(maze, here, west);
		var eastClosed = !GridModel.isOpen(maze, here, east);

		var northEntries = row == 1 ? null : GridModel.rowBoundaryNeighbors(row, col, row - 1);
		var southEntries = row == GridModel.ROWS - 2 ? null : GridModel.rowBoundaryNeighbors(row, col, row + 1);
		var northWestNode = row == 1 ? PoleNode(North) : northEntries[0].node;
		var northEastNode = row == 1 ? PoleNode(North) : northEntries[northEntries.length - 1].node;
		var southWestNode = row == GridModel.ROWS - 2 ? PoleNode(South) : southEntries[0].node;
		var southEastNode = row == GridModel.ROWS - 2 ? PoleNode(South) : southEntries[southEntries.length - 1].node;
		var northWestClosed = !GridModel.isOpen(maze, here, northWestNode);
		var northEastClosed = !GridModel.isOpen(maze, here, northEastNode);
		var southWestClosed = !GridModel.isOpen(maze, here, southWestNode);
		var southEastClosed = !GridModel.isOpen(maze, here, southEastNode);

		var northWestFlush = row != 1
			&& isGenuineRowBoundaryCorner(cols, GridModel.colsForRow(row - 1), col, true)
			&& !northWestClosed
			&& continuesAcrossRowBoundary(northWestNode, true);
		var northEastFlush = row != 1
			&& isGenuineRowBoundaryCorner(cols, GridModel.colsForRow(row - 1), col, false)
			&& !northEastClosed
			&& continuesAcrossRowBoundary(northEastNode, false);
		var southWestFlush = row != GridModel.ROWS - 2
			&& isGenuineRowBoundaryCorner(cols, GridModel.colsForRow(row + 1), col, true)
			&& !southWestClosed
			&& continuesAcrossRowBoundary(southWestNode, true);
		var southEastFlush = row != GridModel.ROWS - 2
			&& isGenuineRowBoundaryCorner(cols, GridModel.colsForRow(row + 1), col, false)
			&& !southEastClosed
			&& continuesAcrossRowBoundary(southEastNode, false);

		var westInner = GridMesh.innerCornersOf(row, col, !northWestFlush, !southWestFlush);
		var eastInner = GridMesh.innerCornersOf(row, col, !northEastFlush, !southEastFlush);

		maybeAddPiece(here, west, outer.nw, outer.sw, westInner.nw, westInner.sw, !northWestClosed && !northWestFlush, !southWestClosed && !southWestFlush);
		maybeAddPiece(here, east, outer.se, outer.ne, eastInner.se, eastInner.ne, !southEastClosed && !southEastFlush, !northEastClosed && !northEastFlush);

		if (row == 1) {
			var poleInner = GridMesh.innerCornersOf(row, col);
			maybeAddPiece(here, PoleNode(North), outer.ne, outer.nw, poleInner.ne, poleInner.nw, !eastClosed, !westClosed);
		} else {
			addRowBoundaryPieces(here, row, col, row - 1, true, westClosed, eastClosed);
		}
		if (row == GridModel.ROWS - 2) {
			var poleInner = GridMesh.innerCornersOf(row, col);
			maybeAddPiece(here, PoleNode(South), outer.sw, outer.se, poleInner.sw, poleInner.se, !westClosed, !eastClosed);
		} else {
			addRowBoundaryPieces(here, row, col, row + 1, false, westClosed, eastClosed);
		}
	}

	/**
		Whether a west/east wall genuinely continues straight past a row
		boundary, rather than meeting a perpendicular wall or simply ending
		— true only when the neighbor across that boundary has its own
		matching (west or east) side closed, carrying the same wall into the
		next row. Callers only check this when this cell's own corner there
		is already open (see `addWallsAround`); a `PoleNode` neighbor is
		never a straight continuation (a pole isn't parameterized by west/
		east at all, and every ring cell meets it independently as its own
		wedge).
		@param neighborNode the node across the row boundary at this corner.
		@param wantWest whether to check that neighbor's own west side (true) or east side (false).
		@return whether the wall continues flush into that neighbor.
	**/
	function continuesAcrossRowBoundary(neighborNode:GridNode, wantWest:Bool):Bool {
		return switch neighborNode {
			case PoleNode(_): false;
			case RingNode(nRow, nCol):
				var nCols = GridModel.colsForRow(nRow);
				var neighborSide = RingNode(nRow, wantWest ? (nCol - 1 + nCols) % nCols : (nCol + 1) % nCols);
				!GridModel.isOpen(maze, neighborNode, neighborSide);
		}
	}

	/**
		Whether this cell's west (`west = true`) or east corner toward
		`otherRow` actually lands on a cell-to-cell boundary there, rather
		than partway through a single coarser neighbor's own solid,
		undivided interior.

		Only matters when this row has *more* columns than `otherRow` (a
		single coarser cell then spans several of this row's own cells —
		`GridModel.rowBoundaryNeighbors` collapses them all to that one parent,
		see its own doc): only this cell's outermost west or east corner
		within that shared parent lands on one of the parent's own real
		edges (where the parent meets ITS OWN west or east neighbor); every
		corner in between is interior to that one parent, where nothing
		could ever "continue flush" into regardless of what's open or
		closed elsewhere, since there's no subdivision there to continue
		into or a wall to meet. `col % ratio`/`(col + 1) % ratio` picks out
		exactly those two outermost children (`ratio` is always this row's
		column count divided by the coarser row's, an exact doubling at
		every banding change — see `GridModel.colsForRow`).

		Always true when this row's own column count is less than or equal
		to `otherRow`'s: either a plain one-to-one row (every corner is a
		real boundary already) or this row is itself the coarser side,
		which never reaches this check to begin with (`addWallsAround` only
		calls this for whichever of the two rows has *more* columns).
		@param cols this cell's own row's column count.
		@param otherCols the row on the other side of this boundary's column count.
		@param col this cell's own column.
		@param west whether to check the west corner (true) or east corner (false).
		@return whether that corner is a genuine coarser-row boundary, not an interior split point.
	**/
	function isGenuineRowBoundaryCorner(cols:Int, otherCols:Int, col:Int, west:Bool):Bool {
		if (cols <= otherCols) {
			return true;
		}
		var ratio = Std.int(cols / otherCols);
		return west ? col % ratio == 0 : (col + 1) % ratio == 0;
	}

	/**
		Adds this cell's piece(s) for its north (`towardNorth = true`) or
		south side, toward `otherRow` — one piece per
		`GridModel.rowBoundaryNeighbors` entry, each spanning only that entry's
		own fraction of this cell's phi width (matching whichever of
		`otherRow`'s cells actually borders it there), rather than assuming
		a single neighbor spans the whole side the way west/east always do.

		An entry's `phiStart`/`phiEnd` are already this cell's true *outer*
		boundary phi for that fraction (`GridModel.rowBoundaryNeighbors` computes
		them the same way `cornersOf` does) — used directly for the outer
		corners. The matching *inner* corners need the same fraction applied
		to this cell's own inner phi range instead, so a split piece still
		tapers the same way a whole one does — computed by re-deriving each
		entry's fraction of the *outer* range and applying it to the *inner*
		one. That inset phi range uses this side's own boundary theta
		(`outerTheta`) for the curvature correction, not this cell's center
		theta — matching `innerCornersOf`'s own fix for the same reason:
		this side's west/east ends have to land on the exact same points
		`innerCornersOf` computes for this cell's west/east pieces, or the
		two would meet at a corner with mismatched inner edges again, just
		relocated from a row boundary to a west/east one.

		The inner range's own west and east ends independently retreat (or
		not) the same way a west/east piece's north/south ends do (see
		`continuesAcrossColumnBoundary`): retreat only where a real
		perpendicular wall needs the room or the side is a genuine dead
		end, and run the full outer width through where this same
		north/south wall instead continues straight into the next column —
		otherwise it pinches into a wedge at *every* column it crosses the
		same way an unfixed west/east wall pinched at every row.

		Each entry's end caps are skipped wherever whatever's adjacent to it
		there is also closed or flush (see `maybeAddPiece`'s doc): its
		outermost (westmost/eastmost) end against this cell's own west/east
		wall (or its continuation), and — when this side is itself split
		into more than one entry — each interior end against its
		neighboring entry, so two closed sub-pieces of the *same* logical
		side connect plainly too, not just a whole side against a
		perpendicular one.
		@param here this cell's own node.
		@param row this cell's row.
		@param col this cell's column.
		@param otherRow the row on the other side of this side — row - 1 or row + 1.
		@param towardNorth whether this is the north (smaller theta) side or the south (larger theta) one.
		@param westClosed whether this cell's own west side is closed.
		@param eastClosed whether this cell's own east side is closed.
	**/
	function addRowBoundaryPieces(here:GridNode, row:Int, col:Int, otherRow:Int, towardNorth:Bool, westClosed:Bool, eastClosed:Bool):Void {
		var theta = Math.PI * row / (GridModel.ROWS - 1);
		var halfTheta = Math.PI / (GridModel.ROWS - 1) / 2;
		var cols = GridModel.colsForRow(row);
		var centerPhi = 2 * Math.PI * (col + 0.5) / cols;
		var halfPhi = Math.PI / cols;
		var insetTheta = Math.min(halfTheta, GridGeometry.WALL_THICKNESS / GridGeometry.RADIUS);

		var outerTheta = towardNorth ? theta - halfTheta : theta + halfTheta;
		var innerTheta = towardNorth ? theta - (halfTheta - insetTheta) : theta + (halfTheta - insetTheta);
		var insetPhi = Math.min(halfPhi, GridGeometry.WALL_THICKNESS / (GridGeometry.RADIUS * Math.sin(outerTheta)));
		var outerRangeStart = centerPhi - halfPhi;
		var outerRangeEnd = centerPhi + halfPhi;

		var westNeighborCol = (col - 1 + cols) % cols;
		var eastNeighborCol = (col + 1) % cols;
		var westFlush = !westClosed && continuesAcrossColumnBoundary(row, westNeighborCol, otherRow, true);
		var eastFlush = !eastClosed && continuesAcrossColumnBoundary(row, eastNeighborCol, otherRow, false);
		var innerRangeStart = westFlush ? outerRangeStart : outerRangeStart + insetPhi;
		var innerRangeEnd = eastFlush ? outerRangeEnd : outerRangeEnd - insetPhi;

		var entries = GridModel.rowBoundaryNeighbors(row, col, otherRow);
		for (i in 0...entries.length) {
			var entry = entries[i];
			var fractionStart = (entry.phiStart - outerRangeStart) / (2 * halfPhi);
			var fractionEnd = (entry.phiEnd - outerRangeStart) / (2 * halfPhi);
			var innerPhiStart = innerRangeStart + fractionStart * (innerRangeEnd - innerRangeStart);
			var innerPhiEnd = innerRangeStart + fractionEnd * (innerRangeEnd - innerRangeStart);

			// North orders its two corners (east, west); south orders them
			// (west, east) — matches cornersOf/innerCornersOf's own nw/ne
			// vs sw/se ordering for a whole (unsplit) piece.
			var outerA = GridMesh.cornerAt(outerTheta, towardNorth ? entry.phiEnd : entry.phiStart);
			var outerB = GridMesh.cornerAt(outerTheta, towardNorth ? entry.phiStart : entry.phiEnd);
			var innerA = GridMesh.cornerAt(innerTheta, towardNorth ? innerPhiEnd : innerPhiStart);
			var innerB = GridMesh.cornerAt(innerTheta, towardNorth ? innerPhiStart : innerPhiEnd);

			var westEndCap = i == 0 ? (!westClosed && !westFlush) : GridModel.isOpen(maze, here, entries[i - 1].node);
			var eastEndCap = i == entries.length - 1 ? (!eastClosed && !eastFlush) : GridModel.isOpen(maze, here, entries[i + 1].node);
			var capA = towardNorth ? eastEndCap : westEndCap;
			var capB = towardNorth ? westEndCap : eastEndCap;

			maybeAddPiece(here, entry.node, outerA, outerB, innerA, innerB, capA, capB);
		}
	}

	/**
		Whether a north/south wall piece genuinely continues straight past a
		west/east boundary, rather than meeting a perpendicular wall or
		simply ending — true only when the neighbor there has its own
		matching row-boundary entry (toward the same `otherRow`) also
		closed, carrying the same wall into the next column. West/east
		neighbors always share this row's own column count (only north/
		south crosses a resolution change), so unlike
		`continuesAcrossRowBoundary` there's no doubling to account for —
		just whichever of the neighbor's own (possibly still split) entries
		is physically adjacent to this cell.
		@param row this row.
		@param neighborCol the west or east neighbor's column.
		@param otherRow the row this side's entries lead toward.
		@param wantNeighborsEastmostEntry whether to check the neighbor's eastmost entry (true, for this cell's west end) or westmost (false, for this cell's east end).
		@return whether the wall continues flush into that neighbor.
	**/
	function continuesAcrossColumnBoundary(row:Int, neighborCol:Int, otherRow:Int, wantNeighborsEastmostEntry:Bool):Bool {
		var neighborHere = RingNode(row, neighborCol);
		var neighborEntries = GridModel.rowBoundaryNeighbors(row, neighborCol, otherRow);
		var entry = wantNeighborsEastmostEntry ? neighborEntries[neighborEntries.length - 1] : neighborEntries[0];
		return !GridModel.isOpen(maze, neighborHere, entry.node);
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
	function maybeAddPiece(a:GridNode, b:GridNode, outerA:h3d.Vector, outerB:h3d.Vector, innerA:h3d.Vector, innerB:h3d.Vector, capA:Bool, capB:Bool):Void {
		if (GridModel.isOpen(maze, a, b)) {
			return;
		}

		var center = new h3d.Vector(0, 0, 0);
		var upA = SphereMath.upVectorAt(outerA, center);
		var upB = SphereMath.upVectorAt(outerB, center);
		var topOuterA = outerA.add(upA.scaled(GridMesh.WALL_HEIGHT));
		var topOuterB = outerB.add(upB.scaled(GridMesh.WALL_HEIGHT));
		var topInnerA = innerA.add(upA.scaled(GridMesh.WALL_HEIGHT));
		var topInnerB = innerB.add(upB.scaled(GridMesh.WALL_HEIGHT));

		// Chord length as a stand-in for arc length (cells are small relative
		// to the sphere, so the two are close enough for texture tiling) —
		// repeats the texture across the wall's length rather than stretching
		// one tile to fit, so differently-sized walls read at a consistent
		// texel density.
		var uRepeat = outerA.sub(outerB).length() / MeshBuilder.WALL_TEXTURE_TILE_SIZE;
		var vHeight = GridMesh.WALL_HEIGHT / MeshBuilder.WALL_TEXTURE_TILE_SIZE;
		var vThickness = GridGeometry.WALL_THICKNESS / MeshBuilder.WALL_TEXTURE_TILE_SIZE;

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
		MeshBuilder.addQuad(points, idx, a, b, c, d);
		uvs.push(new h3d.prim.UV(0, vSpan));
		uvs.push(new h3d.prim.UV(uRepeat, vSpan));
		uvs.push(new h3d.prim.UV(uRepeat, 0));
		uvs.push(new h3d.prim.UV(0, 0));
	}
}
