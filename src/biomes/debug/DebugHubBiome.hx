package biomes.debug;

import biomes.common.Biome;
import biomes.common.Gravity;
import biomes.common.space.flat.FlatSpace;
import entities.painting.PaintingModel;
import entities.player.PlayerModel;
import game.MeshBuilder;
import graphics.Colours;
import graphics.LabelTexture;
import graphics.shaders.UnlitTexture;

/**
	A dev-only flat room with one labelled portal per biome, and where the
	player starts — so trying out whichever biome is currently being worked on
	is two seconds of walking rather than an edit to `game.GameLoop`'s own
	startup call (which is how it was done until now: `enterBiome` pointed at
	whichever biome was under development, and got changed back and forth).

	Deliberately *not* the real hub. `biomes.hub.HubBiome` is a designed place
	with structures, an hourglass and a story job; it earns its layout, and
	adding "and also every biome has a plain sign here" to it would spoil
	exactly what makes it diegetic. This one is scaffolding: a flat floor, a
	ring of signs, no atmosphere, and it should be as boring as possible so
	nobody mistakes it for content.

	Flat rather than spherical (`FlatSpace`, the same topology the tower's
	shaft uses) for the same reason: a sphere is a *feature*, and the debug
	room shouldn't have any.

	The portals are ordinary `PaintingModel` warps, so they behave exactly
	like every real biome transition — including arriving as `returning`,
	which is what a painting warp always is (see `Biome.spawnPlayer`).
**/
class DebugHubBiome implements Biome {
	public static inline final ID:String = "debug-hub";

	/** Half-width of the square floor; the player is clamped inside it (see `tryMove`). **/
	static inline final ARENA_HALF:Float = 90;

	/** How far from the centre the ring of portals stands. **/
	static inline final PORTAL_RING:Float = 55;

	/**
		Width of one portal sign. Wide and short on purpose: the sign's own
		proportions have to roughly match the label texture's, or the text
		renders stretched — which is exactly how the first version came out,
		with a near-square sign carrying a 4:1 texture, squashing "hub" into
		three unreadable slivers.
	**/
	static inline final PORTAL_WIDTH:Float = 44;

	/** Vertical span a portal sign fills — see `PaintingModel.fillWall`, and `PORTAL_WIDTH` for why it's this short. **/
	static inline final PORTAL_HEIGHT:Float = 14;

	/** Label texture size, in pixels — proportioned to match the sign quad (see `PORTAL_WIDTH`), not chosen for its own sake. **/
	static inline final LABEL_WIDTH:Int = 256;

	static inline final LABEL_HEIGHT:Int = 72;

	/** Same first-pass value as every other biome's — see `biomes.hub.HubBiome.GRAVITY`'s own doc for why each biome states its own. **/
	static inline final GRAVITY:Float = 60;

	/** Which biomes this room has portals to, in ring order. **/
	final destinations:Array<String>;

	/**
		Label textures, built once and kept — `build` runs on every entry, and
		rendering a fresh texture per sign per visit would leak one GPU texture
		per sign per walk-through.
	**/
	final labels:Map<String, h3d.mat.Texture> = [];

	/**
		@param destinations the biome ids to place portals to, in ring order — everything registered except this room itself (see `game.GameLoop`).
	**/
	public function new(destinations:Array<String>) {
		this.destinations = destinations;
	}

	public function id():String {
		return ID;
	}

	public function gravity():Float {
		return GRAVITY;
	}

	/** Flat grey, distinct from every real biome's own backdrop so it's obvious at a glance this isn't content. **/
	public function backgroundColor():Int {
		return 0x151515;
	}

	public function build(parent:h3d.scene.Object):Void {
		buildFloor(parent);
		for (index in 0...destinations.length) {
			var destination = destinations[index];
			if (destination == null) {
				continue;
			}
			var wall = wallFor(index);
			var size = PaintingModel.fillWall(PORTAL_HEIGHT);
			PaintingModel.buildQuad(parent, wall.a, wall.b, new h3d.Vector(0, 0, 0), labelFor(destination), size.baseHeight, size.height,
				FlatSpace.INSTANCE.upAt(wall.a));
		}
	}

	/** Always the centre of the room, facing the first portal — a dev room has no "where you left off" worth restoring. **/
	public function spawnPlayer(returning:Bool, fromBiomeId:Null<String>):PlayerModel {
		return new PlayerModel(new h3d.Vector(0, 0, 0), new h3d.Vector(1, 0, 0), 0, FlatSpace.INSTANCE);
	}

	public function exitPaintings():Array<PaintingModel> {
		var paintings:Array<PaintingModel> = [];
		for (index in 0...destinations.length) {
			var destination = destinations[index];
			if (destination == null) {
				continue;
			}
			var wall = wallFor(index);
			paintings.push(new PaintingModel(PaintingModel.midpointOf(wall.a, wall.b), destination));
		}
		return paintings;
	}

	/**
		Walks, then clamps back inside the floor — no walls to collide with in
		here, and clamping each axis independently gives sliding along the
		room's own edges for free rather than stopping the player dead in a
		corner.
	**/
	public function tryMove(player:PlayerModel, direction:h3d.Vector, distance:Float):Void {
		player.moveAlong(direction, distance, 1);
		player.pos.x = hxd.Math.clamp(player.pos.x, -ARENA_HALF, ARENA_HALF);
		player.pos.z = hxd.Math.clamp(player.pos.z, -ARENA_HALF, ARENA_HALF);
	}

	public function applyGravity(player:PlayerModel, dt:Float):Void {
		Gravity.fallToSurface(player, GRAVITY, dt);
	}

	/** Nothing here ticks — see `biomes.common.Biome.tick`'s own doc. **/
	public function tick(player:PlayerModel, dt:Float):Void {}

	/** No game-speed control here — see `biomes.common.Biome.timeScale`'s own doc. **/
	public function timeScale():Float {
		return 1;
	}

	/** Nothing worth saving: the room is derived entirely from its `destinations`. **/
	public function serialize():String {
		return "{}";
	}

	/** No-op — see `serialize`. **/
	public function restore(json:String):Void {}

	/**
		Where portal `index`'s sign stands: a wall segment `PORTAL_WIDTH`
		wide, tangent to the portal ring, facing the centre of the room.
		@param index the portal's own place in the ring.
		@return that sign's two wall ends.
	**/
	function wallFor(index:Int):{a:h3d.Vector, b:h3d.Vector} {
		var angle = 2 * Math.PI * index / Math.max(1, destinations.length);
		var outward = new h3d.Vector(Math.cos(angle), 0, Math.sin(angle));
		var along = new h3d.Vector(-Math.sin(angle), 0, Math.cos(angle));
		var centre = outward.scaled(PORTAL_RING);
		// `b` before `a` along the ring tangent, i.e. the wall runs clockwise
		// as seen from the room's centre. Every painting in the game so far
		// carries abstract art, where a horizontally mirrored quad is
		// invisible; a *label* is the first texture here with a reading
		// direction, and in tangent order the text came out mirrored ("hub"
		// rendering as "dud", which is how this was spotted).
		return {
			a: centre.add(along.scaled(PORTAL_WIDTH / 2)),
			b: centre.sub(along.scaled(PORTAL_WIDTH / 2))
		};
	}

	/**
		This destination's own sign texture, rendered on first use and kept
		(see `labels`).
		@param destination the biome id to label.
		@return that label's texture.
	**/
	function labelFor(destination:String):h3d.mat.Texture {
		var existing = labels.get(destination);
		if (existing != null) {
			return existing;
		}
		var texture = LabelTexture.build(destination, LABEL_WIDTH, LABEL_HEIGHT, Colours.DEBUG_SIGN, Colours.DEBUG_SIGN_TEXT);
		labels.set(destination, texture);
		return texture;
	}

	/** One flat quad, unlit and untextured beyond a flat fill — see the class doc on staying boring. **/
	function buildFloor(parent:h3d.scene.Object):Void {
		var points:Array<h3d.Vector> = [];
		var idx = new hxd.IndexBuffer();
		MeshBuilder.addQuad(points, idx, new h3d.Vector(-ARENA_HALF, 0, -ARENA_HALF), new h3d.Vector(ARENA_HALF, 0, -ARENA_HALF),
			new h3d.Vector(ARENA_HALF, 0, ARENA_HALF), new h3d.Vector(-ARENA_HALF, 0, ARENA_HALF));

		var prim = new h3d.prim.Polygon(points, idx);
		prim.uvs = [
			new h3d.prim.UV(0, 0),
			new h3d.prim.UV(1, 0),
			new h3d.prim.UV(1, 1),
			new h3d.prim.UV(0, 1)
		];
		var mesh = new h3d.scene.Mesh(prim, parent);
		mesh.material.mainPass.addShader(new UnlitTexture(h3d.mat.Texture.fromColor(Colours.DEBUG_FLOOR)));
		mesh.material.mainPass.culling = None;
	}
}
