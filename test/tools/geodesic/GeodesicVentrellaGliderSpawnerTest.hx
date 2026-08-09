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

	/** Every one of the 12 pentagons gets its own site — over enough generations to cover every site's own phase, every one should launch at least once. **/
	function testEveryPentagonEventuallyLaunches():Void {
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

		for (pentagon in pentagons) {
			var anchor = sphere.neighbors[pentagon][0];
			var anchorOrNeighborAlive = everAlive.exists(anchor);
			for (neighbor in sphere.neighbors[anchor]) {
				anchorOrNeighborAlive = anchorOrNeighborAlive || everAlive.exists(neighbor);
			}
			Assert.isTrue(anchorOrNeighborAlive, 'pentagon $pentagon\'s own site (anchor $anchor) never seems to have launched a glider');
		}
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
