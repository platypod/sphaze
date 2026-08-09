package tools.geodesic;

import graphics.Colours;
import tools.geodesic.GeodesicMesh.TrackedCell;
import tools.geodesic.GeodesicSphere.GeodesicSphereData;

/**
	Spawn points, not glider guns (2026-08-06). Two kinds of generator site,
	each next to a different set of anchors:

	- **Traveler sites** seed the real, confirmed spaceship
	  (`GeodesicGliderPatterns.placeKnownSpaceship` — Catagolue's
	  `xq14_0ig5l3z102`, verified on this exact mesh by `GeodesicGliderPort`'s
	  own headless probe: 8 clean periods of genuine net travel before it
	  reaches a pentagon).
	- **Shuttle sites** (2026-08-07) seed one of the six confirmed `B2/S34`
	  1-ring patterns `GeodesicGliderSearch`/`GeodesicGliderTrajectory` found
	  and rejected as spawn-point material on their own (bounded, they never
	  go anywhere) — brought back in once hooman reframed them: not useless
	  because they don't travel, potentially interesting *because* they sit
	  still and a traveling glider might run into one. Anchored directly next
	  to a pentagon (`sphere.neighbors[pentagon][0]`), same placement the old
	  shuttle-only tracker used, since a 1-ring pattern needs no walking room.

	Both kinds render through `GeodesicMesh.build`'s own `trackedCells`
	routing, in `GeodesicConwayBiome.rebuildMesh`. **Every site gets its own
	color from `Colours.CONWAY_TILE_SITE_PALETTE` (2026-08-07), not one
	shared `CONWAY_TILE_GLIDER`** — explicitly "for now," a debug palette for
	watching which structure came from which pentagon and telling a real
	meeting between two of them apart from one just growing. See that
	constant's own doc.

	**A true glider gun — a structure that emits gliders on its own,
	forever, the way Conway's Gosper gun does — is still not what this is.**
	This class re-seeds by timer instead — a scripted stand-in, not an
	emergent one. See `docs/game-design/ideas-backlog.md`'s own entry.

	**Traveler anchors need real clearance from a pentagon, not proximity to
	one.** `placeKnownSpaceship`'s own walk can reach 6 hex-steps out from
	its anchor, so a site sitting right next to a pentagon would regularly
	fail to place at all. `MIN_PENTAGON_CLEARANCE` keeps traveler sites
	planted in open hex territory instead. Shuttle sites have no such
	requirement — their own 1-ring pattern fits next to a pentagon fine,
	which is exactly where they're anchored.

	**Spawns once per site, not on a repeating clock**, and only respawns
	after tracking is actually lost and `RESPAWN_COOLDOWN` generations have
	passed since. A placement failure (only possible for traveler sites) is
	treated the same way — retry after the cooldown rather than every tick.

	**Tracking a structure once it's alive** gathers every currently live
	cell within `TRACK_RADIUS` hops of its last known cells
	(`GeodesicShapeSignature.multiSourceBfs`), and accepts that set as its
	new position as long as *something* is still there and it hasn't grown
	past `MAX_TRACKED_POPULATION` — not an exact population/shape match, see
	`relocateActive`'s own doc for why that was tried first and broke. A
	miss gets `MISS_GRACE` generations of benefit of the doubt before the
	tracker gives up — the structure quietly rejoins the ordinary live-cell
	rendering, still simulated, just no longer drawn specially. This also
	means two sites' own structures meeting and merging keep being tracked
	as one (now oddly-colored) blob rather than vanishing — which is the
	point, for watching what an interaction actually does.

	Not persisted across `GeodesicConwayBiome.serialize`/`restore` — a save
	just resumes with every current structure untracked until its site's
	next spawn. Losing a visual overlay across a save is a fair trade
	against carrying tracker state through the save format; revisit only if
	that actually reads as jarring in play.
**/
class GeodesicGliderTracker {
	/** How many traveler sites. **/
	static inline final GENERATOR_SITE_COUNT:Int = 3;

	/** The six confirmed `B2/S34` 1-ring shuttles from `GeodesicGliderSearch`'s own findings, by seed mask — one site per pattern, no repeats. **/
	static final SHUTTLE_MASKS:Array<Int> = [30, 46, 92, 102, 114, 120];

	static inline final SHUTTLE_SITE_COUNT:Int = 6;

	/** BFS hops a traveler site's own anchor must sit from the nearest pentagon — enough that `GeodesicGliderPatterns.placeKnownSpaceship`'s own up-to-6-hex-step walk reliably has room, without needing every attempt to succeed. **/
	static inline final MIN_PENTAGON_CLEARANCE:Int = 4;

	/** Generations a site waits after losing its structure (or failing to place one) before trying again — long enough that whatever ended the last one has had time to clear. **/
	static inline final RESPAWN_COOLDOWN:Int = 40;

	/** How far (BFS hops) to look for a tracked structure's own next position — a Life birth can only ever occur adjacent to an already-live cell, so this only needs to comfortably clear one generation's own worth of movement. **/
	static inline final TRACK_RADIUS:Int = 2;

	/** Generations a structure is allowed to go unmatched before tracking gives up on it. **/
	static inline final MISS_GRACE:Int = 2;

	/** A tracked blob larger than this is soup, or several structures having genuinely merged — either way not one legible thing to keep drawing as a single site's own color. Well above any one site's own steady population. **/
	static inline final MAX_TRACKED_POPULATION:Int = 30;

	/** Larger than any `RESPAWN_COOLDOWN`-scale generation count actually reached — stands in for "not due," since a site with an active, still-tracked structure shouldn't spawn again at all. **/
	static inline final INFINITE_GENERATION:Int = 0x7FFFFFFF;

	final sphere:GeodesicSphereData;
	final sites:Array<GeneratorSite>;
	var active:Array<ActiveGlider> = [];
	var generation:Int = 0;

	public function new(sphere:GeodesicSphereData) {
		this.sphere = sphere;
		this.sites = buildSites(sphere);
	}

	/** Call once per `GeodesicLifeState.step` — spawns whichever sites are due (freshly built, or recovering from a lost/failed structure), then re-locates every structure already being tracked. **/
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

	/** Every currently-tracked structure's own live cells, each paired with its own site's color — `GeodesicMesh.build`'s own `trackedCells` routing reads this. **/
	public function trackedCells():Array<TrackedCell> {
		var result:Array<TrackedCell> = [];
		for (glider in active) {
			for (id in glider.cells) {
				result.push({id: id, color: glider.site.color});
			}
		}
		return result;
	}

	function spawn(state:GeodesicLifeState, site:GeneratorSite):Bool {
		var cells = switch site.kind {
			case Traveler: GeodesicGliderPatterns.placeKnownSpaceship(sphere, site.anchor);
			case Shuttle(mask):
				var matches = GeodesicGliderPatterns.localPatterns(sphere, site.anchor).filter((candidate) -> candidate.mask == mask);
				matches.length > 0 ? matches[0].cells : null;
		}
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
		Whatever's alive within `TRACK_RADIUS` of a structure's last known
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
					RESPAWN_COOLDOWN; // lost for good (commonly: a traveler reached a pentagon, or several structures merged past MAX_TRACKED_POPULATION) — let its site try again once things settle
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
		var sites = buildTravelerSites(sphere).concat(buildShuttleSites(sphere));
		for (i in 0...sites.length) {
			sites[i].dueAtGeneration = i; // staggered by a few generations so all sites don't spawn on the exact same tick
			sites[i].color = Colours.CONWAY_TILE_SITE_PALETTE[i % Colours.CONWAY_TILE_SITE_PALETTE.length];
		}
		return sites;
	}

	function buildTravelerSites(sphere:GeodesicSphereData):Array<GeneratorSite> {
		var pentagonDistances = GeodesicShapeSignature.multiSourceBfs(sphere, GeodesicSphere.pentagons(sphere));
		var eligible:Array<Int> = [];
		for (id in 0...sphere.neighbors.length) {
			var d = pentagonDistances.get(id);
			if (d != null && d >= MIN_PENTAGON_CLEARANCE && sphere.neighbors[id].length == 6) {
				eligible.push(id);
			}
		}
		var chosen = spreadPoints(sphere, eligible, GENERATOR_SITE_COUNT);
		return [
			for (anchor in chosen)
				{
					anchor: anchor,
					kind: Traveler,
					color: 0,
					dueAtGeneration: 0
				}
		];
	}

	/** One site per `SHUTTLE_MASKS` entry, anchored directly next to its own spread-out pentagon — a 1-ring pattern needs no walking room, unlike a traveler's own placement. **/
	function buildShuttleSites(sphere:GeodesicSphereData):Array<GeneratorSite> {
		var pentagons = spreadPoints(sphere, GeodesicSphere.pentagons(sphere), SHUTTLE_SITE_COUNT);
		var sites:Array<GeneratorSite> = [];
		for (i in 0...pentagons.length) {
			var anchor = sphere.neighbors[pentagons[i]][0];
			var mask = SHUTTLE_MASKS[i % SHUTTLE_MASKS.length];
			sites.push({
				anchor: anchor,
				kind: Shuttle(mask),
				color: 0,
				dueAtGeneration: 0
			});
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

enum SiteKind {
	Traveler;
	Shuttle(mask:Int);
}

typedef GeneratorSite = {anchor:Int, kind:SiteKind, color:Int, dueAtGeneration:Int};
typedef ActiveGlider = {cells:Array<Int>, missed:Int, site:GeneratorSite};
