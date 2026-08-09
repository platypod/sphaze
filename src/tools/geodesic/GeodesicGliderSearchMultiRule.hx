package tools.geodesic;

import tools.geodesic.GeodesicLifeRule.GeodesicLifeRules;
import tools.geodesic.GeodesicSphere.GeodesicSphereData;

/**
	Exhaustive multi-rule search across B2/S34 baseline, B24/S46, and B35/S2,
	comparing spaceship/glider richness across each rule.

	Methodology: same 2-ring patch and population range (3-5 cells) as
	`GeodesicGliderSearch2`, but sweeps across multiple rules to discover
	whether alternative rules produce richer structures. Each rule gets its
	own screening and confirmation pass, logging summary statistics per rule.

	Run by hand (`neko` target) and compare results side-by-side.
**/
class GeodesicGliderSearchMultiRule {
	static inline final FREQUENCY:Int = 10;
	static inline final MIN_POPULATION:Int = 3;
	static inline final MAX_POPULATION:Int = 5;

	static inline final SCREEN_STEPS:Int = 40;
	static inline final SCREEN_CONFIRM_PERIODS:Int = 2;
	static inline final SCREEN_MAX_PERIOD:Int = 10;
	static inline final DRIFT_EPSILON:Float = 0.01;
	static inline final EXPLOSION_CAP:Int = 25;

	static inline final CONFIRM_STEPS:Int = 2000;
	static inline final CONFIRM_CHECKPOINT:Int = 20;

	static var sphere:GeodesicSphereData;
	static var patch:Array<Int>;
	static var candidates:Array<Array<Int>>;

	public static function main():Void {
		sphere = GeodesicSphere.generate(FREQUENCY);
		var center = GeodesicGliderPatterns.flattestNode(sphere);
		patch = ring2(sphere, center);
		candidates = populationRangeSubsets(patch, MIN_POPULATION, MAX_POPULATION);

		Sys.println('=== MULTI-RULE GLIDER SEARCH ===');
		Sys.println('${sphere.neighbors.length} nodes, center $center, patch size ${patch.length}, ${candidates.length} candidates (population $MIN_POPULATION-$MAX_POPULATION)');
		Sys.println('');

		var rulesToTest = [GeodesicLifeRules.B2_S34, GeodesicLifeRules.B24_S46, GeodesicLifeRules.B35_S2];

		var results:Map<String, {screened:Int, confirmed:Int, travelers:Array<{cells:Array<Int>, driftRate:Float}>}> = new Map();

		for (rule in rulesToTest) {
			Sys.println('--- Testing rule ${rule.name} ---');
			var ruleResults = searchRule(rule);
			results.set(rule.name, ruleResults);
			Sys.println('Rule ${rule.name}: ${candidates.length} candidates → ${ruleResults.screened} screened → ${ruleResults.confirmed} confirmed travelers');
			if (ruleResults.travelers.length > 0) {
				for (traveler in ruleResults.travelers) {
					Sys.println('  [${rule.name}] pop=${traveler.cells.length} drift=${round(traveler.driftRate)}/step cells=${traveler.cells}');
				}
			}
			Sys.println('');
		}

		Sys.println('=== SUMMARY ===');
		for (rule in rulesToTest) {
			var r = results.get(rule.name);
			Sys.println('${rule.name}: ${r.screened} screened, ${r.confirmed} confirmed travelers');
		}
	}

	static function searchRule(rule:GeodesicLifeRule):{screened:Int, confirmed:Int, travelers:Array<{cells:Array<Int>, driftRate:Float}>} {
		var screened = 0;
		var confirmed = 0;
		var travelers:Array<{cells:Array<Int>, driftRate:Float}> = [];

		for (cells in candidates) {
			var drift = screen(rule, cells);
			if (drift == null) {
				continue;
			}
			screened++;
			var travels = confirmTravels(rule, cells);
			if (travels != null) {
				confirmed++;
				travelers.push({cells: cells, driftRate: travels});
			}
		}

		return {screened: screened, confirmed: confirmed, travelers: travelers};
	}

	static function screen(rule:GeodesicLifeRule, cells:Array<Int>):Null<Float> {
		var state = new GeodesicLifeState(sphere, rule);
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
					return null;
				}
			}
		}
		return null;
	}

	static function confirmTravels(rule:GeodesicLifeRule, cells:Array<Int>):Null<Float> {
		var state = new GeodesicLifeState(sphere, rule);
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
				return null;
			}
			if ((generation + 1) % CONFIRM_CHECKPOINT == 0) {
				var drift = GeodesicShapeSignature.centroidDistance(sphere, origin, alive);
				stillGrowing = drift > maxDrift + DRIFT_EPSILON;
				maxDrift = Math.max(maxDrift, drift);
				lastCheckpointDrift = drift;
			}
		}
		if (stillGrowing && lastCheckpointDrift > 0.3) {
			return lastCheckpointDrift / (CONFIRM_STEPS / CONFIRM_CHECKPOINT);
		}
		return null;
	}

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
