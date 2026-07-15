package maze;

/**
	The physical sphere the maze grid is mapped onto. `MazeMesh` derives its
	own corner positions directly from `Maze.ROWS`/`Maze.COLS` and this
	radius via `SphereMath`, rather than through a per-node lookup here —
	walls need shared *corner* points with their neighboring floor cells to
	connect seamlessly, not independent per-node centers.
**/
class MazeGeometry {
	/** Radius of the physical sphere the maze grid is mapped onto. **/
	public static inline final RADIUS:Float = 50;
}
