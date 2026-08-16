package tools.geodesic;

import tools.geodesic.GeodesicSphere.GeodesicSphereData;

/**
	Twelve launch sites, one per pentagon, each periodically reseeding
	`GeodesicVentrellaGliderPattern`'s own confirmed traveling glider in a
	different heading — `GeodesicConwayBiome`'s replacement for the old
	`GeodesicGliderTracker` spawn-site mechanic, now that there's an actual
	long-range traveler to spawn instead of a bounded shuttle. Same
	underlying philosophy as that earlier mechanic ("I want only the
	spawned gliders," `docs/archive/decisions.md`'s own
	2026-08-07 entry) — deliberate spawns, no ambient soup — just built on
	a rule where that philosophy finally has something worth spawning.

	**Anchor**: each active pentagon's own first neighbor
	(`sphere.neighbors[pentagon][0]`) — guaranteed a real hexagon, since
	pentagons are never adjacent to each other (`GeodesicValidator`'s own
	invariant). Close enough to "around the pentagon" that the pentagon's
	own irregularity sits one or two hops from the glider's own
	construction path. That's deliberate, not overlooked: a glider
	launched this close to a pentagon may cross it within its first couple
	of steps — an accepted, interesting part of watching this rule up
	close, not a bug to route around.

	**Which pentagons are active**: every `PENTAGON_STRIDE`-th one, not all
	12 — played too busy at one site per pentagon ("we are spawning too
	much stuff," 2026-08-10), cut to a third rather than tuning `SPAWN_INTERVAL`
	down, since the complaint was about how much is on screen at once, not
	how often any one site fires. See that constant's own doc.

	**Heading**: `southIndex = pentagonIndex % 6` (the *original* index into
	all 12 pentagons, not the filtered active list) — a hexagon has 6
	neighbors, so this still cycles through varied headings even with only
	a third of sites active, and a pentagon's own heading stays stable if
	`PENTAGON_STRIDE` changes later.

	**Cadence**: each active site reseeds every `SPAWN_INTERVAL` generations,
	with a staggered phase (`active-site index * SPAWN_INTERVAL / active count`)
	so they don't fire in lockstep. Untuned against real play — see this
	class's own `SPAWN_INTERVAL` doc.
**/
class GeodesicVentrellaGliderSpawner {
	/**
		Generations between one site's own respawns. The confirmed
		glider's own lifespan (`GeodesicVentrellaFigure2`'s own trace) ran
		roughly 100 generations before its self-collision death, so this
		is short enough that several gliders from different sites can be
		in flight at once. Not measured against real play yet — revisit
		once seen running for real.
	**/
	public static inline final SPAWN_INTERVAL:Int = 30;

	/**
		Only every `PENTAGON_STRIDE`-th pentagon (by its own index into
		`GeodesicSphere.pentagons`) gets a launch site — `3` means a third
		of the 12 are active (4 sites). Requested directly after playing
		the all-12 version ("we are spawning too much stuff... for now,
		we'll adjust later") — a single constant to retune rather than a
		design that needs revisiting, on purpose.
	**/
	public static inline final PENTAGON_STRIDE:Int = 3;

	final sphere:GeodesicSphereData;
	final sites:Array<{anchor:Int, southIndex:Int, phase:Int}>;

	/** How many launch sites are actually active — `GeodesicSphere.pentagons(sphere).length / PENTAGON_STRIDE`, rounded up. Mainly for tests. **/
	public var siteCount(get, never):Int;

	function get_siteCount():Int {
		return sites.length;
	}

	public function new(sphere:GeodesicSphereData) {
		this.sphere = sphere;
		var pentagons = GeodesicSphere.pentagons(sphere);
		var activeIndexes = [for (i in 0...pentagons.length) if (i % PENTAGON_STRIDE == 0) i];
		sites = [
			for (j in 0...activeIndexes.length)
				{
					anchor: sphere.neighbors[pentagons[activeIndexes[j]]][0],
					southIndex: activeIndexes[j] % 6,
					phase: Std.int(j * SPAWN_INTERVAL / activeIndexes.length)
				}
		];
	}

	/**
		Reseeds every site whose own clock is due this generation —
		including generation `0`, so the board isn't empty while the first
		full interval elapses.
		@param state the layer to spawn onto.
		@param generation the current generation count (`GeodesicConwayBiome`'s own, `0`-based).
	**/
	public function tick(state:GeodesicVentrellaState, generation:Int):Void {
		for (site in sites) {
			if ((generation - site.phase) % SPAWN_INTERVAL == 0) {
				GeodesicVentrellaGliderPattern.seed(state, sphere, site.anchor, site.southIndex);
			}
		}
	}
}
