package maze;

/**
	The maze lives on a latitude/longitude grid over the sphere. The two pole
	rows would otherwise collapse into COLS degenerate slivers meeting at a
	point, so each pole is a single merged node that every cell in the
	adjacent ring connects to directly.

	Ported from old/src/maze/mazeGenerator.ts — the algorithm is engine-
	agnostic, so it carries over unchanged; only language/API details differ
	(a Haxe enum instead of a tagged union, a StringMap-backed set instead of
	Set<string>).
**/
/** Which pole a `PoleNode` merges into. **/
enum Pole {
	North;
	South;
}

/** A single cell on the maze grid: one of the two merged poles, or a ring cell at (row, col). **/
enum MazeNode {
	PoleNode(pole:Pole);
	RingNode(row:Int, col:Int);
}

/** A generated maze: which edges between adjacent nodes are open passages. **/
typedef MazeData = {
	/** Keys are `Maze.nodeKey`-formatted edge keys (see `Maze.isOpen`), not node keys. **/
	var openEdges:haxe.ds.StringMap<Bool>;
}

/**
	One row-boundary neighbor a `RingNode` has toward an adjacent row, paired
	with its own share of that cell's phi range on that side — see
	`Maze.rowBoundaryNeighbors`.
**/
typedef RowBoundaryNeighbor = {node:MazeNode, phiStart:Float, phiEnd:Float}

/** Grid queries and generation for the maze defined by MazeNode/MazeData above. **/
class Maze {
	/** Row count of the ring grid, poles excluded (poles are merged nodes, not rows). **/
	public static inline final ROWS:Int = 14;

	/**
		Column count at the equatorial band — the grid's *maximum* longitude
		resolution, not a uniform one. See `colsForRow` for how it varies by
		row.
	**/
	public static inline final COLS:Int = 28;

	/**
		Column count for a given ring row — fewer nearer the poles, full
		`COLS` resolution at the equator, so a cell's physical east-west
		width stays roughly consistent everywhere instead of shrinking
		toward the poles (a column's physical width is proportional to
		`sin(theta)`, which shrinks toward the poles, while a fixed column
		count doesn't compensate — see docs/PROJECT_LOG.md for the actual
		numbers this band scheme was tuned against).

		Banded by `d`, the row's distance in rows from the nearer pole:
		`d<=1` (the rows immediately adjacent to a pole) gets `COLS/4`,
		`d<=3` gets `COLS/2`, everything else gets the full `COLS`. Every
		boundary here is an exact halving/doubling — `rowBoundaryNeighbors`
		depends on that to nest cleanly. (Assumes `COLS` divides evenly by
		4; true today at `COLS=28`, would need revisiting if `COLS` ever
		changed to something that doesn't.)
		@param row the ring row (1 to ROWS - 2).
		@return that row's column count.
	**/
	public static function colsForRow(row:Int):Int {
		var distFromPole = row < ROWS - 1 - row ? row : ROWS - 1 - row;
		if (distFromPole <= 1) {
			return Std.int(COLS / 4);
		}
		if (distFromPole <= 3) {
			return Std.int(COLS / 2);
		}
		return COLS;
	}

	/**
		Every neighbor `RingNode(row, col)` has directly across the row
		boundary toward `otherRow` (row-1 or row+1; must itself be a ring
		row, not a pole — poles stay `neighborsOf`'s own special case,
		never routed through here), each paired with its own share of this
		cell's phi range on that side.

		A single entry (this cell's own full phi range) when the two rows
		share the same column count. When `otherRow` has *fewer* columns
		(moving toward a pole), also a single entry — several of this row's
		cells share one neighbor there, so this cell's own full range maps
		onto its one parent, at whichever fraction of it that parent
		actually is. When `otherRow` has *more* columns (moving away from a
		pole), one entry per child, each covering an even fraction of this
		cell's own phi range — the reverse of the same halving.

		Column phi is boundary-anchored (see `centerOf`'s doc) specifically
		so this nests exactly: a coarser row's own boundary is always also
		one of a finer row's boundaries at any of these integer ratios, so
		there's never a sub-boundary that splits unevenly or leaves a gap.
		@param row the cell's own row.
		@param col the cell's own column.
		@param otherRow the row to find boundary neighbors toward — row - 1 or row + 1, never a pole row.
		@return this cell's neighbor(s) across that boundary, each with its own phi sub-range.
	**/
	public static function rowBoundaryNeighbors(row:Int, col:Int, otherRow:Int):Array<RowBoundaryNeighbor> {
		var myCols = colsForRow(row);
		var otherCols = colsForRow(otherRow);
		var phiStart = 2 * Math.PI * col / myCols;
		var phiEnd = 2 * Math.PI * (col + 1) / myCols;

		if (otherCols == myCols) {
			return [{node: RingNode(otherRow, col), phiStart: phiStart, phiEnd: phiEnd}];
		}
		if (otherCols < myCols) {
			var ratio = Std.int(myCols / otherCols);
			return [
				{node: RingNode(otherRow, Std.int(col / ratio)), phiStart: phiStart, phiEnd: phiEnd}
			];
		}
		var ratio = Std.int(otherCols / myCols);
		return [
			for (i in 0...ratio)
				{
					node: RingNode(otherRow, col * ratio + i),
					phiStart: phiStart + (phiEnd - phiStart) * i / ratio,
					phiEnd: phiStart + (phiEnd - phiStart) * (i + 1) / ratio
				}
		];
	}

	/**
		Stable string key for a node, used to store/look up nodes and edges in
		a StringMap (Haxe enum values don't structurally hash/compare, so a
		string key is how this module gets set/map semantics out of them).
		@param node the node to compute a key for.
		@return the node's stable string key.
	**/
	public static function nodeKey(node:MazeNode):String {
		return switch node {
			case PoleNode(North): "pole:north";
			case PoleNode(South): "pole:south";
			case RingNode(row, col): 'ring:$row:$col';
		}
	}

	static function edgeKey(a:MazeNode, b:MazeNode):String {
		var keyA = nodeKey(a);
		var keyB = nodeKey(b);
		return keyA < keyB ? '$keyA|$keyB' : '$keyB|$keyA';
	}

	/**
		Every node directly reachable from `node` on the grid (not accounting
		for which edges the maze has actually opened). A ring cell's west/
		east neighbors are always exactly one node (column count never
		changes within a row); its north/south neighbors — unless it's the
		one ring row adjacent to a pole, still its own special case — come
		from `rowBoundaryNeighbors` and so can be more than one, at a row
		boundary where column count doubles moving away from a pole.
		@param node the node to find neighbors of.
		@return `node`'s neighbors on the grid.
	**/
	public static function neighborsOf(node:MazeNode):Array<MazeNode> {
		return switch node {
			case PoleNode(pole):
				var row = pole == North ? 1 : ROWS - 2;
					[for (col in 0...colsForRow(row)) RingNode(row, col)];
			case RingNode(row, col):
				var cols = colsForRow(row);
				var neighbors = [RingNode(row, (col - 1 + cols) % cols), RingNode(row, (col + 1) % cols)];
				if (row == 1) {
					neighbors.push(PoleNode(North));
				} else {
					for (boundaryNeighbor in rowBoundaryNeighbors(row, col, row - 1)) {
						neighbors.push(boundaryNeighbor.node);
					}
				}
				if (row == ROWS - 2) {
					neighbors.push(PoleNode(South));
				} else {
					for (boundaryNeighbor in rowBoundaryNeighbors(row, col, row + 1)) {
						neighbors.push(boundaryNeighbor.node);
					}
				}
				neighbors;
		}
	}

	/**
		Every node on the grid: the two poles plus every ring cell. Order is
		significant only in that `generate` starts its spanning tree from the
		first element.
		@return every node on the grid.
	**/
	public static function allNodes():Array<MazeNode> {
		var nodes:Array<MazeNode> = [PoleNode(North), PoleNode(South)];
		for (row in 1...(ROWS - 1)) {
			for (col in 0...colsForRow(row)) {
				nodes.push(RingNode(row, col));
			}
		}
		return nodes;
	}

	/**
		Generates a perfect maze (spanning tree — exactly one path between any
		two cells) over the sphere's lat/long grid via randomized depth-first
		search.
		@param random source of randomness in [0, 1); defaults to Math.random.
		@return the generated maze's open edges.
	**/
	public static function generate(?random:Void->Float):MazeData {
		var rng = random != null ? random : Math.random;
		var visited = new haxe.ds.StringMap<Bool>();
		var openEdges = new haxe.ds.StringMap<Bool>();

		var start = allNodes()[0];
		if (start == null) {
			return {openEdges: openEdges};
		}

		var stack:Array<MazeNode> = [start];
		visited.set(nodeKey(start), true);

		while (stack.length > 0) {
			var current = stack[stack.length - 1];
			if (current == null) {
				break;
			}

			var unvisited = neighborsOf(current).filter(neighbor -> !visited.exists(nodeKey(neighbor)));
			if (unvisited.length == 0) {
				stack.pop();
				continue;
			}

			var next = unvisited[Math.floor(rng() * unvisited.length)];
			if (next == null) {
				continue;
			}
			openEdges.set(edgeKey(current, next), true);
			visited.set(nodeKey(next), true);
			stack.push(next);
		}

		return {openEdges: openEdges};
	}

	/**
		Which node a physical position on the grid's sphere belongs to —
		the inverse of the cell/pole layout `MazeMesh.cornersOf` and
		`neighborsOf` assume. Takes plain spherical coordinates rather than a
		3D point so this module stays engine-agnostic (see the class doc);
		callers on a 3D point go through `SphereMath.thetaOf`/`phiOf` first.

		Snaps to a `PoleNode` within `halfTheta` of a pole regardless of phi —
		matching `neighborsOf`'s merged-pole topology, where every column
		converges on the same single node there. Without this, a column
		index computed right at a pole would be meaningless (circles of
		latitude shrink to zero circumference there — the same instability
		`entities.Player`'s class doc describes for orientation).

		Column classification is boundary-anchored, not center-anchored:
		column `col` owns `[2*pi*col/colsForRow(row), 2*pi*(col+1)/
		colsForRow(row))`, so a position floors cleanly into its column with
		no rounding/wraparound ambiguity at the top of the range (see
		`centerOf`'s doc for why this convention was chosen over rounding to
		the nearest center) — and, since `colsForRow` varies by row, row
		must be resolved first, column second, always against that row's
		own column count.
		@param theta polar angle from +Y, in radians.
		@param phi azimuth around Y, in radians, in [0, 2*pi).
		@return the node the position falls within.
	**/
	public static function nodeAt(theta:Float, phi:Float):MazeNode {
		var halfTheta = Math.PI / (ROWS - 1) / 2;
		if (theta < halfTheta) {
			return PoleNode(North);
		}
		if (theta > Math.PI - halfTheta) {
			return PoleNode(South);
		}

		var row = Math.round(theta * (ROWS - 1) / Math.PI);
		var cols = colsForRow(row);
		var col = Math.floor(phi * cols / (2 * Math.PI)) % cols;
		if (col < 0) {
			col += cols;
		}
		return RingNode(row, col);
	}

	/**
		A node's nominal position in spherical coordinates — the same
		theta/phi `MazeMesh` derives a cell's corners around. For a pole this
		is theta=0/pi at an arbitrary phi (meaningless there — the point
		itself is what matters, see `entities.Player`'s class doc on the
		phi singularity at the poles).

		Column `col`'s phi is boundary-anchored: `col` spans
		`[2*pi*col/colsForRow(row), 2*pi*(col+1)/colsForRow(row))`, center at
		`2*pi*(col+0.5)/colsForRow(row)`. This (rather than treating
		`2*pi*col/colsForRow(row)` itself as the center) matters once column
		counts vary by row — under a center-anchored convention, a coarser
		row's cell boundaries never land exactly on a finer row's cell
		boundaries even at a clean integer resolution ratio, which breaks
		wall/floor adjacency at every such boundary. Boundary-anchored
		columns nest exactly at any integer ratio: a parent's own boundary
		is always also one of its children's boundaries. Invisible for a
		uniform column count (just a fixed relabeling of which point is
		"col 0").
		@param node the node to find the nominal center of.
		@return the node's center in spherical coordinates.
	**/
	public static function centerOf(node:MazeNode):{theta:Float, phi:Float} {
		return switch node {
			case PoleNode(North): {theta: 0.0, phi: 0.0};
			case PoleNode(South): {theta: Math.PI, phi: 0.0};
			case RingNode(row, col): {theta: Math.PI * row / (ROWS - 1), phi: 2 * Math.PI * (col + 0.5) / colsForRow(row)};
		}
	}

	/**
		Whether the maze has an open passage between two (necessarily
		adjacent) nodes.
		@param maze the maze to query.
		@param a one endpoint.
		@param b the other endpoint.
		@return true if a passage is open between `a` and `b`.
	**/
	public static function isOpen(maze:MazeData, a:MazeNode, b:MazeNode):Bool {
		return maze.openEdges.exists(edgeKey(a, b));
	}

	/**
		Which of `node`'s neighbors, if any, the position (theta, phi) has
		crossed into the *wall-zone* of — the strip between this cell's own
		inner boundary and its true outer boundary (see
		`MazeMesh.innerCornersOf`), *plus* `MazeGeometry.COLLISION_CLEARANCE`,
		on whichever side has a closed edge. Lets `game.Collision` block
		movement a bit short of the wall's actual visible face instead of
		the old zero-thickness boundary line the wall no longer sits on —
		without the base thickness, a player could walk into (and partway
		through) a wall's rendered thickness before anything stopped them;
		without the extra clearance on top, they'd stop exactly flush
		against that thickness, close enough for the camera to catch
		glimpses past the wall's geometry.

		Returns null for `PoleNode` unconditionally: the merged pole cap
		isn't subdivided by column, so it has no per-neighbor wall-zone
		concept the way a ring cell does. A player approaching a wall right
		at the pole boundary is still stopped by the ordinary node-transition
		check in `Collision.tryMoveForward` (just at the old zero-thickness
		line rather than the wall's actual face) — a known, small gap in an
		already-distorted corner of the grid, not solved here.

		Only flags a side whose zone the position is *more* embedded in than
		`fromTheta`/`fromPhi` (this tick's starting position) — not simply
		"still nominally inside" it. The zone is thicker than one tick's
		step distance, so a player already pressed against a wall (which
		can legitimately happen — walking right up to its face is allowed)
		can't fully retreat out of it in a single step; without this
		comparison, every subsequent tick would see "still inside the zone"
		and reject the *entire* step back to the exact starting position,
		forever — a genuine, permanent lockup approaching square-on, where
		`Collision.slideAlong`'s own square-hit fallback also has nothing to
		slide with. Comparing against the tick's own starting depth instead
		allows any move that's a net retreat (or sideways, not changing this
		axis at all) while still blocking one that digs in further.
		@param maze the maze whose closed edges have thickness.
		@param node the cell the position is nominally within.
		@param fromTheta this tick's starting polar angle, before the attempted move.
		@param fromPhi this tick's starting azimuth, before the attempted move.
		@param theta the candidate position's polar angle.
		@param phi the candidate position's azimuth.
		@param radius sphere radius — must match the maze's physical sphere (see MazeGeometry.RADIUS).
		@return the neighbor whose wall-zone was entered *more deeply than at the start of this tick*, or null.
	**/
	public static function wallZoneNeighbor(maze:MazeData, node:MazeNode, fromTheta:Float, fromPhi:Float, theta:Float, phi:Float, radius:Float):Null<MazeNode> {
		switch node {
			case PoleNode(_):
				return null;
			case RingNode(row, col):
				var center = centerOf(node);
				var halfTheta = Math.PI / (ROWS - 1) / 2;
				var halfPhi = Math.PI / COLS;
				var blockAt = MazeGeometry.WALL_THICKNESS + MazeGeometry.COLLISION_CLEARANCE;
				var insetTheta = Math.min(halfTheta, blockAt / radius);
				var insetPhi = Math.min(halfPhi, blockAt / (radius * Math.sin(center.theta)));

				var dTheta = theta - center.theta;
				var dPhi = wrapAngle(phi - center.phi);
				var fromDTheta = fromTheta - center.theta;
				var fromDPhi = wrapAngle(fromPhi - center.phi);

				var west = RingNode(row, (col - 1 + COLS) % COLS);
				var east = RingNode(row, (col + 1) % COLS);
				var north = row == 1 ? PoleNode(North) : RingNode(row - 1, col);
				var south = row == ROWS - 2 ? PoleNode(South) : RingNode(row + 1, col);

				if (dPhi < -(halfPhi - insetPhi) && dPhi < fromDPhi && !isOpen(maze, node, west)) {
					return west;
				}
				if (dPhi > (halfPhi - insetPhi) && dPhi > fromDPhi && !isOpen(maze, node, east)) {
					return east;
				}
				if (dTheta < -(halfTheta - insetTheta) && dTheta < fromDTheta && !isOpen(maze, node, north)) {
					return north;
				}
				if (dTheta > (halfTheta - insetTheta) && dTheta > fromDTheta && !isOpen(maze, node, south)) {
					return south;
				}
				return null;
		}
	}

	/** Normalizes an angular difference to (-pi, pi] so a cell near phi=0/2*pi wraps correctly. **/
	static function wrapAngle(delta:Float):Float {
		var wrapped = delta;
		while (wrapped > Math.PI) {
			wrapped -= 2 * Math.PI;
		}
		while (wrapped < -Math.PI) {
			wrapped += 2 * Math.PI;
		}
		return wrapped;
	}
}
