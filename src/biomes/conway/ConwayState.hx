package biomes.conway;

import biomes.common.grid.GridModel;
import biomes.common.grid.GridModel.GridNode;

/**
	Mutable Conway Game of Life state over the ring cells of `GridModel`.

	Only `RingNode`s participate. `PoleNode`s are intentionally ignored so the
	two merged poles don't behave like giant hub-neighbors that connect entire
	rings at once.
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
		return alive.exists(keyOf(row, col));
	}

	/** Advances one Conway generation. **/
	public function step():Void {
		var next = new haxe.ds.StringMap<Bool>();
		for (row in 1...(GridModel.ROWS - 1)) {
			for (col in 0...GridModel.colsForRow(row)) {
				var hereAlive = isAlive(row, col);
				var liveNeighbors = 0;
				for (neighbor in GridModel.neighborsOf(RingNode(row, col))) {
					switch neighbor {
						case RingNode(neighborRow, neighborCol):
							if (isAlive(neighborRow, neighborCol)) {
								liveNeighbors++;
							}
						case PoleNode(_):
					}
				}
				var nextAlive = hereAlive ? (liveNeighbors == 2 || liveNeighbors == 3) : liveNeighbors == 3;
				if (nextAlive) {
					next.set(keyOf(row, col), true);
				}
			}
		}
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
		for (row in 1...(GridModel.ROWS - 1)) {
			for (col in 0...GridModel.colsForRow(row)) {
				// Deterministic noise so the same session starts from the same
				// pattern, while still looking naturally scattered.
				if (hash01(row, col) < INITIAL_DENSITY) {
					alive.set(keyOf(row, col), true);
				}
			}
		}
	}

	static function hash01(row:Int, col:Int):Float {
		var h = Math.sin(row * 127.1 + col * 311.7) * 43758.5453;
		return h - Math.floor(h);
	}

	static function keyOf(row:Int, col:Int):String {
		return GridModel.nodeKey(RingNode(row, col));
	}
}
