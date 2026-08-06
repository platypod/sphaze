package tools.geodesic;

/**
	A deterministic `[0, 1)` generator that behaves **identically on every
	target**, which is the entire reason it exists.

	The obvious thing to reach for — and what this package first did — is
	the xorshift32 in `test.biomes.maze.MazeGeneratorTest.SeededRandom`.
	That one is correct where it's used (the `utest` suite compiles to JS,
	whose `Int` is 32-bit and whose `>>>` really is an unsigned shift:
	measured mean `0.499`, `24.0%` of draws below `0.24`, no negatives).
	It is **not** portable: neko's `Int` is 31-bit, so the shifts overflow
	and `>>> 0` never produces an unsigned 32-bit value. Measured on neko,
	the same code yields mean `0`, `50%` negative draws, and `74%` of draws
	below `0.24`.

	That is not a theoretical concern — it silently invalidated this
	package's own first Life-rule comparison. `GeodesicLifeReport` runs on
	neko (it needs `Sys.println`), so its `rng() < MUTATION_RATE` check fired
	on roughly *half* of all nodes every generation instead of the intended
	`0.08%`. Every candidate rule was therefore measured as the same
	coin-flip noise, and the resulting "all four rules are statistically
	indistinguishable" conclusion measured the generator, not the rules.

	This uses the Park-Miller minimal standard LCG (`state = 16807 * state
	mod 2^31 - 1`) evaluated entirely in `Float`. The largest intermediate
	is `16807 * (2^31 - 2)` — about `3.6e13`, comfortably inside the `2^53`
	range every Haxe target represents exactly — so no target's own integer
	width can change the sequence. Not cryptographic and not the fastest
	choice; it is uniform, reproducible everywhere, and cheap to verify,
	which is what a comparison harness actually needs.
**/
class SeededRandom {
	static inline final MULTIPLIER:Float = 16807;

	/** `2^31 - 1`, the Mersenne prime this generator is defined over. **/
	static inline final MODULUS:Float = 2147483647;

	var state:Float;

	/**
		@param seed any value; `0` and multiples of `MODULUS` would freeze the sequence at zero, so they're nudged to `1`.
	**/
	public function new(seed:Int) {
		var start = Math.abs(seed) % MODULUS;
		state = start == 0 ? 1 : start;
	}

	/**
		Parentheses around the multiplication are load-bearing: Haxe binds
		`%` *tighter* than `*` (unlike C/Java/JS), so `MULTIPLIER * state %
		MODULUS` parses as `MULTIPLIER * (state % MODULUS)` — which never
		reduces anything and lets `state` run away past `2^53`. Caught by
		checking the output distribution rather than by reading the code:
		it produced a mean of `8409` instead of `0.5`.
		@return the next value in the sequence, in `[0, 1)`.
	**/
	public function next():Float {
		state = (MULTIPLIER * state) % MODULUS;
		return (state - 1) / (MODULUS - 1);
	}

	/** @return this generator as the plain `Void->Float` every seeded API in this package takes. **/
	public function asFunction():Void->Float {
		return next;
	}
}
