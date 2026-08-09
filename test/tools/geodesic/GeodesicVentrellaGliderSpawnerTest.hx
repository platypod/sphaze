package tools.geodesic;

import tools.geodesic.GeodesicVentrellaRule.GeodesicVentrellaRules;
import utest.Assert;
import utest.Test;

class GeodesicVentrellaGliderSpawnerTest extends Test {
	static inline final FREQUENCY:Int = 10;

	function testTickAtGenerationZeroLaunchesAtLeastOneSite():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var spawner = new GeodesicVentrellaGliderSpawner(sphere);
		var state = new GeodesicVentrellaState(sphere, GeodesicVentrellaRules.SPHERE_CA);

		spawner.tick(state, 0);

		Assert.isTrue(state.population() > 0, "the phase-0 site should launch immediately, not wait a full interval");
	}

	/** Only every `PENTAGON_STRIDE`-th pentagon (by its own index into `GeodesicSphere.pentagons`) gets a site — over enough generations to cover every active site's own phase, each of those should launch at least once. **/
	function testEveryActivePentagonEventuallyLaunches():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var pentagons = GeodesicSphere.pentagons(sphere);
		var spawner = new GeodesicVentrellaGliderSpawner(sphere);
		var state = new GeodesicVentrellaState(sphere, GeodesicVentrellaRules.SPHERE_CA);

		var everAlive = new Map<Int, Bool>();
		for (generation in 0...40) {
			spawner.tick(state, generation);
			for (id in 0...sphere.neighbors.length) {
				if (state.isAlive(id)) {
					everAlive.set(id, true);
				}
			}
			state.step(() -> 1.0);
		}

		for (i in 0...pentagons.length) {
			if (i % GeodesicVentrellaGliderSpawner.PENTAGON_STRIDE != 0) {
				continue; // not an active site — nothing to assert about it directly
			}
			var anchor = sphere.neighbors[pentagons[i]][0];
			var anchorOrNeighborAlive = everAlive.exists(anchor);
			for (neighbor in sphere.neighbors[anchor]) {
				anchorOrNeighborAlive = anchorOrNeighborAlive || everAlive.exists(neighbor);
			}
			Assert.isTrue(anchorOrNeighborAlive, 'pentagon ${pentagons[i]}\'s own site (anchor $anchor) never seems to have launched a glider');
		}
	}

	/** Exactly `ceil(12 / PENTAGON_STRIDE)` sites are active, not all 12 — the actual fix for "spawning too much stuff." **/
	function testOnlyAFractionOfPentagonsAreActive():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var pentagons = GeodesicSphere.pentagons(sphere);
		var expectedActive = Math.ceil(pentagons.length / GeodesicVentrellaGliderSpawner.PENTAGON_STRIDE);

		var spawner = new GeodesicVentrellaGliderSpawner(sphere);

		Assert.equals(Std.int(expectedActive), spawner.siteCount);
	}

	/**
		The phase-`0` site fires again at generation `SPAWN_INTERVAL` — a
		fresh state each time, deliberately not simulated forward between
		checks, since the confirmed glider's own natural lifespan (~100
		generations, `GeodesicVentrellaFigure2`'s own trace) is far longer
		than `SPAWN_INTERVAL`, so "does the board go quiet in between" isn't
		a real signal here — only the spawner's own cadence is.
	**/
	function testASiteFiresAtItsOwnPhasePlusSpawnInterval():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var spawner = new GeodesicVentrellaGliderSpawner(sphere);

		var stateAtInterval = new GeodesicVentrellaState(sphere, GeodesicVentrellaRules.SPHERE_CA);
		spawner.tick(stateAtInterval, GeodesicVentrellaGliderSpawner.SPAWN_INTERVAL);
		Assert.isTrue(stateAtInterval.population() > 0, "the phase-0 site should fire again exactly one SPAWN_INTERVAL after generation 0");

		var stateJustBefore = new GeodesicVentrellaState(sphere, GeodesicVentrellaRules.SPHERE_CA);
		spawner.tick(stateJustBefore, GeodesicVentrellaGliderSpawner.SPAWN_INTERVAL - 1);
		Assert.equals(0, stateJustBefore.population(), "no site's own phase should land exactly one generation early");
	}
}
