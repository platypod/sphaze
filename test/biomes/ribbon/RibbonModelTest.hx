package biomes.ribbon;

import utest.Assert;
import utest.Test;

/**
	Covers the world↔cell mapping and the strip's own edges.

	The round-trip tests are the load-bearing ones: an off-by-half in
	either direction would put the relief the player walks on out of step
	with the relief they can see, by exactly one cell — close enough to
	look right in a screenshot and wrong enough to feel like the ground
	is lying.
**/
class RibbonModelTest extends Test {
	/** Every cell's own centre maps back to that cell — the invariant that keeps walked ground and drawn ground the same ground. **/
	function testCellCentresRoundTrip():Void {
		for (i in 0...RibbonModel.WIDTH) {
			Assert.equals(i, RibbonModel.cellIndexAt(RibbonModel.xOf(i)), 'cell $i did not round trip');
		}
		for (g in 0...RibbonModel.GENERATIONS) {
			Assert.equals(g, RibbonModel.generationAt(RibbonModel.zOf(g)), 'generation $g did not round trip');
		}
	}

	/** And so does anywhere within a cell, not just its exact centre. **/
	function testAnywhereWithinACellMapsToThatCell():Void {
		var nudge = RibbonModel.CELL_SIZE * 0.49;

		for (i in 0...RibbonModel.WIDTH) {
			Assert.equals(i, RibbonModel.cellIndexAt(RibbonModel.xOf(i) - nudge), 'the west side of cell $i mapped elsewhere');
			Assert.equals(i, RibbonModel.cellIndexAt(RibbonModel.xOf(i) + nudge), 'the east side of cell $i mapped elsewhere');
		}
	}

	/** Positions past either edge clamp into the strip rather than indexing outside it. **/
	function testOutOfRangePositionsClamp():Void {
		Assert.equals(0, RibbonModel.cellIndexAt(-99999));
		Assert.equals(RibbonModel.WIDTH - 1, RibbonModel.cellIndexAt(99999));
		Assert.equals(0, RibbonModel.generationAt(-99999));
		Assert.equals(RibbonModel.GENERATIONS - 1, RibbonModel.generationAt(99999));
	}

	/** The strip holds the player in, per axis, so walking into a boundary slides along it. **/
	function testClampToBoundsHoldsThePlayerOnTheStrip():Void {
		var beyond = RibbonModel.clampToBounds(new h3d.Vector(99999, 3, 99999));
		Assert.floatEquals(RibbonModel.HALF_WIDTH, beyond.x);
		Assert.floatEquals(RibbonModel.PRESENT_EDGE, beyond.z);
		Assert.floatEquals(3, beyond.y, "clamping should not touch height");

		var before = RibbonModel.clampToBounds(new h3d.Vector(-99999, 0, -99999));
		Assert.floatEquals(-RibbonModel.HALF_WIDTH, before.x);
		Assert.floatEquals(RibbonModel.PAST_EDGE, before.z, "the world should end just past generation 0");
	}

	/** A position already inside is left exactly alone. **/
	function testClampLeavesAnInteriorPositionAlone():Void {
		var inside = new h3d.Vector(RibbonModel.xOf(5), 0, RibbonModel.zOf(7));
		var clamped = RibbonModel.clampToBounds(inside);

		Assert.floatEquals(inside.x, clamped.x);
		Assert.floatEquals(inside.z, clamped.z);
	}

	/** Relief follows the automaton exactly: raised over live cells, flat over dead ones. **/
	function testGroundHeightFollowsTheAutomaton():Void {
		var automaton = new RibbonAutomaton(RibbonModel.RULE, RibbonModel.WIDTH, RibbonModel.GENERATIONS, RibbonModel.SEED_INDEX);

		for (g in 0...12) {
			for (i in 0...RibbonModel.WIDTH) {
				var at = new h3d.Vector(RibbonModel.xOf(i), 0, RibbonModel.zOf(g));
				var expected = RibbonModel.baseHeightAt(at.z) + (automaton.isLive(g, i) ? RibbonModel.RELIEF : 0);
				Assert.floatEquals(expected, RibbonModel.groundHeightAt(automaton, at), 'wrong ground height over cell ($g, $i)');
			}
		}
	}

	/**
		**The strip descends into the past**, which is what makes the
		diagram legible as landscape rather than as a uniform plane — see
		`RibbonModel.DESCENT_PER_GENERATION`, and the flat version that
		did not work.
	**/
	function testTheGroundDescendsIntoThePast():Void {
		Assert.floatEquals(0, RibbonModel.baseHeightAt(RibbonModel.zOf(0)), "generation 0 should be the lowest point");

		var previous = -1.0;
		for (g in 0...RibbonModel.GENERATIONS) {
			var height = RibbonModel.baseHeightAt(RibbonModel.zOf(g));
			Assert.isTrue(height > previous, 'the ground did not rise toward the present at generation $g');
			previous = height;
		}
	}

	/** Relief sits *on* the slope rather than replacing it, so a live cell high on the strip still stands above its own dead neighbours. **/
	function testReliefStacksOnTopOfTheSlope():Void {
		var automaton = new RibbonAutomaton(RibbonModel.RULE, RibbonModel.WIDTH, RibbonModel.GENERATIONS, RibbonModel.SEED_INDEX);
		var g = RibbonModel.GENERATIONS - 1;
		var base = RibbonModel.baseHeightAt(RibbonModel.zOf(g));

		for (i in 0...RibbonModel.WIDTH) {
			var at = new h3d.Vector(RibbonModel.xOf(i), 0, RibbonModel.zOf(g));
			var height = RibbonModel.groundHeightAt(automaton, at);
			Assert.isTrue(height >= base, 'cell $i sank below the slope');
			Assert.isTrue(height <= base + RibbonModel.RELIEF, 'cell $i rose above the slope plus one relief');
		}
	}

	/**
		**The seed's own cell is the one the monolith stands on**, and the
		oldest generation really is a single live cell — the beat the whole
		walk exists to arrive at. Worth pinning because
		`RibbonMesh.addMonolith` places the marker from `SEED_INDEX`
		independently of the automaton, so the two could drift apart
		silently.
	**/
	function testGenerationZeroIsTheLoneSeedUnderTheMonolith():Void {
		var automaton = new RibbonAutomaton(RibbonModel.RULE, RibbonModel.WIDTH, RibbonModel.GENERATIONS, RibbonModel.SEED_INDEX);

		for (i in 0...RibbonModel.WIDTH) {
			Assert.equals(i == RibbonModel.SEED_INDEX, automaton.isLive(0, i), 'generation 0 was wrong at cell $i');
		}
	}
}
