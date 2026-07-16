package maze;

/**
	The physical sphere the maze grid is mapped onto. `MazeMesh` derives its
	own corner positions directly from `Maze.ROWS`/`Maze.COLS` and this
	radius via `SphereMath`, rather than through a per-node lookup here —
	walls need shared *corner* points with their neighboring floor cells to
	connect seamlessly, not independent per-node centers.
**/
class MazeGeometry {
	// Corridor width scales directly with this (fixed Maze.ROWS/COLS angular
	// resolution), so bumping it is what widens corridors without touching
	// maze complexity/topology at all — bumped from 50 to leave more
	// breathing room once walls gained real thickness (see MazeMesh) rather
	// than being paper-thin planes right at the cell boundary.

	/** Radius of the physical sphere the maze grid is mapped onto. **/
	public static inline final RADIUS:Float = 58;
}
