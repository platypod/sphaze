package maze;

/**
	The physical sphere the maze grid is mapped onto. `MazeMesh` derives its
	own corner positions directly from `Maze.ROWS`/`Maze.COLS` and this
	radius via `SphereMath`, rather than through a per-node lookup here —
	walls need shared *corner* points with their neighboring floor cells to
	connect seamlessly, not independent per-node centers.
**/
class MazeGeometry {
	// Corridor width scales directly with this at a *fixed* Maze.ROWS/COLS —
	// bumping RADIUS alone widens corridors by roughly the same factor as
	// the sphere itself grows, no more. Bumped 58->87 (1.5x) for a bigger
	// sphere; Maze.ROWS/COLS were *also* dropped 16/32->14/28 in the same
	// change specifically to widen corridors further on top of that, to
	// about 2x their old width — reducing the grid resolution independently
	// of RADIUS is the only way to decouple "how big is the sphere" from
	// "how much space is between its walls", since a wall is nothing more
	// than a cell boundary at this resolution. That's also why it's a
	// visibly sparser maze now (~25% fewer cells) rather than just a scaled
	// up copy of the old one.

	/** Radius of the physical sphere the maze grid is mapped onto. **/
	public static inline final RADIUS:Float = 87;

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
