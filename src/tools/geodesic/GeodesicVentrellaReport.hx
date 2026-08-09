package tools.geodesic;

import tools.geodesic.GeodesicVentrellaRule.GeodesicVentrellaRules;
import tools.geodesic.GeodesicSphere.GeodesicSphereData;
import tools.geodesic.GeodesicVentrellaState.NeighborCountMode;

/**
	One-time exploratory report — not part of the permanent test suite or
	the regular build/bake pipeline, run by hand and read, the same way
	`GeodesicLifeReport` already is for the 2-state rules.

	Built directly in response to playing the real biome (2026-08-09):
	"very much 'not much' happening... everything dies in a few
	generations. Then, random isolated cells birth, then die." Rather than
	keep eyeballing that through the 3D renderer — this project's own
	`CLAUDE.md` already documents that Claude can't reliably drive the game
	interactively — this is pure computation over the same
	`GeodesicVentrellaState` the real biome runs, cheap enough to iterate
	on headlessly. `GeodesicLifeReport`'s own doc has the cautionary tale
	for why this kind of report has to be trusted carefully (a broken RNG
	source once produced a confidently wrong conclusion); this one reuses
	`SeededRandom`, the fix that came out of that.

	Two things `GeodesicLifeReport` doesn't need that this does:
	- **An early-generation trace**, not just a post-warmup steady-state
	  average. `GeodesicLifeReport`'s own `WARMUP` (50 generations) would
	  silently hide exactly the collapse being reported here if reused
	  as-is — this prints population every generation for the first
	  `TRACE_GENERATIONS`, at the real biome's own `GeodesicConwayBiome.SEED_DENSITY`,
	  so the collapse (or lack of one) is visible directly rather than
	  averaged away.
	- **A per-state breakdown**, not just total population. This rule has
	  three distinct live states (not one "alive"), and "random isolated
	  cells birth, then die" is exactly what `GeodesicVentrellaStateTest.testAnIsolatedCellCyclesThroughStatesBeforeDying`
	  already proved happens to any cell with no live neighbors — worth
	  seeing whether the real board's population is mostly that 3-generation
	  flicker (many cells, evenly split across states 1/2/3, none
	  interacting) versus genuine sustained structure.

	**First run's own finding (2026-08-09, `Clamp` only, the then-only
	mode): uniform near-total extinction.** `0.1%`-`0.3%` mean settled
	population at *every* tested density, `0.1` through `1.0` — density-
	independent collapse, which points at the neighbor-counting semantics
	rather than the seed (a real density effect would show *some* density
	sustaining better than others). `GeodesicVentrellaState.NeighborCountMode`
	was added in response, and this report now runs both modes side by
	side rather than assuming a fix: `Clamp` (the original reading, "3"
	means "3 or more" — most neighborhoods start mostly-quiescent, so a
	cell's own quiescent-neighbor count sits at its full raw degree, `5`
	or `6`, clamping straight to `3` and skipping every subrule that
	needs an *exact* count of `2`) versus `Proportional` (raw count
	scaled by the node's own actual degree, so "3" means "every
	neighbor" instead).
**/
class GeodesicVentrellaReport {
	static inline final FREQUENCY:Int = 6;
	static inline final GENERATIONS:Int = 200;
	static inline final WARMUP:Int = 50;
	static inline final TRACE_GENERATIONS:Int = 40;

	/** Matches `GeodesicConwayBiome.SEED_DENSITY` exactly — the trace is only useful if it's the density actually shipping. **/
	static inline final PRODUCTION_DENSITY:Float = 0.24;

	static final BOARD_SEEDS:Array<Int> = [1, 2, 3, 4, 5];
	static final SEED_DENSITIES:Array<Float> = [0.1, 0.24, 0.5, 0.75, 1.0];

	static final COUNT_MODES:Array<NeighborCountMode> = [Clamp, Proportional, Literal];

	public static function main():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		Sys.println('${sphere.neighbors.length} nodes, rule ${GeodesicVentrellaRules.SPHERE_CA.name}\n');

		for (mode in COUNT_MODES) {
			Sys.println('=== countMode $mode: early-generation trace at production density ($PRODUCTION_DENSITY), seed 1 ===');
			traceOneRun(sphere, mode, PRODUCTION_DENSITY, 1);
			Sys.println("");
		}

		for (mode in COUNT_MODES) {
			Sys.println('=== countMode $mode: steady-state sweep ($GENERATIONS generations, first $WARMUP discarded, averaged over ${BOARD_SEEDS.length} board seeds) ===');
			for (density in SEED_DENSITIES) {
				runDensity(sphere, mode, density);
			}
			Sys.println("");
		}
	}

	/** Population (broken down by state) every generation for the first `TRACE_GENERATIONS` — the collapse (or lack of one) `GeodesicLifeReport`'s own post-warmup averaging would hide. **/
	static function traceOneRun(sphere:GeodesicSphereData, mode:NeighborCountMode, density:Float, seed:Int):Void {
		var state = new GeodesicVentrellaState(sphere, GeodesicVentrellaRules.SPHERE_CA, mode);
		var rng = new SeededRandom(seed).asFunction();
		state.seed(density, rng);

		Sys.println('  gen  total  state1  state2  state3');
		printCounts(sphere, state, 0);
		for (generation in 1...TRACE_GENERATIONS + 1) {
			state.step(rng);
			printCounts(sphere, state, generation);
		}
	}

	static function printCounts(sphere:GeodesicSphereData, state:GeodesicVentrellaState, generation:Int):Void {
		var counts = stateCounts(sphere, state);
		Sys.println('  ${pad(Std.string(generation), 4)} ${pad(Std.string(counts.total), 6)} ${pad(Std.string(counts.s1), 7)} ${pad(Std.string(counts.s2), 7)} ${pad(Std.string(counts.s3), 7)}');
	}

	static function stateCounts(sphere:GeodesicSphereData, state:GeodesicVentrellaState):{
		total:Int,
		s1:Int,
		s2:Int,
		s3:Int
	} {
		var s1 = 0;
		var s2 = 0;
		var s3 = 0;
		for (id in 0...sphere.neighbors.length) {
			switch state.stateOf(id) {
				case 1:
					s1++;
				case 2:
					s2++;
				case 3:
					s3++;
				default:
			}
		}
		return {
			total: s1 + s2 + s3,
			s1: s1,
			s2: s2,
			s3: s3
		};
	}

	static function runDensity(sphere:GeodesicSphereData, mode:NeighborCountMode, density:Float):Void {
		var shareTotal = 0.0;
		var activityTotal = 0.0;
		var extinctions = 0;
		for (seed in BOARD_SEEDS) {
			var run = runSeed(sphere, mode, density, seed);
			shareTotal += run.meanShare;
			activityTotal += run.meanActivity;
			if (run.extinct) {
				extinctions++;
			}
		}
		var meanShare = shareTotal / BOARD_SEEDS.length;
		var meanActivity = activityTotal / BOARD_SEEDS.length;
		Sys.println('  density ${pad(Std.string(density), 5)} mean population ${pad(percent(meanShare), 8)} mean activity ${pad(round(meanActivity), 8)} went extinct in $extinctions of ${BOARD_SEEDS.length} runs');
	}

	static function runSeed(sphere:GeodesicSphereData, mode:NeighborCountMode, density:Float, seed:Int):{meanShare:Float, meanActivity:Float, extinct:Bool} {
		var state = new GeodesicVentrellaState(sphere, GeodesicVentrellaRules.SPHERE_CA, mode);
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

	static function averageActivity(state:GeodesicVentrellaState, sphere:GeodesicSphereData):Float {
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
