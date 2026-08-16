package biomes.sprawl;

import biomes.common.space.hyperbolic.HyperbolicSpace;
import utest.Assert;
import utest.Test;

/**
	Covers the one place this biome deliberately reuses machinery that is
	*wrong* for it, plus the spawn that depends on that reuse being right.

	`entities.painting.PaintingModel.triggeredBy` measures ambient
	Euclidean distance, which is meaningless between two hyperboloid
	coordinates. `SprawlBiome.exitPaintings` argues it is nonetheless
	exactly correct against a painting sitting at the model origin, by the
	hyperboloid's rotational symmetry about its own axis. An argument in a
	doc comment is not a check, and this is precisely the sort of claim
	that would hold near the origin, fail far from it, and look fine in a
	screenshot either way — so it is checked here instead.
**/
class SprawlBiomeTest extends Test {
	function home():h3d.Vector {
		return new h3d.Vector(0, 0, SprawlBiome.CURVATURE_RADIUS);
	}

	/** A unit tangent at the origin, `angle` radians round from `+x`. **/
	function tangentAt(angle:Float):h3d.Vector {
		return new h3d.Vector(Math.cos(angle), Math.sin(angle), 0);
	}

	/**
		**Euclidean distance from home really is a function of hyperbolic
		distance from home** — the same intrinsic distance walked in eight
		different directions must land at the same Euclidean radius, and at
		the one `euclideanRadiusOf` predicts. This is what licenses the
		stock Euclidean trigger; without it, walking in one direction would
		reach the exit sooner than walking in another.
	**/
	function testEuclideanDistanceFromHomeDependsOnlyOnHyperbolicDistance():Void {
		var space = new HyperbolicSpace(SprawlBiome.CURVATURE_RADIUS);

		for (intrinsic in [0.1, 0.5, 1.09, 3.0]) {
			var expected = SprawlBiome.euclideanRadiusOf(intrinsic);
			for (step in 0...8) {
				var direction = tangentAt(step * Math.PI / 4);
				var walked = space.moveAlong(home(), direction, direction, intrinsic * SprawlBiome.CURVATURE_RADIUS, SprawlBiome.CURVATURE_RADIUS);

				Assert.floatEquals(expected, walked.pos.sub(home()).length(), 1e-4,
					'walking $intrinsic in direction $step landed at a different euclidean radius');
			}
		}
	}

	/** Strictly increasing, so a Euclidean threshold is a hyperbolic threshold rather than merely correlating with one. **/
	function testEuclideanRadiusIsStrictlyIncreasing():Void {
		var previous = -1.0;
		for (step in 0...40) {
			var radius = SprawlBiome.euclideanRadiusOf(step * 0.2);
			Assert.isTrue(radius > previous, 'euclidean radius did not increase at step $step');
			previous = radius;
		}
	}

	/** Zero maps to zero — the home tile's own centre is the painting's own position, not merely near it. **/
	function testHomeIsAtEuclideanZero():Void {
		Assert.floatEquals(0, SprawlBiome.euclideanRadiusOf(0), 1e-12);
	}

	/**
		**The spawn does not stand on the exit.** Spawning inside the home
		painting's trigger radius would warp the player back to the hub on
		their first tick — a bounce that would read as "the biome is
		broken", not as a subtle geometry bug, and one that only shows up
		when the two constants involved are compared.
	**/
	function testSpawnIsOutsideTheExitTrigger():Void {
		var biome = new SprawlBiome();
		var player = biome.spawnPlayer(false, null);

		for (painting in biome.exitPaintings()) {
			Assert.isFalse(painting.triggeredBy(player.pos), "the player spawns on top of the exit painting");
		}
	}

	/** The spawn faces home, so the landmark the player is meant to walk back to is the first thing they see. **/
	function testSpawnFacesHome():Void {
		var biome = new SprawlBiome();
		var space = new HyperbolicSpace(SprawlBiome.CURVATURE_RADIUS);
		var player = biome.spawnPlayer(false, null);

		var startDistance = space.distance(player.pos, home());
		var afterAStep = space.moveAlong(player.pos, player.forward, player.forward, 1.0, SprawlBiome.CURVATURE_RADIUS);

		Assert.isTrue(space.distance(afterAStep.pos, home()) < startDistance, "walking forward from the spawn should approach home");
	}
}
