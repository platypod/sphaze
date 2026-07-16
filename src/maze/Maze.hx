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

/** Grid queries and generation for the maze defined by MazeNode/MazeData above. **/
class Maze {
	/** Row count of the ring grid, poles excluded (poles are merged nodes, not rows). **/
	public static inline final ROWS:Int = 16;

	/** Column count of the ring grid — the longitude resolution. **/
	public static inline final COLS:Int = 32;

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
		for which edges the maze has actually opened).
		@param node the node to find neighbors of.
		@return `node`'s neighbors on the grid.
	**/
	public static function neighborsOf(node:MazeNode):Array<MazeNode> {
		return switch node {
			case PoleNode(pole):
				var row = pole == North ? 1 : ROWS - 2;
					[for (col in 0...COLS) RingNode(row, col)];
			case RingNode(row, col):
				var neighbors = [RingNode(row, (col - 1 + COLS) % COLS), RingNode(row, (col + 1) % COLS)];
				neighbors.push(row == 1 ? PoleNode(North) : RingNode(row - 1, col));
				neighbors.push(row == ROWS - 2 ? PoleNode(South) : RingNode(row + 1, col));
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
			for (col in 0...COLS) {
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
		var col = Math.round(phi * COLS / (2 * Math.PI)) % COLS;
		if (col < 0) {
			col += COLS;
		}
		return RingNode(row, col);
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
}
