package tools.geodesic;

import tools.geodesic.GeodesicSphere.GeodesicSphereData;

/**
	Which visual/physical stage of its own life a node is in this
	generation — the thing `biomes.conway.ConwayMesh` currently decides
	inline while sorting cells into its three buffers, pulled out into
	something nameable and testable on the way to the geodesic renderer.
**/
enum LifecycleStage {
	/** Alive this generation — standable at `GeodesicLifecycle.ALIVE_BLOCK_HEIGHT`. **/
	Alive;

	/** Died on the most recent step — a one-generation visual flash only, never standable. **/
	Dying;

	/** Neither alive nor freshly dead: nothing rendered, flat floor. **/
	Absent;
}

/**
	The alive/dying → height/brightness rules, keyed by node id, over
	`GeodesicVentrellaState` — the node-id counterpart to what
	`biomes.conway.ConwayGrid` (heights, `groundHeightAt`) and
	`biomes.conway.ConwayMesh` (brightnesses, bucket sorting) split between
	them on the square grid.

	**No age tier, deliberately (2026-08-09) — simplified from an earlier
	Young/Aged split built for `GeodesicLifeState`.** That split read a
	single species getting visually older; `GeodesicVentrellaState`'s own
	states are different species appearing as gliders collide, not age
	classes of one thing, so aging a cell in place stopped meaning anything
	once the biome switched engines (see `GeodesicVentrellaState`'s own
	doc for why). Per-state coloring was raised as the natural next step
	but deliberately deferred rather than guessed at ahead of seeing what
	the rule actually produces — this class carries exactly one visual
	tier for "alive" until that's designed.

	One real cost of dropping the split: `ALIVE_BLOCK_HEIGHT` reuses the
	old `YOUNG_BLOCK_HEIGHT` value specifically (not `AGED_BLOCK_HEIGHT`)
	so the combo-jump mechanic (`GeodesicLifecycleTest`'s own
	`testAnAliveBlockIsTallEnoughToJumpAWall`) stays available on every
	live block rather than silently narrowing to a subset of them — a
	real gameplay-feel change (every live cell is now jumpable, not just
	freshly-born ones), flagged rather than left as an unstated side
	effect of the merge.
**/
class GeodesicLifecycle {
	/** How tall an `Alive` node's own standable block rises. Tall enough that a second jump off it clears `WALL_HEIGHT` — the combo-jump mechanic. See this class's own doc for why every live cell gets this height now, not just freshly-born ones. **/
	public static inline final ALIVE_BLOCK_HEIGHT:Float = 2.0;

	/** How tall a `Dying` node's own one-generation flash rises. Purely visual — `groundHeightOf` ignores it, so a node dying out from under a standing player drops them. **/
	public static inline final DYING_BLOCK_HEIGHT:Float = 1.0;

	/** How tall a closed edge's own wall rises above the base surface. See `biomes.conway.ConwayGrid.WALL_HEIGHT`. **/
	public static inline final WALL_HEIGHT:Float = 7.5;

	/** `Alive`'s own brightness multiplier on the live tile colour. **/
	public static inline final ALIVE_BRIGHTNESS:Float = 1.15;

	/** `Dying`'s own brightness multiplier. **/
	public static inline final DYING_BRIGHTNESS:Float = 0.7;

	/**
		Which stage a node is in right now.
		@param state the Ventrella layer to query.
		@param nodeId the node to classify.
		@return that node's own stage this generation.
	**/
	public static function stageOf(state:GeodesicVentrellaState, nodeId:Int):LifecycleStage {
		if (state.isAlive(nodeId)) {
			return Alive;
		}
		return state.justDiedAt(nodeId) ? Dying : Absent;
	}

	/**
		Every node's own stage, snapshotted in one array — what
		`GeodesicConwayBiome` diffs across two consecutive generation
		boundaries (`previousStages`/`currentStages`) so
		`GeodesicMesh.buildLiveCells` can smoothly interpolate block height
		between them every render frame, instead of a live block popping
		into or out of existence the instant a generation advances.
		@param state the Ventrella layer to snapshot.
		@param sphere the topology `state` runs on.
		@return one stage per node, indexed the same way `sphere.neighbors` is.
	**/
	public static function stagesOf(state:GeodesicVentrellaState, sphere:GeodesicSphereData):Array<LifecycleStage> {
		return [for (id in 0...sphere.neighbors.length) stageOf(state, id)];
	}

	/**
		How tall a stage's own block is drawn.
		@param stage the stage to size.
		@return its render height, `0` for `Absent`.
	**/
	public static function blockHeightOf(stage:LifecycleStage):Float {
		return switch stage {
			case Alive: ALIVE_BLOCK_HEIGHT;
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
			case Alive: ALIVE_BRIGHTNESS;
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
		@param state the Ventrella layer to query.
		@param nodeId the node under the player.
		@return `0` unless the node is alive, its block height otherwise.
	**/
	public static function groundHeightOf(state:GeodesicVentrellaState, nodeId:Int):Float {
		return switch stageOf(state, nodeId) {
			case Alive: ALIVE_BLOCK_HEIGHT;
			case Dying | Absent: 0;
		}
	}
}
