package geometry;

import geometry.CurvedSpace.ModelPoint;
import utest.Assert;
import utest.Test;

/**
	Checks the quotient machinery against properties that identify the
	group rather than merely describe it.

	The failure mode this file exists for: **a wrong deck group still
	produces a world that walks and looks like a quotient space.** Fold a
	point one cell too far and the torus is still a torus, just not the
	one the level was authored in. Build a glide reflection about the
	wrong axis and the quotient is orientable, so the Turn quietly teaches
	the opposite of its lesson. Neither shows up on screen. So the tests
	here are structural — group relations, lattice counts, agreement
	between a fast fold and an exhaustive one — rather than screenshots of
	plausible-looking worlds.

	**These were mutation-checked rather than assumed to have teeth.**
	Reflecting about `y` instead of `x` fails three of them; collapsing
	the torus lattice onto a single axis fails four. A third mutation —
	swapping the glide's composition operands — changed *nothing*, which
	is how the note claiming that order mattered was found to be wrong and
	corrected in `DeckGroups`.
**/
class DeckGroupTest extends Test {
	static inline final WIDTH:Float = 12.0;
	static inline final HEIGHT:Float = 8.0;

	function at(x:Float, y:Float):ModelPoint {
		return {x: x, y: y, z: 1};
	}

	function assertSamePoint(expected:ModelPoint, actual:ModelPoint, message:String):Void {
		Assert.floatEquals(expected.x, actual.x, 1e-6, '$message (x)');
		Assert.floatEquals(expected.y, actual.y, 1e-6, '$message (y)');
	}

	function assertSameIsometry(expected:Isometry, actual:Isometry, message:String):Void {
		for (i in 0...9) {
			Assert.floatEquals(expected.m[i], actual.m[i], 1e-9, '$message (entry $i)');
		}
	}

	// ---- the isometry primitives the groups are built from ----

	/** Inverting really inverts, in every curvature and for orientation-reversing elements too — the operation `DeckGroup` builds its whole generator list on. **/
	function testInvertUndoesEveryKindOfIsometry():Void {
		var curvatures:Array<Curvature> = [Flat, Spherical, Hyperbolic];
		for (k in curvatures) {
			var samples = [
				Isometry.translation(k, 0.7),
				Isometry.rotation(1.1),
				Isometry.reflection(0.4),
				Isometry.compose(Isometry.translation(k, 1.3), Isometry.rotation(-0.9)),
				Isometry.compose(Isometry.compose(Isometry.rotation(0.3), Isometry.translation(k, 0.8)), Isometry.reflection(1.2)),
			];
			for (i => iso in samples) {
				var inverse = Isometry.invert(k, iso);
				assertSameIsometry(Isometry.identity(), Isometry.compose(iso, inverse), '$k sample $i times its inverse');
				assertSameIsometry(Isometry.identity(), Isometry.compose(inverse, iso), '$k inverse times sample $i');
			}
		}
	}

	/** A reflection preserves the model's own bilinear form — i.e. it is genuinely an isometry, in all three curvatures at once. **/
	function testReflectionPreservesTheForm():Void {
		var curvatures:Array<Curvature> = [Flat, Spherical, Hyperbolic];
		for (k in curvatures) {
			var reflect = Isometry.reflection(0.6);
			var a = {x: 0.3, y: -0.5, z: 1.2};
			var b = {x: -0.9, y: 0.2, z: 1.4};

			var before = CurvedSpace.inner(k, a, b);
			var after = CurvedSpace.inner(k, Isometry.apply(reflect, a), Isometry.apply(reflect, b));
			Assert.floatEquals(before, after, 1e-9, '$k: reflection changed the inner product');
		}
	}

	/** A reflection reverses orientation, which is the entire reason it exists — no product of translations and rotations could stand in for it. **/
	function testReflectionReversesOrientation():Void {
		Assert.floatEquals(-1, determinantOf(Isometry.reflection(0)), 1e-9);
		Assert.floatEquals(-1, determinantOf(Isometry.reflection(0.9)), 1e-9);
		Assert.floatEquals(1, determinantOf(Isometry.rotation(0.9)), 1e-9);
		Assert.floatEquals(1, determinantOf(Isometry.translation(Flat, 2.0)), 1e-9);
	}

	// ---- the torus ----

	/** Walking one full period each way returns exactly to the start, which is what makes this a torus at all. **/
	function testTheTorusPeriodsClose():Void {
		var group = DeckGroups.torus(WIDTH, HEIGHT);
		var start = at(3, 2);

		for (g in group.generators) {
			var moved = Isometry.apply(g, start);
			assertSamePoint(group.canonicalise(start), group.canonicalise(moved), "a translate should fold to the same point");
		}
	}

	/**
		The enumerated elements are exactly the lattice points within the
		radius — counted against an independent double loop, so a group
		that silently generated a *finer* or *coarser* lattice than asked
		for would be caught.
	**/
	function testTheTorusEnumeratesExactlyItsLattice():Void {
		var group = DeckGroups.torus(WIDTH, HEIGHT);
		var radius = 40.0;

		var expected = 0;
		var columns = Math.ceil(radius / WIDTH) + 1;
		var rows = Math.ceil(radius / HEIGHT) + 1;
		for (i in -columns...columns + 1) {
			for (j in -rows...rows + 1) {
				var x = i * WIDTH;
				var y = j * HEIGHT;
				if (Math.sqrt(x * x + y * y) <= radius) {
					expected++;
				}
			}
		}

		Assert.equals(expected, group.elementsWithin(radius).length, "enumerated a different lattice than a direct count");
	}

	/** Folding lands inside the Dirichlet cell — half a period either way, which for a rectangular lattice is exactly the rectangle. **/
	function testFoldingLandsInTheFundamentalDomain():Void {
		var group = DeckGroups.torus(WIDTH, HEIGHT);

		for (i in -4...5) {
			for (j in -4...5) {
				var folded = group.canonicalise(at(i * 7.3 + 1.1, j * 5.1 - 0.4));
				Assert.isTrue(Math.abs(folded.x) <= WIDTH / 2 + 1e-6, 'folded x ${folded.x} escaped the domain');
				Assert.isTrue(Math.abs(folded.y) <= HEIGHT / 2 + 1e-6, 'folded y ${folded.y} escaped the domain');
			}
		}
	}

	/** Folding an already-folded point changes nothing. **/
	function testFoldingIsIdempotent():Void {
		var group = DeckGroups.torus(WIDTH, HEIGHT);

		for (i in -3...4) {
			var once = group.canonicalise(at(i * 9.4, i * -6.2));
			assertSamePoint(once, group.canonicalise(once), 'folding twice moved the point (i=$i)');
		}
	}

	/**
		**The fast fold agrees with the exhaustive one.** `canonicalise` is
		a greedy descent and greedy descents can stop early; this is the
		check that it does not, for the groups actually shipped, rather
		than the argument that it should not.
	**/
	function testTheGreedyFoldAgreesWithAnExhaustiveSearch():Void {
		var groups = [
			DeckGroups.torus(WIDTH, HEIGHT),
			DeckGroups.mobiusBand(9.0),
			DeckGroups.kleinBottle(WIDTH, HEIGHT)
		];

		for (index => group in groups) {
			for (i in -3...4) {
				for (j in -3...4) {
					var p = at(i * 5.7 + 0.9, j * 4.3 - 1.3);
					assertSamePoint(group.canonicaliseBySearch(p, 90), group.canonicalise(p), 'group $index disagreed at ($i, $j)');
				}
			}
		}
	}

	// ---- the Möbius band and the Klein bottle ----

	/**
		**A glide reflection squares to a pure translation of twice the
		period** — the identity that pins down both the axis and the
		distance at once. A reflection about the wrong axis fails it, which
		is the mistake actually available to make here.
	**/
	function testTheGlideSquaresToAPureTranslation():Void {
		var period = 9.0;
		var glide = DeckGroups.mobiusBand(period).generators[0];
		var twice = Isometry.compose(glide, glide);

		assertSameIsometry(Isometry.translation(Flat, 2 * period), twice, "a glide squared should be a pure translation");
	}

	/** Applying the glide once flips which side of the axis you are on; applying it twice does not. **/
	function testTheGlideReversesTheBand():Void {
		var glide = DeckGroups.mobiusBand(9.0).generators[0];
		var start = at(1.0, 2.5);

		var once = Isometry.apply(glide, start);
		var twice = Isometry.apply(glide, once);

		Assert.floatEquals(-start.y, once.y, 1e-9, "one glide should cross the axis");
		Assert.floatEquals(start.y, twice.y, 1e-9, "two glides should come back to the same side");
	}

	/**
		**The Klein bottle's defining relation**, `a·b·a⁻¹ = b⁻¹`, checked
		on the matrices. This is the strongest available statement that the
		group is the one named rather than some other group of flat
		isometries that happens to be discrete — the relation is what
		distinguishes a Klein bottle from a torus, and nothing about
		walking either one would tell them apart quickly.
	**/
	function testTheKleinBottleRelationHolds():Void {
		var group = DeckGroups.kleinBottle(WIDTH, HEIGHT);
		var a = group.generators[0]; // the glide
		var b = group.generators[2]; // the translation across it

		var conjugated = Isometry.compose(Isometry.compose(a, b), Isometry.invert(Flat, a));
		assertSameIsometry(Isometry.invert(Flat, b), conjugated, "a·b·a⁻¹ should equal b⁻¹");
	}

	/** The generator list carries every generator's inverse, since every method here needs to step both ways. **/
	function testGeneratorsComeWithTheirInverses():Void {
		var group = DeckGroups.torus(WIDTH, HEIGHT);
		Assert.equals(4, group.generators.length, "two generators should yield four with inverses");

		for (i in 0...2) {
			assertSameIsometry(Isometry.identity(), Isometry.compose(group.generators[i * 2], group.generators[i * 2 + 1]),
				'generator $i and its neighbour should be inverse');
		}
	}

	/** A group with no generators is a programming mistake, not a degenerate quotient. **/
	function testRejectsAGroupWithNoGenerators():Void {
		Assert.raises(() -> new DeckGroup(Flat, []), String);
	}

	function determinantOf(iso:Isometry):Float {
		var m = iso.m;
		return m[0] * (m[4] * m[8] - m[5] * m[7]) - m[1] * (m[3] * m[8] - m[5] * m[6]) + m[2] * (m[3] * m[7] - m[4] * m[6]);
	}
}
