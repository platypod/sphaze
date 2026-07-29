package biomes.common.maze;

/**
	Which algorithm carves a maze — the knob that makes two biomes on the
	same grid feel like different places without touching geometry,
	rendering, or collision. Each style has a recognizable signature in play,
	which is the actual reason this enum exists (see
	`docs/game-design/inspirations.md` on identity coming from restriction):

	- `RandomizedDfs` — long snaking corridors, few branches, low dead-end
	  density. The original (and default) carve: what every existing maze in
	  the game is.
	- `RandomizedPrim` — spongy and bushy: many short dead-ends off a
	  compact trunk. Punishes committing to a direction, rewards surveying
	  from across the sphere before walking.
	- `RandomizedKruskal` — similar dead-end density to Prim but with no
	  growth bias at all (it carves everywhere at once rather than outward
	  from one seed), so it reads as uniformly textured with no "centre".
	- `AxisBiased` — a DFS that prefers one axis, so corridors tend to
	  *circle* the sphere (`alongRowWeight` above 1) or run *pole to pole*
	  (below 1). One float, and the journey's whole shape changes.
	- `RecursiveDivision` — rooms and halls rather than corridors, since it
	  works by adding walls to open space instead of carving passages
	  through solid. The mansion-feeling generator.

	Braiding isn't a style: it's a post-pass that applies to any of them
	(see `MazeBraider`), so it's a separate parameter rather than a
	constructor here.
**/
enum MazeStyle {
	/** Randomized depth-first search. **/
	RandomizedDfs;

	/** Randomized Prim: grow a tree by repeatedly carving a random frontier edge. **/
	RandomizedPrim;

	/** Randomized Kruskal: shuffle every edge, carve the ones that join two separate components. **/
	RandomizedKruskal;

	/**
		Randomized DFS weighting `EdgeAxis.AlongRow` neighbors by
		`alongRowWeight` against `EdgeAxis.AcrossRow`/`EdgeAxis.Irregular`
		neighbors at weight 1. Above 1 favors east-west corridors, below 1
		favors north-south ones; exactly 1 is `RandomizedDfs` with extra
		steps. Must be positive.
	**/
	AxisBiased(alongRowWeight:Float);

	/**
		Recursive division — requires a `RectangularTopology` (dividing a
		region in two is meaningless on an arbitrary graph), and throws if
		handed anything else rather than silently falling back to another
		style.
	**/
	RecursiveDivision;
}
