package tools.geodesic;

import tools.geodesic.GeodesicGliderPatterns.SeedPattern;
import tools.geodesic.GeodesicLifeRule.GeodesicLifeRules;
import tools.geodesic.GeodesicSphere.GeodesicSphereData;

/**
	One-time exploratory follow-up to `GeodesicGliderSearch`, not part of the
	permanent test suite — run by hand (`neko` target) and read.

	`GeodesicGliderSearch` only confirms `CONFIRM_PERIODS` (4) repeats on an
	empty board seeded far from every pentagon — real evidence that a
	pattern *translates* between consecutive periods, but not evidence of
	open-ended travel, and not a test of what happens near a pentagon. This
	runs each `B2/S34` candidate (the rule the real biome actually plays
	under — `GeodesicLifeRules.DEFAULT`) for a long, uninterrupted 5000
	generations, logging centroid drift from its own spawn point every
	`CHECKPOINT_INTERVAL` generations.

	**Result (2026-08-06): every one of the 6 candidates is a bounded local
	shuttle, not a traveler.** First version of this probe logged "population
	changed" events and produced 2500 near-identical lines per candidate —
	that was never a pentagon interaction, just this period-2 family's own
	normal locomotion (4 live cells on even steps, 3 on odd, forever). This
	version measures the thing that actually matters — distance from the
	spawn point — and found e.g. seed mask 30's drift alternating cleanly
	between `0.106` and `0` (roughly one hex-cell out and back) on a
	~100-generation round trip, for the full 5000 generations, never
	trending outward and never approaching a pentagon. Robust (no death, no
	explosion, no pinch-point interaction observed in any candidate) but not
	what "gliders gliding forevermore" asked for — see
	`GeodesicGliderSearch`'s own doc for the correction this forced there,
	and `GeodesicGliderTracker`'s own doc for how these get used anyway
	(as scripted, honestly-labeled spawn points, not a claim of having found
	real long-range travelers).
**/
class GeodesicGliderTrajectory {
	static inline final FREQUENCY:Int = 10;
	static inline final TOTAL_STEPS:Int = 5000;

	/** How often (generations) to log centroid drift from the spawn point — coarse enough that 5000 generations stays readable. **/
	static inline final CHECKPOINT_INTERVAL:Int = 50;

	/** The 6 confirmed-translating `B2/S34` patterns from `GeodesicGliderSearch`'s own first-pass findings, by seed mask. **/
	static final CANDIDATE_MASKS:Array<Int> = [30, 46, 92, 102, 114, 120];

	public static function main():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var center = GeodesicGliderPatterns.flattestNode(sphere);
		var seeds = GeodesicGliderPatterns.localPatterns(sphere, center);
		var pentagons = GeodesicSphere.pentagons(sphere);
		Sys.println('${sphere.neighbors.length} nodes, center node $center, rule ${GeodesicLifeRules.B2_S34.name}, $TOTAL_STEPS generations per candidate');

		for (mask in CANDIDATE_MASKS) {
			var seed = seeds.filter((candidate) -> candidate.mask == mask)[0];
			runTrajectory(sphere, seed, pentagons);
		}
	}

	static function runTrajectory(sphere:GeodesicSphereData, seed:SeedPattern, pentagons:Array<Int>):Void {
		var state = new GeodesicLifeState(sphere, GeodesicLifeRules.B2_S34);
		for (id in seed.cells) {
			state.seedSingle(id);
		}
		var noMutation = () -> 1.0;
		var origin = seed.cells;
		var pentagonDistances = GeodesicShapeSignature.multiSourceBfs(sphere, pentagons);

		Sys.println('\n=== seedMask=${seed.mask} (population ${seed.cells.length}) ===');

		for (generation in 0...TOTAL_STEPS) {
			state.step(noMutation);
			var alive = GeodesicShapeSignature.aliveNodes(state, sphere);
			if (alive.length == 0) {
				Sys.println('  DIED at generation $generation');
				return;
			}
			if (alive.length > GeodesicGliderSearch.EXPLOSION_CAP) {
				Sys.println('  EXPLODED at generation $generation');
				return;
			}
			if ((generation + 1) % CHECKPOINT_INTERVAL == 0) {
				var driftFromOrigin = GeodesicShapeSignature.centroidDistance(sphere, origin, alive);
				var nearestPentagon = nearestDistance(pentagonDistances, alive);
				Sys.println('  generation ${generation + 1}: drift from spawn=${round(driftFromOrigin)}, nearest pentagon=${round(nearestPentagon)} hops, population=${alive.length}');
			}
		}
		Sys.println('  survived all $TOTAL_STEPS generations');
	}

	static function nearestDistance(pentagonDistances:Map<Int, Int>, alive:Array<Int>):Float {
		var best = 999.0;
		for (id in alive) {
			var d = pentagonDistances.get(id);
			if (d != null && d < best) {
				best = d;
			}
		}
		return best;
	}

	static function round(value:Float):String {
		return Std.string(Math.round(value * 1000) / 1000);
	}
}
