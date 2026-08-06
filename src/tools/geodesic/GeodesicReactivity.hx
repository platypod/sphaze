package tools.geodesic;

import biomes.common.maze.MazeEdges;
import biomes.common.maze.MazeTopology.MazeLayout;
import tools.geodesic.GeodesicSphere.GeodesicSphereData;

/** One reactive (non-core) edge, with its `MazeEdges.edgeKey` precomputed — see `GeodesicReactivity`'s own class doc for why these are held rather than re-derived each generation. **/
typedef ReactiveEdge = {
	var a:Int;
	var b:Int;
	var key:String;
}

/**
	Lets population activity erode and regrow the biome's non-core walls
	each generation — the node-id-keyed counterpart to
	`biomes.conway.ConwayMazeReactivity`, same two thresholds and the same
	guarantee: the spanning tree that `biomes.common.maze.MazeCarver`
	carved always stays open, so the maze can never be split into
	unreachable pieces no matter how the reactive edges move. Every other
	edge opens where nearby nodes have recently been flipping and closes
	back where they've gone quiet.

	Unlike `ConwayMazeReactivity` — which is a static class re-enumerating
	`ConwayMaze.allEdges()` and re-testing `isCore` on every single edge,
	every generation — this is an instance that resolves both *once* in its
	constructor and then only ever walks the reactive edges. On this sphere
	that's a real difference and not a micro-optimization: at frequency
	`11` there are `1212` nodes and `~3630` edges, of which `1211` (the
	spanning tree) are core and can never change, so per-generation work
	drops by a third before counting the `edgeKey` string concatenations
	that no longer happen at all.

	The core set is simply a snapshot of the carve's own output: a carver
	returns exactly a spanning tree, so "what was open when we started" and
	"the edges that guarantee connectivity" are the same set. That's why
	`GeodesicSphereData` needs no `coreEdges` field the way
	`biomes.conway.ConwayMaze.ConwayMazeData` carries one — the information
	is already in the layout at the moment of carving, it just has to be
	captured before anything is allowed to move.
**/
class GeodesicReactivity {
	/** A non-core edge opens once either endpoint's rolling activity reaches this. Ported from `biomes.conway.ConwayMazeReactivity.OPEN_THRESHOLD` rather than re-derived. **/
	static inline final OPEN_THRESHOLD:Float = 0.5;

	/** A non-core edge closes back once both endpoints' activity falls to this or below — kept well under `OPEN_THRESHOLD` so an edge doesn't flicker every generation. **/
	static inline final CLOSE_THRESHOLD:Float = 0.15;

	final reactiveEdges:Array<ReactiveEdge>;
	final reactiveKeys:haxe.ds.StringMap<Bool>;

	/**
		Captures `carved`'s own open edges as the permanent core, and
		precomputes every remaining edge as reactive.
		@param sphere the topology both the carve and the Life layer run on.
		@param carved the freshly carved layout — must be straight out of a carver, before any `step` has moved anything, or the core set will be wrong (see this class's own doc).
	**/
	public function new(sphere:GeodesicSphereData, carved:MazeLayout) {
		reactiveEdges = [];
		reactiveKeys = new haxe.ds.StringMap();
		var seen = new haxe.ds.StringMap<Bool>();
		for (a in 0...sphere.neighbors.length) {
			for (b in sphere.neighbors[a]) {
				var key = MazeEdges.edgeKey(Std.string(a), Std.string(b));
				if (seen.exists(key) || carved.openEdges.exists(key)) {
					continue; // already handled from the other end, or core and therefore never touched
				}
				seen.set(key, true);
				reactiveEdges.push({a: a, b: b, key: key});
				reactiveKeys.set(key, true);
			}
		}
	}

	/**
		Rebuilds a `GeodesicReactivity` from a previously-persisted core
		edge set — the counterpart to a fresh carve's own constructor call,
		for `GeodesicConwayBiome.restore`. A save doesn't have "the freshly
		carved layout" lying around (only whatever `layout.openEdges`
		happens to be after however many generations of reactive churn),
		so the core set has to be persisted on its own — this class's
		constructor already does exactly "capture what's open here as
		core," so reconstructing it is just handing it a synthetic layout
		with *only* the core edges open, same as a fresh carve would
		produce.
		@param sphere the topology to reconstruct against.
		@param coreKeys `MazeEdges.edgeKey`-formatted core edges, as returned by a prior `coreEdgeKeys()`.
		@return a `GeodesicReactivity` with exactly that core set.
	**/
	public static function fromCoreKeys(sphere:GeodesicSphereData, coreKeys:Array<String>):GeodesicReactivity {
		var coreOnly:MazeLayout = {openEdges: new haxe.ds.StringMap()};
		for (key in coreKeys) {
			coreOnly.openEdges.set(key, true);
		}
		return new GeodesicReactivity(sphere, coreOnly);
	}

	/** How many edges this instance can actually move — the rest are core. Mainly for tests and for confirming the core/reactive split came out as expected. **/
	public function reactiveEdgeCount():Int {
		return reactiveEdges.length;
	}

	/**
		Every core edge's own `MazeEdges.edgeKey` — the save-format
		counterpart to `reactiveEdgeCount`'s introspection, since a save
		needs the actual keys, not just a count. Recomputed from
		`sphere.neighbors` rather than cached at construction (this is only
		ever called once per save, not once per generation, so there's no
		reason to spend memory keeping a second copy of information
		`reactiveKeys` already determines).
		@param sphere the same topology this instance was built against.
		@return every core edge's own key.
	**/
	public function coreEdgeKeys(sphere:GeodesicSphereData):Array<String> {
		var keys:Array<String> = [];
		var seen = new haxe.ds.StringMap<Bool>();
		for (a in 0...sphere.neighbors.length) {
			for (b in sphere.neighbors[a]) {
				var key = MazeEdges.edgeKey(Std.string(a), Std.string(b));
				if (seen.exists(key)) {
					continue;
				}
				seen.set(key, true);
				if (!reactiveKeys.exists(key)) {
					keys.push(key);
				}
			}
		}
		return keys;
	}

	/**
		Whether the edge between `a` and `b` is part of the permanent
		spanning tree — never touched by `step`, and (unlike a reactive
		edge, whether open or closed) never worth drawing a wall panel for
		at all, the same distinction `biomes.conway.ConwayMesh.addEdge`
		makes via `ConwayMaze.isCore`.
		@param a one endpoint's node id.
		@param b the other endpoint's node id.
		@return `true` if this edge is core (bare corridor, always open).
	**/
	public function isCore(a:Int, b:Int):Bool {
		return !reactiveKeys.exists(MazeEdges.edgeKey(Std.string(a), Std.string(b)));
	}

	/**
		Reacts one generation's worth of Life activity into the maze's
		non-core edges. Call once per `GeodesicLifeState.step`, same cadence
		as the Life layer itself.

		Takes an edge's own activity directly (`(a, b) -> Float`) rather
		than a per-node reading this class combines itself — deliberately
		generalized past that (2026-08-06), once `GeodesicCoarseMaze`'s own
		first cut (per-*node* activity, an edge just taking the max of its
		two endpoints) measured out badly in the real biome: two coarse
		nodes' own whole regions is a much bigger, noisier sample than the
		one specific boundary between them. This class no longer assumes
		how an edge's activity was derived — `edgeActivity` below is still
		there as the "max of two node readings" convenience for callers
		that genuinely want that (a single sphere with no coarse layer in
		between), but it's the caller's own choice now, not baked in here.
		@param layout the layout to mutate — only this instance's own reactive edges are ever touched.
		@param edgeActivityOf an edge's own current activity, addressed by its two node ids — `GeodesicCoarseMaze.boundaryActivity`'s own output for the coarse-maze case; `(a, b) -> edgeActivity(state.activityOf, a, b)` (or an equivalent lambda) when node and edge activity are the same Life layer directly.
		@param playerNode the node the player currently occupies, or `-1` for none — its edges are never closed, so a wall can't arrive on a stationary player.
	**/
	public function step(layout:MazeLayout, edgeActivityOf:(Int, Int) -> Float, playerNode:Int):Void {
		for (edge in reactiveEdges) {
			var activity = edgeActivityOf(edge.a, edge.b);
			var isOpen = layout.openEdges.exists(edge.key);
			if (!isOpen && activity >= OPEN_THRESHOLD) {
				layout.openEdges.set(edge.key, true);
			} else if (isOpen && activity <= CLOSE_THRESHOLD && edge.a != playerNode && edge.b != playerNode) {
				layout.openEdges.remove(edge.key);
			}
		}
	}

	/**
		An edge's own activity as the hotter of its two *node* readings —
		the convenience this class's own `step` used to bake in
		unconditionally, kept as an opt-in helper for a caller that
		genuinely wants that (a single sphere, no coarse layer in
		between). A wall's own glow should be driven off the exact same
		reading that decided whether to open or close it, not a second one
		that can drift out of step with it, so this is the one place that
		combination happens — both `step` and rendering should go through
		it (or an equivalent), not two independent copies of "max the
		endpoints" that could disagree.
		@param activityOf a node's own current activity.
		@param a one endpoint's node id.
		@param b the other endpoint's node id.
		@return the higher of the two endpoints' rolling activity.
	**/
	public static function edgeActivity(activityOf:Int->Float, a:Int, b:Int):Float {
		return Math.max(activityOf(a), activityOf(b));
	}
}
