package biomes.knot;

import biomes.common.Biome;
import biomes.common.Gravity;
import biomes.common.space.hyperbolic.HyperbolicSpace;
import biomes.common.space.hyperbolic.HyperbolicView;
import biomes.hub.HubBiome;
import entities.painting.PaintingModel;
import entities.player.Camera.CameraOverride;
import entities.player.PlayerModel;
import game.MeshBuilder;
import geometry.CurvedSpace.ModelPoint;
import geometry.DeckGroup;
import geometry.DeckGroups;
import geometry.HyperbolicProjection;
import geometry.HyperbolicTiling;
import geometry.Isometry;

/**
	**The Knot** — a closed hyperbolic surface of genus 2. See
	[the design](../../../docs/game/world.md)'s
	own entry (`### 8. The Knot`), which files it as late-game mastery:
	the space that proves you have learned to think in geometries rather
	than in maps.

	**The one thing that separates this from the Sprawl.** Both are
	hyperbolic and both look, locally, exactly alike. But the Sprawl goes
	on forever and every cell is somewhere new, while this surface is
	*closed* and **every octagon you can see is the same octagon** —
	there is one room here, and you are looking at many images of it. Walk
	in any direction and you come back. Which is why the design's
	legibility law for this space is that position is insufficient and you
	must track your *route*: "where am I" has the same answer everywhere,
	and the honest answer is a word in a group rather than a point.

	**Why the landmark is asymmetric and off-centre.** With identical
	content in every copy, the only readable information is *orientation*
	— which image of the room you are looking at, and how it is turned
	relative to you. A symmetric landmark would make the images
	indistinguishable and the space unreadable rather than merely hard.

	Reuses the Sprawl's whole spatial and rendering approach unchanged
	(`HyperbolicSpace`, `HyperbolicView`, a camera pinned at the origin
	with the world transformed around it) — see
	`biomes.sprawl.SprawlBiome` for why hyperbolic rendering has to work
	that way. What is new here is only *which* group the copies come from.

	**Not built:** anything that uses the two handles. The design's verb
	is `braid`, and distinguishing two independent families of loop is the
	content this space exists for. What is here answers the prior
	question — whether a closed hyperbolic surface reads as closed at all
	from inside it.
**/
class KnotBiome implements Biome {
	public static inline final ID:String = "knot";

	/** Same as the Sprawl's, so the two hyperbolic spaces walk at the same pace and can be compared honestly — see `biomes.sprawl.SprawlBiome.CURVATURE_RADIUS` for how it was derived. **/
	public static inline final CURVATURE_RADIUS:Float = 13.6;

	/** How far out to enumerate copies of the room. Past this everything is inside the last few percent of the Klein disc. **/
	static inline final DRAW_DISTANCE:Float = 4.0;

	/** Camera height, in *rendered* units — see `biomes.sprawl.SprawlBiome.EYE_HEIGHT` on why rendering scale is its own thing. **/
	static inline final EYE_HEIGHT:Float = 1.7;

	/** Floor tiles drawn just inside their true boundary, so the octagon edges read as gaps. **/
	static inline final TILE_INSET:Float = 0.9;

	static inline final PILLAR_HEIGHT:Float = 3.2;
	static inline final PILLAR_RADIUS:Float = 0.09;

	static inline final FLOOR_COLOR:Int = 0x241C33;
	static inline final PILLAR_COLOR:Int = 0x4C3E6B;

	/** The one asymmetric marker in the room — the only way to tell which image you are looking at, and how it is turned. **/
	static inline final LANDMARK_COLOR:Int = 0xC9A227;

	static inline final LANDMARK_HEIGHT:Float = 7.0;
	static inline final LANDMARK_RADIUS:Float = 0.13;

	final group:DeckGroup;
	final space:HyperbolicSpace;

	/**
		The images of the room to draw, enumerated **once**.

		`DeckGroup.elementsWithin` runs a breadth-first search over the
		group with a map keyed on matrix entries. That is fine to do once
		and wrong to do sixty times a second — which is what the first
		version did, from `tick` *and* again from every fold. The set never
		changes, so it is computed in the constructor.
	**/
	final images:Array<Isometry>;

	/** The octagon's own corners, in the room's own coordinates — static, so computed once. **/
	final corners:Array<ModelPoint>;

	/** Where the room's furniture stands, in the room's own coordinates: pillars, then the single landmark last. **/
	final pillars:Array<ModelPoint>;

	final landmark:ModelPoint;

	var world:Null<h3d.scene.Object>;

	public function new() {
		group = DeckGroups.genusTwo();
		space = new HyperbolicSpace(CURVATURE_RADIUS);

		var circumradius = HyperbolicTiling.circumradiusOf(8, 8) * TILE_INSET;
		corners = [
			for (k in 0...8)
				Isometry.positionOf(Isometry.compose(Isometry.rotation(k * Math.PI / 4 + Math.PI / 8), Isometry.translation(Hyperbolic, circumradius)))
		];

		var inradius = HyperbolicTiling.inradiusOf(8, 8);
		// Four pillars, deliberately not eight: a room with the octagon's own
		// symmetry would look the same from every side, and this space's only
		// readable information is which way round an image of it is.
		pillars = [
			for (k in 0...4)
				Isometry.positionOf(Isometry.compose(Isometry.rotation(k * Math.PI / 2 + 0.3), Isometry.translation(Hyperbolic, inradius * 0.55)))
		];
		landmark = Isometry.positionOf(Isometry.compose(Isometry.rotation(-0.9), Isometry.translation(Hyperbolic, inradius * 0.72)));
		images = group.elementsWithin(DRAW_DISTANCE);
	}

	public function id():String {
		return ID;
	}

	public function gravity():Float {
		return 60;
	}

	/** Cold and violet — κ < 0, per `docs/game/art-and-audio.md`, and pushed further from the Sprawl's blue since this is the deeper end of the same scale. **/
	public function backgroundColor():Int {
		return 0x0B0814;
	}

	public function build(parent:h3d.scene.Object):Void {
		world = new h3d.scene.Object(parent);
	}

	/** Spawns off-centre in the room, facing the landmark, so the one asymmetric thing here is the first thing seen. **/
	public function spawnPlayer(returning:Bool, fromBiomeId:Null<String>):PlayerModel {
		var origin = new h3d.Vector(0, 0, CURVATURE_RADIUS);
		var facing = new h3d.Vector(1, 0, 0);
		var stepped = space.moveAlong(origin, facing, facing, -0.6 * CURVATURE_RADIUS, CURVATURE_RADIUS);
		return new PlayerModel(stepped.pos, stepped.forward, 0, space);
	}

	/** One way out, at the room's own centre. Its trigger is a hyperbolic radius converted the same way the Sprawl's is — see `biomes.sprawl.SprawlBiome.exitPaintings`. **/
	public function exitPaintings():Array<PaintingModel> {
		var centre = new h3d.Vector(0, 0, CURVATURE_RADIUS);
		return [
			new PaintingModel(centre, HubBiome.ID, biomes.sprawl.SprawlBiome.euclideanRadiusOf(0.28))
		];
	}

	/**
		Walks, and folds the result back into the room.

		**This is the whole topology, in one call.** `DeckGroup.canonicalise`
		returns the representative of the player's orbit nearest the
		origin, so stepping out of the octagon puts them back in at the
		corresponding point of the identified side. Nothing about it is
		visible: the identification is by an isometry and the room is drawn
		on both sides of every edge.
		@param player the player to move.
		@param direction unit tangent to move along.
		@param distance arc length in world units.
	**/
	public function tryMove(player:PlayerModel, direction:h3d.Vector, distance:Float):Void {
		player.moveAlong(direction, distance, CURVATURE_RADIUS);

		var unit = {x: player.pos.x / CURVATURE_RADIUS, y: player.pos.y / CURVATURE_RADIUS, z: player.pos.z / CURVATURE_RADIUS};
		var folded = group.canonicalise(unit);
		if (folded.x == unit.x && folded.y == unit.y) {
			return; // still inside the room
		}

		// The same isometry has to carry the facing, or the view spins at the edge.
		var carried = carryFacing(unit, folded, player.forward);
		player.pos = new h3d.Vector(folded.x * CURVATURE_RADIUS, folded.y * CURVATURE_RADIUS, folded.z * CURVATURE_RADIUS);
		player.forward = carried;
	}

	/**
		Transports `forward` by whichever group element did the fold.

		Recovered by *searching* the generators for the one that maps the
		player's old position to the new one, rather than by having
		`canonicalise` report it: the fold is a greedy descent that may
		take several steps, and reconstructing the composite from the
		outside keeps `DeckGroup`'s own interface as narrow as it was for
		the flat quotients.
	**/
	function carryFacing(from:ModelPoint, to:ModelPoint, forward:h3d.Vector):h3d.Vector {
		for (element in images) {
			var moved = geometry.CurvedSpace.normalize(Hyperbolic, Isometry.apply(element, from));
			if (geometry.CurvedSpace.distance(Hyperbolic, moved, to) > 1e-6) {
				continue;
			}
			var faced = Isometry.apply(element, {x: forward.x, y: forward.y, z: forward.z});
			return new h3d.Vector(faced.x, faced.y, faced.z);
		}
		return forward; // unreachable while the fold only ever uses group elements
	}

	/** Height is the Euclidean factor of H²×ℝ, so jumping behaves normally — see `HyperbolicSpace.upAt`. **/
	public function applyGravity(player:PlayerModel, dt:Float):Void {
		Gravity.fallToSurface(player, 60, dt);
	}

	/** Rebuilds the visible images of the room around the player — see `biomes.sprawl.SprawlBiome.tick` on the one-step lag and why it is invisible here. **/
	public function tick(player:PlayerModel, dt:Float):Void {
		var container = world;
		if (container == null) {
			return;
		}
		container.removeChildren();

		var view = HyperbolicView.viewOf(player.pos, player.forward, CURVATURE_RADIUS);

		var floorPoints:Array<h3d.Vector> = [];
		var floorIdx = new hxd.IndexBuffer();
		var pillarPoints:Array<h3d.Vector> = [];
		var pillarIdx = new hxd.IndexBuffer();
		var landmarkPoints:Array<h3d.Vector> = [];
		var landmarkIdx = new hxd.IndexBuffer();

		for (element in images) {
			var placement = Isometry.compose(view, element);
			if (HyperbolicProjection.distanceFromCamera(Isometry.apply(placement, geometry.CurvedSpace.origin())) > DRAW_DISTANCE) {
				continue;
			}
			addRoom(floorPoints, floorIdx, pillarPoints, pillarIdx, landmarkPoints, landmarkIdx, placement);
		}

		addMesh(container, floorPoints, floorIdx, FLOOR_COLOR);
		addMesh(container, pillarPoints, pillarIdx, PILLAR_COLOR);
		addMesh(container, landmarkPoints, landmarkIdx, LANDMARK_COLOR);
	}

	/** One image of the room: its floor, its pillars and its landmark, all under one placement. **/
	function addRoom(floorPoints:Array<h3d.Vector>, floorIdx:hxd.IndexBuffer, pillarPoints:Array<h3d.Vector>, pillarIdx:hxd.IndexBuffer,
			landmarkPoints:Array<h3d.Vector>, landmarkIdx:hxd.IndexBuffer, placement:Isometry):Void {
		var hub = HyperbolicProjection.toWorld(Isometry.apply(placement, geometry.CurvedSpace.origin()), 0);
		var placed = [for (c in corners) HyperbolicProjection.toWorld(Isometry.apply(placement, c), 0)];
		for (k in 0...placed.length) {
			MeshBuilder.addTriangle(floorPoints, floorIdx, hub, placed[k], placed[(k + 1) % placed.length]);
		}

		for (p in pillars) {
			addPost(pillarPoints, pillarIdx, placement, p, PILLAR_RADIUS, PILLAR_HEIGHT);
		}
		addPost(landmarkPoints, landmarkIdx, placement, landmark, LANDMARK_RADIUS, LANDMARK_HEIGHT);
	}

	/** A square post standing at a point of the room, its footprint kept in *hyperbolic* units so it is the same real size in every image. **/
	function addPost(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, placement:Isometry, at:ModelPoint, radius:Float, height:Float):Void {
		var base = [
			for (k in 0...4)
				Isometry.apply(placement,
					Isometry.positionOf(Isometry.compose(frameAt(at),
						Isometry.compose(Isometry.rotation(k * Math.PI / 2), Isometry.translation(Hyperbolic, radius)))))
		];
		var low = [for (p in base) HyperbolicProjection.toWorld(p, 0)];
		var high = [for (p in base) HyperbolicProjection.toWorld(p, height)];

		for (k in 0...4) {
			var next = (k + 1) % 4;
			MeshBuilder.addQuad(points, idx, low[k], low[next], high[next], high[k]);
		}
		MeshBuilder.addQuad(points, idx, high[0], high[1], high[2], high[3]);
	}

	/** The frame standing at a point of the room, so a post can be built around it in that point's own local coordinates. **/
	static function frameAt(at:ModelPoint):Isometry {
		var bearing = Math.atan2(at.y, at.x);
		return Isometry.compose(Isometry.rotation(bearing), Isometry.translation(Hyperbolic, distanceFromOrigin(at)));
	}

	static function distanceFromOrigin(at:ModelPoint):Float {
		return geometry.CurvedSpace.distance(Hyperbolic, geometry.CurvedSpace.origin(), at);
	}

	function addMesh(parent:h3d.scene.Object, points:Array<h3d.Vector>, idx:hxd.IndexBuffer, color:Int):Void {
		if (points.length == 0) {
			return; // Polygon rejects an empty vertex list
		}
		var mesh = new h3d.scene.Mesh(new h3d.prim.Polygon(points, idx), parent);
		mesh.material.mainPass.addShader(new h3d.shader.FixedColor(color));
		mesh.material.mainPass.culling = None;
	}

	/** Nothing to interact with yet — the braid mechanic is unbuilt, see the class doc. **/
	public function interact(player:PlayerModel):Void {}

	/** The camera never moves: the world is transformed around it — see `biomes.sprawl.SprawlBiome.cameraOverride`. **/
	public function cameraOverride(player:PlayerModel):Null<CameraOverride> {
		var eye = new h3d.Vector(0, EYE_HEIGHT + player.airborneHeight, 0);
		return {
			pos: eye,
			target: new h3d.Vector(eye.x + Math.cos(player.pitch), eye.y + Math.sin(player.pitch), eye.z),
			up: new h3d.Vector(0, 1, 0),
		};
	}

	/** Walking and looking stay with the player — see `biomes.common.Biome.capturesInput`'s own doc. **/
	public function capturesInput():Bool {
		return false;
	}

	/** Nothing to click on here — see `biomes.common.Biome.onEditClick`'s own doc. **/
	public function onEditClick(ray:h3d.col.Ray):Void {}

	/** No game-speed control here — see `biomes.common.Biome.timeScale`'s own doc. **/
	public function timeScale():Float {
		return 1;
	}

	/** Nothing worth saving: the room is regenerated identically from this class's own constants. **/
	public function serialize():String {
		return "{}";
	}

	/** Nothing to restore — see `serialize`. **/
	public function restore(json:String):Void {}
}
