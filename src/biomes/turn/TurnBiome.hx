package biomes.turn;

import biomes.common.Biome;
import biomes.common.Gravity;
import biomes.common.space.flat.FlatSpace;
import biomes.hub.HubBiome;
import entities.painting.PaintingModel;
import entities.player.Camera.CameraOverride;
import entities.player.PlayerModel;

/**
	**The Turn** — a flat, genuinely non-orientable band. See
	[the design](../../../docs/game/world.md)'s
	own entry (`### 4. The Turn`).

	**Built against the design's own stated ordering.** That entry carries
	two open problems and is explicit about which comes first: the
	chirality mechanism cannot be judged until traversal is proven
	tolerable, because "a bad ribbon kills a good mechanic here". So this
	prototype is the ribbon. What it answers is *is going round repeatedly
	pleasant*, and it deliberately does not build the glider-annihilation
	puzzle on top of an unproven answer.

	**A proposal, flagged as one.** The design leaves open how the player
	discovers their own current handedness "cheaply enough that testing it
	isn't itself the boring part", and calls marks-as-reference the
	leading but unsettled candidate. This build offers a cheaper answer:
	**the band's single boundary curve is painted pale for one period and
	dashed for the next**, so which rail is beside you tells you which
	lift you are on — no instrument, no memory, no detour, read in a
	glance at speed. See `TurnMesh`, including the correction to how I
	first described it. If it works it should go into the design doc; if
	it feels like being told rather than discovering, the marks idea is
	still there.

	**Locomotion, the harder problem.** The design names two ways out and
	takes neither: make movement itself the pleasure (*Race the Sun*), or
	give each lap its own skill. This takes both, cheaply — the biome
	moves at `SPEED_MULTIPLIER` times normal walking speed, and the band
	is strewn with obstacles to weave through on a rhythm. That the rhythm
	arrives **mirrored** after each lap is what stops the second lap being
	the first lap again, which is the specific failure the design warns
	about.

	Left standing beside `biomes.mobius.MobiusBiome` rather than replacing
	it — see `TurnModel` for why the embedded version is not flat and this
	one is, and why both are worth having.
**/
class TurnBiome implements Biome {
	public static inline final ID:String = "turn";

	/** Same first-pass value as the maze's — see `biomes.hub.HubBiome.GRAVITY`'s own doc for why each biome states its own. **/
	static inline final GRAVITY:Float = 60;

	/**
		How much faster this biome moves than the rest of the game.

		Applied here in `tryMove` rather than through `timeScale()`, which
		would be wrong twice over: it is global by design (see
		`entities.registries.BiomesRegistry.globalTimeScale`) and it scales
		*time*, so it would speed up every other biome's simulation as a
		side effect of this one wanting a livelier walk.
	**/
	static inline final SPEED_MULTIPLIER:Float = 2.4;

	/** Copies of the fundamental domain drawn each way. One is enough to fill the view at this period, and the next lap is visibly mirrored from where the player stands. **/
	static inline final DRAWN_COPIES:Int = 1;

	public function new() {}

	public function id():String {
		return ID;
	}

	public function gravity():Float {
		return GRAVITY;
	}

	/** Neutral and dark, so the bright rail carries as far as possible — the one thing in this space the player must never lose track of. **/
	public function backgroundColor():Int {
		return 0x121519;
	}

	public function build(parent:h3d.scene.Object):Void {
		TurnMesh.build(parent, DRAWN_COPIES);
	}

	/**
		Spawns midway between the first two obstacles, already lined up on
		the open side of the one ahead.

		Not on the band's own axis at the origin, which is where the first
		build put the player: obstacles sit every `OBSTACLE_SPACING` along
		the band, so the origin happened to be twenty-five units from one,
		dead in line with it, and the whole first frame was a grey slab.
		Starting in a gap facing a visible line through gives the space one
		frame to say what it is.
		@param returning unused — the band is the same band however you arrive.
		@param fromBiomeId unused.
		@return the spawned player, walking in `FlatSpace`.
	**/
	public function spawnPlayer(returning:Bool, fromBiomeId:Null<String>):PlayerModel {
		var between = (TurnModel.obstacleAlong(0) + TurnModel.obstacleAlong(1)) / 2;
		// stand on whichever side of the next obstacle it is not occupying
		var clearSide = TurnModel.obstacleAcross(1) > 0 ? -1 : 1;
		var across = clearSide * TurnModel.OBSTACLE_HALF_WIDTH;
		return new PlayerModel(new h3d.Vector(between, 0, across), new h3d.Vector(1, 0, 0), 0, FlatSpace.INSTANCE);
	}

	/** One way out, on the axis a little ahead of the spawn — off to one side of the racing line, so it is not walked into by accident on every lap. **/
	public function exitPaintings():Array<PaintingModel> {
		return [
			new PaintingModel(new h3d.Vector(TurnModel.obstacleAlong(0) - 40, 0, TurnModel.HALF_WIDTH - 10), HubBiome.ID, 12)
		];
	}

	/** Moves at this biome's own pace — see `SPEED_MULTIPLIER`. **/
	public function tryMove(player:PlayerModel, direction:h3d.Vector, distance:Float):Void {
		TurnCollision.tryMove(player, direction, distance * SPEED_MULTIPLIER);
	}

	/** Flat band, flat gravity — the rails and obstacles are walls, not terrain. **/
	public function applyGravity(player:PlayerModel, dt:Float):Void {
		Gravity.fallToSurface(player, GRAVITY, dt);
	}

	/**
		Nothing here advances with time — the band is static and the whole
		motion is the player's own.

		The wrap is *not* done here despite being per-tick in spirit: it has
		to happen in the same step as the move that crossed the seam, or a
		frame renders with the player a full period outside the drawn
		world. `TurnCollision.tryMove` applies it directly.
	**/
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

	/** No game-speed control here — see `biomes.common.Biome.timeScale`'s own doc, and `SPEED_MULTIPLIER` for why this biome's own pace is not expressed through it. **/
	public function timeScale():Float {
		return 1;
	}

	/** Nothing worth saving: the band is regenerated identically from `TurnModel`'s own constants. **/
	public function serialize():String {
		return "{}";
	}

	/** Nothing to restore — see `serialize`. **/
	public function restore(json:String):Void {}
}
