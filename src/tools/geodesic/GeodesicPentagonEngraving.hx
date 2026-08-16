package tools.geodesic;

import tools.geodesic.GeodesicSphere.GeodesicSphereData;

/**
	The player-composed pattern at each of the sphere's 12 pentagons — see
	`docs/open/ideas-backlog.md`'s "Deliberate pentagon activation"
	entry, "The composing interface" for the full design: the player zooms
	into a pentagon's own floor engraving, toggles cells on/off, and every
	`RESTAMP_INTERVAL_TICKS` ticks the composed pattern is force-written
	onto the live `GeodesicVentrellaState` board — overwriting its own
	footprint exactly (every footprint cell, on or off, not just the ones
	turned on), a deliberate choice over an additive OR: the pentagon
	engraving is meant as a metronome the board can never permanently
	drift from, not a one-shot seed left to evolve freely.

	Deliberately separate from `GeodesicVentrellaGliderSpawner` — that
	class drives the *ambient* traveling-glider mechanic (a fixed shape,
	reseeded from a hexagon anchor near a pentagon, on its own clock).
	This class is the *player-authored* counterpart: an arbitrary pattern,
	anchored directly on a pentagon and its own `FOOTPRINT_RADIUS`-hop
	neighborhood, that only exists where the player has actually composed
	one.
**/
class GeodesicPentagonEngraving {
	/**
		How often (in `GeodesicConwayBiome.tick` calls, i.e. real fixed-update
		ticks — not simulation generations) a pentagon with a composed
		pattern gets restamped. Untuned — a first guess from the design
		conversation ("every 20 ticks or something"), not a measured value;
		revisit after playing.
	**/
	public static inline final RESTAMP_INTERVAL_TICKS:Int = 20;

	/**
		How many hops out from a pentagon its own editable footprint
		reaches — widened from `1` to `3` (2026-08-10, asked directly: "a
		wider range of config, say, three cells radius"). Safe against
		overlapping a neighboring pentagon's own footprint: the checked-in
		sphere is baked at frequency `11`
		(`docs/archive/decisions.md`'s own "Geodesic
		sphere for Conway" entry), so the *closest* two pentagons — which
		are always icosahedron vertices, and only ever share a subdivided
		icosahedral edge — are `11` hops apart, more than three times
		`2 * FOOTPRINT_RADIUS` (`6`). Untuned as a *size* otherwise — "three
		cells" was the ask, not a measured value.
	**/
	public static inline final FOOTPRINT_RADIUS:Int = 3;

	final sphere:GeodesicSphereData;

	/** Every pentagon's own editable footprint (itself plus every node within `FOOTPRINT_RADIUS` hops), computed once — see `footprintOf`'s own doc. **/
	final footprints:Map<Int, Array<Int>>;

	/** Per pentagon, the composed pattern: node id → desired state. A node absent here reads as `0` (off) — see `stateAt`. Only pentagons the player has actually touched get an entry at all. **/
	final patterns:Map<Int, Map<Int, Int>>;

	/** Per pentagon with a composed pattern, ticks since the last restamp (or since it was first composed). **/
	final ticksSinceRestamp:Map<Int, Int>;

	public function new(sphere:GeodesicSphereData) {
		this.sphere = sphere;
		footprints = new Map();
		patterns = new Map();
		ticksSinceRestamp = new Map();
	}

	/**
		A pentagon's own editable neighborhood: itself plus every node
		reachable within `FOOTPRINT_RADIUS` hops — see that constant's own
		doc for why a footprint this wide still can't overlap a
		neighboring pentagon's.
		@param pentagonId a pentagon's own node id.
		@return that pentagon's own footprint, pentagon first, computed once and cached.
	**/
	public function footprintOf(pentagonId:Int):Array<Int> {
		var existing = footprints.get(pentagonId);
		if (existing != null) {
			return existing;
		}
		var footprint = hopNeighborhoodOf(pentagonId, FOOTPRINT_RADIUS);
		footprints.set(pentagonId, footprint);
		return footprint;
	}

	/**
		Every node within `radius` hops of `origin` (inclusive, `origin`
		itself first), by breadth-first search over `sphere.neighbors` — no
		ring/radius helper existed anywhere in `tools.geodesic` before this
		(confirmed by search across the whole package: every existing
		"nearby nodes" need, e.g. `GeodesicVentrellaGliderPattern`'s own
		`stepToward`, walks a fixed handful of hand-specified hops rather
		than collecting a general neighborhood), so this is a small one of
		its own rather than a reuse.
		@param origin the node to search outward from.
		@param radius how many hops out to include.
		@return every node within `radius` hops, `origin` first, in BFS discovery order.
	**/
	function hopNeighborhoodOf(origin:Int, radius:Int):Array<Int> {
		var visited = new Map<Int, Bool>();
		visited.set(origin, true);
		var order = [origin];
		var frontier = [origin];
		for (_ in 0...radius) {
			var nextFrontier = [];
			for (nodeId in frontier) {
				for (neighbor in sphere.neighbors[nodeId]) {
					if (visited.exists(neighbor)) {
						continue;
					}
					visited.set(neighbor, true);
					order.push(neighbor);
					nextFrontier.push(neighbor);
				}
			}
			frontier = nextFrontier;
		}
		return order;
	}

	/** Whether `nodeId` is inside `pentagonId`'s own editable footprint — what `GeodesicConwayBiome.onEditClick` gates a toggle on, so a click doesn't reach past the engraving's own edge. **/
	public function isInFootprint(pentagonId:Int, nodeId:Int):Bool {
		return footprintOf(pentagonId).indexOf(nodeId) != -1;
	}

	/** `0` (off) for any node never explicitly toggled at this pentagon, or for a pentagon never composed at all. **/
	public function stateAt(pentagonId:Int, nodeId:Int):Int {
		var pattern = patterns.get(pentagonId);
		if (pattern == null || !pattern.exists(nodeId)) {
			return 0;
		}
		return pattern.get(nodeId);
	}

	/**
		Flips `nodeId`'s own composed state at `pentagonId` between `0` and
		`1` — the click-to-toggle verb. Starts that pentagon's own restamp
		clock the first time it's touched, so a freshly-composed pattern
		doesn't wait up to `RESTAMP_INTERVAL_TICKS` before it first appears
		on the live board.
	**/
	public function toggle(pentagonId:Int, nodeId:Int):Void {
		var pattern = patterns.get(pentagonId);
		if (pattern == null) {
			pattern = new Map();
			patterns.set(pentagonId, pattern);
			ticksSinceRestamp.set(pentagonId, RESTAMP_INTERVAL_TICKS); // due immediately
		}
		pattern.set(nodeId, pattern.exists(nodeId) && pattern.get(nodeId) != 0 ? 0 : 1);
	}

	/**
		Advances every composed pentagon's own restamp clock by one tick,
		force-writing (`GeodesicVentrellaState.seedSingle`) its own
		footprint onto `state` once the clock reaches
		`RESTAMP_INTERVAL_TICKS` — every footprint node, not just the ones
		currently on, so a cell the simulation grew inside the footprint
		since the last restamp is overwritten back to whatever the composed
		pattern actually says (`0` if the player never turned it on).
		Called once per `GeodesicConwayBiome.tick`, unconditionally — a
		pentagon's own pattern keeps reasserting itself whether or not the
		player is currently standing there composing it (the "sustaining
		source, not a one-shot seed" the design conversation asked for).
		@param state the live board to restamp onto.
	**/
	public function tickAll(state:GeodesicVentrellaState):Void {
		for (pentagonId in patterns.keys()) {
			var ticks = ticksSinceRestamp.get(pentagonId) + 1;
			if (ticks < RESTAMP_INTERVAL_TICKS) {
				ticksSinceRestamp.set(pentagonId, ticks);
				continue;
			}
			ticksSinceRestamp.set(pentagonId, 0);
			for (nodeId in footprintOf(pentagonId)) {
				state.seedSingle(nodeId, stateAt(pentagonId, nodeId));
			}
		}
	}
}
