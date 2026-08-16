package biomes.ribbon;

import biomes.common.Biome;
import biomes.common.Gravity;
import biomes.common.space.flat.FlatSpace;
import biomes.hub.HubBiome;
import entities.painting.PaintingModel;
import entities.player.Camera.CameraOverride;
import entities.player.PlayerModel;

/**
	**The Ribbon** — a world that is a *line*, whose second walkable axis
	is time. See
	[the design](../../../docs/game/world.md)'s
	own entry (`### 6. The Ribbon`).

	The ground is the spacetime diagram of an elementary cellular
	automaton (`RibbonAutomaton`, Rule 110), laid out generation by
	generation: **walking north walks into the past**. Every live cell of
	every generation is a raised slab, so the history the player is
	standing on is legible as relief. Walk far enough and the diagram
	thins to the single cell of generation `0` — the initial condition,
	which somebody typed — and then the ground stops.

	Tonally the odd one out on purpose: a museum, or a graveyard, rather
	than a place with weather. Nothing here moves. Every other biome in
	the game ticks; this one is the only place whose contents are already
	finished, which is what makes it read as the past rather than as more
	present.

	**Geometrically it is the simplest biome in the game**, and that is
	the point of building it now. `FlatSpace` already existed, gravity
	against a heightfield is `Gravity.fallToSurface`'s own `groundHeight`
	parameter (which `biomes.hub.HubBiome` already uses to stand on
	walls), and collision is a per-axis clamp. Almost nothing here is new
	machinery — the interesting content is the *idea*, and it was worth
	finding out how cheaply the idea could be made walkable.
**/
class RibbonBiome implements Biome {
	public static inline final ID:String = "ribbon";

	/** Same first-pass value as the maze's — see `biomes.hub.HubBiome.GRAVITY`'s own doc for why each biome states its own. **/
	static inline final GRAVITY:Float = 60;

	/** How far in front of the newest generation's own edge the player starts, so they are standing on the diagram rather than on its boundary. **/
	static inline final SPAWN_MARGIN:Float = RibbonModel.CELL_SIZE * 2;

	/**
		Spawn pitch, looking down the slope rather than level.

		Every other biome spawns at `0`, and level is wrong here for a
		reason worth stating: the strip *descends* into the past (see
		`RibbonModel.DESCENT_PER_GENERATION`), so a player standing at the
		present end and looking horizontally is looking out over the top of
		the whole diagram at empty sky — which is exactly what standing at
		the top of a hill looks like, and a terrible first frame. Pitched
		down a little past the slope's own angle, the first thing in view
		is the history itself falling away toward the monolith.
	**/
	static inline final SPAWN_PITCH:Float = -0.55;

	final automaton:RibbonAutomaton;

	public function new() {
		automaton = new RibbonAutomaton(RibbonModel.RULE, RibbonModel.WIDTH, RibbonModel.GENERATIONS, RibbonModel.SEED_INDEX);
	}

	public function id():String {
		return ID;
	}

	public function gravity():Float {
		return GRAVITY;
	}

	/** Neutral and unlit — κ = 0 is bone/slate/ash per `docs/game/art-and-audio.md`, and this is the flattest thing in the game in both senses. **/
	public function backgroundColor():Int {
		return 0x16181B;
	}

	public function build(parent:h3d.scene.Object):Void {
		RibbonMesh.build(automaton, parent);
	}

	/**
		Spawns at the newest generation, facing the past — so the first
		thing in view is the monolith at the far end, and the direction of
		the whole biome needs no telling.
		@param returning unused — there is nothing here to resume, and the walk is the content.
		@param fromBiomeId unused.
		@return the spawned player, walking in `FlatSpace`.
	**/
	public function spawnPlayer(returning:Bool, fromBiomeId:Null<String>):PlayerModel {
		var pos = new h3d.Vector(RibbonModel.xOf(RibbonModel.SEED_INDEX), 0, RibbonModel.PRESENT_EDGE - SPAWN_MARGIN);
		return new PlayerModel(pos, new h3d.Vector(0, 0, -1), SPAWN_PITCH, FlatSpace.INSTANCE);
	}

	/** One way out, at the present end — behind the player at spawn, so leaving is a decision to turn round rather than something walked into by accident. **/
	public function exitPaintings():Array<PaintingModel> {
		return [
			new PaintingModel(new h3d.Vector(RibbonModel.xOf(RibbonModel.SEED_INDEX), 0, RibbonModel.PRESENT_EDGE), HubBiome.ID, RibbonModel.CELL_SIZE)
		];
	}

	/**
		Walks, then holds the result inside the strip.

		Clamping the destination rather than rejecting the move is what
		makes the boundaries slide — see `RibbonModel.clampToBounds`. Safe
		here in a way it would not be against maze walls: the strip is
		convex, so a clamped point is always somewhere the player could
		legitimately have walked, and there is nothing to clip through.
		@param player the player to move.
		@param direction unit tangent at `player.pos` to move along.
		@param distance arc length to move; negative moves the opposite way.
	**/
	public function tryMove(player:PlayerModel, direction:h3d.Vector, distance:Float):Void {
		player.moveAlong(direction, distance, 1);
		player.pos = RibbonModel.clampToBounds(player.pos);
	}

	/** Falls onto the diagram's own relief — `groundHeight` is what turns a picture of a history into terrain, see `RibbonModel.groundHeightAt`. **/
	public function applyGravity(player:PlayerModel, dt:Float):Void {
		Gravity.fallToSurface(player, GRAVITY, dt, RibbonModel.groundHeightAt(automaton, player.pos));
	}

	/** **Nothing here ticks**, and that is the biome — see the class doc. **/
	public function tick(player:PlayerModel, dt:Float):Void {}

	/** Nothing to interact with yet — see `biomes.common.Biome.interact`'s own doc. **/
	public function interact(player:PlayerModel):Void {}

	/** No camera override here — see `biomes.common.Biome.cameraOverride`'s own doc. **/
	public function cameraOverride(player:PlayerModel):Null<CameraOverride> {
		return null;
	}

	/** Never captures input — see `biomes.common.Biome.capturesInput`'s own doc. **/
	public function capturesInput():Bool {
		return false;
	}

	/** Nothing to click on here — see `biomes.common.Biome.onEditClick`'s own doc. **/
	public function onEditClick(ray:h3d.col.Ray):Void {}

	/** No game-speed control here — see `biomes.common.Biome.timeScale`'s own doc. **/
	public function timeScale():Float {
		return 1;
	}

	/** Nothing worth saving: the history is regenerated identically from `RibbonModel`'s own constants — see `biomes.common.Biome.serialize`'s own doc. **/
	public function serialize():String {
		return "{}";
	}

	/** Nothing to restore — see `serialize`. **/
	public function restore(json:String):Void {}
}
