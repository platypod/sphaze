package biomes.conway;

import biomes.conway.ConwayGrid.Pole;
import biomes.conway.ConwayMaze.ConwayMazeData;

/**
	Mutable Conway Game of Life state over `ConwayGrid`'s own denser tile set.
**/
class ConwayState {
	static inline final INITIAL_DENSITY:Float = 0.24;
	static inline final POLE_DENSITY:Float = 0.5;

	/**
		How much a single flip nudges a cell's rolling activity score, and how
		much of the previous score survives each generation — smooths a lone
		flip into a blip rather than a spike, so `ConwayMazeReactivity` reacts
		to sustained flickering, not one-off noise.
	**/
	static inline final ACTIVITY_DECAY:Float = 0.8;

	/**
		Per-cell, per-generation chance of flipping whatever plain B3/S23
		computed, independent of neighbor count. Raw soup on a board this size
		reliably dies back into a handful of frozen still lifes/oscillators
		within a few dozen generations — see the "why raw Conway is a bad wall
		generator" note in `docs/game-design/ideas-backlog.md`, the same decay
		this fixes, just felt on the visible board instead of the walls it
		gates. A cosmic-ray-style mutation is the standard fix for a Life board
		that's too small/bounded to sustain itself: it both plants rare fresh
		births in dead regions and cracks existing still lifes back into
		motion, which density alone can't do (a frozen block has no live
		neighbors to birth into, no matter how dense the board started).
		~1234 cells (`ConwayGrid.RING_ROWS * ConwayGrid.COLS` ring cells plus 2
		poles) at this rate mutate roughly one cell per generation on average —
		enough to keep the board perpetually unsettled without reading as
		static over the deliberate B3/S23 shapes.
	**/
	static inline final MUTATION_RATE:Float = 0.0008;

	/**
		Per-generation chance of stamping a random `ConwaySeedLibrary`
		pattern onto the board at a random position/rotation. Complements
		`MUTATION_RATE` rather than replacing it: per-cell noise keeps
		existing structures from freezing solid, but it doesn't *travel* or
		*churn* the way a real pattern does — raised directly ("still too
		dead... more generators and such, some movement in the whole biome,
		structures that live longer, come across other structures and
		mutate and react"). At `0.75s`/generation, `0.15` lands a new
		structure roughly every `5` generations (`~3.75s`) — frequent enough
		to keep the board busy, spaced out enough that one spawn's own
		glider or methuselah gets to actually run for a while (and collide
		with whatever's already there) before the next one lands.
	**/
	static inline final STRUCTURE_SPAWN_RATE:Float = 0.15;

	var alive:haxe.ds.StringMap<Bool>;

	/**
		Rolling per-cell activity, in [0, 1]: how often this cell has recently
		flipped alive/dead. Read by `ConwayMazeReactivity` to decide which
		non-core maze edges open or close — a quiet cell lets its edges settle
		back to closed, a flickering one keeps them open.
	**/
	var activity:haxe.ds.StringMap<Float>;

	/**
		How many consecutive generations each currently-alive cell has
		stayed alive — birth is age `1`, incrementing every generation it
		survives; absent entirely once the cell dies. Read by `ConwayMesh`
		to color a freshly-born cell differently from one that's settled in
		(hooman, directly: "a freshly born cell should be green, a stale one
		blue").
	**/
	var age:haxe.ds.StringMap<Int>;

	/**
		Cells that were alive last generation and are dead this one —
		rebuilt fresh every `step`, not serialized: a one-generation visual
		cue ("a dead one red before disappearing"), not state that needs to
		survive a save. A cell that dies and stays dead only ever appears
		here for the single generation it actually died in.
	**/
	var justDied:haxe.ds.StringMap<Bool>;

	public function new() {
		alive = new haxe.ds.StringMap<Bool>();
		activity = new haxe.ds.StringMap<Float>();
		age = new haxe.ds.StringMap<Int>();
		justDied = new haxe.ds.StringMap<Bool>();
		seedInitial();
	}

	/** Whether ring cell `(row, col)` is currently alive. **/
	public function isAlive(row:Int, col:Int):Bool {
		return alive.exists(ConwayGrid.keyOf(row, col));
	}

	public function isPoleAlive(pole:Pole):Bool {
		return alive.exists(ConwayGrid.keyOfPole(pole));
	}

	/** This cell's rolling activity score — see `activity`'s own doc. **/
	public function activityOf(row:Int, col:Int):Float {
		return activityAt(ConwayGrid.keyOf(row, col));
	}

	/** This pole's rolling activity score — see `activity`'s own doc. **/
	public function poleActivityOf(pole:Pole):Float {
		return activityAt(ConwayGrid.keyOfPole(pole));
	}

	/** This cell's own age in generations — see `age`'s own doc. `0` if it isn't currently alive. **/
	public function ageOf(row:Int, col:Int):Int {
		return ageAt(ConwayGrid.keyOf(row, col));
	}

	/** This pole's own age in generations — see `age`'s own doc. `0` if it isn't currently alive. **/
	public function poleAgeOf(pole:Pole):Int {
		return ageAt(ConwayGrid.keyOfPole(pole));
	}

	/** Whether this cell died on the most recent `step` — see `justDied`'s own doc. **/
	public function justDiedAt(row:Int, col:Int):Bool {
		return justDied.exists(ConwayGrid.keyOf(row, col));
	}

	/** Whether this pole died on the most recent `step` — see `justDied`'s own doc. **/
	public function poleJustDiedAt(pole:Pole):Bool {
		return justDied.exists(ConwayGrid.keyOfPole(pole));
	}

	/**
		Advances one Conway generation.
		@param maze this generation's maze, for `ConwayGrid.liveNeighborCount`'s wall-gated influence.
		@param random source of randomness in [0, 1) for `MUTATION_RATE`; defaults to `Math.random`. Exposed so tests can pin it (a stub that never/always mutates) rather than depending on real randomness.
	**/
	public function step(maze:ConwayMazeData, ?random:Void->Float):Void {
		var rng = random != null ? random : Math.random;
		var next = new haxe.ds.StringMap<Bool>();
		var nextActivity = new haxe.ds.StringMap<Float>();
		var nextAge = new haxe.ds.StringMap<Int>();
		var nextJustDied = new haxe.ds.StringMap<Bool>();
		ConwayGrid.eachRingCell((row, col) -> {
			var key = ConwayGrid.keyOf(row, col);
			var hereAlive = isAlive(row, col);
			var liveNeighbors = ConwayGrid.liveNeighborCount(this, maze, row, col);
			var ruleAlive = hereAlive ? (liveNeighbors == 2 || liveNeighbors == 3) : liveNeighbors == 3;
			var nextAlive = rng() < MUTATION_RATE ? !ruleAlive : ruleAlive;
			if (nextAlive) {
				next.set(key, true);
				nextAge.set(key, hereAlive ? ageAt(key) + 1 : 1);
			} else if (hereAlive) {
				nextJustDied.set(key, true);
			}
			nextActivity.set(key, decayedActivity(key, hereAlive != nextAlive));
		});
		ConwayGrid.eachPole((pole) -> {
			var key = ConwayGrid.keyOfPole(pole);
			var hereAlive = isPoleAlive(pole);
			var liveNeighbors = ConwayGrid.liveNeighborCountPole(this, maze, pole);
			var ruleAlive = hereAlive ? (liveNeighbors == 2 || liveNeighbors == 3) : liveNeighbors == 3;
			var nextAlive = rng() < MUTATION_RATE ? !ruleAlive : ruleAlive;
			if (nextAlive) {
				next.set(key, true);
				nextAge.set(key, hereAlive ? ageAt(key) + 1 : 1);
			} else if (hereAlive) {
				nextJustDied.set(key, true);
			}
			nextActivity.set(key, decayedActivity(key, hereAlive != nextAlive));
		});
		if (rng() < STRUCTURE_SPAWN_RATE) {
			spawnStructure(next, nextActivity, nextAge, rng);
		}
		alive = next;
		activity = nextActivity;
		age = nextAge;
		justDied = nextJustDied;
	}

	/**
		Stamps one random `ConwaySeedLibrary` pattern, in a random
		rotation, at a random position, directly into `target`/`targetActivity` —
		run last (after the ordinary rule has already decided every
		cell for this generation) so the spawn always lands rather than
		being immediately overwritten by that per-cell decision.
		@param target this generation's own live-cell set — mutated in place.
		@param targetActivity this generation's own activity set — mutated in place; every stamped cell reads as maximally active, so `ConwayMazeReactivity` reacts to a fresh structure landing the same way it would to one arriving by ordinary play.
		@param targetAge this generation's own age set — mutated in place; every stamped cell is a birth (age `1`), so it reads as freshly born (green) rather than inheriting whatever `ConwayMesh`'s "stale" color would otherwise show for a cell that just started existing.
		@param rng source of randomness — see `step`'s own doc.
	**/
	function spawnStructure(target:haxe.ds.StringMap<Bool>, targetActivity:haxe.ds.StringMap<Float>, targetAge:haxe.ds.StringMap<Int>, rng:Void->Float):Void {
		var pattern = ConwaySeedLibrary.ALL[Std.int(rng() * ConwaySeedLibrary.ALL.length)];
		var cells = ConwaySeedLibrary.rotated(pattern, Std.int(rng() * 4));
		var height = 0;
		for (cell in cells) {
			if (cell.row + 1 > height) {
				height = cell.row + 1;
			}
		}
		if (height >= ConwayGrid.RING_ROWS) {
			return; // none of the library patterns are this tall; guards against a future addition that is
		}

		var anchorRow = Std.int(rng() * (ConwayGrid.RING_ROWS - height));
		var anchorCol = Std.int(rng() * ConwayGrid.COLS);
		for (cell in cells) {
			var row = anchorRow + cell.row;
			var col = ((anchorCol + cell.col) % ConwayGrid.COLS + ConwayGrid.COLS) % ConwayGrid.COLS;
			var key = ConwayGrid.keyOf(row, col);
			target.set(key, true);
			targetActivity.set(key, 1);
			targetAge.set(key, 1);
		}
	}

	public function serialize():String {
		var live:Array<String> = [];
		for (key => _ in alive) {
			live.push(key);
		}
		var activityEntries:Array<{k:String, v:Float}> = [];
		for (key => value in activity) {
			activityEntries.push({k: key, v: value});
		}
		var ageEntries:Array<{k:String, v:Int}> = [];
		for (key => value in age) {
			ageEntries.push({k: key, v: value});
		}
		// justDied isn't included: a one-generation visual cue, not state worth a save format entry.
		return haxe.Json.stringify({live: live, activity: activityEntries, age: ageEntries});
	}

	public static function deserialize(json:String):ConwayState {
		var parsed:Dynamic = haxe.Json.parse(json);
		var state = new ConwayState();
		state.alive = new haxe.ds.StringMap<Bool>();
		state.activity = new haxe.ds.StringMap<Float>();
		state.age = new haxe.ds.StringMap<Int>();
		state.justDied = new haxe.ds.StringMap<Bool>();
		var liveEntries:Array<Dynamic> = parsed.live;
		if (liveEntries != null) {
			for (entry in liveEntries) {
				var key:String = Std.string(entry);
				if (key.length > 0) {
					state.alive.set(key, true);
				}
			}
		}
		var activityEntries:Array<Dynamic> = parsed.activity;
		if (activityEntries != null) {
			for (entry in activityEntries) {
				var key:String = Std.string(entry.k);
				var value:Float = Std.parseFloat(Std.string(entry.v));
				if (key.length > 0 && !Math.isNaN(value)) {
					state.activity.set(key, value);
				}
			}
		}
		var ageEntries:Array<Dynamic> = parsed.age;
		if (ageEntries != null) {
			for (entry in ageEntries) {
				var key:String = Std.string(entry.k);
				var value:Null<Int> = Std.parseInt(Std.string(entry.v));
				if (key.length > 0 && value != null) {
					state.age.set(key, value);
				}
			}
		}
		return state;
	}

	function seedInitial():Void {
		ConwayGrid.eachRingCell((row, col) -> {
			// Deterministic noise so the same session starts from the same
			// pattern, while still looking naturally scattered.
			if (hash01(row, col) < INITIAL_DENSITY) {
				alive.set(ConwayGrid.keyOf(row, col), true);
			}
		});
		ConwayGrid.eachPole((pole) -> {
			var seed = switch pole {
				case North: hash01(-1, 0);
				case South: hash01(-2, 0);
			}
			if (seed < POLE_DENSITY) {
				alive.set(ConwayGrid.keyOfPole(pole), true);
			}
		});
	}

	static function hash01(row:Int, col:Int):Float {
		var h = Math.sin(row * 127.1 + col * 311.7) * 43758.5453;
		return h - Math.floor(h);
	}

	function activityAt(key:String):Float {
		return activity.exists(key) ? activity.get(key) : 0;
	}

	function ageAt(key:String):Int {
		return age.exists(key) ? age.get(key) : 0;
	}

	function decayedActivity(key:String, flipped:Bool):Float {
		var sample = flipped ? 1.0 : 0.0;
		return activityAt(key) * ACTIVITY_DECAY + sample * (1 - ACTIVITY_DECAY);
	}
}
