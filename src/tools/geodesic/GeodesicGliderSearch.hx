package tools.geodesic;

import tools.geodesic.GeodesicGliderPatterns.SeedPattern;
import tools.geodesic.GeodesicLifeRule.GeodesicLifeRules;
import tools.geodesic.GeodesicSphere.GeodesicSphereData;

/**
	One-time exploratory search, not part of the permanent test suite or the
	regular build/bake pipeline — run by hand (`neko` target) and read.

	The question this answers: does *any* small seed pattern, under *any* of
	our candidate rules, behave like a Conway-Life glider — a shape that
	survives indefinitely by translating rather than sitting still, dying,
	or dissolving into soup? Prompted directly by hooman wanting "gliders
	gliding... forevermore" instead of the undifferentiated soup `B2/S34`
	settles into (see `GeodesicLifeRules.DEFAULT`'s own doc for that
	rule's own history).

	No known Conway-Life glider transplants here: this grid's neighborhood
	is 6-cell (hex, 5 at the 12 pentagons), not the 8-cell Moore
	neighborhood the classic glider is built for, and there's no
	`(theta, phi)` coordinate system to place a hand-designed pattern by —
	see `GeodesicMesh`'s own doc for why this package gave up on grid
	coordinates entirely. So this is a search, not a lookup: every non-empty
	subset of one node's own 1-ring (itself plus its 6 neighbors, 127
	patterns) is tried under every rule in `GeodesicLifeRules.ALL`.

	**Shape matching without coordinates**, and **confirmation, not a single
	coincidence**: both handled by `GeodesicShapeSignature` — a translating
	pattern is recognized by its live set's own shape (sorted pairwise
	graph-BFS distances) recurring at different node ids, confirmed across
	several consecutive periods rather than trusted on one lucky match (see
	that class's own doc, and `GeodesicLifeReport`'s own first, wrong,
	version for what one-sample evidence costs).

	**Findings, first pass (2026-08-06):** 24 confirmed "Glider" outcomes
	out of 508 (rule, seed) trials — meaning translating (non-zero drift,
	different node ids) rather than standing still, *not* yet meaning
	open-ended travel; see the correction below. `B2/S23` produced 12
	distinct 3-cell, period-1 patterns (drift ≈0.082-0.087, a new shape
	every single generation). `B2/S3` and `B2/S34` share an identical
	6-pattern family of 4-cell, period-2 patterns (drift ≈0.071-0.076) —
	expected, since their `survive` sets agree at the low neighbor counts
	these patterns actually produce. `B3/S34` produced none — everything it
	turned up was a same-footprint rotator (`sameNodes` false but
	`centroidDistance` ~0, filtered by `DRIFT_EPSILON`).

	**Correction from the long-run follow-up (`GeodesicGliderTrajectory`,
	same day):** "translates between two consecutive periods" is not the
	same claim as "travels indefinitely." Run 5000 generations instead of
	this search's `CONFIRM_PERIODS`-worth (8-16 generations), every one of
	the 6 `B2/S34` patterns turned out to be a bounded *shuttle* — it drifts
	away from its own spawn point by about one hex-cell, then drifts back,
	on a much longer cycle than the short period this search measured
	(`Glider` mask 30: drift alternates `0.106`/`0` on a ~100-generation
	round trip, never trending outward) — never approaching a pentagon,
	never escaping its own neighborhood. Robust (all 6 survived the full
	5000 generations with no death/explosion/pentagon interaction) but not
	what "gliders gliding forevermore" asked for. `GeodesicGliderTracker`'s
	pentagon-side spawn points use these anyway, explicitly as a scripted
	stand-in rather than a claim of finding a real long-range traveler — see
	its own doc, and `docs/open/ideas-backlog.md`'s own entry for
	widening this search (larger seed radius, more rules) as real follow-up
	work.
**/
class GeodesicGliderSearch {
	static inline final FREQUENCY:Int = 10;

	/** Generations simulated per (rule, seed) trial — needs to cover both the search and `CONFIRM_PERIODS` repeats of whatever period turns up. **/
	static inline final TOTAL_STEPS:Int = 100;

	/** How many consecutive recurrences of a candidate period are required before it's trusted. **/
	static inline final CONFIRM_PERIODS:Int = 4;

	/** Longest period searched for — five glider-lengths' worth of `TOTAL_STEPS` margin past this is still available for confirmation. **/
	static inline final MAX_PERIOD:Int = 20;

	/** A run whose population ever exceeds this is soup, not a glider — abandoned rather than tracked further. Public: `GeodesicGliderTrajectory` uses the same cutoff. **/
	public static inline final EXPLOSION_CAP:Int = 40;

	/**
		Below this centroid drift, a period whose live *ids* differ from one
		occurrence to the next is a same-footprint oscillator flipping
		between symmetric layouts (a rotator around a fixed hub), not a
		glider — `sameNodes` alone isn't enough to tell them apart, since a
		pattern can cycle through several distinct id sets without its
		centroid ever leaving its own neighborhood. Well under one hex-cell
		hop (empirically ~0.08 on this sphere's unit-vector positions), so
		it only screens out true non-movers.
	**/
	static inline final DRIFT_EPSILON:Float = 0.01;

	public static function main():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var center = GeodesicGliderPatterns.flattestNode(sphere);
		var seeds = GeodesicGliderPatterns.localPatterns(sphere, center);
		Sys.println('${sphere.neighbors.length} nodes, center node $center (farthest from any pentagon), ${seeds.length} candidate seed patterns x ${GeodesicLifeRules.ALL.length} rules, $TOTAL_STEPS generations each');

		var gliders = 0;
		var statics = 0;
		var died = 0;
		var exploded = 0;
		var noMatch = 0;

		for (rule in GeodesicLifeRules.ALL) {
			for (seed in seeds) {
				switch runOne(sphere, rule, seed) {
					case Glider(period, drift):
						gliders++;
						Sys.println('GLIDER  rule=${rule.name} seedMask=${seed.mask} population=${seed.cells.length} period=$period drift=${round(drift)}');
					case StaticOscillator(period):
						statics++;
					case Died:
						died++;
					case Exploded:
						exploded++;
					case NoMatch:
						noMatch++;
				}
			}
		}

		Sys.println('\ndone: $gliders gliders, $statics static oscillators, $died died, $exploded exploded (soup), $noMatch no match within $TOTAL_STEPS generations');
	}

	/** One (rule, seed) trial: simulate `TOTAL_STEPS` generations with mutation disabled (a glider is a deterministic claim, not a lucky mutation), then classify from the recorded history. **/
	static function runOne(sphere:GeodesicSphereData, rule:GeodesicLifeRule, seed:SeedPattern):SearchOutcome {
		var state = new GeodesicLifeState(sphere, rule);
		for (id in seed.cells) {
			state.seedSingle(id);
		}
		var noMutation = () -> 1.0; // never below GeodesicLifeState.MUTATION_RATE

		var history:Array<{signature:String, alive:Array<Int>}> = [];
		for (generation in 0...TOTAL_STEPS) {
			state.step(noMutation);
			var alive = GeodesicShapeSignature.aliveNodes(state, sphere);
			if (alive.length == 0) {
				return Died;
			}
			if (alive.length > EXPLOSION_CAP) {
				return Exploded;
			}
			history.push({signature: GeodesicShapeSignature.of(sphere, alive), alive: alive});
		}
		return analyzeHistory(sphere, history);
	}

	/** Smallest period, if any, whose signature recurs `CONFIRM_PERIODS` times in a row — translating (different node ids, non-trivial drift) reported as `Glider`, standing-still as `StaticOscillator`. **/
	static function analyzeHistory(sphere:GeodesicSphereData, history:Array<{signature:String, alive:Array<Int>}>):SearchOutcome {
		for (period in 1...MAX_PERIOD + 1) {
			var span = period * CONFIRM_PERIODS;
			if (span >= history.length) {
				continue;
			}
			for (start in 0...(history.length - span)) {
				var base = history[start];
				var matches = true;
				for (k in 1...CONFIRM_PERIODS + 1) {
					if (history[start + period * k].signature != base.signature) {
						matches = false;
						break;
					}
				}
				if (matches) {
					var recurrence = history[start + period];
					var drift = GeodesicShapeSignature.centroidDistance(sphere, base.alive, recurrence.alive);
					if (GeodesicShapeSignature.sameNodes(base.alive, recurrence.alive) || drift < DRIFT_EPSILON) {
						return StaticOscillator(period);
					}
					return Glider(period, drift);
				}
			}
		}
		return NoMatch;
	}

	static function round(value:Float):String {
		return Std.string(Math.round(value * 1000) / 1000);
	}
}

enum SearchOutcome {
	Glider(period:Int, drift:Float);
	StaticOscillator(period:Int);
	Died;
	Exploded;
	NoMatch;
}
