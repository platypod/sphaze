package biomes.conway;

/**
	Mutable Conway Game of Life state over `ConwayGrid`'s own denser tile set.
**/
class ConwayState {
	static inline final INITIAL_DENSITY:Float = 0.24;

	var alive:haxe.ds.StringMap<Bool>;

	public function new() {
		alive = new haxe.ds.StringMap<Bool>();
		seedInitial();
	}

	/** Whether ring cell `(row, col)` is currently alive. **/
	public function isAlive(row:Int, col:Int):Bool {
		return alive.exists(ConwayGrid.keyOf(row, col));
	}

	/** Advances one Conway generation. **/
	public function step():Void {
		var next = new haxe.ds.StringMap<Bool>();
		ConwayGrid.eachCell((row, col) -> {
			var hereAlive = isAlive(row, col);
			var liveNeighbors = ConwayGrid.liveNeighborCount(this, row, col);
			var nextAlive = hereAlive ? (liveNeighbors == 2 || liveNeighbors == 3) : liveNeighbors == 3;
			if (nextAlive) {
				next.set(ConwayGrid.keyOf(row, col), true);
			}
		});
		alive = next;
	}

	public function serialize():String {
		var live:Array<String> = [];
		for (key => _ in alive) {
			live.push(key);
		}
		return haxe.Json.stringify({live: live});
	}

	public static function deserialize(json:String):ConwayState {
		var parsed:Dynamic = haxe.Json.parse(json);
		var state = new ConwayState();
		state.alive = new haxe.ds.StringMap<Bool>();
		var liveEntries:Array<Dynamic> = parsed.live;
		if (liveEntries != null) {
			for (entry in liveEntries) {
				var key:String = Std.string(entry);
				if (key.length > 0) {
					state.alive.set(key, true);
				}
			}
		}
		return state;
	}

	function seedInitial():Void {
		ConwayGrid.eachCell((row, col) -> {
			// Deterministic noise so the same session starts from the same
			// pattern, while still looking naturally scattered.
			if (hash01(row, col) < INITIAL_DENSITY) {
				alive.set(ConwayGrid.keyOf(row, col), true);
			}
		});
	}

	static function hash01(row:Int, col:Int):Float {
		var h = Math.sin(row * 127.1 + col * 311.7) * 43758.5453;
		return h - Math.floor(h);
	}
}
