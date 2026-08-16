package tools.geodesic;

/**
	A birth/survival rule as plain data — which neighbor counts cause a
	dead node to become alive (`birth`), and which let an alive node
	remain alive (`survive`). Generic across topologies (this project's
	own square-grid B3/S23 could be expressed the same way), but the four
	named instances below are specifically this package's own 6-neighbor
	candidates — see
	`docs/building/notes/geodesic-sphere-engineering.md`'s "Life rule
	candidates" section for how they were derived (proportional scaling
	from B3/S23's own 8-neighbor thresholds) and `GeodesicLifeRules.DEFAULT`'s
	own doc for which one actually got picked, and why.
**/
typedef GeodesicLifeRule = {
	var name:String;
	var birth:Array<Int>;
	var survive:Array<Int>;
}

class GeodesicLifeRules {
	/** The direct proportional scaling of B3/S23's own thresholds (birth at 3/8, survive at 2-3/8) to 6 neighbors. **/
	public static final B2_S23:GeodesicLifeRule = {name: "B2/S23", birth: [2], survive: [2, 3]};

	/** Tighter survival than `B2_S23` — expected sparser, more oscillator-heavy. **/
	public static final B2_S3:GeodesicLifeRule = {name: "B2/S3", birth: [2], survive: [3]};

	/** Looser survival than `B2_S23` — expected denser, more stable-structure-heavy. **/
	public static final B2_S34:GeodesicLifeRule = {name: "B2/S34", birth: [2], survive: [3, 4]};

	/** A higher birth threshold than the other three — a control for "what if birth should scale differently than survival." **/
	public static final B3_S34:GeodesicLifeRule = {name: "B3/S34", birth: [3], survive: [3, 4]};

	/** Birth at 2,4 neighbors; survive at 4,6 neighbors. Documented to produce period-8 gliders with multi-unit movement; richer structure candidate. **/
	public static final B24_S46:GeodesicLifeRule = {name: "B24/S46", birth: [2, 4], survive: [4, 6]};

	/** Birth at 3,5; survive at 2. Well-studied in standalone hex-CA research. **/
	public static final B35_S2:GeodesicLifeRule = {name: "B35/S2", birth: [3, 5], survive: [2]};

	/** Every candidate, in the order `GeodesicLifeReport` compares them. **/
	public static final ALL:Array<GeodesicLifeRule> = [B2_S23, B2_S3, B2_S34, B3_S34, B24_S46, B35_S2];

	/**
		`B2_S34` — its third pick, each time for a different measured
		reason, not the same one re-litigated.

		**Round 1** picked `B2/S23`, but off numbers that turned out
		worthless — `GeodesicLifeReport`'s own xorshift returned
		non-uniform values on neko, so `MUTATION_RATE` fired on ~50% of
		nodes a generation instead of `0.08%`, and every rule measured as
		the same coin flip. See `tools.geodesic.SeededRandom`'s own doc.

		**Round 2**, re-run with a uniform generator: `B2/S23` really was
		the standout — `54.9%` mean live share once settled, against
		`0.5%`-`2.1%` for the other three, which died out or hovered near
		extinction. Genuinely the right pick *for that question* ("which
		rule sustains a population on an open board"). But it was the
		wrong question — nobody had yet asked what population `B2/S23`
		actually needs to look *legible* once real walls and a real player
		are involved.

		**Round 3 (2026-08-06)** asked that question, after `B2/S23`
		shipped and got played: "too many walls disappear... I'd like 5%
		walls open, tops... we still have way too many cells activated."
		Measured directly rather than guessed at: `B2/S23` settles at
		`~56%` fine-cell population and `~9%` of reactive coarse walls
		open (`GeodesicCoarseMaze.boundaryActivity`, over 300 generations,
		8 seeds) — both far above what reads as a legible, walkable maze.
		The fix was never the wall-reactivity formula (already tightened
		once, from per-region to per-boundary activity — see
		`GeodesicCoarseMaze`'s own doc); it was always this rule's own
		equilibrium population.

		`B2/S34` lands almost exactly on the actual ask: mean settled open
		rate `4.8%` (against a `5%` target), mean population `~1.1%`. Its
		own risk, measured rather than assumed from the earlier (differently-
		conditioned) round-2 note calling it "near extinction": `1` of `8`
		seeds hit zero population at all over 300 generations, and that one
		self-healed via `MUTATION_RATE` within `2` generations — an
		expected, brief flicker (~1200 fine cells × `0.0008` ≈ 1 random
		birth per generation even from a bare board), not a permanent
		freeze. `B2/S3` was also tried and rejected: `75%` (`6`/`8`) of
		seeds went extinct, too fragile to trust.

		The still-standing finding from round 2 remains true and
		unaffected by this: every rule, `B2/S34` included, dies within ~5
		generations on a *bare* carved maze with no open edges at all —
		see `docs/building/notes/geodesic-sphere-engineering.md`'s own
		Phase 5 entry for that table. Wall-gating Life itself is still
		removed for the same reason as always; this round only ever
		concerned which rule drives the *unrestricted* fine simulation.
	**/
	public static final DEFAULT:GeodesicLifeRule = B2_S34;

	public static function isBirth(rule:GeodesicLifeRule, liveNeighbors:Int):Bool {
		return rule.birth.indexOf(liveNeighbors) != -1;
	}

	public static function isSurvival(rule:GeodesicLifeRule, liveNeighbors:Int):Bool {
		return rule.survive.indexOf(liveNeighbors) != -1;
	}
}
