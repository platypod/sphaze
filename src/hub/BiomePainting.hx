package hub;

import maze.Maze;
import maze.Maze.MazeData;
import maze.Maze.MazeNode;
import maze.MazeMesh;

/** The wall segment `BiomePainting.findReturnWall` found, plus enough context to render a painting flush against it. **/
typedef FoundWall = {
	a:h3d.Vector,
	b:h3d.Vector,
	cellCenter:h3d.Vector
}

/**
	Places the return-to-hub painting in whatever biome maze was just
	generated or imported — same functions either way (`Main` calls these
	after both `Maze.generate()` and `Maze.deserialize()`), so an imported
	maze always gets one too, not a special case.
**/
class BiomePainting {
	/**
		Scans cells in row-major order, checking each one's west then east
		side, for the first closed edge — using `MazeMesh.innerCornersOf`'s
		default (fully retreated) corners rather than replicating
		`WallBuilder`'s private flush logic: a painting only ever sits at a
		wall's *own* midpoint, far from either end, so the small difference
		between a flush and a retreated corner (which only matters right at
		an end) never moves that midpoint enough to matter.

		Only checks west/east, never north/south: a generated or imported
		maze is a spanning tree, so the overwhelming majority of *all* edges
		are closed — checking just one axis is already virtually certain to
		find a match within the first row or two, and skips the added
		complexity of the pole/row-boundary-doubling cases north/south
		checks would need.
		@param maze the maze to find a wall in.
		@return the found wall segment.
	**/
	public static function findReturnWall(maze:MazeData):FoundWall {
		for (row in 1...(Maze.ROWS - 1)) {
			var cols = Maze.colsForRow(row);
			for (col in 0...cols) {
				var here = RingNode(row, col);
				var west = RingNode(row, (col - 1 + cols) % cols);
				if (!Maze.isOpen(maze, here, west)) {
					var inner = MazeMesh.innerCornersOf(row, col);
					return {a: inner.nw, b: inner.sw, cellCenter: cellCenterOf(row, col)};
				}
				var east = RingNode(row, (col + 1) % cols);
				if (!Maze.isOpen(maze, here, east)) {
					var inner = MazeMesh.innerCornersOf(row, col);
					return {a: inner.ne, b: inner.se, cellCenter: cellCenterOf(row, col)};
				}
			}
		}
		throw "unreachable: a generated/imported maze is a spanning tree, so some west/east edge is always closed somewhere";
	}

	/**
		The return-to-hub `Painting` for whatever wall `findReturnWall`
		finds in `maze`.
		@param maze the maze to place the painting in.
		@return the placed painting.
	**/
	public static function findReturnPainting(maze:MazeData):Painting {
		var wall = findReturnWall(maze);
		return new Painting(Painting.midpointOf(wall.a, wall.b), ToHub);
	}

	/** A ring cell's center point — same theta/phi formula `MazeMesh.cornersOf`/`innerCornersOf` use internally. **/
	static function cellCenterOf(row:Int, col:Int):h3d.Vector {
		var theta = Math.PI * row / (Maze.ROWS - 1);
		var cols = Maze.colsForRow(row);
		var phi = 2 * Math.PI * (col + 0.5) / cols;
		return MazeMesh.cornerAt(theta, phi);
	}
}
