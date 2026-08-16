package tools.geodesic;

import tools.geodesic.GeodesicLifeRule.GeodesicLifeRules;
import tools.geodesic.GeodesicSphere.GeodesicSphereData;

/**
	Conway Game of Life over a `GeodesicSphereData`'s own adjacency — the
	node-id-keyed counterpart to `biomes.conway.ConwayState`, generalized
	off `(row, col)` string keys per Phase 5 of
	`docs/building/notes/geodesic-sphere-engineering.md`'s own build
	order. Every mechanic `ConwayState` already has (rolling per-node
	activity, per-node age, a small per-generation mutation chance) carries
	over unchanged in spirit; the address type (a plain `Int` node id
	instead of a `"cell:row:col"` string) and the neighbor source (baked
	adjacency instead of a 3x3 Moore-neighborhood formula) are the
	mechanical differences.

	**Walls do not gate this simulation, unlike the square grid's.**
	`ConwayGrid.liveNeighborCount` only counts a neighbor whose edge the
	maze currently leaves open; that was ported here first and had to be
	taken back out, because on this topology it doesn't merely change the
	dynamics — it kills them outright. A hex node has 6 neighbors, a carved
	maze is a spanning tree leaving ~2 of them open, and every candidate
	rule needs 2-3 *live* neighbors to sustain anything, so a gated board
	dies within ~5 generations regardless of rule or seed (measured across
	all four candidates in `GeodesicLifeReport`). `GeodesicReactivity`
	can't rescue it either: opening a wall needs activity, activity needs
	life, life needs open walls — a dead board stays dead forever. The
	square grid gets away with the same rule because it has 8 neighbors
	*and* because `ConwayGrid.allowsInfluence` lets diagonal influence flow
	through either intermediate cell, so influence leaks around corners
	there; a hexagon has no diagonals and every neighbor is
	all-or-nothing.

	So the division of labour is now: **walls are what the player
	navigates, this is what the biome does.** `GeodesicReactivity` still
	reads this layer's activity to move walls around — the coupling runs
	one way (life shapes the maze) rather than both. Whether a rule exists
	that stays alive *while* being wall-gated is a genuinely open question
	and a live backlog item; see `docs/open/ideas-backlog.md`'s
	"maze-compatible life rule" entry. Nothing here forecloses it — the
	gate would come back as a change to this one method.

	Deliberately doesn't port `biomes.conway.ConwaySeedLibrary`'s spawner —
	that's Phase 8, gated on which `GeodesicLifeRule` this class's own
	default ships with, since a square-grid glider isn't a hex-grid
	glider.
**/
class GeodesicLifeState {
	/** See `biomes.conway.ConwayState.MUTATION_RATE`'s own doc for the full reasoning — same fix, same rate, ported rather than re-derived. **/
	public static inline final MUTATION_RATE:Float = 0.0008;

	/** See `biomes.conway.ConwayState.ACTIVITY_DECAY`'s own doc. **/
	static inline final ACTIVITY_DECAY:Float = 0.8;

	final sphere:GeodesicSphereData;
	final rule:GeodesicLifeRule;

	var alive:haxe.ds.IntMap<Bool>;
	var activity:haxe.ds.IntMap<Float>;
	var age:haxe.ds.IntMap<Int>;
	var justDied:haxe.ds.IntMap<Bool>;

	public function new(sphere:GeodesicSphereData, rule:GeodesicLifeRule) {
		this.sphere = sphere;
		this.rule = rule;
		alive = new haxe.ds.IntMap();
		activity = new haxe.ds.IntMap();
		age = new haxe.ds.IntMap();
		justDied = new haxe.ds.IntMap();
	}

	public function isAlive(nodeId:Int):Bool {
		return alive.exists(nodeId);
	}

	/** This node's own rolling activity score — see `biomes.conway.ConwayState.activity`'s own doc. `0` if it isn't currently alive. **/
	public function activityOf(nodeId:Int):Float {
		return activity.exists(nodeId) ? activity.get(nodeId) : 0;
	}

	/** This node's own age in generations — see `biomes.conway.ConwayState.age`'s own doc. `0` if it isn't currently alive. **/
	public function ageOf(nodeId:Int):Int {
		return age.exists(nodeId) ? age.get(nodeId) : 0;
	}

	/** Whether this node died on the most recent `step` — see `biomes.conway.ConwayState.justDied`'s own doc. **/
	public function justDiedAt(nodeId:Int):Bool {
		return justDied.exists(nodeId);
	}

	/** How many nodes are currently alive — mainly for `GeodesicLifeReport`'s own comparison stats, not gameplay. **/
	public function population():Int {
		var count = 0;
		for (_ in alive.keys()) {
			count++;
		}
		return count;
	}

	/** Directly forces `nodeId` alive, as a fresh birth (age `1`) — controlled setup for tests, the way `biomes.conway.ConwayState.deserialize` gives `ConwayStateTest` direct control without this class needing a save format yet (that's Phase 9). **/
	public function seedSingle(nodeId:Int):Void {
		alive.set(nodeId, true);
		age.set(nodeId, 1);
	}

	/**
		Seeds this board with independent per-node random births —
		deliberately not the deterministic sine-hash `ConwayState.seedInitial`
		uses (that determinism is specifically so a *lat/long* session
		always starts from the same-looking scatter; nothing about this
		class depends on that particular property, and an injectable `random`
		already gives callers — tests, `GeodesicLifeReport` — their own
		determinism when they need it).
		@param density independent per-node chance of starting alive.
		@param random source of randomness in [0, 1); defaults to `Math.random`.
	**/
	public function seed(density:Float, ?random:Void->Float):Void {
		var rng = random != null ? random : Math.random;
		for (id in 0...sphere.neighbors.length) {
			if (rng() < density) {
				alive.set(id, true);
			}
		}
	}

	/**
		Advances one generation.
		@param random source of randomness in [0, 1) for `MUTATION_RATE`; defaults to `Math.random`. Exposed so tests/`GeodesicLifeReport` can pin it.
	**/
	public function step(?random:Void->Float):Void {
		var rng = random != null ? random : Math.random;
		var nextAlive = new haxe.ds.IntMap<Bool>();
		var nextActivity = new haxe.ds.IntMap<Float>();
		var nextAge = new haxe.ds.IntMap<Int>();
		var nextJustDied = new haxe.ds.IntMap<Bool>();

		for (id in 0...sphere.neighbors.length) {
			var hereAlive = isAlive(id);
			var liveNeighbors = liveNeighborCount(id);
			var ruleAlive = hereAlive ? GeodesicLifeRules.isSurvival(rule, liveNeighbors) : GeodesicLifeRules.isBirth(rule, liveNeighbors);
			var nextIsAlive = rng() < MUTATION_RATE ? !ruleAlive : ruleAlive;
			if (nextIsAlive) {
				nextAlive.set(id, true);
				nextAge.set(id, hereAlive ? ageOf(id) + 1 : 1);
			} else if (hereAlive) {
				nextJustDied.set(id, true);
			}
			nextActivity.set(id, decayedActivity(id, hereAlive != nextIsAlive));
		}

		alive = nextAlive;
		activity = nextActivity;
		age = nextAge;
		justDied = nextJustDied;
	}

	/**
		Counts live neighbors over this sphere's own full adjacency,
		deliberately ignoring where the maze's walls currently are — see
		this class's own doc for why the wall-gating that
		`biomes.conway.ConwayGrid.liveNeighborCount` does was dropped
		rather than ported.
	**/
	function liveNeighborCount(nodeId:Int):Int {
		var count = 0;
		for (neighbor in sphere.neighbors[nodeId]) {
			if (isAlive(neighbor)) {
				count++;
			}
		}
		return count;
	}

	function decayedActivity(nodeId:Int, flipped:Bool):Float {
		var sample = flipped ? 1.0 : 0.0;
		return activityOf(nodeId) * ACTIVITY_DECAY + sample * (1 - ACTIVITY_DECAY);
	}

	/**
		This layer's own state as JSON — the node-id-keyed counterpart to
		`biomes.conway.ConwayState.serialize`, same shape (`live` as a plain
		id list, `activity`/`age` as `{k, v}` pairs since `haxe.Json` can't
		serialize an `IntMap` directly) and the same omission: `justDied`
		isn't included, a one-generation visual cue, not state worth
		persisting.
		@return this layer's state as JSON.
	**/
	public function serialize():String {
		var live:Array<Int> = [for (id in alive.keys()) id];
		var activityEntries:Array<{k:Int, v:Float}> = [for (id => value in activity) {k: id, v: value}];
		var ageEntries:Array<{k:Int, v:Int}> = [for (id => value in age) {k: id, v: value}];
		return haxe.Json.stringify({live: live, activity: activityEntries, age: ageEntries});
	}

	/**
		Rebuilds a `GeodesicLifeState` from `serialize`'s own output.
		`sphere`/`rule` aren't part of the JSON (the sphere is the same
		checked-in baked asset every session loads fresh, and the rule is
		`GeodesicLifeRules.DEFAULT` for every save so far) — supplied by the
		caller the same way `GeodesicLifeState`'s own constructor requires
		them.
		@param sphere the topology this state runs on.
		@param rule the Life rule this state runs under.
		@param json a `serialize`-produced JSON string.
		@return the deserialized state.
	**/
	public static function deserialize(sphere:GeodesicSphereData, rule:GeodesicLifeRule, json:String):GeodesicLifeState {
		var parsed:{live:Array<Int>, activity:Array<{k:Int, v:Float}>, age:Array<{k:Int, v:Int}>} = haxe.Json.parse(json);
		var state = new GeodesicLifeState(sphere, rule);
		if (parsed.live != null) {
			for (id in parsed.live) {
				state.alive.set(id, true);
			}
		}
		if (parsed.activity != null) {
			for (entry in parsed.activity) {
				state.activity.set(entry.k, entry.v);
			}
		}
		if (parsed.age != null) {
			for (entry in parsed.age) {
				state.age.set(entry.k, entry.v);
			}
		}
		return state;
	}
}
