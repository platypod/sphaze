package biomes.ribbon;

import utest.Assert;
import utest.Test;

/**
	Checks the automaton against things that can be worked out by hand or
	looked up, rather than against itself.

	This matters more here than the file's size suggests. The Ribbon's
	entire claim — the reason
	`docs/game/world.md` puts a
	Turing-complete rule under the player's feet — is that the ground is
	*really* Rule 110. A neighbourhood indexed backwards, or an off-by-one
	at the edges, would produce a diagram that still looked like a
	plausible cellular automaton and would quietly be some other rule
	entirely. Nothing on screen would give it away.
**/
class RibbonAutomatonTest extends Test {
	static inline final WIDTH:Int = 21;
	static inline final SEED:Int = 18;

	function ruleOneTen(generations:Int):RibbonAutomaton {
		return new RibbonAutomaton(110, WIDTH, generations, SEED);
	}

	/** Which cells are live in a generation, as indices — easier to state an expectation against than an array of `Bool`. **/
	function liveIndices(automaton:RibbonAutomaton, generation:Int):Array<Int> {
		return [
			for (i in 0...automaton.width)
				if (automaton.isLive(generation, i)) i
		];
	}

	/**
		**The first four generations of Rule 110 from a single cell**,
		worked out by hand from Wolfram's numbering and checkable against
		any published diagram: one cell, then two, then three, then a gap
		opens. If the neighbourhood encoding were reversed this would be
		Rule 124 instead, and generation 1 would grow the other way.
	**/
	function testRuleOneTenMatchesTheKnownOpeningGenerations():Void {
		var automaton = ruleOneTen(4);

		Assert.same([SEED], liveIndices(automaton, 0), "generation 0 should be the single seed");
		Assert.same([SEED - 1, SEED], liveIndices(automaton, 1));
		Assert.same([SEED - 2, SEED - 1, SEED], liveIndices(automaton, 2));
		Assert.same([SEED - 3, SEED - 2, SEED], liveIndices(automaton, 3), "generation 3 should open a gap");
	}

	/**
		**Rule 110 never grows east**, which is what
		`RibbonModel.SEED_INDEX` relies on to place the seed two cells from
		that edge without wasting half the strip. Structural rather than
		incidental: no neighbourhood with a dead centre *and* a dead left
		neighbour produces a live cell, so the rightmost live cell can
		never advance.
	**/
	function testTheDiagramNeverGrowsEast():Void {
		var automaton = ruleOneTen(60);

		for (g in 0...automaton.generations()) {
			for (i in (SEED + 1)...automaton.width) {
				Assert.isFalse(automaton.isLive(g, i), 'cell $i came alive east of the seed at generation $g');
			}
		}
	}

	/** The west frontier advances exactly one cell per generation, until it reaches the edge — the growth rate the biome's own proportions are chosen against. **/
	function testTheWestFrontierAdvancesOneCellPerGeneration():Void {
		var automaton = ruleOneTen(SEED + 1);

		for (g in 0...automaton.generations()) {
			Assert.isTrue(automaton.isLive(g, SEED - g), 'the frontier was not live at generation $g');
			Assert.isFalse(automaton.isLive(g, SEED - g - 1), 'something was live ahead of the frontier at generation $g');
		}
	}

	/** Rule 0 sends everything to death in one step, rule 255 brings everything to life — the two ends of the numbering, and the cheapest possible check that the rule byte is read as a byte. **/
	function testTheDegenerateRulesBehave():Void {
		var dead = new RibbonAutomaton(0, WIDTH, 3, SEED);
		var alive = new RibbonAutomaton(255, WIDTH, 3, SEED);

		for (i in 0...WIDTH) {
			Assert.isFalse(dead.isLive(1, i), 'rule 0 left cell $i alive');
			Assert.isTrue(alive.isLive(1, i), 'rule 255 left cell $i dead');
		}
	}

	/** Rule 90 is a Sierpinski triangle and is symmetric about its seed — a rule that grows *both* ways, so this also proves the west-only result above is Rule 110's own behaviour and not an artifact of `step`. **/
	function testRuleNinetyIsSymmetric():Void {
		var middle = 10;
		var automaton = new RibbonAutomaton(90, WIDTH, 9, middle);

		for (g in 0...automaton.generations()) {
			for (offset in 0...9) {
				Assert.equals(automaton.isLive(g, middle - offset), automaton.isLive(g, middle + offset),
					'rule 90 was asymmetric at generation $g, offset $offset');
			}
		}
	}

	/** Anything off the diagram reads as dead, so collision and mesh building never have to bounds-check first. **/
	function testOffTheDiagramIsDead():Void {
		var automaton = ruleOneTen(4);

		Assert.isFalse(automaton.isLive(-1, SEED));
		Assert.isFalse(automaton.isLive(99, SEED));
		Assert.isFalse(automaton.isLive(0, -1));
		Assert.isFalse(automaton.isLive(0, WIDTH));
	}

	/** A strip with no cells, no generations, or a seed outside it is a programming mistake rather than a degenerate world, so it fails loudly. **/
	function testRejectsAnImpossibleStrip():Void {
		Assert.raises(() -> new RibbonAutomaton(110, 0, 4, 0), String);
		Assert.raises(() -> new RibbonAutomaton(110, WIDTH, 0, 0), String);
		Assert.raises(() -> new RibbonAutomaton(110, WIDTH, 4, WIDTH), String);
	}
}
