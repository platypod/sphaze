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
		so a fall always eventually lands somewhere real.
		@param random source of randomness in [0, 1); defaults to `Math.random`.
		@return the generated tower's layout.
	**/
	public static function generate(?random:Void->Float):TowerData {
		var rng = random != null ? random : Math.random;
		var solidTiles:Array<Array<Array<Bool>>> = [];

		for (layer in 0...TowerModel.GOAL_LEVELS) {
			var density = densityAt(layer);
			var rings:Array<Array<Bool>> = [];

			for (ring in 0...TowerModel.RINGS_PER_LAYER) {
				var tiles:Array<Bool> = [];
				for (_ in 0...TowerModel.tilesForRing(ring)) {
					tiles.push(layer == TowerModel.GOAL_LEVELS - 1 ? true : rng() < density);
				}
				rings.push(tiles);
			}

			solidTiles.push(rings);
		}

		return {solidTiles: solidTiles};
	}

	/**
		The fraction of a ring's tiles that should come out solid at `layer`
		— linearly interpolated from `TowerModel.FLOOR_DENSITY_START` (level
		0) to `TowerModel.FLOOR_DENSITY_END` (the goal level), so the descent
		reads as getting harder the deeper the player goes. The one knob to
		retune if that pacing needs to grow, shrink, or flatten out instead.
		@param layer the layer index (0 to `TowerModel.GOAL_LEVELS - 1`).
		@return that layer's own floor density, in [0, 1).
	**/
	public static function densityAt(layer:Int):Float {
		if (TowerModel.GOAL_LEVELS <= 1) {
			return TowerModel.FLOOR_DENSITY_START;
		}
		var t = layer / (TowerModel.GOAL_LEVELS - 1);
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
