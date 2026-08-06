package tools.geodesic;

/**
	Which visual/physical stage of its own life a node is in this
	generation — the thing `biomes.conway.ConwayMesh` currently decides
	inline while sorting cells into its three buffers, pulled out into
	something nameable and testable on the way to the geodesic renderer.
**/
enum LifecycleStage {
	/** Alive and freshly born — at or under `GeodesicLifecycle.YOUNG_AGE_THRESHOLD` generations old. Tallest and brightest. **/
	Young;

	/** Alive and settled — past `GeodesicLifecycle.YOUNG_AGE_THRESHOLD`. Shorter, so it can't be used to clear a wall. **/
	Aged;

	/** Died on the most recent step — a one-generation visual flash only, never standable. **/
	Dying;

	/** Neither alive nor freshly dead: nothing rendered, flat floor. **/
	Absent;
}

/**
	The age → height/brightness lifecycle rules, keyed by node id — the
	node-id counterpart to what `biomes.conway.ConwayGrid` (heights,
	`groundHeightAt`) and `biomes.conway.ConwayMesh` (brightnesses,
	bucket sorting) split between them on the square grid.

	Deliberately one class rather than that same split: on the square grid
	the heights had to live in `ConwayGrid` because collision needed them
	and the mesh couldn't be a dependency of physics, but the *stage* was
	then re-derived independently in `ConwayMesh` from the same
	`age`/`justDied` readings — two copies of one rule, which is exactly
	the kind of drift this port is a chance to not repeat. Here
	`stageOf` is computed once and both consumers (a future geodesic mesh,
	`groundHeightOf` for collision) read off it.

	Constants are ported from `ConwayGrid`/`ConwayMesh` rather than
	re-derived — they're tuned against the player's own jump physics
	(`biomes.conway.ConwayBiome.GRAVITY`), which the sphere's cell shape
	doesn't change. See `ConwayGrid.YOUNG_BLOCK_HEIGHT`'s own doc for the
	full arithmetic behind the two standable heights and how little margin
	they leave.
**/
class GeodesicLifecycle {
	/** A node's own age, in generations, at or under which it still counts as `Young`. See `biomes.conway.ConwayGrid.YOUNG_AGE_THRESHOLD`. **/
	public static inline final YOUNG_AGE_THRESHOLD:Int = 4;

	/** How tall a `Young` node's own standable block rises. Tall enough that a second jump off it clears `WALL_HEIGHT` — the combo-jump mechanic. **/
	public static inline final YOUNG_BLOCK_HEIGHT:Float = 2.0;

	/** How tall an `Aged` node's own standable block rises — deliberately short enough that a second jump off it does *not* clear `WALL_HEIGHT`. **/
	public static inline final AGED_BLOCK_HEIGHT:Float = 1.5;

	/** How tall a `Dying` node's own one-generation flash rises. Purely visual — `groundHeightOf` ignores it, so a node dying out from under a standing player drops them. **/
	public static inline final DYING_BLOCK_HEIGHT:Float = 1.0;

	/** How tall a closed edge's own wall rises above the base surface. See `biomes.conway.ConwayGrid.WALL_HEIGHT`. **/
	public static inline final WALL_HEIGHT:Float = 7.5;

	/** `Young`'s own brightness multiplier on the live tile colour. See `biomes.conway.ConwayMesh.BIRTH_BRIGHTNESS`. **/
	public static inline final YOUNG_BRIGHTNESS:Float = 1.15;

	/** `Aged`'s own brightness multiplier. **/
	public static inline final AGED_BRIGHTNESS:Float = 0.9;

	/** `Dying`'s own brightness multiplier. **/
	public static inline final DYING_BRIGHTNESS:Float = 0.7;

	/**
		Which stage a node is in right now.
		@param state the Life layer to query.
		@param nodeId the node to classify.
		@return that node's own stage this generation.
	**/
	public static function stageOf(state:GeodesicLifeState, nodeId:Int):LifecycleStage {
		if (state.isAlive(nodeId)) {
			return state.ageOf(nodeId) <= YOUNG_AGE_THRESHOLD ? Young : Aged;
		}
		return state.justDiedAt(nodeId) ? Dying : Absent;
	}

	/**
		How tall a stage's own block is drawn.
		@param stage the stage to size.
		@return its render height, `0` for `Absent`.
	**/
	public static function blockHeightOf(stage:LifecycleStage):Float {
		return switch stage {
			case Young: YOUNG_BLOCK_HEIGHT;
			case Aged: AGED_BLOCK_HEIGHT;
			case Dying: DYING_BLOCK_HEIGHT;
			case Absent: 0;
		}
	}

	/**
		A stage's own brightness multiplier on the live tile colour.
		@param stage the stage to shade.
		@return its multiplier, `0` for `Absent` (nothing is drawn).
	**/
	public static function brightnessOf(stage:LifecycleStage):Float {
		return switch stage {
			case Young: YOUNG_BRIGHTNESS;
			case Aged: AGED_BRIGHTNESS;
			case Dying: DYING_BRIGHTNESS;
			case Absent: 0;
		}
	}

	/**
		The standable ground height at a node — the collision-side reading,
		which is *not* the same as `blockHeightOf(stageOf(...))`: a `Dying`
		node still renders its farewell flash but has already stopped being
		floor, so a player standing on it falls, the same way
		`biomes.conway.ConwayGrid.groundHeightAt` answers `0` for anything
		not currently alive. Read fresh every tick, never cached.
		@param state the Life layer to query.
		@param nodeId the node under the player.
		@return `0` unless the node is alive, its block height otherwise.
	**/
	public static function groundHeightOf(state:GeodesicLifeState, nodeId:Int):Float {
		return switch stageOf(state, nodeId) {
			case Young: YOUNG_BLOCK_HEIGHT;
			case Aged: AGED_BLOCK_HEIGHT;
			case Dying | Absent: 0;
		}
	}
}
