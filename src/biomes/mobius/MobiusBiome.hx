package biomes.mobius;

import biomes.common.Biome;
import biomes.common.Gravity;
import biomes.common.space.mobius.MobiusMath;
import biomes.common.space.mobius.MobiusSpace;
import biomes.hub.HubBiome;
import biomes.mobius.MobiusForestGenerator.ForestLayout;
import entities.painting.PaintingModel;
import entities.player.PlayerModel;

/**
	A walkable Möbius ribbon — `twists` half-twists over one full lap (3 by
	construction the first time this was tried, per the ask; any odd value
	keeps it one-sided), grown into a proper forest (hooman: "make a forest
	out of the Moëbius Strip Biome... sow and grow lots of them"). Started
	as a bare ribbon (see `MobiusModel`'s own class doc) purely to evaluate
	the twist count's own visual/spatial feel in isolation first, per
	`docs/game-design.md`'s "prototype unproven mechanics before
	committing" pillar — the forest is the first obstacle layout built on
	top of that.

	`forest` is generated once by `MobiusForestGenerator` and handed in
	(constructor-injected from `game.GameLoop`, same "generate once, reuse
	for the whole session" shape `biomes.tower.TowerBiome`/`biomes.maze.MazeBiome`
	already use for their own layouts) rather than a bare ribbon — a
	tree's own trunk has a real hitbox now (`biomes.mobius.MobiusCollision`),
	so re-rolling it fresh on every visit would mean a path that was clear
	one visit could be blocked the next.

	Gravity uses `biomes.common.Gravity.fallToSurface` (a floor always
	directly underfoot along `space.upAt`), same as `biomes.hub.HubBiome`/
	`biomes.maze.MazeBiome` — not the tower's own real free-fall, since
	there's nothing to fall *through* here, trees included (a trunk blocks
	sideways, not underfoot).
**/
class MobiusBiome implements Biome {
	public static inline final ID:String = "mobius";

	/** Same first-pass value as the hub/maze's own. **/
	static inline final GRAVITY:Float = 60;

	/**
		Arc distance behind spawn (negative `u`) the return-to-hub trigger
		sits at — far enough that a fresh arrival standing at spawn
		(`MobiusModel.spawnPosition`) doesn't immediately re-trigger it
		(must clear `entities.painting.PaintingModel.TRIGGER_DISTANCE`, 4).
		No visible painting mounted here yet (see class doc) — a bare
		ribbon has no wall to mount one on — so this is a positional-only
		trigger for now, a known first-pass simplification alongside the
		bare-ribbon scope itself.
	**/
	static inline final EXIT_ARC_OFFSET:Float = 8;

	final twists:Int;

	final space:MobiusSpace;

	/** The generated forest this visit walks through — see class doc for why it's handed in rather than rolled fresh each visit. Replaced wholesale by `restore`, never mutated tree-by-tree. **/
	var forest:ForestLayout;

	public function new(forest:ForestLayout, twists:Int = MobiusModel.DEFAULT_TWISTS) {
		this.forest = forest;
		this.twists = twists;
		this.space = new MobiusSpace(twists, MobiusModel.RADIUS);
	}

	public function id():String {
		return ID;
	}

	public function gravity():Float {
		return GRAVITY;
	}

	public function build(parent:h3d.scene.Object):Void {
		MobiusMesh.build(parent, twists, forest);
	}

	/** Always the loop's own `u = 0`, dead center across the width — see `MobiusModel.spawnPosition`/`spawnForward`. **/
	public function spawnPlayer(returning:Bool, fromBiomeId:Null<String>):PlayerModel {
		return new PlayerModel(MobiusModel.spawnPosition(twists), MobiusModel.spawnForward(twists), 0, space);
	}

	public function exitPaintings():Array<PaintingModel> {
		var exitPos = MobiusMath.pointAt(-EXIT_ARC_OFFSET / MobiusModel.RADIUS, 0, twists, MobiusModel.RADIUS);
		return [new PaintingModel(exitPos, HubBiome.ID)];
	}

	public function tryMove(player:PlayerModel, direction:h3d.Vector, distance:Float):Void {
		MobiusCollision.tryMove(player, direction, distance, twists, MobiusModel.RADIUS, forest);
	}

	public function applyGravity(player:PlayerModel, dt:Float):Void {
		Gravity.fallToSurface(player, GRAVITY, dt);
	}

	/** Nothing here ticks on its own — see `biomes.common.Biome.tick`'s own doc. **/
	public function tick(player:PlayerModel, dt:Float):Void {}

	/** No game-speed control here — see `biomes.common.Biome.timeScale`'s own doc. **/
	public function timeScale():Float {
		return 1;
	}

	public function serialize():String {
		return MobiusForestGenerator.serialize(forest);
	}

	public function restore(json:String):Void {
		forest = MobiusForestGenerator.deserialize(json);
	}
}
