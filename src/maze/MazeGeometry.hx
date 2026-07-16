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

	/**
		How far a wall's inner face sits from the true cell boundary (see
		`MazeMesh.innerCornersOf`) — each cell's own contribution to a shared
		wall's total thickness. Lives here rather than in `MazeMesh` because
		`game.Collision` needs the exact same value to block movement at the
		wall's actual visible face (`Maze.wallZoneNeighbor`) instead of the
		old zero-thickness boundary line the wall no longer sits on.
	**/
	public static inline final WALL_THICKNESS:Float = 1.5;

	/**
		Extra buffer `Maze.wallZoneNeighbor` adds on top of `WALL_THICKNESS`
		when blocking movement — purely a collision-side margin, not a
		render one. `MazeMesh` still builds the wall's visible face exactly
		`WALL_THICKNESS` in from the cell boundary; this keeps the *player*
		(and so the camera, which sits close to `pos`) stopped a bit short
		of that face instead of flush against it, since standing exactly at
		a thin wall's surface let the camera's corners catch glimpses past
		it — most noticeably while pitched up toward it.
	**/
	public static inline final COLLISION_CLEARANCE:Float = 1;
}
