package biomes.repeat;

import biomes.common.Biome;
import biomes.common.Gravity;
import biomes.common.space.flat.FlatSpace;
import biomes.hub.HubBiome;
import entities.painting.PaintingModel;
import entities.player.Camera.CameraOverride;
import entities.player.PlayerModel;

/**
	**The Repeat** — a city that goes on forever, in which every block is
	the same block. See
	[the design](../../../docs/game-design/direction/world-and-threads.md)'s
	own entry (`### 3. The Repeat`).

	**Not a quotient, on purpose.** `geometry.DeckGroup` exists and would
	fold this space into a single tile drawn many times — and that would
	destroy the mechanic, because a true torus has exactly one tile and
	nothing to compare it against. What the design wants is *many separate
	tiles that happen to be identical*: same generator, same layout, same
	future, so that a difference is evidence something intervened. See
	`RepeatModel`, which is where that distinction is kept honest.

	**The mechanic, and how much of it is here.** Walk one period and
	compare. Most tiles are indistinguishable; some have exactly one
	building missing, and the gap it leaves is ground you can walk into
	that you could not walk into in the last tile — recognising the
	difference and reaching the new ground are the same act, which is the
	design's own requirement that no puzzle be bolted on top of noticing.
	Reaching it takes the fragment standing there.

	**What is deliberately not here yet:** the composite reveal. The
	design has the fragments overlaying into *a mark, not the player's
	own* — the evidence that someone else stood here and left it to be
	found this way. That is the content payload and it wants
	`entities.painting`/`MarkModel` rendering rather than new geometry;
	building it before the comparison mechanic is confirmed to read would
	be authoring content for a mechanic that might not work. Collecting a
	fragment currently just removes it, which is enough to tell whether
	spotting divergences is satisfying at all.
**/
class RepeatBiome implements Biome {
	public static inline final ID:String = "repeat";

	/** Same first-pass value as the maze's — see `biomes.hub.HubBiome.GRAVITY`'s own doc for why each biome states its own. **/
	static inline final GRAVITY:Float = 60;

	/**
		How many tiles out from the player's own are built.

		Two is the smallest radius that still shows a *third* tile edge-on
		at the horizon, which matters: the space has to read as endlessly
		repeating rather than as a small city with a boundary, and one
		neighbouring tile in each direction does not do that.
	**/
	static inline final BUILD_RADIUS:Int = 2;

	/** How close the player must get to a fragment to take it — generous, since it stands in an open plot and hunting for a precise spot is not the puzzle. **/
	static inline final FRAGMENT_REACH:Float = 8.0;

	/** Which tiles have had their fragment taken. Keyed by `tileKey`, since the plane is unbounded and an array would have to be. **/
	final collected:Map<String, Bool> = new Map();

	/** The scene object the built region hangs under, so it can be replaced wholesale when the player crosses into a new tile. **/
	var world:Null<h3d.scene.Object>;

	/** Which tile the built region is centred on, or null before the first build. **/
	var builtAround:Null<{i:Int, j:Int}> = null;

	public function new() {}

	/** A tile's own identity as a map key. **/
	public static function tileKey(i:Int, j:Int):String {
		return '$i:$j';
	}

	public function id():String {
		return ID;
	}

	public function gravity():Float {
		return GRAVITY;
	}

	/** Neutral, and lighter than the game's other flat space — an overcast city rather than the Ribbon's own graveyard dark. **/
	public function backgroundColor():Int {
		return 0x20242A;
	}

	public function build(parent:h3d.scene.Object):Void {
		world = new h3d.scene.Object(parent);
		builtAround = null; // force a rebuild on the first tick, wherever the player turns out to be
	}

	/**
		Spawns at the centre of an open plot in tile `(0, 0)`, facing down
		a street.

		**A plot centre, specifically.** The first version spawned at the
		tile's own geometric centre and stepped outward by whole plots to
		find open ground — which, since plot centres sit at half-plot
		offsets, meant every candidate was on a plot *boundary*, nine units
		from the nearest wall. The result was a first frame with a building
		filling half of it. Searching plots by index and standing in the
		middle of one puts the nearest wall a full plot away.
		@param returning unused — the city is the same city however you arrive.
		@param fromBiomeId unused.
		@return the spawned player, walking in `FlatSpace`.
	**/
	public function spawnPlayer(returning:Bool, fromBiomeId:Null<String>):PlayerModel {
		var spot = firstOpenPlotCentre();
		return new PlayerModel(new h3d.Vector(spot.x, 0, spot.z), new h3d.Vector(0, 0, 1), 0, FlatSpace.INSTANCE);
	}

	/** The centre of the first standable plot in the spawn tile — see `spawnPlayer` for why a centre and not just any open point. **/
	function firstOpenPlotCentre():{x:Float, z:Float} {
		for (plotX in 0...RepeatModel.PLOTS_PER_TILE) {
			for (plotZ in 0...RepeatModel.PLOTS_PER_TILE) {
				if (RepeatModel.hasBuilding(0, 0, plotX, plotZ)) {
					continue;
				}
				var centre = RepeatModel.plotCentre(0, 0, plotX, plotZ);
				if (RepeatCollision.isOpen(centre.x, centre.z)) {
					return centre;
				}
			}
		}
		return RepeatModel.plotCentre(0, 0, 0, 0); // unreachable: the generator always leaves some plots empty
	}

	/** One way out, at the origin corner of the spawn tile. **/
	public function exitPaintings():Array<PaintingModel> {
		return [
			new PaintingModel(new h3d.Vector(0, 0, 0), HubBiome.ID, RepeatModel.PLOT_SIZE / 2)
		];
	}

	public function tryMove(player:PlayerModel, direction:h3d.Vector, distance:Float):Void {
		RepeatCollision.tryMove(player, direction, distance);
	}

	/** Flat ground everywhere — the buildings are walls, not terrain, so there is nothing to stand on above zero. **/
	public function applyGravity(player:PlayerModel, dt:Float):Void {
		Gravity.fallToSurface(player, GRAVITY, dt);
	}

	/**
		Rebuilds the visible city when the player crosses into a new tile,
		and takes any fragment they have reached.

		Rebuilding on a tile boundary rather than every frame is the whole
		reason the city can be unbounded: what is drawn is always a fixed
		number of tiles, and crossing a boundary shifts the window by one.
		@param player the player to build around.
		@param dt unused — nothing here advances with time, which is the point of a deterministic city.
	**/
	public function tick(player:PlayerModel, dt:Float):Void {
		collectFragmentNear(player);

		var tile = RepeatModel.tileIndexAt(player.pos.x, player.pos.z);
		var around = builtAround;
		if (around != null && around.i == tile.i && around.j == tile.j) {
			return;
		}
		rebuild(tile);
	}

	/**
		Takes the fragment in the player's own tile, if they have reached
		it — the moment the design calls "recognising the difference and
		reaching the new ground are the same act".
	**/
	function collectFragmentNear(player:PlayerModel):Void {
		var tile = RepeatModel.tileIndexAt(player.pos.x, player.pos.z);
		var key = tileKey(tile.i, tile.j);
		if (collected.exists(key)) {
			return;
		}
		var divergence = RepeatModel.divergenceOf(tile.i, tile.j);
		if (divergence == null) {
			return;
		}

		var at = RepeatModel.plotCentre(tile.i, tile.j, divergence.plotX, divergence.plotZ);
		var dx = player.pos.x - at.x;
		var dz = player.pos.z - at.z;
		if (Math.sqrt(dx * dx + dz * dz) > FRAGMENT_REACH) {
			return;
		}

		collected.set(key, true);
		rebuild(tile); // the fragment has to actually disappear, which is the only feedback this prototype gives
	}

	function rebuild(around:{i:Int, j:Int}):Void {
		var container = world;
		if (container == null) {
			return; // not built yet — nothing to draw into
		}
		container.removeChildren();
		RepeatMesh.build(container, around, BUILD_RADIUS, collected);
		builtAround = around;
	}

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

	/** Which tiles have been solved — the only state here that is not a pure function of the generator. **/
	public function serialize():String {
		return haxe.Json.stringify({collected: [for (key in collected.keys()) key]});
	}

	public function restore(json:String):Void {
		var saved:{collected:Array<String>} = haxe.Json.parse(json);
		collected.clear();
		for (key in saved.collected) {
			collected.set(key, true);
		}
		var around = builtAround;
		if (around != null) {
			rebuild(around);
		}
	}
}
