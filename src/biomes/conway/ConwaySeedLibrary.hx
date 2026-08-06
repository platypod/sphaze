package biomes.conway;

/**
	Small library of classic Life patterns `ConwayState` periodically stamps
	onto the board (see `ConwayState.STRUCTURE_SPAWN_RATE`) so a generation
	keeps producing fresh movement and long chaotic runs instead of settling
	into whatever the initial soup plus per-cell mutation alone produces.
	Each pattern is its own canonical shape as `(row, col)` offsets from a
	`(0, 0)` top-left corner; `rotated` turns any of them 0/90/180/270
	degrees so a spawn doesn't always travel or unfold the same direction.

	Picked for what each contributes, not for variety's own sake:
	- `GLIDER`/`LWSS` are the classic *moving* patterns — actual travel
	  across the board, not just flicker in place.
	- `R_PENTOMINO`/`ACORN` are the two best-known *methuselahs*: tiny seeds
	  that churn chaotically for hundreds of generations (1103 and 5206 in
	  unrestricted Life) before settling — "structures that live longer."

	A literal glider *gun* (the Game of Life term for a pattern that emits
	gliders forever, which is the more literal reading of "more
	generators") was considered and dropped: `ConwayGrid.liveNeighborCount`
	gates every influence, including orthogonal, through the maze's own
	open edges (`ConwayMaze.isOpen`). A gun's ~36x9 footprint needs every
	one of its internal cells' neighbor counts exactly right, every
	generation, forever; the maze under any given spawn is random, so some
	closed edge inside that footprint is all but certain, and the gun
	fizzles within a handful of generations instead of ever firing. These
	four patterns are far more robust to a stray closed edge nearby — a
	glider deflecting or a methuselah's chaos reading differently near a
	wall is *more* interesting under this biome's own rules, not a bug the
	way a gun silently failing to gun would be.
**/
class ConwaySeedLibrary {
	public static final GLIDER:Array<{row:Int, col:Int}> = [
		{row: 0, col: 1},
		{row: 1, col: 2},
		{row: 2, col: 0},
		{row: 2, col: 1},
		{row: 2, col: 2},
	];

	public static final LWSS:Array<{row:Int, col:Int}> = [
		{row: 0, col: 1},
		{row: 0, col: 2},
		{row: 0, col: 3},
		{row: 0, col: 4},
		{row: 1, col: 0},
		{row: 1, col: 4},
		{row: 2, col: 4},
		{row: 3, col: 0},
		{row: 3, col: 3},
	];

	public static final R_PENTOMINO:Array<{row:Int, col:Int}> = [
		{row: 0, col: 1},
		{row: 0, col: 2},
		{row: 1, col: 0},
		{row: 1, col: 1},
		{row: 2, col: 1},
	];

	public static final ACORN:Array<{row:Int, col:Int}> = [
		{row: 0, col: 1},
		{row: 1, col: 3},
		{row: 2, col: 0},
		{row: 2, col: 1},
		{row: 2, col: 4},
		{row: 2, col: 5},
		{row: 2, col: 6},
	];

	/** Every pattern above, in the order `ConwayState.spawnStructure` picks from by index. **/
	public static final ALL:Array<Array<{row:Int, col:Int}>> = [GLIDER, LWSS, R_PENTOMINO, ACORN];

	/**
		`pattern` rotated 90 degrees clockwise `turns` times around its own
		bounding box, re-normalized so its own top-left corner sits back at
		`(0, 0)`.
		@param pattern the pattern to rotate, as `(row, col)` offsets.
		@param turns how many 90-degree clockwise turns to apply — taken mod 4, so any `Int` is valid.
		@return the rotated pattern.
	**/
	public static function rotated(pattern:Array<{row:Int, col:Int}>, turns:Int):Array<{row:Int, col:Int}> {
		var cells = pattern;
		var normalizedTurns = ((turns % 4) + 4) % 4;
		for (_ in 0...normalizedTurns) {
			var height = boundingHeight(cells);
			cells = [for (cell in cells) {row: cell.col, col: height - 1 - cell.row}];
		}
		return cells;
	}

	static function boundingHeight(cells:Array<{row:Int, col:Int}>):Int {
		var height = 0;
		for (cell in cells) {
			if (cell.row + 1 > height) {
				height = cell.row + 1;
			}
		}
		return height;
	}
}
