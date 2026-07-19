package biomes.tower;

import biomes.tower.TowerModel.TowerData;

/**
	Generates and (de)serializes the tower biome's own layout — which ring
	tiles come out solid per layer, as opposed to `TowerModel`'s topology/
	query logic, which any layer shares regardless of its own content. Same
	split `biomes.maze.MazeGenerator` keeps from `biomes.common.grid.GridModel`.
**/
class TowerGenerator {
	/**
		Generates a full tower: each layer's own ring tiles come out solid
		independently at random, at that layer's own interpolated density
		(see `densityAt`) — except the bottom-most layer, always fully solid
		so a fall always eventually lands somewhere real, and layer 0's own
		`TowerModel.entranceTileIndex()`, always forced solid too so a fresh
		arrival through the entrance painting always has real footing right
		at the doorway (see that method's own doc).
		@param random source of randomness in [0, 1); defaults to `Math.random`.
		@return the generated tower's layout.
	**/
	public static function generate(?random:Void->Float):TowerData {
		var rng = random != null ? random : Math.random;
		var solidTiles:Array<Array<Array<Bool>>> = [];

		for (layer in 0...TowerModel.TOTAL_LEVELS) {
			var density = densityAt(layer);
			var rings:Array<Array<Bool>> = [];

			for (ring in 0...TowerModel.RINGS_PER_LAYER) {
				var tiles:Array<Bool> = [];
				for (tile in 0...TowerModel.tilesForRing(ring)) {
					tiles.push(isForcedSolid(layer, ring, tile) ? true : rng() < density);
				}
				rings.push(tiles);
			}

			solidTiles.push(rings);
		}

		return {solidTiles: solidTiles};
	}

	/** Whether `(layer, ring, tile)` is solid regardless of the random roll — see `generate`'s own doc for why the bottom layer and `SPAWN_LAYER`'s entrance tile both are. **/
	static inline function isForcedSolid(layer:Int, ring:Int, tile:Int):Bool {
		if (layer == TowerModel.TOTAL_LEVELS - 1) {
			return true;
		}
		return layer == TowerModel.SPAWN_LAYER && ring == TowerModel.entranceTileRing() && tile == TowerModel.entranceTileIndex();
	}

	/**
		The fraction of a ring's tiles that should come out solid at `layer`
		— linearly interpolated from `TowerModel.FLOOR_DENSITY_START` (at
		`SPAWN_LAYER`) to `TowerModel.FLOOR_DENSITY_END` (the goal level), so
		the descent reads as getting harder the deeper the player goes.
		Layers above `SPAWN_LAYER` (`TowerModel.ABOVE_SPAWN_LEVELS`) aren't
		part of that descent at all — they read at the same, easiest density
		as the entrance itself, same as `SPAWN_LAYER` would if the curve
		were extrapolated backward past its own start. The one knob to
		retune if the descent's own pacing needs to grow, shrink, or flatten
		out instead.
		@param layer the physical layer index (0 to `TowerModel.TOTAL_LEVELS - 1`).
		@return that layer's own floor density, in [0, 1).
	**/
	public static function densityAt(layer:Int):Float {
		if (TowerModel.GOAL_LEVELS <= 1) {
			return TowerModel.FLOOR_DENSITY_START;
		}
		var descentLayer = layer - TowerModel.SPAWN_LAYER;
		if (descentLayer < 0) {
			descentLayer = 0;
		}
		var t = descentLayer / (TowerModel.GOAL_LEVELS - 1);
		return TowerModel.FLOOR_DENSITY_START + (TowerModel.FLOOR_DENSITY_END - TowerModel.FLOOR_DENSITY_START) * t;
	}

	/**
		Serializes a generated tower to a JSON string — same role as
		`biomes.maze.MazeGenerator.serialize`, for `GameLoop`'s E (export) dev
		tool. Unlike the maze's own open-edge set, a tower's layout is
		already a plain nested array, so this needs no encoding beyond
		`haxe.Json.stringify` itself.
		@param layout the tower to serialize.
		@return a JSON string.
	**/
	public static function serialize(layout:TowerData):String {
		return haxe.Json.stringify(layout);
	}

	/**
		Inverse of `serialize`.
		@param json a JSON string produced by `serialize`.
		@return the tower layout it encodes.
	**/
	public static function deserialize(json:String):TowerData {
		var parsed:TowerData = haxe.Json.parse(json);
		return parsed;
	}
}
