package tools.geodesic;

import tools.geodesic.GeodesicSphere.GeodesicSphereData;
import tools.geodesic.GeodesicVentrellaRule;
import tools.geodesic.GeodesicVentrellaRule.GeodesicVentrellaRules;

/**
	Jeffrey Ventrella's evolved 4-state hex-CA (`GeodesicVentrellaRules.SPHERE_CA`)
	over a `GeodesicSphereData`'s own adjacency — `GeodesicConwayBiome`'s
	live simulation layer as of 2026-08-09, replacing `GeodesicLifeState`'s
	2-state birth/survival engine there. See
	`docs/archive/decisions.md` for why: that engine's
	own exhaustive 2-ring search (`GeodesicGliderSearchMultiRule`) found
	zero confirmed travelers under any of three candidate 2-state rules in
	the 3-5 cell range, where this rule's own source paper demonstrates
	period-2 gliders that survive collisions on the same hex-sphere
	topology. `GeodesicLifeState`/`GeodesicLifeRule` and every tool built
	on them (`GeodesicGliderSearch*`, `GeodesicGliderTracker`,
	`GeodesicLifeReport`, ...) are untouched and still compile — a
	complete, trivially-revertible fallback, not dead code pruned away,
	the same precedent `GeodesicConwayBiome`'s own doc already set when it
	replaced `biomes.conway.ConwayBiome`.

	**Transition rule, per node, per generation**: start from quiescence
	(state `0`) as the default next state, then apply every subrule in
	`GeodesicVentrellaRules.SPHERE_CA.subrules` *in order* against this
	generation's own (unmodified) states — a subrule matches when the
	node's current state equals its own `referenceState` and the node's
	count of neighbors currently in `neighborState` (clamped to
	`GeodesicVentrellaRules.MAX_NEIGHBOR_COUNT`, see that constant's own
	doc) equals its own `neighborCount`; on a match, the *next* state is
	set to `resultState`, and a later matching subrule freely overwrites
	an earlier one's result (the source paper's own "genes only expressed
	under certain circumstances" framing, and exactly the mechanism behind
	its subrule-2/subrule-8 example).

	**No aging tier, deliberately** — unlike `GeodesicLifeState`'s own
	Young/Aged split (a single species getting visually older),
	Ventrella's states `1`/`2`/`3` are different *species* that appear as
	gliders collide, not age classes of one thing; layering an age readout
	on top would just be a second, unrelated axis competing for the same
	visual channel. `GeodesicLifecycle` was simplified to
	`Alive`/`Dying`/`Absent` accordingly — no per-state color yet either,
	deliberately deferred rather than guessed at ahead of actually seeing
	what the rule produces.

	**Activity, adapted rather than ported**: `GeodesicLifeState.activityOf`
	decays toward whether a node flipped alive/dead; a boolean flip has no
	direct analogue in a 4-state cell, so this reads "flipped" as "changed
	state value at all" (`0→1`, `1→3`, `3→1`, anything) — the same
	`GeodesicReactivity` wall-opening consumer just cares whether a node is
	*doing something*, not the specific transition.

	**`countMode` — under live-in-game measurement (2026-08-09), not yet
	resolved.** `GeodesicVentrellaReport`'s own density sweep found the
	live biome's own `Clamp` mode (the default here) collapsing to
	near-total extinction (`0.1%-0.3%` mean population) at *every* tested
	seed density, `0.1` through `1.0` — a uniform-across-density collapse
	that points at the neighbor-counting semantics rather than the seed,
	the same way `GeodesicLifeState`'s own Phase 5 once traced a dead
	board back to maze openness rather than the rule. `Proportional` was
	tried next and made no measurable difference (`GeodesicVentrellaReport`'s
	own doc has the numbers — the two modes only disagree in a dense
	neighborhood, and every run collapses to a sparse one within a few
	generations regardless). `Literal` is the current working hypothesis,
	untested as of this note — `GeodesicVentrellaGliderSearch`'s own killed
	first run only ever tried `Clamp`; see this enum's own `Literal` doc
	for why it's a materially different (and more literal) reading of the
	source paper's own wording, not just a third guess alongside the other
	two. Not yet promoted to `DEFAULT_COUNT_MODE` — measure first.
**/
/**
	How a node's own raw neighbor-in-state count (0 to its degree, `5` or
	`6`) maps onto a subrule's own `0`-`GeodesicVentrellaRules.MAX_NEIGHBOR_COUNT`
	digit — the interpretive gap `GeodesicVentrellaRules.MAX_NEIGHBOR_COUNT`'s
	own doc flags, made an explicit, swappable parameter rather than a
	silent constant once the default reading measured badly in play. See
	`GeodesicVentrellaState`'s own `countMode` doc for the measurement.
**/
enum NeighborCountMode {
	/** Raw count, capped at `MAX_NEIGHBOR_COUNT` — "3" means "3 or more." This class's own default, unchanged from the original port. **/
	Clamp;

	/** Raw count scaled down to `[0, MAX_NEIGHBOR_COUNT]` by the node's own actual degree (`Std.int(count * MAX_NEIGHBOR_COUNT / degree)`) — "3" means "every neighbor," not "3 or more." **/
	Proportional;

	/**
		Raw count, unmodified — no bucket, no scale. A subrule's own
		`neighborCount` digit only ever reaches `3`, so this makes "3" mean
		*exactly* `3`: a node with `4`, `5`, or `6` same-state neighbors
		matches nothing that asks for `3`, the same as it matches nothing
		that asks for `0`, `1`, or `2`. The most literal reading of the
		source paper's own wording ("neighborCount - can be any number from
		`0` to `M`") — it doesn't describe a bucket or a cap, just a
		parameter range, and says nothing about what a raw count *outside*
		that range should do. `Clamp` and `Proportional` both guess at an
		answer to a question this reading doesn't have to ask at all.
		Meaningfully *sparser* than `Clamp` on this topology (`5`-`6`
		neighbors): where `Clamp` treats every dense, mostly-quiescent
		neighborhood as satisfying "count = 3," this treats the same
		neighborhood as satisfying none of the four count digits unless the
		raw count happens to land exactly on `0`-`3`.
	**/
	Literal;
}

class GeodesicVentrellaState {
	/** `GeodesicVentrellaState`'s own default `countMode` — `Clamp`, the original port's own reading, unchanged pending the measurement `countMode`'s own class-doc note describes. **/
	public static final DEFAULT_COUNT_MODE:NeighborCountMode = Clamp;

	/**
		A small chance per node per generation to land on a random state
		instead of whatever the subrules computed — the same anti-extinction
		rationale as `GeodesicLifeState.MUTATION_RATE` (own doc has the full
		reasoning), adapted from "flip alive/dead" to "pick any of the 4
		states" since there's no single boolean to flip here. Same rate,
		carried over rather than re-derived; unlike `GeodesicLifeState.MUTATION_RATE`,
		this hasn't been measured against this specific rule yet — flagged,
		not assumed safe.
	**/
	public static inline final MUTATION_RATE:Float = 0.0008;

	/** See `GeodesicLifeState.ACTIVITY_DECAY`'s own doc — same rate, same role. **/
	static inline final ACTIVITY_DECAY:Float = 0.8;

	final sphere:GeodesicSphereData;
	final rule:GeodesicVentrellaRule;
	final countMode:NeighborCountMode;

	var state:haxe.ds.IntMap<Int>;
	var activity:haxe.ds.IntMap<Float>;
	var justDied:haxe.ds.IntMap<Bool>;

	public function new(sphere:GeodesicSphereData, rule:GeodesicVentrellaRule, ?countMode:NeighborCountMode) {
		this.sphere = sphere;
		this.rule = rule;
		this.countMode = countMode != null ? countMode : DEFAULT_COUNT_MODE;
		state = new haxe.ds.IntMap();
		activity = new haxe.ds.IntMap();
		justDied = new haxe.ds.IntMap();
	}

	/** `0` (quiescent) for any node never touched by `seedSingle`/`seed`/`step`. **/
	public function stateOf(nodeId:Int):Int {
		return state.exists(nodeId) ? state.get(nodeId) : 0;
	}

	public function isAlive(nodeId:Int):Bool {
		return stateOf(nodeId) != 0;
	}

	/** This node's own rolling activity score — see `GeodesicLifeState.activityOf`'s own doc for the decay shape; `0` if it isn't currently alive. **/
	public function activityOf(nodeId:Int):Float {
		return activity.exists(nodeId) ? activity.get(nodeId) : 0;
	}

	/** Whether this node's own state dropped to `0` on the most recent `step` — see `GeodesicLifeState.justDiedAt`'s own doc. **/
	public function justDiedAt(nodeId:Int):Bool {
		return justDied.exists(nodeId);
	}

	/** How many nodes currently hold a non-`0` state — mainly for tests/tooling, not gameplay. **/
	public function population():Int {
		var count = 0;
		for (_ in state.keys()) {
			count++;
		}
		return count;
	}

	/** Directly forces `nodeId` to `nodeState` (default `1`) — controlled setup for tests, the way `GeodesicLifeState.seedSingle` gives its own tests direct control. **/
	public function seedSingle(nodeId:Int, nodeState:Int = 1):Void {
		state.set(nodeId, nodeState);
	}

	/**
		Seeds this board with independent per-node random births into state
		`1` — the ambient-soup counterpart to `GeodesicLifeState.seed`, and
		what `GeodesicConwayBiome` now uses instead of that class's own
		scripted `GeodesicGliderTracker` spawn sites: Ventrella's own rule is
		built to produce gliders from generic seed noise, not from
		hand-placed patterns (see this class's own doc).
		@param density independent per-node chance of starting in state `1`.
		@param random source of randomness in [0, 1); defaults to `Math.random`.
	**/
	public function seed(density:Float, ?random:Void->Float):Void {
		var rng = random != null ? random : Math.random;
		for (id in 0...sphere.neighbors.length) {
			if (rng() < density) {
				state.set(id, 1);
			}
		}
	}

	/**
		Advances one generation, applying every subrule to every node
		against this generation's own unmodified states — see this class's
		own doc for the full transition rule.
		@param random source of randomness in [0, 1) for `MUTATION_RATE`; defaults to `Math.random`. Exposed so tests can pin it.
	**/
	public function step(?random:Void->Float):Void {
		var rng = random != null ? random : Math.random;
		var nextState = new haxe.ds.IntMap<Int>();
		var nextActivity = new haxe.ds.IntMap<Float>();
		var nextJustDied = new haxe.ds.IntMap<Bool>();

		for (id in 0...sphere.neighbors.length) {
			var here = stateOf(id);
			var computed = nextStateOf(id, here);
			var mutated = rng() < MUTATION_RATE ? Std.int(rng() * rule.states) : computed;
			if (mutated != 0) {
				nextState.set(id, mutated);
			} else if (here != 0) {
				nextJustDied.set(id, true);
			}
			nextActivity.set(id, decayedActivity(id, here != mutated));
		}

		state = nextState;
		activity = nextActivity;
		justDied = nextJustDied;
	}

	/** Every subrule, in order, against `here`/this generation's own neighbor states — last match wins. Quiescent (`0`) if nothing matches. **/
	function nextStateOf(nodeId:Int, here:Int):Int {
		var result = 0;
		for (subrule in rule.subrules) {
			if (subrule.referenceState != here) {
				continue;
			}
			if (liveNeighborStateCount(nodeId, subrule.neighborState) != subrule.neighborCount) {
				continue;
			}
			result = subrule.resultState;
		}
		return result;
	}

	/** Count of `nodeId`'s own neighbors currently in `targetState`, mapped onto `[0, GeodesicVentrellaRules.MAX_NEIGHBOR_COUNT]` per this instance's own `countMode` — see `NeighborCountMode`'s own doc for the two readings. **/
	function liveNeighborStateCount(nodeId:Int, targetState:Int):Int {
		var count = 0;
		for (neighbor in sphere.neighbors[nodeId]) {
			if (stateOf(neighbor) == targetState) {
				count++;
			}
		}
		return switch countMode {
			case Clamp: count < GeodesicVentrellaRules.MAX_NEIGHBOR_COUNT ? count : GeodesicVentrellaRules.MAX_NEIGHBOR_COUNT;
			case Proportional: Std.int(count * GeodesicVentrellaRules.MAX_NEIGHBOR_COUNT / sphere.neighbors[nodeId].length);
			case Literal: count;
		}
	}

	function decayedActivity(nodeId:Int, flipped:Bool):Float {
		var sample = flipped ? 1.0 : 0.0;
		return activityOf(nodeId) * ACTIVITY_DECAY + sample * (1 - ACTIVITY_DECAY);
	}

	/**
		This layer's own state as JSON — the `GeodesicLifeState.serialize`
		counterpart, same shape/omissions (`justDied` dropped as a
		one-generation visual cue), just `state` as `{k, v}` pairs (node id
		→ 1-3) instead of a plain alive-id list, since a node's own value
		matters here and not just whether it's non-zero.
		@return this layer's state as JSON.
	**/
	public function serialize():String {
		var stateEntries:Array<{k:Int, v:Int}> = [for (id => value in state) {k: id, v: value}];
		var activityEntries:Array<{k:Int, v:Float}> = [for (id => value in activity) {k: id, v: value}];
		return haxe.Json.stringify({state: stateEntries, activity: activityEntries});
	}

	/**
		Rebuilds a `GeodesicVentrellaState` from `serialize`'s own output.
		`sphere`/`rule` aren't part of the JSON — supplied by the caller, the
		same way `GeodesicLifeState.deserialize` requires them.
		@param sphere the topology this state runs on.
		@param rule the rule this state runs under.
		@param json a `serialize`-produced JSON string.
		@return the deserialized state.
	**/
	public static function deserialize(sphere:GeodesicSphereData, rule:GeodesicVentrellaRule, json:String):GeodesicVentrellaState {
		var parsed:{state:Array<{k:Int, v:Int}>, activity:Array<{k:Int, v:Float}>} = haxe.Json.parse(json);
		var result = new GeodesicVentrellaState(sphere, rule);
		if (parsed.state != null) {
			for (entry in parsed.state) {
				result.state.set(entry.k, entry.v);
			}
		}
		if (parsed.activity != null) {
			for (entry in parsed.activity) {
				result.activity.set(entry.k, entry.v);
			}
		}
		return result;
	}
}
