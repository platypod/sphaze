package tools.geodesic;

/**
	One line of Jeffrey Ventrella's evolved 4-state hex-CA rule
	(`https://www.ventrella.com/SphereCA/`) — a `(referenceState,
	neighborState, neighborCount, resultState)` tuple, encoded in the
	source as four decimal digits (e.g. `"1223"`). Evolved by genetic
	search for gliders that survive collisions (annihilation, reproduction,
	reflection), not hand-derived like this package's own `GeodesicLifeRule`
	candidates — see `GeodesicVentrellaRules`'s own doc for the transition
	semantics this drives.
**/
typedef VentrellaSubrule = {
	var referenceState:Int;
	var neighborState:Int;
	var neighborCount:Int;
	var resultState:Int;
}

/**
	A named, ordered list of `VentrellaSubrule`s plus the state count `K`
	they're defined over.
**/
typedef GeodesicVentrellaRule = {
	var name:String;
	var states:Int;
	var subrules:Array<VentrellaSubrule>;
}

class GeodesicVentrellaRules {
	/**
		Every neighbor-count digit in the source table tops out at `3`
		despite a hex node having 6 neighbors (5 for the sphere's 12
		pentagons) — `M` in the paper's own `(K, M)` genome-size notation is
		fixed independently of grid degree, the same way `K` (state count)
		is fixed at `4` regardless of what a richer automaton might use.
		**Adapted, not verified against the source**: since the subrule
		table itself is silent on what a count past `M` means, this reads
		digit `3` as "3 or more" — `liveNeighborStateCount` in
		`GeodesicVentrellaState` clamps its own raw count to this ceiling
		before comparing, so a hexagon's 6th neighbor and a pentagon's
		5th both still match against whichever subrule's own count digit
		is `3`. Flagged rather than assumed correct: this is the one
		genuinely new interpretive call this port makes, and it's worth
		watching gliders emerge (or not) before trusting it.
	**/
	public static inline final MAX_NEIGHBOR_COUNT:Int = 3;

	/**
		The 80 genes behind Ventrella's own Figure 2/3 (a period-2 glider,
		colliding gliders that annihilate/reproduce/reflect) — hand-transcribed
		from `https://www.ventrella.com/SphereCA/`'s own rule table, 20
		subrules of 4 digits each, kept in the paper's own order since later
		subrules deliberately overwrite earlier ones (`GeodesicVentrellaState.step`'s
		own doc): the paper calls out subrule 1 as redundant with subrule 3
		(both `1223`) and subrule 2's own result (state `3`) as always
		overwritten by subrule 8's (state `0`) for exactly that reason.
		Kept as transcribed, redundancies included — eliminating them is a
		compaction the paper itself treats as optional ("not elegance...
		but evolvability"), not a correctness requirement.
	**/
	public static final SPHERE_CA:GeodesicVentrellaRule = {
		name: "Ventrella4State",
		states: 4,
		subrules: parseAll([
			"1223", "0013", "1223", "1012", "0213", "1110", "0313", "0010", "2211", "1103",
			"2110", "0320", "1102", "2120", "0313", "2023", "0100", "2303", "3111", "1310"
		])
	};

	static function parseAll(codes:Array<String>):Array<VentrellaSubrule> {
		return [for (code in codes) parse(code)];
	}

	static function parse(code:String):VentrellaSubrule {
		return {
			referenceState: Std.parseInt(code.charAt(0)),
			neighborState: Std.parseInt(code.charAt(1)),
			neighborCount: Std.parseInt(code.charAt(2)),
			resultState: Std.parseInt(code.charAt(3))
		};
	}
}
