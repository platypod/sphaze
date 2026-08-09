package tools.geodesic;

import biomes.common.maze.MazeEdges;
import biomes.common.maze.MazeTopology.MazeLayout;
import tools.geodesic.GeodesicSphere.GeodesicSphereData;
import tools.geodesic.GeodesicWallSimplifier.WallSegment;

/**
	Ties a fine sphere (rendered floor, Life simulation) to a coarser one
	(the maze itself — carving, collision, reactivity) — the mechanism
	behind wall straightening's second attempt (2026-08-06), after the
	first one (`GeodesicWallSimplifier`, merging geometry after the fact)
	was retracted for breaking the correspondence between what a player
	sees and what actually blocks them.

	This attempt doesn't merge anything. It changes what the maze graph
	*is* instead: build it on a coarser `GeodesicSphere.generate` call
	(a handful of fine cells per coarse region — `fineToCoarse` is the
	assignment), and let `GeodesicCollision`/`GeodesicReactivity`/
	`MazeCarver` all run on *that* graph, addressed by coarse node ids.
	The rendered wall panel for a fine edge that happens to cross a coarse
	boundary still uses that fine edge's own real geometry
	(`GeodesicDual.sharedEdge` on the fine sphere) — visual detail is
	unchanged — but its open/closed/ghost *state* comes from the one
	coarse edge the whole boundary shares. Wall and collision boundary are
	the same object again, at coarse granularity, without approximating
	either one to match the other.

	One geometric fact this leans on, checked empirically rather than
	assumed: two fine cells on either side of a coarse boundary are always
	assigned to *adjacent* coarse regions, never ones two hops apart.
	Verified with a standalone script across several fine/coarse frequency
	pairings (frequency `11`/`4`, `11`/`5`, `10`/`3`) — zero violations in
	every case, out of `1100`-`2000` boundary edges each. Not a proof for
	every possible pairing, but strong enough evidence to build on rather
	than guard against a failure mode that's never actually been observed.

	Also true for free, not engineered: both spheres subdivide the exact
	same 12 `Icosahedron.VERTICES`, so the coarse sphere's own 12
	pentagons and the fine sphere's own 12 pentagons are the literal same
	12 points in space, at any frequency pairing.

	**Reactive activity is per coarse *edge*, not per coarse node
	(2026-08-06).** See `boundaryActivity`'s own doc for the full story —
	the first version aggregated per node (hottest fine cell anywhere in
	the region) and, played for real, opened far too much of the maze.

	**Reactive activity is binary, not decaying (2026-08-06, same day).**
	`boundaryActivity` now opens a wall only while both of a fine edge's
	own two adjacent cells are alive, closing the instant either one
	isn't — no more lingering open on decayed recency. See that function's
	own doc for the full three-version history.
**/
class GeodesicCoarseMaze {
	/**
		Which coarse node owns each fine node — nearest coarse node to that
		fine node's own baked position, via the same lookup machinery
		`GeodesicLookup` already provides for turning an arbitrary point
		into a node id.
		@param fineSphere the sphere being assigned.
		@param coarseLookup a lookup built over the coarse sphere to assign onto.
		@return one coarse node id per fine node, indexed the same way `fineSphere.positions`/`neighbors` are.
	**/
	public static function fineToCoarse(fineSphere:GeodesicSphereData, coarseLookup:GeodesicLookup):Array<Int> {
		return [
			for (id in 0...fineSphere.neighbors.length)
				coarseLookup.nodeAt(fineSphere.positions[id])
		];
	}

	/**
		Every fine edge that crosses from one coarse region into another —
		the set of edges that actually need a wall panel drawn for them.
		A fine edge whose two endpoints share a coarse region is never a
		wall at all, whatever the coarse maze does: the player can freely
		cross it, since there's no coarse edge for it to correspond to.
		@param fineSphere the sphere the boundary is traced over.
		@param fineToCoarseMap `fineToCoarse`'s own output.
		@return every crossing fine edge, each once.
	**/
	public static function boundaryEdges(fineSphere:GeodesicSphereData, fineToCoarseMap:Array<Int>):Array<{a:Int, b:Int}> {
		var edges:Array<{a:Int, b:Int}> = [];
		for (a in 0...fineSphere.neighbors.length) {
			for (b in fineSphere.neighbors[a]) {
				if (b <= a || fineToCoarseMap[a] == fineToCoarseMap[b]) {
					continue;
				}
				edges.push({a: a, b: b});
			}
		}
		return edges;
	}

	/**
		A coarse *edge's* own activity, straight from the fine cells that
		actually sit on that specific boundary — not the whole region
		either endpoint belongs to. The first version of this class
		aggregated per coarse *node* instead (hottest fine cell anywhere
		in the whole region), which measured out badly once played for
		real: a region's own hottest-of-~5 reads hot `24`-`38%` of the
		time against any single fine cell's own `7`-`10%`, and a coarse
		*edge's* own activity then took the max of *two* such regions —
		effectively sampling ~10 fine cells for one edge's decision,
		against the ~2 the original per-edge fine system watched. Measured
		result: `89%` of reactive coarse edges open within 10 generations,
		settling near `49%`, against the fine system's own settled
		`3`-`7%` — "too many walls disappear," reported directly.

		The second version (per coarse *edge*, still a decaying-activity
		max) only ever looked at the fine cells that are actual endpoints
		of a `boundaryEdges` crossing between exactly this coarse edge's
		own two regions. Closer to the original design, but still let a
		wall stay open on lingering recency after the cells that opened it
		had already died — reported directly as "I'd like the wall to
		close faster."

		**Third version (2026-08-06): binary, not decaying.** A wall's own
		two adjacent cells are literally `edge.a`/`edge.b` — every fine
		edge is exactly one of a hexagon's (or pentagon's) six sides, with
		exactly two cells touching it. This returns `1.0` the moment
		*both* of a crossing's own two cells are alive (`isAlive`, not
		`activityOf`'s rolling recency), `0.0` otherwise — no decay, so a
		coarse edge closes the very next generation either of its own
		crossing cells dies, not whenever recency finally erodes below
		`GeodesicReactivity.CLOSE_THRESHOLD`. A coarse edge is a bundle of
		several fine crossings (measured: `4`-`5` per edge), so this is an
		*or* across them — any one crossing with both cells alive is
		enough to hold that edge open, matching how a single fine wall
		already worked before the coarse maze existed at all.
		@param fineState the Ventrella layer, fine-keyed.
		@param boundaryEdges `boundaryEdges`'s own output.
		@param fineToCoarseMap `fineToCoarse`'s own output.
		@return a coarse edge's own activity, as a function of its two node ids — `1.0` if any of its crossings has both fine endpoints alive, `0.0` otherwise (including a pair with no boundary crossing between them at all).
	**/
	public static function boundaryActivity(fineState:GeodesicVentrellaState, boundaryEdges:Array<{a:Int, b:Int}>,
			fineToCoarseMap:Array<Int>):(Int, Int) -> Float {
		var byEdge = new haxe.ds.StringMap<Bool>();
		for (edge in boundaryEdges) {
			var coarseA = fineToCoarseMap[edge.a];
			var coarseB = fineToCoarseMap[edge.b];
			var key = MazeEdges.edgeKey(Std.string(coarseA), Std.string(coarseB));
			var bothAlive = fineState.isAlive(edge.a) && fineState.isAlive(edge.b);
			var alreadyHot = byEdge.exists(key) && byEdge.get(key);
			byEdge.set(key, alreadyHot || bothAlive);
		}
		return (a, b) -> {
			var key = MazeEdges.edgeKey(Std.string(a), Std.string(b));
			return byEdge.exists(key) && byEdge.get(key) ? 1.0 : 0.0;
		};
	}

	/**
		Every boundary edge's own drawable wall, sorted into the same
		wall/ghost split `GeodesicMesh.build` uses on a single sphere —
		geometry from the fine edge (`GeodesicDual.sharedEdge`), state
		from whichever *coarse* edge the whole boundary shares. Shared by
		`GeodesicPreview` and `GeodesicConwayBiome` so the two don't grow
		two copies of this classification to drift apart — this class
		stays Heaps-free (plain `WallSegment` data out), so a caller still
		does its own `GeodesicMesh.buildWallMesh` for the actual meshes.
		@param fineSphere the sphere the wall geometry is traced over.
		@param fineBoundaries `GeodesicDual.cellBoundaries(fineSphere)`.
		@param boundaryEdges `boundaryEdges`'s own output.
		@param fineToCoarseMap `fineToCoarse`'s own output.
		@param coarseLayout the maze — coarse node ids.
		@param coarseReactivity the same instance driving `coarseLayout`'s own open/close.
		@param edgeActivityOf a coarse edge's own current activity — `boundaryActivity`'s own output, so a wall's own glow is driven by the exact same reading that decided whether to open or close it, not a second one that can drift out of step with it.
		@return the solid-wall and ghost-wall segments, ready for `GeodesicMesh.buildWallMesh`.
	**/
	public static function wallSegments(fineSphere:GeodesicSphereData, fineBoundaries:Array<Array<Vec3>>, boundaryEdges:Array<{a:Int, b:Int}>,
			fineToCoarseMap:Array<Int>, coarseLayout:MazeLayout, coarseReactivity:GeodesicReactivity,
			edgeActivityOf:(Int, Int) -> Float):{walls:Array<WallSegment>, ghosts:Array<WallSegment>} {
		var walls:Array<WallSegment> = [];
		var ghosts:Array<WallSegment> = [];
		for (edge in boundaryEdges) {
			var coarseA = fineToCoarseMap[edge.a];
			var coarseB = fineToCoarseMap[edge.b];
			var geometry = GeodesicDual.sharedEdge(fineSphere, fineBoundaries, edge.a, edge.b);
			var activity = edgeActivityOf(coarseA, coarseB);
			var coarseAKey = Std.string(coarseA);
			var coarseBKey = Std.string(coarseB);
			if (!MazeEdges.isOpen(coarseLayout, coarseAKey, coarseBKey)) {
				walls.push({a: geometry.a, b: geometry.b, activity: activity});
			} else if (!coarseReactivity.isCore(coarseA, coarseB)) {
				ghosts.push({a: geometry.a, b: geometry.b, activity: activity});
			}
		}
		return {walls: walls, ghosts: ghosts};
	}

	/**
		A `(layout, reactivity)` pair with every fine edge open and every
		fine edge core — the exact state a topology has right after
		`MazeCarver.carve` if the carve opened literally everything. Fed
		to `GeodesicMesh.build` so it draws floor and blocks only: its own
		`collectEdge` only ever adds to the wall/ghost buckets when an edge
		is closed, or open-and-non-core, and with this pair neither is
		ever true. The maze itself is drawn separately, by `wallSegments`.
		@param fineSphere the sphere to build the no-op pair against.
		@return a layout/reactivity pair that never contributes a wall.
	**/
	public static function noOpFineMazeLayer(fineSphere:GeodesicSphereData):{layout:MazeLayout, reactivity:GeodesicReactivity} {
		var layout:MazeLayout = {openEdges: new haxe.ds.StringMap()};
		for (id in 0...fineSphere.neighbors.length) {
			for (neighbor in fineSphere.neighbors[id]) {
				MazeEdges.open(layout, Std.string(id), Std.string(neighbor));
			}
		}
		return {layout: layout, reactivity: new GeodesicReactivity(fineSphere, layout)};
	}
}
