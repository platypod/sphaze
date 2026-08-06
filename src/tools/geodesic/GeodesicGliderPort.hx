package tools.geodesic;

import tools.geodesic.GeodesicLifeRule.GeodesicLifeRules;
import tools.geodesic.GeodesicSphere.GeodesicSphereData;

/**
	One-time exploratory probe, not part of the permanent test suite — run
	by hand (`neko` target) and read.

	`GeodesicGliderSearch`'s own 1-ring exhaustive search never found a real
	traveler under `B2/S34` — everything confirmed was a bounded shuttle
	(`GeodesicGliderTrajectory`'s own finding). Web research turned up
	`xq14_0ig5l3z102`: a real, confirmed period-14 spaceship in `B2/S34H`
	(Golly/Catagolue's own name for exactly this rule on a hexagonal
	neighborhood — the same `GeodesicLifeRules.B2_S34`), found by Catagolue's
	own distributed soup search across ~100 billion random soups.

	**Coordinate-convention story.** Its 12 cells (decoded from the apgcode
	via Catagolue's own `decodeCanon` algorithm, `rle_tools.js`) come as
	`(x,y)` pairs in a hex-on-square embedding. First guess at which
	diagonal pair of Moore-neighborhood corners the hex neighborhood keeps —
	`(x+1,y-1)`/`(x-1,y+1)`, the convention most web sources describe —
	collapsed the pattern to a trivial 3-cell fragment within 15 generations
	when checked on a plain flat hex grid (Python, outside this codebase).
	The other diagonal pair, `(x+1,y+1)`/`(x-1,y-1)`, reproduces the pattern
	exactly: generation 14's live set is generation 0's, shifted by
	`(-1,-1)` — genuinely period-14, genuinely translating. Under that
	convention `(1,0)` and `(0,1)` are neighbors of a shared origin cell but
	*not of each other*, so they sit 120° apart, not 60° —
	`GeodesicGliderPatterns.hexBasis` picks its two basis neighbors two
	apart in angle-sorted order for exactly this reason.

	**Result on this sphere: a real traveler, not a shuttle.** Placed via
	`GeodesicGliderPatterns.placeKnownSpaceship` and stepped under
	`GeodesicLifeRules.B2_S34`: population holds at exactly 12 for 8 clean
	periods (112 generations), with centroid drift from the spawn point
	growing steadily each period (`0.116, 0.232, 0.35, ..., 0.913` — linear,
	not the shuttles' back-and-forth oscillation) — real, sustained net
	travel. It breaks apart at generation ~126, the exact moment its own
	nearest-pentagon distance hits `0` hops: it flew into a pinch point and
	dissolved into a small stable residual oscillator rather than crashing
	or exploding. This is now what `GeodesicGliderTracker` actually spawns.
**/
class GeodesicGliderPort {
	static inline final FREQUENCY:Int = 10;
	static inline final TOTAL_STEPS:Int = 2000;
	static inline final CHECKPOINT_INTERVAL:Int = 14; // this pattern's own period
	static inline final EXPLOSION_CAP:Int = 60;

	public static function main():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var anchor = GeodesicGliderPatterns.flattestNode(sphere);
		Sys.println('${sphere.neighbors.length} nodes, anchor $anchor, placing xq14_0ig5l3z102 (12 cells)');

		var cells = GeodesicGliderPatterns.placeKnownSpaceship(sphere, anchor);
		if (cells == null) {
			Sys.println("placement failed (ran into a pentagon, or curvature drift collapsed the walk onto itself) — try a different anchor");
			return;
		}

		var state = new GeodesicLifeState(sphere, GeodesicLifeRules.B2_S34);
		for (id in cells) {
			state.seedSingle(id);
		}
		var noMutation = () -> 1.0;
		var origin = cells.copy();
		var pentagonDistances = GeodesicShapeSignature.multiSourceBfs(sphere, GeodesicSphere.pentagons(sphere));

		for (generation in 0...TOTAL_STEPS) {
			state.step(noMutation);
			var alive = GeodesicShapeSignature.aliveNodes(state, sphere);
			if (alive.length == 0) {
				Sys.println('  DIED at generation $generation');
				return;
			}
			if (alive.length > EXPLOSION_CAP) {
				Sys.println('  EXPLODED at generation $generation');
				return;
			}
			if ((generation + 1) % CHECKPOINT_INTERVAL == 0) {
				var drift = GeodesicShapeSignature.centroidDistance(sphere, origin, alive);
				var nearestPentagon = nearestDistance(pentagonDistances, alive);
				Sys.println('  generation ${generation + 1}: population=${alive.length}, drift from spawn=${round(drift)}, nearest pentagon=${nearestPentagon} hops');
			}
		}
		Sys.println('  survived all $TOTAL_STEPS generations');
	}

	static function nearestDistance(pentagonDistances:Map<Int, Int>, alive:Array<Int>):Int {
		var best = 999;
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
