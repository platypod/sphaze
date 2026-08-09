package tools.geodesic;

import tools.geodesic.GeodesicVentrellaRule.GeodesicVentrellaRules;
import tools.geodesic.GeodesicSphere.GeodesicSphereData;
import tools.geodesic.GeodesicVentrellaState.NeighborCountMode;

/**
	Exhaustive small hand-placed-pattern search for `GeodesicVentrellaRules.SPHERE_CA`
	— the counterpart to `GeodesicGliderSearchMultiRule` for this rule, but a
	different search axis entirely, chosen after that class's own
	ambient-soup finding (`GeodesicVentrellaReport`'s own doc): every tested
	seed density from `0.1` to `1.0` converged to the same near-total-extinction
	equilibrium under `Clamp`, `Proportional`, *and* `Literal` alike — the
	three diverge only in dense neighborhoods, and ambient soup collapses to
	sparse within a handful of generations regardless of mode. That rules
	out "wrong density" as the whole story — what's untested is whether
	*any* compact, deliberately-placed pattern survives
	at all, as opposed to a random scatter of independent single cells (most
	of which are alone in their own neighborhood and, per
	`GeodesicVentrellaStateTest.testAnIsolatedCellCyclesThroughStatesBeforeDying`,
	die on a fixed 3-generation clock regardless of density). Ventrella's own
	rule was evolved by genetic search scored against a specific glider
	pattern's own collision behavior, not against random-soup survival the
	way Conway's B3/S23 happens to be robust to — there's no reason to
	expect it to self-sustain from noise even if hand-placed structures
	thrive under it.

	**States restricted to `{1, 3}`, not all of `{1, 2, 3}`.** The source
	paper's own text: "While this traveling glider only uses these two
	states, glider collisions evoke state 2... some genes are only
	expressed under certain circumstances." An isolated glider is exactly
	the case being searched for here — state `2` is deliberately excluded
	from seed patterns, cutting the per-subset state-assignment space from
	`3^n` to `2^n`.

	**1-ring patch (7 cells), not 2-ring (19).** Smaller than
	`GeodesicGliderSearchMultiRule`'s own patch on purpose: population ×
	state-assignment combinations grow fast (`2^n` per subset on top of the
	subset count itself), and the illustrated glider in the source paper
	reads as a handful of cells, not a dozen. Widen to a 2-ring patch (same
	shape `GeodesicGliderSearch2`/`GeodesicGliderSearchMultiRule` already
	use) if this comes up empty — the same "narrow first, widen only if
	needed" progression this package's own glider-search history already
	follows.

	Same screen-then-confirm rigor as `GeodesicGliderSearchMultiRule`:
	`GeodesicShapeSignature`'s own coordinate-free footprint matching flags
	periodic recurrence with real drift over a short window, then
	`confirmTravels`'s own long-run centroid check separates an actual
	traveler from a shuttle that only looked like one. One deliberate
	simplification, not the full picture: both checks work off *which*
	nodes are alive (footprint), not their specific state values — two
	generations with the same live-cell footprint but swapped `1`/`3`
	assignments would read as "the same shape," which is coarser than
	Ventrella's own genuinely-4-state dynamics but sufficient for "does
	this survive and move at all," the actual question being asked here.

	Run by hand (`neko` target) and read — not part of the permanent test
	suite or the regular build/bake pipeline.
**/
class GeodesicVentrellaGliderSearch {
	static inline final FREQUENCY:Int = 10;
	static inline final MIN_POPULATION:Int = 2;
	static inline final MAX_POPULATION:Int = 5;
	static final SEED_STATES:Array<Int> = [1, 3];

	/**
		`Literal`, not `GeodesicVentrellaState.DEFAULT_COUNT_MODE` (`Clamp`)
		— this run is specifically testing the hypothesis that `Literal`'s
		own stricter, unbucketed reading is what the source paper's own
		evolution process actually selected against. The killed first run of
		this search (`Clamp`, `docs/game-design/design-decisions-records.md`
		has the numbers) found only bounded shuttles; see
		`GeodesicVentrellaState.NeighborCountMode.Literal`'s own doc for why
		this is a materially different rule, not just a third variant of the
		same guess.
	**/
	static final COUNT_MODE:NeighborCountMode = Literal;

	static inline final SCREEN_STEPS:Int = 40;
	static inline final SCREEN_CONFIRM_PERIODS:Int = 2;
	static inline final SCREEN_MAX_PERIOD:Int = 10;
	static inline final DRIFT_EPSILON:Float = 0.01;
	static inline final EXPLOSION_CAP:Int = 25;

	static inline final CONFIRM_STEPS:Int = 2000;
	static inline final CONFIRM_CHECKPOINT:Int = 20;

	public static function main():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var center = GeodesicGliderPatterns.flattestNode(sphere);
		var patch = ring1(sphere, center);
		var candidates = candidatesFor(patch);
		Sys.println('${sphere.neighbors.length} nodes, center $center, patch size ${patch.length}, ${candidates.length} candidates (population $MIN_POPULATION-$MAX_POPULATION, states $SEED_STATES)');

		var survivedToScreenEnd = 0;
		var screened = 0;
		var confirmed = 0;
		for (candidate in candidates) {
			var outcome = screen(sphere, candidate);
			if (outcome == null) {
				continue;
			}
			survivedToScreenEnd++;
			if (outcome.drift == null) {
				continue;
			}
			screened++;
			Sys.println('SCREEN cells=${candidate.cells} states=${candidate.states} drift=${round(outcome.drift)} — confirming long-run...');
			var travels = confirmTravels(sphere, candidate);
			if (travels) {
				confirmed++;
				Sys.println('  CONFIRMED TRAVELER cells=${candidate.cells} states=${candidate.states}');
			} else {
				Sys.println('  shuttle (bounded), not a traveler');
			}
		}
		Sys.println('\ndone: ${candidates.length} candidates, $survivedToScreenEnd survived $SCREEN_STEPS generations without dying/exploding, $screened of those showed periodic motion, $confirmed confirmed long-run travelers');
	}

	/** `null` if this seed dies or explodes within `SCREEN_STEPS`; otherwise the survivor's own periodicity reading (`drift == null` if it never showed a confirmed recurring period — alive throughout, just not (yet) shown to be periodic). **/
	static function screen(sphere:GeodesicSphereData, candidate:Candidate):Null<{drift:Null<Float>}> {
		var state = new GeodesicVentrellaState(sphere, GeodesicVentrellaRules.SPHERE_CA, COUNT_MODE);
		seedCandidate(state, candidate);
		var noMutation = () -> 1.0;
		var history:Array<{signature:String, alive:Array<Int>}> = [];
		for (_ in 0...SCREEN_STEPS) {
			state.step(noMutation);
			var alive = aliveNodes(state, sphere);
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
					return {drift: drift >= DRIFT_EPSILON ? drift : null};
				}
			}
		}
		return {drift: null};
	}

	static function confirmTravels(sphere:GeodesicSphereData, candidate:Candidate):Bool {
		var state = new GeodesicVentrellaState(sphere, GeodesicVentrellaRules.SPHERE_CA, COUNT_MODE);
		seedCandidate(state, candidate);
		var noMutation = () -> 1.0;
		var origin = candidate.cells.copy();
		var maxDrift = 0.0;
		var lastCheckpointDrift = 0.0;
		var stillGrowing = false;

		for (generation in 0...CONFIRM_STEPS) {
			state.step(noMutation);
			var alive = aliveNodes(state, sphere);
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
		return stillGrowing && lastCheckpointDrift > 0.3;
	}

	static function seedCandidate(state:GeodesicVentrellaState, candidate:Candidate):Void {
		for (i in 0...candidate.cells.length) {
			state.seedSingle(candidate.cells[i], candidate.states[i]);
		}
	}

	static function aliveNodes(state:GeodesicVentrellaState, sphere:GeodesicSphereData):Array<Int> {
		var alive = [];
		for (id in 0...sphere.neighbors.length) {
			if (state.isAlive(id)) {
				alive.push(id);
			}
		}
		return alive;
	}

	/** A node plus its own immediate neighbors — `1 + 6 = 7` cells on a hexagon-centered patch. **/
	static function ring1(sphere:GeodesicSphereData, center:Int):Array<Int> {
		var patch = [center];
		for (neighbor in sphere.neighbors[center]) {
			patch.push(neighbor);
		}
		return patch;
	}

	/** Every population-in-range subset of `cells`, crossed with every `SEED_STATES` assignment over that subset. **/
	static function candidatesFor(cells:Array<Int>):Array<Candidate> {
		var result:Array<Candidate> = [];
		for (subset in populationRangeSubsets(cells, MIN_POPULATION, MAX_POPULATION)) {
			for (states in stateAssignments(subset.length)) {
				result.push({cells: subset, states: states});
			}
		}
		return result;
	}

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

	/** Every assignment of `SEED_STATES` values to `size` cells — a base-`SEED_STATES.length` counter over `size` digits. **/
	static function stateAssignments(size:Int):Array<Array<Int>> {
		var result:Array<Array<Int>> = [];
		var total = 1;
		for (_ in 0...size) {
			total *= SEED_STATES.length;
		}
		for (index in 0...total) {
			var assignment:Array<Int> = [];
			var remainder = index;
			for (_ in 0...size) {
				assignment.push(SEED_STATES[remainder % SEED_STATES.length]);
				remainder = Std.int(remainder / SEED_STATES.length);
			}
			result.push(assignment);
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

/** One seed to try: `cells[i]` starts in `states[i]`. **/
typedef Candidate = {cells:Array<Int>, states:Array<Int>};
