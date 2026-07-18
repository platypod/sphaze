package biomes.maze;

import grid.Grid;
import grid.Grid.GridData;
import grid.Grid.GridNode;
import grid.GridMesh;

/** The wall segment `MazeExitWall.find` found, plus enough context to render a painting flush against it. **/
typedef FoundWall = {
	a:h3d.Vector,
	b:h3d.Vector,
	cellCenter:h3d.Vector
}

/**
	Finds a spot on a maze biome's own grid to mount its exit painting —
	moved out of the old hub-specific `BiomePainting`: picking a wall for
	this is the maze biome's own concern (see `MazeBiome`), not something
	specific to wherever the painting happens to lead.
**/
class MazeExitWall {
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
	public static function find(maze:GridData):FoundWall {
		for (row in 1...(Grid.ROWS - 1)) {
			var cols = Grid.colsForRow(row);
			for (col in 0...cols) {
				var here = RingNode(row, col);
				var west = RingNode(row, (col - 1 + cols) % cols);
				if (!Grid.isOpen(maze, here, west)) {
					var inner = GridMesh.innerCornersOf(row, col);
					return {a: inner.nw, b: inner.sw, cellCenter: cellCenterOf(row, col)};
				}
				var east = RingNode(row, (col + 1) % cols);
				if (!Grid.isOpen(maze, here, east)) {
					var inner = GridMesh.innerCornersOf(row, col);
					return {a: inner.ne, b: inner.se, cellCenter: cellCenterOf(row, col)};
				}
			}
		}
		throw "unreachable: a generated/imported maze is a spanning tree, so some west/east edge is always closed somewhere";
	}

	/** A ring cell's center point — same theta/phi formula `GridMesh.cornersOf`/`innerCornersOf` use internally. **/
	static function cellCenterOf(row:Int, col:Int):h3d.Vector {
		var theta = Math.PI * row / (Grid.ROWS - 1);
		var cols = Grid.colsForRow(row);
		var phi = 2 * Math.PI * (col + 0.5) / cols;
		return GridMesh.cornerAt(theta, phi);
	}
}
