package biomes.hub;

import game.MeshBuilder;
import biomes.common.grass.GrassMesh;
import biomes.common.grass.GrassModel;
import entities.painting.PaintingModel;
import graphics.Colours;
import graphics.shaders.GrassWind;
import graphics.shaders.UnlitTexture;

/**
	Builds the hub's actual scene-graph meshes: the outer shell (an
	`h3d.prim.Sphere`, textured with a tiled grass image so the floor the
	`GrassMesh` blades stand on reads as ground rather than an abstract
	surface) and its central 8-sided column (side panels textured like biome
	walls, the to-biome painting mounted as an inset overlay on one of
	them). All the geometry this builds from — `HubModel.columnEdge`,
	`RADIUS`, `COLUMN_RADIUS` — lives there, not here; see its own class doc
	for the reasoning behind the column's shape.
**/
class HubMesh {
	/** Segment counts for the outer shell's `h3d.prim.Sphere` — smooth enough to not read as faceted, unlike the deliberately 8-sided column. **/
	static inline final SHELL_SEGS_W = 32;

	static inline final SHELL_SEGS_H = 24;

	/** Grass texture repeat density: tiles around the equator, and pole to pole — chosen so tiles read roughly square (the equator's circumference is about twice the pole-to-pole distance), same ratio the previous checkerboard used. **/
	static inline final FLOOR_TILE_U = 40;

	static inline final FLOOR_TILE_V = 20;

	/**
		@param parent the scene object to attach the meshes under.
	**/
	public static function build(parent:h3d.scene.Object):Void {
		// h3d.prim.Sphere's own poles sit on the Z axis (built from
		// cos/sin(t) into x/y, cos(t) into z) — rotated here to match this
		// project's Y-axis pole convention (SphereMath.sphericalToCartesian)
		// instead. Keeps the tiled texture's own grain aligned with the
		// column's pole-to-pole axis instead of running crosswise to it.
		var shellPrim = new h3d.prim.Sphere(HubModel.RADIUS, SHELL_SEGS_W, SHELL_SEGS_H);
		shellPrim.addUVs();
		var shellMesh = new h3d.scene.Mesh(shellPrim, parent);
		shellMesh.setRotation(-Math.PI / 2, 0, 0);
		var grassTexture = hxd.Res.textures.grass.toTexture();
		grassTexture.wrap = Repeat;
		shellMesh.material.mainPass.addShader(new UnlitTexture(grassTexture, FLOOR_TILE_U, FLOOR_TILE_V));
		shellMesh.material.mainPass.culling = None;

		buildColumn(parent);
		// Denser and calmer than the baseline: the hub is a small, mostly-empty
		// room the player lingers in rather than passes through, so a thicker
		// floor reads better, and a busier sway would compete with the room's
		// own stillness.
		GrassMesh.build(parent, HubModel.RADIUS, HubModel.isInside, GrassModel.DEFAULT_TUFT_COUNT * 4, GrassWind.DEFAULT_SWAY_AMPLITUDE * 2 / 3);
	}

	static function buildColumn(parent:h3d.scene.Object):Void {
		var points:Array<h3d.Vector> = [];
		var idx = new hxd.IndexBuffer();
		var uvs:Array<h3d.prim.UV> = [];

		for (i in 0...HubModel.COLUMN_SIDES) {
			var a = HubModel.columnEdge(i);
			var b = HubModel.columnEdge(i + 1);

			var uRepeat = a.top.sub(b.top).length() / MeshBuilder.WALL_TEXTURE_TILE_SIZE;
			var vHeight = 2 * HubModel.COLUMN_HALF_HEIGHT / MeshBuilder.WALL_TEXTURE_TILE_SIZE;
			MeshBuilder.addQuad(points, idx, a.top, b.top, b.bottom, a.bottom);
			uvs.push(new h3d.prim.UV(0, vHeight));
			uvs.push(new h3d.prim.UV(uRepeat, vHeight));
			uvs.push(new h3d.prim.UV(uRepeat, 0));
			uvs.push(new h3d.prim.UV(0, 0));
		}

		addCap(points, idx, uvs, true);
		addCap(points, idx, uvs, false);

		var prim = new h3d.prim.Polygon(points, idx);
		prim.uvs = uvs;
		var texture = hxd.Res.textures.wall_stone.toTexture();
		texture.wrap = Repeat;
		var mesh = new h3d.scene.Mesh(prim, parent);
		mesh.material.mainPass.addShader(new UnlitTexture(texture));
		mesh.material.mainPass.culling = None;

		// The painting mounts as an inset overlay on top of its face's own
		// wall texture, same as a biome return painting sits in front of
		// GridMesh's already-built wall — not a replacement for it (an
		// earlier version skipped the whole face's own panel here, leaving
		// everything except the small painting quad itself unrendered).
		var left = HubModel.toBiomeFaceEdge(true);
		var right = HubModel.toBiomeFaceEdge(false);
		var mid = PaintingModel.midpointOf(left, right);
		var outward = new h3d.Vector(mid.x, 0, mid.z).normalized();
		var outwardRef = mid.add(outward.scaled(HubModel.COLUMN_RADIUS));
		PaintingModel.buildQuad(parent, left, right, outwardRef, Colours.TO_BIOME, new h3d.Vector(0, 1, 0));
	}

	/** A triangle fan closing off the column's top (`top = true`) or bottom end. **/
	static function addCap(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, uvs:Array<h3d.prim.UV>, top:Bool):Void {
		var apex = new h3d.Vector(0, top ? HubModel.COLUMN_HALF_HEIGHT : -HubModel.COLUMN_HALF_HEIGHT, 0);
		for (i in 0...HubModel.COLUMN_SIDES) {
			var a = HubModel.columnEdge(i);
			var b = HubModel.columnEdge(i + 1);
			var rimA = top ? a.top : a.bottom;
			var rimB = top ? b.top : b.bottom;
			var start = points.length;
			if (top) {
				points.push(apex);
				points.push(rimA);
				points.push(rimB);
			} else {
				points.push(apex);
				points.push(rimB);
				points.push(rimA);
			}
			idx.push(start);
			idx.push(start + 1);
			idx.push(start + 2);
			uvs.push(new h3d.prim.UV(0.5, 0.5));
			uvs.push(new h3d.prim.UV(0, 0));
			uvs.push(new h3d.prim.UV(1, 0));
		}
	}
}
