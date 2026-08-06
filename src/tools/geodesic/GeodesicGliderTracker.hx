package tools.geodesic;

import tools.geodesic.GeodesicSphere.GeodesicSphereData;

/**
	Spawn points, not glider guns (2026-08-06). Seeds a real, confirmed
	traveling spaceship (`GeodesicGliderPatterns.placeKnownSpaceship` —
	Catagolue's `xq14_0ig5l3z102`, verified on this exact mesh by
	`GeodesicGliderPort`'s own headless probe: 8 clean periods of genuine
	net travel before it reaches a pentagon) next to each of a few chosen
	anchors, then follows it generation to generation so
	`GeodesicConwayBiome.rebuildMesh` can draw it in
	`Colours.CONWAY_TILE_GLIDER` instead of the ordinary live-cell green.

	**Superseded here, not on record as wrong: the earlier `B2/S34` 1-ring
	patterns.** `GeodesicGliderSearch`'s own exhaustive 1-ring search found
	24 translating patterns, but `GeodesicGliderTrajectory`'s long-run
	follow-up showed every one of them is a *bounded shuttle* — real
	movement between two consecutive periods, but no actual net travel over
	thousands of generations. Reading web research on hexagonal
	Life-like automata turned up a real spaceship already confirmed for
	this exact rule by a massive external distributed search; porting it
	here (`GeodesicGliderPatterns`'s own doc has the coordinate-convention
	story) is what actually delivered "gliders gliding," not a bigger local
	search.

	**A true glider gun — a structure that emits gliders on its own,
	forever, the way Conway's Gosper gun does — is still not what this is.**
	This class re-seeds by timer instead — a scripted stand-in, not an
	emergent one. See `docs/game-design/ideas-backlog.md`'s own entry.

	**Anchors need real clearance from a pentagon, not proximity to one.**
	`placeKnownSpaceship`'s own walk can reach 6 hex-steps out from its
	anchor, so a site sitting right next to a pentagon (the old shuttle
	design's own placement, since a shuttle never went anywhere) would
	regularly fail to place at all. `MIN_PENTAGON_CLEARANCE` keeps sites
	planted in open hex territory instead — still visually pentagon-
	adjacent in spirit (a few hops off, not clear across the sphere), but
	reliably placeable.

	**Spawns once per site, not on a repeating clock**, and only respawns
	after tracking is actually lost (soup crossed its path, or — the
	expected, common case for a pattern that travels a real distance — it
	reached a pentagon and dissolved into a small residual structure) and
	`RESPAWN_COOLDOWN` generations have passed since. A placement failure
	(rare, given the clearance requirement, but not impossible depending on
	which of the anchor's six directions the walk happens to take) is
	treated the same way — retry after the cooldown rather than every tick.

	**Tracking a glider once it's alive** gathers every currently live cell
	within `TRACK_RADIUS` hops of its last known cells
	(`GeodesicShapeSignature.multiSourceBfs`), and accepts that set as its
	new position as long as *something* is still there and it hasn't grown
	past `MAX_TRACKED_POPULATION` — not an exact population/shape match,
	see `relocateActive`'s own doc for why that was tried first and broke.
	A miss gets `MISS_GRACE` generations of benefit of the doubt before the
	tracker gives up — the glider (or whatever it dissolved into) quietly
	rejoins the ordinary live-cell rendering, still simulated, just no
	longer drawn specially.

	Not persisted across `GeodesicConwayBiome.serialize`/`restore` — a save
	just resumes with every current glider untracked until its site's next
	spawn. Losing a visual overlay across a save is a fair trade against
	carrying tracker state through the save format; revisit only if that
	actually reads as jarring in play.
**/
class GeodesicGliderTracker {
	/** How many generator sites — a few, not many, so most of the sphere still reads as open territory rather than every corner doing something. **/
	static inline final GENERATOR_SITE_COUNT:Int = 3;

	/** BFS hops a site's own anchor must sit from the nearest pentagon — enough that `GeodesicGliderPatterns.placeKnownSpaceship`'s own up-to-6-hex-step walk reliably has room, without needing every attempt to succeed. **/
	static inline final MIN_PENTAGON_CLEARANCE:Int = 4;

	/** Generations a site waits after losing its glider (or failing to place one) before trying again — long enough that whatever ended the last one (soup, a pentagon interaction) has had time to clear. **/
	static inline final RESPAWN_COOLDOWN:Int = 40;

	/** How far (BFS hops) to look for a tracked glider's own next position — a Life birth can only ever occur adjacent to an already-live cell, so this only needs to comfortably clear one generation's own worth of movement. **/
	static inline final TRACK_RADIUS:Int = 2;

	/** Generations a glider is allowed to go unmatched before tracking gives up on it. **/
	static inline final MISS_GRACE:Int = 2;

	/** A tracked blob larger than this is soup, or two gliders having genuinely collided — either way not one legible glider to keep drawing specially. Well above `xq14_0ig5l3z102`'s own 10-12 cell range, so its normal breathing never trips this. **/
	static inline final MAX_TRACKED_POPULATION:Int = 30;

	/** Larger than any `RESPAWN_COOLDOWN`-scale generation count actually reached — stands in for "not due," since a site with an active, still-tracked glider shouldn't spawn again at all. **/
	static inline final INFINITE_GENERATION:Int = 0x7FFFFFFF;

	final sphere:GeodesicSphereData;
	final sites:Array<GeneratorSite>;
	var active:Array<ActiveGlider> = [];
	var generation:Int = 0;

	public function new(sphere:GeodesicSphereData) {
		this.sphere = sphere;
		this.sites = buildSites(sphere);
	}

	/** Call once per `GeodesicLifeState.step` — spawns whichever sites are due (freshly built, or recovering from a lost/failed glider), then re-locates every glider already being tracked. **/
	public function tick(state:GeodesicLifeState):Void {
		generation++;
		for (site in sites) {
			if (site.dueAtGeneration <= generation) {
				if (spawn(state, site)) {
					site.dueAtGeneration = INFINITE_GENERATION; // not due again until relocateActive schedules a real cooldown
				} else {
					site.dueAtGeneration = generation + RESPAWN_COOLDOWN; // placement failed (rare) — try again later rather than every tick
				}
			}
		}
		relocateActive(state);
	}

	/** Every currently-tracked glider's own live cell ids, flattened — `GeodesicMesh.build`'s own glider-color routing reads this. **/
	public function trackedCellIds():Array<Int> {
		var ids:Array<Int> = [];
		for (glider in active) {
			for (id in glider.cells) {
				ids.push(id);
			}
		}
		return ids;
	}

	function spawn(state:GeodesicLifeState, site:GeneratorSite):Bool {
		var cells = GeodesicGliderPatterns.placeKnownSpaceship(sphere, site.anchor);
		if (cells == null) {
			return false;
		}
		for (id in cells) {
			state.seedSingle(id);
		}
		active.push({cells: cells, missed: 0, site: site});
		return true;
	}

	/**
		Whatever's alive within `TRACK_RADIUS` of a glider's last known
		cells becomes its new position, as long as there's still something
		there and it hasn't ballooned past `MAX_TRACKED_POPULATION` — not an
		exact population/shape match. `xq14_0ig5l3z102` itself breathes
		between `10` and `12` live cells across its own 14-generation period
		(`GeodesicBiomeReplay`'s own probe: `12, 10, 12, 11, 12, 12, 12, 12,
		10, ...`), so pinning tracking to the population captured at spawn
		time dropped it within a handful of generations, every time — the
		bug this replaced (found from a played screenshot: nothing ever
		rendered amber, because tracking silently died right after every
		single spawn, `GeodesicBiomeReplay`'s own headless replay of the
		exact same setup confirmed `tracked=0` from generation 5 onward).
	**/
	function relocateActive(state:GeodesicLifeState):Void {
		var stillTracked:Array<ActiveGlider> = [];
		for (glider in active) {
			var nearby = aliveWithin(sphere, state, glider.cells, TRACK_RADIUS);
			if (nearby.length > 0 && nearby.length <= MAX_TRACKED_POPULATION) {
				glider.cells = nearby;
				glider.missed = 0;
				stillTracked.push(glider);
			} else if (glider.missed < MISS_GRACE) {
				glider.missed++;
				stillTracked.push(glider); // keep its last known cells lit for a couple more generations rather than dropping on the first miss
			} else {
				glider.site.dueAtGeneration = generation +
					RESPAWN_COOLDOWN; // lost for good (commonly: it reached a pentagon, or grew past MAX_TRACKED_POPULATION) — let its site try again once things settle
			}
		}
		active = stillTracked;
	}

	static function aliveWithin(sphere:GeodesicSphereData, state:GeodesicLifeState, from:Array<Int>, radius:Int):Array<Int> {
		var distances = GeodesicShapeSignature.multiSourceBfs(sphere, from);
		var result:Array<Int> = [];
		for (entry in distances.keyValueIterator()) {
			if (entry.value <= radius && state.isAlive(entry.key)) {
				result.push(entry.key);
			}
		}
		return result;
	}

	function buildSites(sphere:GeodesicSphereData):Array<GeneratorSite> {
		var pentagonDistances = GeodesicShapeSignature.multiSourceBfs(sphere, GeodesicSphere.pentagons(sphere));
		var eligible:Array<Int> = [];
		for (id in 0...sphere.neighbors.length) {
			var d = pentagonDistances.get(id);
			if (d != null && d >= MIN_PENTAGON_CLEARANCE && sphere.neighbors[id].length == 6) {
				eligible.push(id);
			}
		}

		var chosen = spreadPoints(sphere, eligible, GENERATOR_SITE_COUNT);
		var sites:Array<GeneratorSite> = [];
		for (i in 0...chosen.length) {
			sites.push({anchor: chosen[i], dueAtGeneration: i}); // staggered by a few generations so all sites don't spawn on the exact same tick
		}
		return sites;
	}

	/** Greedy farthest-point spread over `candidates` — cheap at this size, and good enough that generator sites don't cluster on one side of the sphere. **/
	static function spreadPoints(sphere:GeodesicSphereData, candidates:Array<Int>, count:Int):Array<Int> {
		var chosen = [candidates[0]];
		while (chosen.length < count && chosen.length < candidates.length) {
			var distances = GeodesicShapeSignature.multiSourceBfs(sphere, chosen);
			var best = -1;
			var bestDistance = -1;
			for (candidate in candidates) {
				if (chosen.indexOf(candidate) != -1) {
					continue;
				}
				var d = distances.get(candidate);
				if (d != null && d > bestDistance) {
					bestDistance = d;
					best = candidate;
				}
			}
			chosen.push(best);
		}
		return chosen;
	}
}

typedef GeneratorSite = {anchor:Int, dueAtGeneration:Int};
typedef ActiveGlider = {cells:Array<Int>, missed:Int, site:GeneratorSite};
