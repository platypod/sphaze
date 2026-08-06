package tools.geodesic;

import tools.geodesic.GeodesicLifeRule.GeodesicLifeRules;
import tools.geodesic.GeodesicSphere.GeodesicSphereData;

/**
	One-time investigation probe, not part of the permanent test suite —
	run by hand (`neko` target, reading the checked-in baked resource
	directly off disk since there's no `hxd.Res` outside a real Heaps app)
	and read.

	Reported after play: "Nothing's gliding... are we using two pentagons
	too close to one another? They seem to be fighting" — a screenshot
	showed a large, clearly-green (not `Colours.CONWAY_TILE_GLIDER` amber)
	blob of live cells between two pentagons, far bigger than one 12-cell
	spaceship. This replicates `GeodesicConwayBiome`'s own exact
	construction (real baked fine sphere, real `GeodesicGliderTracker`,
	real `noRandomBirths`-gated `GeodesicLifeState.step`) headlessly and
	logs population/tracked-count whenever they disagree, or every 20
	generations otherwise.

	**Found the real bug, not a pentagon-spacing problem.** Before the fix,
	`tracked` dropped to `0` within a handful of generations of every spawn
	and never recovered — `GeodesicGliderTracker.relocateActive` required an
	*exact* population/shape match every generation, but
	`xq14_0ig5l3z102` itself breathes between 10 and 12 live cells across
	its own 14-generation period, so the very first off-12 generation broke
	tracking for good. Worse: a tracker that thinks its glider is lost marks
	the site due for a fresh spawn — so the *same* site kept reseeding a
	second copy of the pattern directly on top of the first one, which was
	still alive and traveling, untracked. That collision (two copies of one
	site's own glider, not two different pentagons fighting) is what
	produced the reported blob. Fixed in `relocateActive` — see its own
	doc. Verified here: 1500 generations, `population == tracked` at every
	logged checkpoint, no untracked growth, no collision blob.
**/
class GeodesicBiomeReplay {
	static inline final TOTAL_GENERATIONS:Int = 1500;
	static inline final RESOURCE_PATH:String = "res/geodesic/conway-sphere.json";

	public static function main():Void {
		var json = sys.io.File.getContent(RESOURCE_PATH);
		var loaded = GeodesicSphere.fromJson(json);
		var sphere = loaded.sphere;
		Sys.println('${sphere.neighbors.length} nodes (frequency ${loaded.frequency})');

		var state = new GeodesicLifeState(sphere, GeodesicLifeRules.DEFAULT);
		var tracker = new GeodesicGliderTracker(sphere);
		var noRandomBirths = () -> 1.0;

		for (generation in 0...TOTAL_GENERATIONS) {
			state.step(noRandomBirths);
			tracker.tick(state);

			var population = 0;
			for (id in 0...sphere.neighbors.length) {
				if (state.isAlive(id)) {
					population++;
				}
			}
			var tracked = tracker.trackedCellIds().length;

			if (population != tracked) {
				Sys.println('generation ${generation + 1}: population=$population, tracked=$tracked, UNTRACKED=${population - tracked}');
			} else if ((generation + 1) % 20 == 0) {
				Sys.println('generation ${generation + 1}: population=$population, tracked=$tracked');
			}
		}
	}
}
