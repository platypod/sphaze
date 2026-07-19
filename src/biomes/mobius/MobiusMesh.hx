package biomes.mobius;

import biomes.common.space.mobius.MobiusMath;
import biomes.common.tree.TreeMesh;
import biomes.mobius.MobiusForestGenerator.ForestLayout;
import game.MeshBuilder;
import graphics.Colours;

/**
	Builds the Möbius ribbon's own scene-graph mesh: a plain rectangular
	`(u, v)` grid, `u` from `0` to `2*PI` and `v` from `-MobiusModel.HALF_WIDTH`
	to `+MobiusModel.HALF_WIDTH`, sampled through `MobiusMath.pointAt` and
	connected into quads exactly like any other parametric surface patch —
	nothing Möbius-specific here at all. The twist and the loop's own
	closure are entirely a property of `MobiusMath.pointAt` itself: sampling
	`u` all the way through the closed `[0, 2*PI]` interval (including both
	endpoints) already produces a seamless, gap-free surface with no special-
	casing, because `pointAt(2*PI, v)` is, by the flip identity
	(`MobiusMath`'s own class doc), exactly coincident with `pointAt(0, v *
	(-1)^twists)` — the ribbon's own defining self-identification, not
	something this mesh builder needs to reason about.

	No texture asset exists for this biome yet — alternating flat-colored
	across-width bands (`h3d.shader.FixedColor`, same "no lighting, just a
	placeholder fill" approach `entities.painting.PaintingModel.buildFrame`
	already uses) stand in for one, and double as the actual diagnostic this
	first pass is for: a colored band visibly spiraling as you walk around
	the loop is the plainest possible read on whether a given twist count
	looks right.

	Also builds the forest `biomes.mobius.MobiusForestGenerator` scattered
	across the ribbon (`buildForest`) — each tree's own trunk/foliage
	geometry comes from the topology-agnostic `biomes.common.tree.TreeMesh`,
	oriented per tree via `MobiusMath.localFrameAt` at that tree's own
	`(u, v)` (`tu`/`tv`/`normal` slot directly into `TreeMesh`'s own
	`tangent`/`right`/`up` parameters, being exactly that orthonormal
	triple already).
**/
class MobiusMesh {
	/** Samples around the loop — fine enough to read as smoothly curved through several twists. **/
	static inline final U_SEGMENTS:Int = 180;

	/** Across-width color bands — small since the width itself is uniform (no width-wise curvature to subdivide for). **/
	static inline final V_SEGMENTS:Int = 4;

	/**
		How many trees' worth of geometry go into one trunk/foliage mesh —
		`addQuad`/`addTriangle` never share or reuse a vertex, so a single
		mesh spanning the whole forest could rack up more distinct vertices
		than `hxd.IndexBuffer` can actually index (an `Array<UInt16>` under
		the hood, silently wrapping indices past `65536` back to `0` instead
		of erroring — the exact bug `biomes.tower.TowerMesh.LAYERS_PER_CHUNK`'s
		own doc already ran into once). Foliage is the worse case per tree
		(two cones, `TreeMesh.FOLIAGE_SIDES` triangles each, 3 new vertices
		per triangle): `500 * 2 * 8 * 3 = 24000`, comfortably clear of the
		limit regardless of how many trees `biomes.mobius.MobiusForestGenerator`
		actually manages to place.
	**/
	static inline final TREES_PER_CHUNK:Int = 500;

	/**
		@param parent the scene object to attach the meshes under.
		@param twists half-twists over one full lap around the loop.
		@param forest the generated forest to render alongside the ribbon itself.
	**/
	public static function build(parent:h3d.scene.Object, twists:Int, forest:ForestLayout):Void {
		var pointsA:Array<h3d.Vector> = [];
		var idxA = new hxd.IndexBuffer();
		var pointsB:Array<h3d.Vector> = [];
		var idxB = new hxd.IndexBuffer();

		var bandWidth = 2 * MobiusModel.HALF_WIDTH / V_SEGMENTS;
		for (band in 0...V_SEGMENTS) {
			var vLo = -MobiusModel.HALF_WIDTH + band * bandWidth;
			var vHi = vLo + bandWidth;
			if (band % 2 == 0) {
				addBandStrip(pointsA, idxA, vLo, vHi, twists);
			} else {
				addBandStrip(pointsB, idxB, vLo, vHi, twists);
			}
		}

		buildColoredMesh(parent, pointsA, idxA, Colours.MOBIUS_BAND_A);
		buildColoredMesh(parent, pointsB, idxB, Colours.MOBIUS_BAND_B);

		buildForest(parent, twists, forest);
	}

	/** The whole forest's own trunks and foliage, chunked (see `TREES_PER_CHUNK`'s own doc) into as few draw calls as the index-buffer limit allows. **/
	static function buildForest(parent:h3d.scene.Object, twists:Int, forest:ForestLayout):Void {
		var fromIndex = 0;
		while (fromIndex < forest.trees.length) {
			var toIndex = hxd.Math.imin(fromIndex + TREES_PER_CHUNK, forest.trees.length);
			buildForestChunk(parent, twists, forest, fromIndex, toIndex);
			fromIndex = toIndex;
		}
	}

	/** One forest chunk's own trunk and foliage meshes, covering trees `fromIndex` (inclusive) to `toIndex` (exclusive). **/
	static function buildForestChunk(parent:h3d.scene.Object, twists:Int, forest:ForestLayout, fromIndex:Int, toIndex:Int):Void {
		var trunkPoints:Array<h3d.Vector> = [];
		var trunkIdx = new hxd.IndexBuffer();
		var foliagePoints:Array<h3d.Vector> = [];
		var foliageIdx = new hxd.IndexBuffer();

		for (i in fromIndex...toIndex) {
			var tree = forest.trees[i];
			var frame = MobiusMath.localFrameAt(tree.u, tree.v, twists, MobiusModel.RADIUS);
			var base = new h3d.Vector(tree.x, tree.y, tree.z).add(frame.normal.scaled(MobiusModel.TREE_ROOT_LIFT));

			TreeMesh.addTrunk(trunkPoints, trunkIdx, base, frame.normal, frame.tu, frame.tv, tree.trunkHeight, tree.trunkRadius);
			TreeMesh.addFoliage(foliagePoints, foliageIdx, base, frame.normal, frame.tu, frame.tv, tree.trunkHeight, tree.foliageRadius, tree.foliageHeight);
		}

		buildColoredMesh(parent, trunkPoints, trunkIdx, Colours.TREE_TRUNK);
		buildColoredMesh(parent, foliagePoints, foliageIdx, Colours.TREE_FOLIAGE);
	}

	/** One across-width band's own quad strip, `v` fixed to `vLo`/`vHi`, `u` swept the whole way around `[0, 2*PI]` — see class doc for why that alone is enough to close the loop. **/
	static function addBandStrip(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, vLo:Float, vHi:Float, twists:Int):Void {
		var step = 2 * Math.PI / U_SEGMENTS;
		for (i in 0...U_SEGMENTS) {
			var u0 = i * step;
			var u1 = (i + 1) * step;
			var loA = MobiusMath.pointAt(u0, vLo, twists, MobiusModel.RADIUS);
			var hiA = MobiusMath.pointAt(u0, vHi, twists, MobiusModel.RADIUS);
			var loB = MobiusMath.pointAt(u1, vLo, twists, MobiusModel.RADIUS);
			var hiB = MobiusMath.pointAt(u1, vHi, twists, MobiusModel.RADIUS);
			MeshBuilder.addQuad(points, idx, loA, loB, hiB, hiA);
		}
	}

	/** One flat-colored mesh — `culling = None` since the ribbon is walked from either face, being one continuous side. **/
	static function buildColoredMesh(parent:h3d.scene.Object, points:Array<h3d.Vector>, idx:hxd.IndexBuffer, color:Int):Void {
		var mesh = new h3d.scene.Mesh(new h3d.prim.Polygon(points, idx), parent);
		mesh.material.mainPass.addShader(new h3d.shader.FixedColor(color));
		mesh.material.mainPass.culling = None;
	}
}
