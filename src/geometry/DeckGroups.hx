package geometry;

/**
	The specific deck groups the game's spaces are quotients by — the
	"four or fewer matrices" each space contributes on top of the shared
	machinery in `DeckGroup`.

	Each is a couple of lines, which is the whole argument for having
	built the framework: the difference between a torus, a Möbius band and
	a Klein bottle is *which isometries you pick*, not which renderer,
	collision system or movement code you write.
**/
class DeckGroups {
	/**
		**The Repeat** — a flat torus, as E² modulo a rectangular lattice.

		Two translations, at right angles. Walking `width` east or `height`
		north returns you exactly where you started, which is the whole of
		what a torus is.
		@param width the east-west period.
		@param height the north-south period.
		@return the lattice group.
	**/
	public static function torus(width:Float, height:Float):DeckGroup {
		return new DeckGroup(Flat, [alongX(width), alongY(height)]);
	}

	/**
		**The Turn** — a flat Möbius band, as a strip of E² modulo a single
		glide reflection.

		**This is the honest Möbius band, and the one already in the game
		is not.** `biomes.mobius.MobiusBiome` embeds a strip in ℝ³ and
		twists it, which is a fine thing to look at and is *not flat*: the
		embedded surface has real curvature everywhere, so walking it
		teaches the wrong lesson for a space
		`docs/game-design/direction/world-and-threads.md` files under
		κ = 0. Quotienting a flat strip by a glide reflection gives a
		genuinely flat, genuinely non-orientable band, with the twist
		living in the identification rather than in the geometry — which is
		exactly the distinction that space exists to teach.

		The band's own width is not this group's business: the group only
		says how to identify, and the biome decides how far either side of
		the axis the floor extends.
		@param period how far along the axis before the band closes on itself, reversed.
		@return the glide-reflection group.
	**/
	public static function mobiusBand(period:Float):DeckGroup {
		return new DeckGroup(Flat, [glideAlongX(period)]);
	}

	/**
		A **Klein bottle**: the Möbius band's glide reflection, closed off
		by a translation across it.

		Not currently a space in the design — kept because it costs one
		line, because it is the natural companion to the two above (the
		fourth of the four closed flat surfaces, after the plane, the
		cylinder and the torus), and because it is the cheapest available
		test that the framework handles a non-orientable *closed* quotient
		and not just a band with edges.
		@param width the glide's own period along the axis.
		@param height the period across it.
		@return the Klein bottle group.
	**/
	public static function kleinBottle(width:Float, height:Float):DeckGroup {
		return new DeckGroup(Flat, [glideAlongX(width), alongY(height)]);
	}

	/** Translation east by `distance`. **/
	static function alongX(distance:Float):Isometry {
		return Isometry.translation(Flat, distance);
	}

	/** Translation north by `distance` — the `+x` translation, turned. **/
	static function alongY(distance:Float):Isometry {
		return Isometry.compose(Isometry.compose(Isometry.rotation(Math.PI / 2), Isometry.translation(Flat, distance)), Isometry.rotation(-Math.PI / 2));
	}

	/**
		Glide reflection along the `x`-axis: reflect across it and slide
		`distance` along it — `(x, y) ↦ (x + distance, −y)`.

		**Composition order does not matter here, and it is worth saying so
		because it looks like it should.** A reflection commutes with a
		translation along its *own axis*: both orders give
		`(x, y) ↦ (x + distance, −y)`. This was originally documented the
		other way round — claiming the reverse order produced a half-turn —
		and a mutation test flatly disproved it by swapping the operands
		and changing nothing at all.

		**What does matter is the axis.** Reflecting across `y` instead of
		`x` gives a genuinely different isometry, and one that is not a
		glide reflection along this translation at all; it fails the
		glide-squared identity and the Klein bottle relation, both of which
		the tests check.
		@param distance the slide.
		@return the glide reflection.
	**/
	static function glideAlongX(distance:Float):Isometry {
		return Isometry.compose(Isometry.translation(Flat, distance), Isometry.reflection(0));
	}
}
