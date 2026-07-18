package biomes.hub;

import biomes.common.space.sphere.SphereMath;
import biomes.hub.HubStructure.StructureBasis;
import game.MeshBuilder;
import graphics.Colours;
import graphics.shaders.UnlitTexture;

/**
	The hub's own tiltable hourglass, standing on a pedestal — a third hub
	landmark alongside `MazeShrine`/`TowerReplica`, but not a portal: no
	painting, no `exitPainting`/`returnSpawn`, just a solid obstacle and a
	diegetic game-speed control (see `HourglassModel`'s own class doc for
	the actual mechanic).

	Built like the other two landmarks in `HubStructure`'s own local `(u, v)`
	frame — see that class's doc for why a fixed tangent-plane frame is a
	reasonable approximation at this size. Unlike them, most of what this
	class builds moves every tick (the tilt, the sand), so `build` (the
	static pedestal, once) and `buildDynamic` (the frame + sand, rebuilt
	fresh every tick from the current `HourglassModel`) are deliberately
	separate entry points rather than one `build` like `MazeShrine`'s —
	`HubBiome` owns a dedicated container object it clears and repopulates
	with `buildDynamic` every tick; the pedestal itself is never touched
	again once built.

	Rebuilding the frame/sand geometry from scratch every tick (rather than,
	say, `GrassWind`'s own shader-driven approach) is a deliberate choice for
	this one small object: its own triangle count is tiny, and reusing this
	project's existing "build geometry from world-space points computed off
	a local frame" style (`HubStructure.worldPoint`) — just fed a *tilted*
	frame each tick — reads far more consistently with `MazeShrine`/
	`TowerReplica` than inventing a bespoke rotate-around-an-arbitrary-axis
	vertex shader would, for a single small decorative object.
**/
class Hourglass {
	static inline final PEDESTAL_RADIUS:Float = 2.2;

	/** Pedestal height — also where the tilt pivot sits, above `basis.origin`: the frame's own base rests right on top of it. **/
	static inline final PEDESTAL_HEIGHT:Float = 3.5;

	static inline final PEDESTAL_SEGMENTS:Int = 16;

	/** How high the neck sits above the pivot — also half the frame's own total height (`0` to `FRAME_HALF_HEIGHT * 2`, base to top cap). **/
	static inline final FRAME_HALF_HEIGHT:Float = 4;

	static inline final FRAME_RADIUS:Float = 2.6;

	static inline final FRAME_POST_COUNT:Int = 4;

	static inline final FRAME_POST_HALF_ANGLE:Float = 0.12;

	static inline final FRAME_CAP_SEGMENTS:Int = 16;

	/** How far above the neck the top sand cone's own surface can rise when full — short of `FRAME_HALF_HEIGHT * 2` so it never pokes through the top cap. **/
	static inline final SAND_TOP_MAX_HEIGHT:Float = 3.2;

	static inline final SAND_TOP_MAX_RADIUS:Float = 2.1;

	/** Height above the bottom cap the sand mound rests at with nothing piled yet — a hair off `0` so a razor-thin mound still reads as sitting on the cap rather than through it. **/
	static inline final SAND_BOTTOM_BASE_HEIGHT:Float = 0.4;

	/** How far above `SAND_BOTTOM_BASE_HEIGHT` the mound's own peak can rise when full — short of the neck (`FRAME_HALF_HEIGHT`) so it never pokes through it. **/
	static inline final SAND_BOTTOM_MOUND_MAX_HEIGHT:Float = 3.2;

	static inline final SAND_BOTTOM_MAX_RADIUS:Float = 2.1;

	static inline final CONE_SEGMENTS:Int = 14;

	/** Below this fraction, a sand cone/mound isn't built at all — nothing left (or nothing yet) to draw, rather than a degenerate zero-size mesh. **/
	static inline final MIN_VISIBLE_FRACTION:Float = 0.01;

	/** How many small "grains" mark the stream between the two bulbs while actively flowing. **/
	static inline final GRAIN_COUNT:Int = 6;

	static inline final GRAIN_SIZE:Float = 0.16;

	/** How many times the grain pattern cycles over a full drain — cosmetic pacing only, not tied to any real quantity. **/
	static inline final GRAIN_ANIM_SCALE:Float = 3;

	/** How close (in local `(u, v)` units) the player needs to be for the hourglass to react to which side they're on at all — see `lean`. **/
	public static inline final PROXIMITY_RANGE:Float = 22;

	/** How far beyond `PEDESTAL_RADIUS` collision blocks the player — the pedestal is solid all the way through, same flat-boundary treatment as `TowerReplica.OUTER_RADIUS`'s own collision. **/
	static inline final COLLISION_CLEARANCE:Float = 1.5;

	/**
		Builds the hourglass's own static pedestal under `parent`, anchored
		at `basis`. Never rebuilt again — unlike the frame/sand, the
		pedestal itself never tilts.
		@param parent the scene object to attach the pedestal under.
		@param basis the hourglass's own local frame (see `HubStructure.anchorAt`).
	**/
	public static function build(parent:h3d.scene.Object, basis:StructureBasis):Void {
		var points:Array<h3d.Vector> = [];
		var idx = new hxd.IndexBuffer();
		var uvs:Array<h3d.prim.UV> = [];
		addFrustumBand(basis, PEDESTAL_RADIUS, 0, PEDESTAL_RADIUS, PEDESTAL_HEIGHT, PEDESTAL_SEGMENTS, points, idx, uvs);
		addCap(basis, PEDESTAL_RADIUS, PEDESTAL_HEIGHT, PEDESTAL_SEGMENTS, points, idx, uvs);

		var prim = new h3d.prim.Polygon(points, idx);
		prim.uvs = uvs;
		var texture = hxd.Res.textures.tower_stone_wall.toTexture();
		texture.wrap = Repeat;
		var mesh = new h3d.scene.Mesh(prim, parent);
		mesh.material.mainPass.addShader(new UnlitTexture(texture));
		mesh.material.mainPass.culling = None;
	}

	/**
		(Re)builds the hourglass's own frame and sand under `container` —
		called once at initial build time and again every tick thereafter
		with the current `model`'s state, after the caller has cleared
		`container`'s previous children (see class doc).
		@param container the (already-cleared) scene object to build into.
		@param basis the hourglass's own local frame, untitled — `tiltedBasis` derives the actual tilted one this builds against.
		@param model the current tilt/sand state to render.
	**/
	public static function buildDynamic(container:h3d.scene.Object, basis:StructureBasis, model:HourglassModel):Void {
		var tilted = tiltedBasis(basis, model.tiltAngle);
		buildFrame(container, tilted);
		buildSand(container, tilted, model);
	}

	/** The frame's own local basis after tilting `basis` by `tiltAngle` around its own `vAxis` — origin moves up to the pivot atop the pedestal, `up`/`uAxis` rotate together so they stay perpendicular to each other and to `vAxis`. **/
	static function tiltedBasis(basis:StructureBasis, tiltAngle:Float):StructureBasis {
		var pivot = HubStructure.worldPoint(basis, 0, 0, PEDESTAL_HEIGHT);
		var tiltedUp = SphereMath.rotateAroundAxis(basis.up, basis.vAxis, tiltAngle);
		var tiltedU = SphereMath.rotateAroundAxis(basis.uAxis, basis.vAxis, tiltAngle);
		return {
			origin: pivot,
			up: tiltedUp,
			uAxis: tiltedU,
			vAxis: basis.vAxis
		};
	}

	/** The wood/metal frame: top and bottom caps plus `FRAME_POST_COUNT` corner posts between them — untextured, a flat `Colours.HOURGLASS_FRAME` fill like every other placeholder shape in this project. **/
	static function buildFrame(container:h3d.scene.Object, tilted:StructureBasis):Void {
		var points:Array<h3d.Vector> = [];
		var idx = new hxd.IndexBuffer();
		addCap(tilted, FRAME_RADIUS, 0, FRAME_CAP_SEGMENTS, points, idx);
		addCap(tilted, FRAME_RADIUS, FRAME_HALF_HEIGHT * 2, FRAME_CAP_SEGMENTS, points, idx);

		for (i in 0...FRAME_POST_COUNT) {
			var angle = i * (2 * Math.PI / FRAME_POST_COUNT);
			var a = ringPoint(tilted, FRAME_RADIUS, angle - FRAME_POST_HALF_ANGLE, 0);
			var b = ringPoint(tilted, FRAME_RADIUS, angle + FRAME_POST_HALF_ANGLE, 0);
			var c = ringPoint(tilted, FRAME_RADIUS, angle + FRAME_POST_HALF_ANGLE, FRAME_HALF_HEIGHT * 2);
			var d = ringPoint(tilted, FRAME_RADIUS, angle - FRAME_POST_HALF_ANGLE, FRAME_HALF_HEIGHT * 2);
			MeshBuilder.addQuad(points, idx, a, b, c, d);
		}

		var mesh = new h3d.scene.Mesh(new h3d.prim.Polygon(points, idx), container);
		mesh.material.mainPass.addShader(new h3d.shader.FixedColor(Colours.HOURGLASS_FRAME));
		mesh.material.mainPass.culling = None;
	}

	/**
		The sand itself: a cone in the top bulb (apex fixed at the neck,
		shrinking as `model.sandPhase` drains it), a mound in the bottom
		bulb (apex-up, growing from the bottom cap), and a handful of small
		"grains" marking the stream between them while actively flowing —
		all one flat `Colours.HOURGLASS_SAND` fill, one mesh.
	**/
	static function buildSand(container:h3d.scene.Object, tilted:StructureBasis, model:HourglassModel):Void {
		var points:Array<h3d.Vector> = [];
		var idx = new hxd.IndexBuffer();

		var topFraction = 1 - model.sandPhase;
		var bottomFraction = model.sandPhase;
		var neckHeight = FRAME_HALF_HEIGHT;

		var bottomApexHeight = SAND_BOTTOM_BASE_HEIGHT;
		if (topFraction > MIN_VISIBLE_FRACTION) {
			var topSurfaceHeight = neckHeight + topFraction * SAND_TOP_MAX_HEIGHT;
			var topSurfaceRadius = topFraction * SAND_TOP_MAX_RADIUS;
			addFrustumBand(tilted, 0, neckHeight, topSurfaceRadius, topSurfaceHeight, CONE_SEGMENTS, points, idx);
			addCap(tilted, topSurfaceRadius, topSurfaceHeight, CONE_SEGMENTS, points, idx);
		}
		if (bottomFraction > MIN_VISIBLE_FRACTION) {
			bottomApexHeight = SAND_BOTTOM_BASE_HEIGHT + bottomFraction * SAND_BOTTOM_MOUND_MAX_HEIGHT;
			addFrustumBand(tilted, SAND_BOTTOM_MAX_RADIUS, SAND_BOTTOM_BASE_HEIGHT, 0, bottomApexHeight, CONE_SEGMENTS, points, idx);
			addCap(tilted, SAND_BOTTOM_MAX_RADIUS, SAND_BOTTOM_BASE_HEIGHT, CONE_SEGMENTS, points, idx);
		}

		if (model.sandPhase > MIN_VISIBLE_FRACTION && model.sandPhase < 1 - MIN_VISIBLE_FRACTION) {
			addStreamGrains(tilted, neckHeight, bottomApexHeight, model.sandPhase, points, idx);
		}

		var mesh = new h3d.scene.Mesh(new h3d.prim.Polygon(points, idx), container);
		mesh.material.mainPass.addShader(new h3d.shader.FixedColor(Colours.HOURGLASS_SAND));
		mesh.material.mainPass.culling = None;
	}

	/**
		`GRAIN_COUNT` small crossed-quad "grains" between the neck and the
		bottom mound's own current peak (`bottomApexHeight`), cycling along
		that span as `sandPhase` advances — and, since nothing here is
		one-directional, cycling the other way for free whenever `sandPhase`
		itself decreases (`HourglassModel.reversing`), which is exactly the
		"reverse the animation" the ask calls for without any separate flag
		or special-cased code path.
	**/
	static function addStreamGrains(tilted:StructureBasis, neckHeight:Float, bottomApexHeight:Float, sandPhase:Float, points:Array<h3d.Vector>,
			idx:hxd.IndexBuffer):Void {
		for (i in 0...GRAIN_COUNT) {
			var baseT = i / GRAIN_COUNT;
			var t = baseT + sandPhase * GRAIN_ANIM_SCALE;
			t -= Math.floor(t);
			var height = hxd.Math.lerp(neckHeight, bottomApexHeight, t);
			addGrain(tilted, height, points, idx);
		}
	}

	/** One stream grain: two small crossed quads centered on `tilted`'s own axis at `height`, so it reads from more than one viewing angle. **/
	static function addGrain(tilted:StructureBasis, height:Float, points:Array<h3d.Vector>, idx:hxd.IndexBuffer):Void {
		var uA = HubStructure.worldPoint(tilted, -GRAIN_SIZE, 0, height - GRAIN_SIZE);
		var uB = HubStructure.worldPoint(tilted, GRAIN_SIZE, 0, height - GRAIN_SIZE);
		var uC = HubStructure.worldPoint(tilted, GRAIN_SIZE, 0, height + GRAIN_SIZE);
		var uD = HubStructure.worldPoint(tilted, -GRAIN_SIZE, 0, height + GRAIN_SIZE);
		MeshBuilder.addQuad(points, idx, uA, uB, uC, uD);

		var vA = HubStructure.worldPoint(tilted, 0, -GRAIN_SIZE, height - GRAIN_SIZE);
		var vB = HubStructure.worldPoint(tilted, 0, GRAIN_SIZE, height - GRAIN_SIZE);
		var vC = HubStructure.worldPoint(tilted, 0, GRAIN_SIZE, height + GRAIN_SIZE);
		var vD = HubStructure.worldPoint(tilted, 0, -GRAIN_SIZE, height + GRAIN_SIZE);
		MeshBuilder.addQuad(points, idx, vA, vB, vC, vD);
	}

	/** A world point on `basis`'s own circle at `radius`/`angle`, raised `height` above its own ground level (or pivot, for a tilted basis). **/
	static function ringPoint(basis:StructureBasis, radius:Float, angle:Float, height:Float):h3d.Vector {
		return HubStructure.worldPoint(basis, radius * Math.cos(angle), radius * Math.sin(angle), height);
	}

	/**
		A ring/frustum band between two (radius, height) circles — a
		cylinder wall (`radiusA == radiusB`), or a cone (`radiusA == 0` or
		`radiusB == 0`), all the same shape. `uvs`, when non-null, gets a
		plain tiled mapping (for the pedestal's own textured wall); left
		null for the flat-shaded sand, which doesn't need one.
	**/
	static function addFrustumBand(basis:StructureBasis, radiusA:Float, heightA:Float, radiusB:Float, heightB:Float, segments:Int, points:Array<h3d.Vector>,
			idx:hxd.IndexBuffer, ?uvs:Array<h3d.prim.UV>):Void {
		for (i in 0...segments) {
			var angleA = i * (2 * Math.PI / segments);
			var angleB = (i + 1) * (2 * Math.PI / segments);
			var a = ringPoint(basis, radiusA, angleA, heightA);
			var b = ringPoint(basis, radiusA, angleB, heightA);
			var c = ringPoint(basis, radiusB, angleB, heightB);
			var d = ringPoint(basis, radiusB, angleA, heightB);
			MeshBuilder.addQuad(points, idx, a, b, c, d);

			if (uvs != null) {
				var uRepeat = a.sub(b).length() / MeshBuilder.WALL_TEXTURE_TILE_SIZE;
				var vRepeat = a.sub(d).length() / MeshBuilder.WALL_TEXTURE_TILE_SIZE;
				uvs.push(new h3d.prim.UV(0, vRepeat));
				uvs.push(new h3d.prim.UV(uRepeat, vRepeat));
				uvs.push(new h3d.prim.UV(uRepeat, 0));
				uvs.push(new h3d.prim.UV(0, 0));
			}
		}
	}

	/** A flat disc cap at `height`/`radius` — a triangle fan from `basis`'s own center, sealing a cylinder/cone so it doesn't read as hollow. Textured (radial UV) only when `uvs` is non-null. **/
	static function addCap(basis:StructureBasis, radius:Float, height:Float, segments:Int, points:Array<h3d.Vector>, idx:hxd.IndexBuffer,
			?uvs:Array<h3d.prim.UV>):Void {
		var center = HubStructure.worldPoint(basis, 0, 0, height);
		for (i in 0...segments) {
			var angleA = i * (2 * Math.PI / segments);
			var angleB = (i + 1) * (2 * Math.PI / segments);
			var a = ringPoint(basis, radius, angleA, height);
			var b = ringPoint(basis, radius, angleB, height);
			MeshBuilder.addTriangle(points, idx, center, a, b);

			if (uvs != null) {
				uvs.push(new h3d.prim.UV(0.5, 0.5));
				uvs.push(new h3d.prim.UV(0.5 + Math.cos(angleA) * 0.5, 0.5 + Math.sin(angleA) * 0.5));
				uvs.push(new h3d.prim.UV(0.5 + Math.cos(angleB) * 0.5, 0.5 + Math.sin(angleB) * 0.5));
			}
		}
	}

	/**
		Whether `worldPos` is too close to the pedestal to be walked into —
		a single circular boundary against the untitled `basis` (the
		pedestal itself never tilts, only the frame/sand above it does).
		@param basis the hourglass's own local frame.
		@param worldPos the position to check — typically the player's own tentative new position.
		@return true if `worldPos` is blocked by the pedestal.
	**/
	public static function blocksMovement(basis:StructureBasis, worldPos:h3d.Vector):Bool {
		var uv = HubStructure.localUV(basis, worldPos);
		return Math.sqrt(uv.u * uv.u + uv.v * uv.v) < PEDESTAL_RADIUS + COLLISION_CLEARANCE;
	}

	/**
		How far left (-1) or right (+1) of the hourglass `playerPos`
		currently stands — `basis`'s own local `u` (see
		`HubStructure.localUV`), signed and normalized by
		`PROXIMITY_RANGE`, `0` once `playerPos` is beyond it (rests at
		neutral when nobody's near) or dead-on `u == 0`. Fed straight into
		`HourglassModel.tick`; "left"/"right" here are this local frame's
		own fixed `uAxis` — the anchor's fixed east/west, not the player's
		own momentary facing, matching the ask's "walks towards it from the
		left" reading as approaching from this structure's own fixed side,
		the same convention every other hub structure's `(u, v)` already
		uses.
		@param basis the hourglass's own local frame.
		@param playerPos the position to check — typically the player's own current position.
		@return the player's own lean, in `[-1, 1]`.
	**/
	public static function lean(basis:StructureBasis, playerPos:h3d.Vector):Float {
		var uv = HubStructure.localUV(basis, playerPos);
		var distance = Math.sqrt(uv.u * uv.u + uv.v * uv.v);
		if (distance > PROXIMITY_RANGE) {
			return 0;
		}
		return hxd.Math.clamp(uv.u / PROXIMITY_RANGE, -1, 1);
	}
}
