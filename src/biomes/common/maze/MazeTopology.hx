package biomes.common.maze;

/**
	Which of a grid-like topology's two axes an edge runs along — what
	`MazeStyle.AxisBiased` weights its choices by, and the only structural
	thing the generic carvers know about an edge beyond its two endpoints.

	`Irregular` covers an edge that is neither: today, any edge onto a merged
	pole node, where "east-west" and "north-south" stop meaning anything
	(every column converges there). A topology with no meaningful axes at all
	— a future great-circle or lattice one — can answer `Irregular` for
	everything, which leaves `AxisBiased` behaving exactly like plain
	`RandomizedDfs` there rather than silently doing something arbitrary.
**/
enum EdgeAxis {
	/** East-west: within one row, around the sphere. **/
	AlongRow;

	/** North-south: across a row boundary, pole to pole. **/
	AcrossRow;

	/** Neither — see this enum's own doc. **/
	Irregular;
}

/** A node's position on a `RectangularTopology`. **/
typedef GridCoords = {row:Int, col:Int};

/**
	Which edges of a maze are open passages — the carvers' own output, and
	structurally the same shape as every biome's own layout typedef
	(`biomes.common.grid.GridModel.GridData`,
	`biomes.conway.ConwayMaze.ConwayMazeData`), so a carved layout is
	assignable straight to either with no conversion. Keys are
	`MazeEdges.edgeKey`-formatted, which is deliberately the same format
	`GridModel.edgeKey` has always produced — a maze exported before this
	package existed still deserializes.
**/
typedef MazeLayout = {
	var openEdges:haxe.ds.StringMap<Bool>;
}

/**
	The seam that makes maze *generation* independent of the surface it
	happens on: a graph of nodes identified by opaque string keys, plus the
	axis of each edge. Every algorithm in this package works through this
	alone, so a style written once applies to the sphere grid, the Conway
	grid, and whatever topology comes next — which is the whole point, since
	the randomized-DFS carve was previously copy-pasted per topology
	(`biomes.maze.MazeGenerator` and `biomes.conway.ConwayMaze` held the same
	loop twice).

	String keys rather than a type parameter: Haxe enums don't structurally
	hash, so both existing topologies *already* reduce their nodes to string
	keys to get set/map semantics (see `GridModel.nodeKey`). Generic carvers
	need exactly those semantics and nothing else, so the key is the honest
	interface — and it keeps `MazeLayout` a plain serializable map instead of
	something parameterized over a node type.
**/
interface MazeTopology {
	/**
		Every node on this topology. Order is significant only in that the
		carvers start from the first element (same as the algorithm this
		package was extracted from).
		@return every node's key.
	**/
	function nodeKeys():Array<String>;

	/**
		Every node adjacent to `nodeKey`, whether or not a carved layout has
		opened the edge between them.
		@param nodeKey the node to find neighbors of.
		@return the adjacent nodes' keys.
	**/
	function neighborsOf(nodeKey:String):Array<String>;

	/**
		Which axis the edge between two adjacent nodes runs along.
		@param a one endpoint's key.
		@param b the other endpoint's key.
		@return that edge's axis.
	**/
	function axisOf(a:String, b:String):EdgeAxis;
}

/**
	A `MazeTopology` whose ring nodes also form a row/column rectangle —
	cylindrical, in practice: columns wrap around the sphere, rows don't, and
	a row's column count may vary (see
	`biomes.common.grid.GridModel.colsForRow`). What `MazeStyle.RecursiveDivision`
	needs, since dividing a region into sub-regions is meaningless on an
	arbitrary graph; every other style works on the plain `MazeTopology`
	above.

	Nodes outside the rectangle (the merged poles) are reachable through
	`neighborsOf` but have no coordinates — `coordsOf` answers null for them,
	and `RecursiveDivision` handles them explicitly rather than pretending
	they're cells.
**/
interface RectangularTopology extends MazeTopology {
	/** @return how many ring rows this topology has (rows are numbered `0...rowCount()`, poles excluded). **/
	function rowCount():Int;

	/**
		@param row the ring row, in `0...rowCount()`.
		@return that row's own column count.
	**/
	function colsInRow(row:Int):Int;

	/**
		@param row the ring row, in `0...rowCount()`.
		@param col the column, in `0...colsInRow(row)`.
		@return that cell's node key.
	**/
	function keyOf(row:Int, col:Int):String;

	/**
		@param nodeKey the node to locate.
		@return `nodeKey`'s row/column, or null if it isn't a ring cell (a merged pole).
	**/
	function coordsOf(nodeKey:String):Null<GridCoords>;

	/**
		Every node that isn't a ring cell but still needs connecting — the
		merged poles. Kept explicit (rather than left for `RecursiveDivision`
		to find by elimination) because how they attach is a topology's own
		business: a pole neighbors an entire row, so opening every one of
		those edges would carve a wide-open cap instead of a passage.
		@return the non-rectangular nodes' keys.
	**/
	function nonRectangularNodes():Array<String>;
}
