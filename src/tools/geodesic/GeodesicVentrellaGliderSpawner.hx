package tools.geodesic;

import tools.geodesic.GeodesicSphere.GeodesicSphereData;

/**
	Twelve launch sites, one per pentagon, each periodically reseeding
	`GeodesicVentrellaGliderPattern`'s own confirmed traveling glider in a
	different heading — `GeodesicConwayBiome`'s replacement for the old
	`GeodesicGliderTracker` spawn-site mechanic, now that there's an actual
	long-range traveler to spawn instead of a bounded shuttle. Same
	underlying philosophy as that earlier mechanic ("I want only the
	spawned gliders," `docs/game-design/design-decisions-records.md`'s own
	2026-08-07 entry) — deliberate spawns, no ambient soup — just built on
	a rule where that philosophy finally has something worth spawning.

	**Anchor**: each pentagon's own first neighbor
	(`sphere.neighbors[pentagon][0]`) — guaranteed a real hexagon, since
	pentagons are never adjacent to each other (`GeodesicValidator`'s own
	invariant). Close enough to "around the pentagon" that the pentagon's
	own irregularity sits one or two hops from the glider's own
	construction path. That's deliberate, not overlooked: a glider
	launched this close to a pentagon may cross it within its first couple
	of steps — an accepted, interesting part of watching this rule up
	close, not a bug to route around.

	**Heading**: `southIndex = pentagonIndex % 6` — a hexagon has 6
	neighbors, so this cycles through every possible heading at least once
	across the 12 pentagons (twice over, since `12 / 6 = 2`), giving
	genuinely varied launch directions rather than every site aiming the
	same way.

	**Cadence**: each site reseeds every `SPAWN_INTERVAL` generations, with
	a staggered phase (`site index * SPAWN_INTERVAL / 12`) so all 12 don't
	fire in lockstep. Untuned against real play — see this class's own
	`SPAWN_INTERVAL` doc.
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

	final sphere:GeodesicSphereData;
	final sites:Array<{anchor:Int, southIndex:Int, phase:Int}>;

	public function new(sphere:GeodesicSphereData) {
		this.sphere = sphere;
		var pentagons = GeodesicSphere.pentagons(sphere);
		sites = [
			for (i in 0...pentagons.length)
				{
					anchor: sphere.neighbors[pentagons[i]][0],
					southIndex: i % 6,
					phase: Std.int(i * SPAWN_INTERVAL / pentagons.length)
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
