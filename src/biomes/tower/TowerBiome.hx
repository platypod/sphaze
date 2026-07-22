package biomes.tower;

import biomes.common.Biome;
import biomes.common.space.flat.FlatSpace;
import biomes.hub.HubBiome;
import biomes.tower.TowerModel.TowerData;
import entities.hourglass.HourglassModel;
import entities.painting.PaintingModel;
import entities.player.PlayerModel;
import graphics.Colours;

/**
	The vertical tower: a shaft of stacked circular layers (see `TowerModel`'s
	own class doc for the cross-section shape) the player free-falls down
	through gaps in, walls all around, gravity lighter than the hub/maze's.
	The descent's own goal is reaching the bottom (`TowerModel.GOAL_LEVELS`),
	tracked here as `deepestLayerReached` — a running max, not just the
	latest tick's own layer, so jumping back upward mid-fall never un-gates
	the return painting once it's actually been earned. Only one biome ever
	leads here (the hub), so `spawnPlayer`'s `returning`/`fromBiomeId` don't
	need to distinguish anything — every arrival starts the same way, at
	`TowerModel.SPAWN_LAYER`'s own always-solid entrance tile.

	Also tracks the "Falls counter" (docs/game-design/ideas-backlog.md's backlog entry,
	being implemented here): how many *distinct* layers the player has
	stood on this visit, `fallCount` — counting a re-landing on an
	already-touched layer only once, unlike `deepestLayerReached`, which
	only cares about the deepest point ever reached regardless of how many
	stops it took to get there. Cued diegetically (per this project's
	"Diegetic over UI chrome" pillar) rather than as a HUD number: the
	floor's own ring-boundary glow (`TowerMesh.setFallGlow`,
	`graphics.shaders.TileRingGlow`) grows brighter and reaches further
	rings out from the center disk as the count's own *percentage* of
	`TowerModel.GOAL_LEVELS` climbs, nudging the player toward threading
	gaps rather than landing on every floor along the way — precision, not
	speed, per the ask.

	`hourglassModel` is the same shared instance `HubBiome` ticks — passed in
	rather than looked up, since a biome only ever knows other biomes by id
	(see `biomes.common.Biome`'s own class doc), never by reaching into
	another one's instance. Once `HourglassModel.unlocked` (the hub's own
	hidden mechanic, "pushing past the minus floor, repeatedly" — see that
	class's own doc), the falls counter above stops meaning anything: the
	floor lights up in full, in gold rather than the counter's own white, and
	stays that way regardless of what's actually been touched (see
	`markTouched`/`build`).
**/
class TowerBiome implements Biome {
	public static inline final ID:String = "tower";

	/**
		Lighter than the hub/maze's own (`biomes.hub.HubBiome.GRAVITY`) —
		"slightly decreased," per the ask. First-pass value, tune by feel.
	**/
	static inline final GRAVITY:Float = 42;

	var layout:TowerData;

	/** The shared hourglass state `HubBiome` owns and ticks — read-only here, just for `unlocked` (see class doc). **/
	final hourglassModel:HourglassModel;

	/** The deepest layer reached so far this visit — see class doc for why this is a running max, not the latest tick's own layer. **/
	var deepestLayerReached:Int = TowerModel.SPAWN_LAYER;

	/** Which layers have been landed on at least once this visit — see `fallCount`'s own doc. Reset fresh every `spawnPlayer` (an `Array<Bool>`, not just a count, so re-landing on the same layer never double-counts). **/
	var touchedLayers:Array<Bool>;

	/** How many distinct entries in `touchedLayers` are `true` — see class doc. Kept alongside `touchedLayers` rather than recomputed, since it's read every landing to drive `updateFallGlow`. **/
	var fallCount:Int = 0;

	/** The floor's own ring-glow shader handle `build` hands back — `null` only in the instant between construction and this biome's first `build()` call. **/
	var visuals:Null<TowerMesh.TowerVisuals>;

	public function new(layout:TowerData, hourglassModel:HourglassModel) {
		this.layout = layout;
		this.hourglassModel = hourglassModel;
		this.touchedLayers = [for (i in 0...TowerModel.TOTAL_LEVELS) false];
	}

	public function id():String {
		return ID;
	}

	public function gravity():Float {
		return GRAVITY;
	}

	public function backgroundColor():Int {
		return 0x202020;
	}

	/**
		Builds the shaft's own meshes, then — if the hourglass secret was
		already triggered on some earlier hub visit before this entry —
		immediately lights the floor in full, gold, per class doc, rather
		than waiting for a landing to ever drive `markTouched` again (which
		`markTouched` itself now refuses to do once `unlocked`).
	**/
	public function build(parent:h3d.scene.Object):Void {
		visuals = TowerMesh.build(layout, parent);
		if (hourglassModel.unlocked) {
			TowerMesh.setFallGlow(visuals, 1, Colours.TOWER_SECRET_GLOW);
		}
	}

	/**
		Always `TowerModel.SPAWN_LAYER`'s own entrance tile
		(`TowerModel.entranceSpawnPosition`) — forced solid by
		`TowerGenerator.generate` regardless of the rest of the generated
		layout, so a fresh arrival always has real footing right at the
		doorway instead of walking blind to the center disk across the
		shaft. Resets `deepestLayerReached` and the fall counter
		(`touchedLayers`/`fallCount`), since every arrival starts the descent
		over — and immediately marks the entrance layer touched, since
		standing on it at spawn is itself "stepping foot on" that layer (see
		`fallCount`'s own doc).
	**/
	public function spawnPlayer(returning:Bool, fromBiomeId:Null<String>):PlayerModel {
		deepestLayerReached = TowerModel.SPAWN_LAYER;
		touchedLayers = [for (i in 0...TowerModel.TOTAL_LEVELS) false];
		fallCount = 0;
		markTouched(TowerModel.SPAWN_LAYER);
		return new PlayerModel(TowerModel.entranceSpawnPosition(), TowerModel.entranceSpawnForward(), 0, FlatSpace.INSTANCE);
	}

	/**
		An always-available entrance painting at the top (an escape hatch
		near spawn — giving up partway down shouldn't strand the player
		until they reach the bottom), plus the goal painting once the
		player has actually reached it — a running max
		(`deepestLayerReached`), not the latest tick's own layer, so
		jumping back upward mid-fall never un-gates it once it's been
		earned. Both lead back to the hub; see `TowerMesh` for where
		they're actually mounted.
	**/
	public function exitPaintings():Array<PaintingModel> {
		var paintings = [wallPainting(TowerModel.SPAWN_LAYER)];
		if (deepestLayerReached >= TowerModel.TOTAL_LEVELS - 1) {
			paintings.push(wallPainting(TowerModel.TOTAL_LEVELS - 1));
		}
		return paintings;
	}

	/**
		The hub-bound painting mounted on the outer wall at `layer`'s own
		height — see `TowerModel.paintingWallEdge`. Triggers off
		`midpointOf` (the wall's own floor-level reference), not the
		painting's actually-rendered, wall-mounted-height center: `pos` is
		a *feet*-level point, so comparing it against an elevated center
		left the vertical gap alone bigger than `PaintingModel.TRIGGER_DISTANCE`
		— the painting was only reachable by jumping to briefly close it
		(reported directly), never by walking straight up to it the way
		every other painting in this project already works.
	**/
	static function wallPainting(layer:Int):PaintingModel {
		var left = TowerModel.paintingWallEdge(layer, true);
		var right = TowerModel.paintingWallEdge(layer, false);
		return new PaintingModel(PaintingModel.midpointOf(left, right), HubBiome.ID);
	}

	public function tryMove(player:PlayerModel, direction:h3d.Vector, distance:Float):Void {
		TowerCollision.tryMove(player, direction, distance);
	}

	public function applyGravity(player:PlayerModel, dt:Float):Void {
		var wasGrounded = player.grounded;
		var layer = TowerCollision.applyGravity(player, GRAVITY, layout, dt);
		if (layer > deepestLayerReached) {
			deepestLayerReached = layer;
		}
		// Edge-triggered, not "grounded every tick": once landed, the
		// player stays grounded on the same layer for many subsequent
		// ticks, and only the tick that transitions into that state is an
		// actual new landing (see fallCount's own doc for why it shouldn't
		// recount a floor already stood on).
		if (player.grounded && !wasGrounded) {
			markTouched(layer);
		}
	}

	/**
		Marks `layer` as stepped on, bumping `fallCount` and refreshing the
		glow only if it wasn't already touched this visit — a no-op entirely
		once `hourglassModel.unlocked`: the counter is disabled at that point
		(per class doc), so a landing never fights `build`'s own gold,
		full-intensity glow back down to whatever the counter alone would
		read.
		@param layer the layer index just landed on (or, at spawn, started on).
	**/
	function markTouched(layer:Int):Void {
		if (hourglassModel.unlocked) {
			return;
		}
		if (touchedLayers[layer]) {
			return;
		}
		touchedLayers[layer] = true;
		fallCount++;
		if (visuals != null) {
			TowerMesh.setFallGlow(visuals, TowerModel.fallGlowIntensity(fallCount));
		}
	}

	/** Nothing here ticks on its own — see `biomes.common.Biome.tick`'s own doc. **/
	public function tick(player:PlayerModel, dt:Float):Void {}

	/** No game-speed control here — see `biomes.common.Biome.timeScale`'s own doc. **/
	public function timeScale():Float {
		return 1;
	}

	public function serialize():String {
		return TowerGenerator.serialize(layout);
	}

	public function restore(json:String):Void {
		layout = TowerGenerator.deserialize(json);
	}
}
