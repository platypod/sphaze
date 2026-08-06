package tools.geodesic;

import tools.geodesic.GeodesicLifeRule.GeodesicLifeRules;
import tools.geodesic.GeodesicSphere.GeodesicSphereData;

/**
	One-time exploratory search, not part of the permanent test suite — run
	by hand (`neko` target) and read.

	`GeodesicGliderSearch`'s own 1-ring search (127 patterns, populations
	1-7, all 4 rules) found only bounded shuttles under `B2/S34` — every
	one of them confirmed by `GeodesicGliderTrajectory`'s long-run probe.
	That fully covers everything smaller than `xq14_0ig5l3z102` (the real,
	confirmed 12-cell spaceship `GeodesicGliderTracker` now spawns) *within
	a single node's own 1-ring*. Catagolue's own distributed soup search —
	checked directly, every one of the 16 symmetry categories it tracks for
	`b2s34h` — has never found anything else either, smaller or otherwise,
	across ~100 billion random soups.

	This widens the search past that footprint: every subset of a 2-ring
	patch (a center node plus its neighbors' own neighbors, up to 19 cells)
	with population between `MIN_POPULATION` and `MAX_POPULATION`, under
	`B2/S34` only (the rule that matters — no reason to re-run the other 3
	candidates here). A short first pass flags anything that translates at
	all (`GeodesicGliderSearch`'s own coordinate-free shape-signature
	matching), then every hit gets `GeodesicGliderTrajectory`'s own long-run
	treatment (centroid drift from spawn, checked over many periods) before
	being trusted — a short-window "translates once" reading is exactly
	what made every 1-ring shuttle look like a real glider at first.
**/
class GeodesicGliderSearch2 {
	static inline final FREQUENCY:Int = 10;

	/** Smaller than `xq14_0ig5l3z102`'s own 10-12 cell range — the whole point of this search. **/
	static inline final MIN_POPULATION:Int = 3;

	static inline final MAX_POPULATION:Int = 5;

	/** Short first-pass generations — just enough to flag a candidate as "translates at all," not to trust it. **/
	static inline final SCREEN_STEPS:Int = 40;

	static inline final SCREEN_CONFIRM_PERIODS:Int = 2;
	static inline final SCREEN_MAX_PERIOD:Int = 10;
	static inline final DRIFT_EPSILON:Float = 0.01;
	static inline final EXPLOSION_CAP:Int = 25;

	/** Long-run confirmation for anything the screen flags — `GeodesicGliderTrajectory`'s own scale, since that's what it actually takes to tell a shuttle from a traveler. **/
	static inline final CONFIRM_STEPS:Int = 2000;

	static inline final CONFIRM_CHECKPOINT:Int = 20;

	public static function main():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var center = GeodesicGliderPatterns.flattestNode(sphere);
		var patch = ring2(sphere, center);
		var candidates = populationRangeSubsets(patch, MIN_POPULATION, MAX_POPULATION);
		Sys.println('${sphere.neighbors.length} nodes, center $center, patch size ${patch.length}, ${candidates.length} candidates (population $MIN_POPULATION-$MAX_POPULATION), rule ${GeodesicLifeRules.B2_S34.name}');

		var screened = 0;
		var confirmed = 0;
		for (cells in candidates) {
			var drift = screen(sphere, cells);
			if (drift == null) {
				continue;
			}
			screened++;
			Sys.println('SCREEN population=${cells.length} cells=${cells} drift=${round(drift)} — confirming long-run...');
			var travels = confirmTravels(sphere, cells);
			if (travels) {
				confirmed++;
				Sys.println('  CONFIRMED TRAVELER population=${cells.length} cells=${cells}');
			} else {
				Sys.println('  shuttle (bounded), not a traveler');
			}
		}
		Sys.println('\ndone: ${candidates.length} candidates, $screened screened positive, $confirmed confirmed long-run travelers');
	}

	/** `null` if this seed dies, explodes, or never shows a confirmed translating period within `SCREEN_STEPS` — a real drift value otherwise. **/
	static function screen(sphere:GeodesicSphereData, cells:Array<Int>):Null<Float> {
		var state = new GeodesicLifeState(sphere, GeodesicLifeRules.B2_S34);
		for (id in cells) {
			state.seedSingle(id);
		}
		var noMutation = () -> 1.0;
		var history:Array<{signature:String, alive:Array<Int>}> = [];
		for (_ in 0...SCREEN_STEPS) {
			state.step(noMutation);
			var alive = GeodesicShapeSignature.aliveNodes(state, sphere);
			if (alive.length == 0 || alive.length > EXPLOSION_CAP) {
				return null;
			}
			history.push({signature: GeodesicShapeSignature.of(sphere, alive), alive: alive});
		}
		for (period in 1...SCREEN_MAX_PERIOD + 1) {
			var span = period * SCREEN_CONFIRM_PERIODS;
			if (span >= history.length) {
				continue;
			}
			for (start in 0...(history.length - span)) {
				var base = history[start];
				var matches = true;
				for (k in 1...SCREEN_CONFIRM_PERIODS + 1) {
					if (history[start + period * k].signature != base.signature) {
						matches = false;
						break;
					}
				}
				if (matches) {
					var recurrence = history[start + period];
					var drift = GeodesicShapeSignature.centroidDistance(sphere, base.alive, recurrence.alive);
					if (drift >= DRIFT_EPSILON) {
						return drift;
					}
					return null; // static or same-footprint rotator
				}
			}
		}
		return null;
	}

	/** Does this seed's own centroid keep trending away from its spawn point over a long run, or does it settle into a shuttle's bounded back-and-forth? Same technique `GeodesicGliderTrajectory` used on `xq14_0ig5l3z102`. **/
	static function confirmTravels(sphere:GeodesicSphereData, cells:Array<Int>):Bool {
		var state = new GeodesicLifeState(sphere, GeodesicLifeRules.B2_S34);
		for (id in cells) {
			state.seedSingle(id);
		}
		var noMutation = () -> 1.0;
		var origin = cells.copy();
		var maxDrift = 0.0;
		var lastCheckpointDrift = 0.0;
		var stillGrowing = false;

		for (generation in 0...CONFIRM_STEPS) {
			state.step(noMutation);
			var alive = GeodesicShapeSignature.aliveNodes(state, sphere);
			if (alive.length == 0 || alive.length > EXPLOSION_CAP) {
				return false;
			}
			if ((generation + 1) % CONFIRM_CHECKPOINT == 0) {
				var drift = GeodesicShapeSignature.centroidDistance(sphere, origin, alive);
				stillGrowing = drift > maxDrift + DRIFT_EPSILON;
				maxDrift = Math.max(maxDrift, drift);
				lastCheckpointDrift = drift;
			}
		}
		// a real traveler's own drift keeps setting new highs late into the run; a shuttle's own drift plateaus early and just oscillates under that ceiling from then on
		return stillGrowing && lastCheckpointDrift > 0.3;
	}

	/** Every node within 2 hops of `center`, itself included — up to `1 + 6 + 12 = 19` cells on a fully hex-regular patch. **/
	static function ring2(sphere:GeodesicSphereData, center:Int):Array<Int> {
		var distances = GeodesicShapeSignature.bfsDistances(sphere, center, [for (id in 0...sphere.neighbors.length) id]);
		var patch:Array<Int> = [];
		for (id in 0...sphere.neighbors.length) {
			var d = distances.get(id);
			if (d != null && d <= 2) {
				patch.push(id);
			}
		}
		return patch;
	}

	/** Every subset of `cells` whose own size falls in `[minPopulation, maxPopulation]` — a bitmask sweep over up to 19 bits (2^19, ~524k), filtered by population count. **/
	static function populationRangeSubsets(cells:Array<Int>, minPopulation:Int, maxPopulation:Int):Array<Array<Int>> {
		var result:Array<Array<Int>> = [];
		var total = 1 << cells.length;
		for (mask in 1...total) {
			var population = popcount(mask);
			if (population < minPopulation || population > maxPopulation) {
				continue;
			}
			var subset:Array<Int> = [];
			for (i in 0...cells.length) {
				if (mask & (1 << i) != 0) {
					subset.push(cells[i]);
				}
			}
			result.push(subset);
		}
		return result;
	}

	static function popcount(mask:Int):Int {
		var count = 0;
		var m = mask;
		while (m != 0) {
			count += m & 1;
			m >>= 1;
		}
		return count;
	}

	static function round(value:Float):String {
		return Std.string(Math.round(value * 1000) / 1000);
	}
}
