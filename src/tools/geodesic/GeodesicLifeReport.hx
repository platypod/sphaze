package tools.geodesic;

import tools.geodesic.GeodesicLifeRule.GeodesicLifeRules;
import tools.geodesic.GeodesicSphere.GeodesicSphereData;

/** One condition's outcome, so a summary table can be printed after the run rather than eyeballed out of the per-generation trace. **/
typedef RuleOutcome = {
	var rule:String;
	var density:Float;

	/** How many of `GeodesicLifeReport.BOARD_SEEDS`' own runs hit zero population at any point. **/
	var extinctAt:Int;

	var meanShare:Float;
	var meanActivity:Float;
}

/**
	One-time exploratory report — not part of the permanent test suite or
	the regular build/bake pipeline, run by hand and read, the same way a
	throwaway analysis script would be.

	**This is the second version.** The first one's numbers were worthless
	and its conclusion ("all four candidate rules are statistically
	indistinguishable, all converging to a noisy ~50% equilibrium") was an
	artifact of its own randomness source: it used the xorshift32 from
	`test.biomes.maze.MazeGeneratorTest`, which is correct on JS but returns
	*negative, non-uniform* values on neko — the target this report runs on.
	`rng() < GeodesicLifeState.MUTATION_RATE` therefore fired on ~50% of
	nodes every generation instead of `0.08%`, so all four rules were
	measured as the same coin flip. See `SeededRandom`'s own doc for the
	measurements that caught it.

	It now uses `SeededRandom`, which is uniform on every target, and
	averages every condition over several board seeds.

	The version in between this one and that one swept **maze openness**
	alongside the rule, and that sweep is what settled the design: every
	rule died within ~5 generations on a bare carve (~2 open edges per
	node), and `B2/S23` only came alive past ~5 of 6 — from which the
	wall-gating came out of `GeodesicLifeState` entirely. The sweep is gone
	with it, since walls no longer touch this simulation and the axis would
	now be flat by construction. Its numbers are preserved in
	`docs/building/notes/geodesic-sphere-engineering.md`'s own Phase 5
	entry, which is where to look before reintroducing any gate.

	What's left is the comparison this was originally supposed to be: the
	four candidate rules against each other, across seed densities.
**/
class GeodesicLifeReport {
	static inline final FREQUENCY:Int = 6;
	static inline final GENERATIONS:Int = 200;

	/** Generations discarded before averaging, so the summary describes settled behavior rather than the seed. **/
	static inline final WARMUP:Int = 50;

	/** Board seeds every condition is averaged over — one seed is exactly the thin evidence that let the first version of this report reach a confident wrong answer. **/
	static final BOARD_SEEDS:Array<Int> = [1, 2, 3, 4, 5];

	/** Starting live share, swept so a rule that only works from one particular soup can't pass as a rule that works. **/
	static final SEED_DENSITIES:Array<Float> = [0.1, 0.24, 0.5];

	public static function main():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		Sys.println('${sphere.neighbors.length} nodes, $GENERATIONS generations (first $WARMUP discarded as warm-up), averaged over ${BOARD_SEEDS.length} board seeds');

		var outcomes:Array<RuleOutcome> = [];
		for (density in SEED_DENSITIES) {
			Sys.println('\n=== seed density $density ===');
			for (rule in GeodesicLifeRules.ALL) {
				outcomes.push(runOne(sphere, density, rule));
			}
		}
		printSummary(outcomes);
	}

	/** Runs `rule` once per entry in `BOARD_SEEDS` and averages, so a single lucky or unlucky soup can't carry the conclusion. **/
	static function runOne(sphere:GeodesicSphereData, density:Float, rule:GeodesicLifeRule):RuleOutcome {
		var shareTotal = 0.0;
		var activityTotal = 0.0;
		var extinctions = 0;
		for (seed in BOARD_SEEDS) {
			var run = runSeed(sphere, density, rule, seed);
			shareTotal += run.meanShare;
			activityTotal += run.meanActivity;
			if (run.extinct) {
				extinctions++;
			}
		}

		var outcome:RuleOutcome = {
			rule: rule.name,
			density: density,
			extinctAt: extinctions,
			meanShare: shareTotal / BOARD_SEEDS.length,
			meanActivity: activityTotal / BOARD_SEEDS.length
		};
		Sys.println('  ${pad(rule.name, 8)} mean population ${pad(percent(outcome.meanShare), 8)} mean activity ${pad(round(outcome.meanActivity), 8)} went extinct in $extinctions of ${BOARD_SEEDS.length} runs');
		return outcome;
	}

	static function runSeed(sphere:GeodesicSphereData, density:Float, rule:GeodesicLifeRule, seed:Int):{meanShare:Float, meanActivity:Float, extinct:Bool} {
		var state = new GeodesicLifeState(sphere, rule);
		var rng = new SeededRandom(seed).asFunction();
		state.seed(density, rng);

		var nodes = sphere.neighbors.length;
		var extinct = false;
		var shareTotal = 0.0;
		var activityTotal = 0.0;
		var sampled = 0;

		for (generation in 0...GENERATIONS) {
			state.step(rng);
			if (state.population() == 0) {
				extinct = true;
			}
			if (generation >= WARMUP) {
				shareTotal += state.population() / nodes;
				activityTotal += averageActivity(state, sphere);
				sampled++;
			}
		}
		return {
			meanShare: sampled == 0 ? 0 : shareTotal / sampled,
			meanActivity: sampled == 0 ? 0 : activityTotal / sampled,
			extinct: extinct
		};
	}

	static function printSummary(outcomes:Array<RuleOutcome>):Void {
		Sys.println("\n=== summary: mean live share once settled, by rule and seed density ===");
		Sys.println('  ${pad("density", 10)}${[for (rule in GeodesicLifeRules.ALL) pad(rule.name, 10)].join("")}');
		for (density in SEED_DENSITIES) {
			var cells = [
				for (rule in GeodesicLifeRules.ALL) {
					var found = outcomes.filter((outcome) -> outcome.rule == rule.name && outcome.density == density);
					pad(found.length == 0 ? "-" : percent(found[0].meanShare), 10);
				}
			];
			Sys.println('  ${pad(Std.string(density), 10)}${cells.join("")}');
		}
	}

	static function averageActivity(state:GeodesicLifeState, sphere:GeodesicSphereData):Float {
		var total = 0.0;
		for (id in 0...sphere.neighbors.length) {
			total += state.activityOf(id);
		}
		return total / sphere.neighbors.length;
	}

	static function percent(share:Float):String {
		return '${Math.round(share * 1000) / 10}%';
	}

	static function round(value:Float):String {
		return Std.string(Math.round(value * 1000) / 1000);
	}

	static function pad(text:String, width:Int):String {
		var padded = text;
		while (padded.length < width) {
			padded += " ";
		}
		return padded;
	}
}
