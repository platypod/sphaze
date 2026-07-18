package biomes.tower;

/**
	A layer's own solid/hole tiles: `solidTiles[ring][tile]`. Which specific
	layer, ring, and tile a world position falls into is this class's own
	query logic (`ringAt`/`tileAt`/`isSolid`); which tiles actually come out
	solid is `TowerGenerator`'s job, same split `biomes.common.grid.GridModel`/
	`biomes.maze.MazeGenerator` already establish for the maze.
**/
typedef TowerData = {
	var solidTiles:Array<Array<Array<Bool>>>;
}

/**
	The tower's own topology: a vertical shaft, cross-section a small always-
	solid center disk surrounded by `RINGS_PER_LAYER` concentric rings, each
	ring cut into tiles at an angle that shears further per ring — successive
	rings' tile boundaries don't line up radially, giving the whole cross-
	section the look of a camera aperture's overlapping blades rather than a
	plain pie chart. `GOAL_LEVELS` such layers stack directly below each
	other, `LAYER_HEIGHT` apart; the bottom-most layer is always fully solid
	(see `TowerGenerator.generate`) so a fall always eventually lands
	somewhere, never past the tower's own floor.

	Pure topology/queries only, same split `biomes.common.grid.GridModel`
	keeps from its own generation algorithm — first-pass numbers below,
	expected to be retuned by feel once this is actually playable (same
	discipline `biomes.common.grid.GridGeometry`'s own constants went
	through; see docs/PROJECT_LOG.md).
**/
class TowerModel {
	/** How many layers make up the tower — reaching the bottom is the descent's own goal. **/
	public static inline final GOAL_LEVELS:Int = 20;

	/** Vertical gap between consecutive layers. **/
	public static inline final LAYER_HEIGHT:Float = 12;

	/** The shaft's own outer wall, measured from the central axis. **/
	public static inline final OUTER_RADIUS:Float = 40;

	/** The always-solid disk at a layer's own center — a reliable landing spot every layer, regardless of the surrounding rings' own generated pattern. **/
	public static inline final CENTER_DISK_RADIUS:Float = 6;

	/** How many concentric rings surround the center disk, out to `OUTER_RADIUS`. **/
	public static inline final RINGS_PER_LAYER:Int = 4;

	/** Tile count of the innermost ring (ring 0) — later rings scale up from this (see `tilesForRing`) so a tile's own physical width stays roughly consistent despite each ring's larger circumference. **/
	public static inline final BASE_TILES_PER_RING:Int = 6;

	/** Angular shear applied per ring, on top of the previous ring's own tile boundaries — what actually gives the cross-section its "aperture blades" look rather than plain radial spokes straight through every ring. **/
	public static inline final RING_ANGLE_STEP:Float = 0.35;

	/** Fraction of a ring's tiles solid at the topmost layer (level 0). **/
	public static inline final FLOOR_DENSITY_START:Float = 0.65;

	/** Fraction of a ring's tiles solid at the goal layer — lower than `FLOOR_DENSITY_START`, so the descent reads as getting harder the deeper the player goes. **/
	public static inline final FLOOR_DENSITY_END:Float = 0.4;

	/**
		The world height a given layer's own floor sits at — layer 0 (the
		spawn layer) at `0`, decreasing (more negative) with each layer down,
		matching how `PlayerModel.pos.y` decreases while falling.
		@param layer the layer index (0 to `GOAL_LEVELS - 1`).
		@return that layer's own floor height.
	**/
	public static inline function layerY(layer:Int):Float {
		return -layer * LAYER_HEIGHT;
	}

	/**
		Which layer a given world height falls within — the inverse of
		`layerY`, clamped to a real layer index at either end of the shaft.
		@param y world height.
		@return the layer index at or containing `y`.
	**/
	public static function layerAt(y:Float):Int {
		var layer = Math.floor(-y / LAYER_HEIGHT);
		return clampInt(layer, 0, GOAL_LEVELS - 1);
	}

	/** Each ring's own uniform radial width, dividing the space between the center disk and the outer wall evenly. **/
	public static inline function ringWidth():Float {
		return (OUTER_RADIUS - CENTER_DISK_RADIUS) / RINGS_PER_LAYER;
	}

	/**
		Tile count for `ring` — scales up with ring index so a tile's own
		physical arc width stays roughly consistent despite each successive
		ring's larger circumference (same reasoning
		`biomes.common.grid.GridModel.colsForRow` uses for the maze's own
		latitude bands).
		@param ring the ring index (0 to `RINGS_PER_LAYER - 1`).
		@return that ring's own tile count.
	**/
	public static inline function tilesForRing(ring:Int):Int {
		return BASE_TILES_PER_RING * (ring + 1);
	}

	/** The angular offset `ring`'s own tile boundaries start at, relative to ring 0's — see `RING_ANGLE_STEP`'s own doc. **/
	public static inline function ringAngleOffset(ring:Int):Float {
		return ring * RING_ANGLE_STEP;
	}

	/**
		Which ring `(x, z)` falls within, within a single layer — `-1` for
		the always-solid center disk, which has no ring/tile data backing it
		at all.
		@param x horizontal position, relative to the shaft's own central axis.
		@param z horizontal position, relative to the shaft's own central axis.
		@return the ring index, or `-1` for the center disk.
	**/
	public static function ringAt(x:Float, z:Float):Int {
		var r = Math.sqrt(x * x + z * z);
		if (r <= CENTER_DISK_RADIUS) {
			return -1;
		}
		var ring = Math.floor((r - CENTER_DISK_RADIUS) / ringWidth());
		return clampInt(ring, 0, RINGS_PER_LAYER - 1);
	}

	/**
		Which of `ring`'s own tiles `(x, z)` falls within.
		@param ring the ring index — see `ringAt`; never called with `-1` (the center disk has no tiles).
		@param x horizontal position, relative to the shaft's own central axis.
		@param z horizontal position, relative to the shaft's own central axis.
		@return the tile index within that ring.
	**/
	public static function tileAt(ring:Int, x:Float, z:Float):Int {
		var tileCount = tilesForRing(ring);
		var tileWidth = 2 * Math.PI / tileCount;
		var angle = Math.atan2(z, x) - ringAngleOffset(ring);
		var normalized = ((angle % (2 * Math.PI)) + 2 * Math.PI) % (2 * Math.PI);
		return clampInt(Math.floor(normalized / tileWidth), 0, tileCount - 1);
	}

	/**
		Whether `(x, z)` has a floor at `layer` — always true within the
		center disk, otherwise whichever `TowerGenerator` generated for that
		specific ring/tile.
		@param layout the tower's own generated layout.
		@param layer the layer index to check.
		@param x horizontal position, relative to the shaft's own central axis.
		@param z horizontal position, relative to the shaft's own central axis.
		@return true if there's a floor at that exact point.
	**/
	public static function isSolid(layout:TowerData, layer:Int, x:Float, z:Float):Bool {
		var ring = ringAt(x, z);
		if (ring == -1) {
			return true;
		}
		return layout.solidTiles[layer][ring][tileAt(ring, x, z)];
	}

	/**
		The first layer at or below `fromLayer` with a floor under `(x, z)`
		— always terminates at or before `GOAL_LEVELS - 1`, which
		`TowerGenerator.generate` always makes fully solid.
		@param layout the tower's own generated layout.
		@param fromLayer the layer to start scanning downward from.
		@param x horizontal position, relative to the shaft's own central axis.
		@param z horizontal position, relative to the shaft's own central axis.
		@return the first solid layer at or below `fromLayer`.
	**/
	public static function floorLayerBelow(layout:TowerData, fromLayer:Int, x:Float, z:Float):Int {
		var layer = clampInt(fromLayer, 0, GOAL_LEVELS - 1);
		while (layer < GOAL_LEVELS - 1 && !isSolid(layout, layer, x, z)) {
			layer++;
		}
		return layer;
	}

	static inline function clampInt(v:Int, lo:Int, hi:Int):Int {
		return v < lo ? lo : (v > hi ? hi : v);
	}
}
