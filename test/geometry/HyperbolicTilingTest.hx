package geometry;

import utest.Assert;
import utest.Test;

/**
	Checks that `HyperbolicTiling` really produces the `{p,q}` tilings it
	claims, and — the point of the exercise — measures the growth rate that
	the whole direction in `docs/game/` rests on.

	This is the headless half of Risk 2's Phase 0 spike: before designing a
	biome around an automaton on `{7,3}`, establish that the tiling can be
	generated, that its faces have the neighbour count the theory predicts
	(**seven**, not three — see that risk's own correction note), and that
	it grows exponentially.
**/
class HyperbolicTilingTest extends Test {
	/** `{7,3}` — Margenstern's ternary heptagrid, the Sprawl's proposed substrate. **/
	function testTheHeptagridGivesEveryInteriorFaceSevenNeighbours():Void {
		var tiling = new HyperbolicTiling(7, 3, 3);
		var interior = tiling.interiorFaces();

		Assert.isTrue(interior.length > 0, "a 3-ring heptagrid patch should have interior faces");
		for (id in interior) {
			Assert.equals(7, tiling.neighbors[id].length, 'face $id should have 7 neighbours');
		}
	}

	/** `{5,4}` — the pentagrid, named in the risk register as the fallback substrate if the heptagrid proves unfriendly. **/
	function testThePentagridGivesEveryInteriorFaceFiveNeighbours():Void {
		var tiling = new HyperbolicTiling(5, 4, 3);
		var interior = tiling.interiorFaces();

		Assert.isTrue(interior.length > 0, "a 3-ring pentagrid patch should have interior faces");
		for (id in interior) {
			Assert.equals(5, tiling.neighbors[id].length, 'face $id should have 5 neighbours');
		}
	}

	/** Adjacency must be symmetric, or every graph algorithm downstream is unsound. **/
	function testAdjacencyIsSymmetric():Void {
		var tiling = new HyperbolicTiling(7, 3, 3);

		for (a in 0...tiling.neighbors.length) {
			for (b in tiling.neighbors[a]) {
				Assert.isTrue(tiling.neighbors[b].indexOf(a) != -1, 'adjacency not symmetric between $a and $b');
			}
		}
	}

	/** No face may be its own neighbour, and no pair may be linked twice — welding collapses several paths onto one face and must not leave duplicates behind. **/
	function testNoSelfLoopsOrDuplicateEdges():Void {
		var tiling = new HyperbolicTiling(7, 3, 3);

		for (a in 0...tiling.neighbors.length) {
			var seen = new Map<Int, Bool>();
			for (b in tiling.neighbors[a]) {
				Assert.notEquals(a, b, 'face $a is its own neighbour');
				Assert.isFalse(seen.exists(b), 'face $a lists $b twice');
				seen.set(b, true);
			}
		}
	}

	/**
		**The measurement Risk 2 exists to take**, and the test that caught a
		real construction bug.

		Ring populations of `{7,3}` are exactly `1, 7, 21, 56, 147, 385` — a
		known sequence, so this is a decisive check rather than a
		plausibility one. An earlier version asserted only "each ring is
		bigger than the last", which a *broken* construction passed happily:
		welding was merging nothing and the structure was a 7-ary tree
		growing as `7ⁿ`. Exact counts fail that instantly.
	**/
	function testRingPopulationsMatchTheKnownHeptagridSequence():Void {
		var tiling = new HyperbolicTiling(7, 3, 5);

		var perRing = [for (_ in 0...6) 0];
		for (id in 0...tiling.rings.length) {
			perRing[tiling.rings[id]]++;
		}

		Assert.same([1, 7, 21, 56, 147, 385], perRing, 'heptagrid ring populations were $perRing');
	}

	/**
		Growth converges on **φ² ≈ 2.618**, the golden ratio squared — the
		known growth rate of these tilings, and a much stronger claim than
		"it grows".

		This is non-amenability as a number: each step outward multiplies the
		available space by a constant factor greater than one, forever, which
		is why no region is ever mostly-interior, why the Sprawl's legibility
		law has to be "see near, not far", and — via the Garden of Eden
		theorem — why an uncaused pattern there need not cost an erasure. A
		flat grid's equivalent ratio converges to 1.
	**/
	function testGrowthRateConvergesOnGoldenRatioSquared():Void {
		var tiling = new HyperbolicTiling(7, 3, 5);

		var perRing = [for (_ in 0...6) 0];
		for (id in 0...tiling.rings.length) {
			perRing[tiling.rings[id]]++;
		}

		var phiSquared = Math.pow((1 + Math.sqrt(5)) / 2, 2);
		var factor = perRing[5] / perRing[4];

		Assert.floatEquals(phiSquared, factor, 0.01, 'growth rate should approach φ² = $phiSquared, measured $factor');
	}

	/** A face's inradius must be smaller than its circumradius, and both positive — a cheap guard on the two closed-form formulas the construction depends on. **/
	function testInradiusIsSmallerThanCircumradius():Void {
		for (pq in [[7, 3], [5, 4], [8, 3], [5, 5]]) {
			var r = HyperbolicTiling.inradiusOf(pq[0], pq[1]);
			var big = HyperbolicTiling.circumradiusOf(pq[0], pq[1]);

			Assert.isTrue(r > 0, '{${pq[0]},${pq[1]}} inradius should be positive, got $r');
			Assert.isTrue(big > r, '{${pq[0]},${pq[1]}} circumradius $big should exceed inradius $r');
		}
	}

	/** Non-hyperbolic parameters must be rejected rather than silently producing nonsense — `{6,3}` is the flat hex grid and `{5,3}` the dodecahedron. **/
	function testRejectsNonHyperbolicParameters():Void {
		Assert.raises(() -> new HyperbolicTiling(6, 3, 2), String);
		Assert.raises(() -> new HyperbolicTiling(5, 3, 2), String);
	}
}
