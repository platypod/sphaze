package biomes.defect;

import biomes.common.Biome;
import biomes.common.Gravity;
import biomes.common.space.flat.FlatSpace;
import biomes.hub.HubBiome;
import entities.painting.PaintingModel;
import entities.player.Camera.CameraOverride;
import entities.player.PlayerModel;

/**
	**The Defect** — a plain that is flat everywhere except one point. See
	[the design](../../../docs/game/world.md)'s
	own entry (`### 5. The Defect`), which calls it the most underrated
	space in the set, and is right for a reason worth restating: it is the
	one place that makes a player understand what curvature *is*.

	Walk a closed loop that **encloses the apex** and you come back turned
	by a quarter turn, having never turned. Walk a closed loop that does
	not, and nothing happens. Curvature is concentrated rather than
	spread, and parallel transport is path-dependent — demonstrable in
	about forty seconds of walking, with no text.

	**How to see it**, since nothing announces itself: line yourself up
	with the meridian — the one straight line of posts running out from
	the apex — walk a wide circuit around the apex, and come back to it.
	The line will not be where your body expects. Do the same circuit
	*beside* the apex instead of around it and the line is exactly where
	you left it. That contrast is the whole lesson.

	**What is deliberately absent.** The design's socket — the one that
	only accepts a pattern arriving at an exact facing, with no in-place
	editing to correct it — is not built. That is the payload, and it
	needs `CARRY`, which does not exist yet. What is here answers the
	prior question: does concentrated curvature read, from inside, as
	anything at all.

	**The known rendering compromise**, stated because the design's own
	legibility law for this space is *"the space looks entirely ordinary,
	nothing is visibly bent"*, and this build does not fully honour it. A
	cone cannot be flattened; something must give. Markers are drawn in a
	window centred on the player so everything they can see is continuous
	and correct, which leaves a marker-free wedge directly behind the apex
	(see `DefectModel.drawAngleFor`). The ground is a full disc, so there
	is no hole. A seamless cone renderer — developing the visible
	neighbourhood properly — is real remaining work, not a tuning pass.
**/
class DefectBiome implements Biome {
	public static inline final ID:String = "defect";

	/** Same first-pass value as every other biome's — see `biomes.hub.HubBiome.GRAVITY`'s own doc. **/
	static inline final GRAVITY:Float = 60;

	/** Where the player starts, out from the apex — far enough that the apex reads as a landmark rather than as something they are standing on. **/
	static inline final SPAWN_RADIUS:Float = 150;

	/** How far round from the meridian the player starts — see `spawnPlayer`. **/
	static inline final SPAWN_OFFSET_ANGLE:Float = 0.22;

	/** How far the player's angular position may drift before the drawn window is re-centred — see `DefectModel.drawAngleFor`. **/
	static inline final REBUILD_ANGLE_STEP:Float = 0.08;

	var world:Null<h3d.scene.Object>;

	/** The player bearing the current drawing is centred on, or null before the first build. **/
	var builtAtAngle:Null<Float> = null;

	public function new() {}

	public function id():String {
		return ID;
	}

	public function gravity():Float {
		return GRAVITY;
	}

	/** Neutral — κ is zero everywhere the player can stand, and hue carries curvature alone. The whole joke of this space is that it has no right to look like anything else. **/
	public function backgroundColor():Int {
		return 0x1B1E22;
	}

	public function build(parent:h3d.scene.Object):Void {
		world = new h3d.scene.Object(parent);
		builtAtAngle = null; // force a rebuild on the first tick
	}

	/**
		Spawns a little to one side of the meridian, facing the apex — so
		the reference line and the cone point are both in the first frame,
		and the line reads as a *line* receding toward the apex.

		Not *on* the meridian, which is where the first version put the
		player: standing in the line of posts means the nearest one is
		twelve units dead ahead and fills half the view, so the reference
		the whole space is read against looks like a wall.
		@param returning unused — the plain is the same plain however you arrive.
		@param fromBiomeId unused.
		@return the spawned player, walking in `FlatSpace`.
	**/
	public function spawnPlayer(returning:Bool, fromBiomeId:Null<String>):PlayerModel {
		var at = DefectModel.rotate(SPAWN_RADIUS, 0, SPAWN_OFFSET_ANGLE);
		var pos = new h3d.Vector(at.x, 0, at.z);
		var towardApex = pos.scaled(-1).normalized();
		return new PlayerModel(pos, towardApex, 0, FlatSpace.INSTANCE);
	}

	/** One way out, off the meridian so it is not walked into while circling. **/
	public function exitPaintings():Array<PaintingModel> {
		var at = DefectModel.rotate(SPAWN_RADIUS, 0, 0.35);
		return [new PaintingModel(new h3d.Vector(at.x, 0, at.z), HubBiome.ID, 14)];
	}

	/**
		Walks, holds the player off the apex and inside the plain, and
		applies the identification when they cross the seam.

		Markers do not block. This space is about walking a *shape* — a
		circuit, a square — and anything that nudged the player off their
		own line would corrupt the very measurement they are here to make.
		@param player the player to move.
		@param direction unit tangent to move along.
		@param distance how far to move.
	**/
	public function tryMove(player:PlayerModel, direction:h3d.Vector, distance:Float):Void {
		var step = direction.scaled(distance);
		var x = player.pos.x + step.x;
		var z = player.pos.z + step.z;

		var radius = DefectModel.radiusOf(x, z);
		if (radius < DefectModel.APEX_EXCLUSION || radius > DefectModel.PLAIN_RADIUS) {
			return;
		}

		player.pos = new h3d.Vector(x, player.pos.y, z);
		DefectCollision.wrapIfNeeded(player);
	}

	public function applyGravity(player:PlayerModel, dt:Float):Void {
		Gravity.fallToSurface(player, GRAVITY, dt);
	}

	/**
		Re-centres the drawn window on the player's own bearing as they
		move around the apex — see `DefectModel.drawAngleFor` for why the
		drawing has to follow them at all.
		@param player the player to draw around.
		@param dt unused — nothing here advances with time; the space is as static as a plain.
	**/
	public function tick(player:PlayerModel, dt:Float):Void {
		var angle = DefectModel.angleOf(player.pos.x, player.pos.z);
		var built = builtAtAngle;
		if (built != null && Math.abs(shortestAngleBetween(built, angle)) < REBUILD_ANGLE_STEP) {
			return;
		}
		rebuild(angle);
	}

	static function shortestAngleBetween(a:Float, b:Float):Float {
		var difference = (b - a) % (2 * Math.PI);
		if (difference > Math.PI) {
			difference -= 2 * Math.PI;
		}
		if (difference < -Math.PI) {
			difference += 2 * Math.PI;
		}
		return difference;
	}

	function rebuild(playerAngle:Float):Void {
		var container = world;
		if (container == null) {
			return; // not built yet
		}
		container.removeChildren();
		DefectMesh.build(container, playerAngle);
		builtAtAngle = playerAngle;
	}

	/** Nothing to interact with yet — see `biomes.common.Biome.interact`'s own doc, and this class's own note on the absent socket. **/
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

	/** Nothing worth saving: the plain is regenerated identically from `DefectModel`'s own constants. **/
	public function serialize():String {
		return "{}";
	}

	/** Nothing to restore — see `serialize`. **/
	public function restore(json:String):Void {}
}
