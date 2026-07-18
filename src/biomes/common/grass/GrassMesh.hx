package biomes.common.grass;

import game.MeshBuilder;
import biomes.common.grass.GrassModel.Tuft;
import biomes.common.space.sphere.SphereMath;
import graphics.Colours;
import graphics.shaders.GrassWind;

/**
	Builds a sphere's own grass as a single `h3d.prim.Polygon` (all tufts
	batched into one mesh/one draw call, same approach `biomes.hub.HubMesh.buildColumn`
	uses for its own many-sided geometry) from `GrassModel`'s scattered
	placements. Biome-agnostic — takes the sphere's `radius`/`isWalkable`
	straight through to `GrassModel.scatter` rather than assuming a specific
	biome's own shape.

	Each tuft is two crossed single-triangle blades — the cheapest silhouette
	that still reads as grass from any horizontal viewing angle, the same
	"cross-quad" trick real-time grass rendering has used forever — rotated
	together by the tuft's own `rotation` so neighboring tufts don't all face
	identically. Blade tips lean slightly along their own blade direction at
	rest (`LEAN_FACTOR`) purely for a less robotic silhouette; the actual
	wind motion is `GrassWind`'s job entirely, driven by the `uv` this class
	packs per vertex (`x` = phase, `y` = 0 at the root/1 at the tip).
**/
class GrassMesh {
	/** Lifts each blade's root off the sphere's own surface, along the local "up," to avoid z-fighting with whatever floor mesh sits at the same radius. **/
	static inline final ROOT_LIFT:Float = 0.05;

	/** Static resting lean, as a fraction of blade height, along the blade's own width direction — purely cosmetic (see class doc); `GrassWind` owns all the actual motion. **/
	static inline final LEAN_FACTOR:Float = 0.2;

	/**
		@param parent the scene object to attach the grass mesh under.
		@param radius the sphere's own radius `isWalkable` was built against.
		@param isWalkable whether a candidate world position is a valid place to grow a tuft — see `GrassModel.scatter`.
		@param tuftCount how many tufts to scatter; defaults to `GrassModel.DEFAULT_TUFT_COUNT`. Callers with a denser or sparser floor (a different biome, a different sphere radius) pass their own rather than this hardcoding one absolute count for everyone.
		@param swayAmplitude passed straight through to `GrassWind`; defaults to its own baseline.
		@param swayFrequency passed straight through to `GrassWind`; defaults to its own baseline.
		@param random source of randomness for `GrassModel.scatter`; defaults to Math.random.
	**/
	public static function build(parent:h3d.scene.Object, radius:Float, isWalkable:h3d.Vector->Bool, tuftCount:Int = GrassModel.DEFAULT_TUFT_COUNT,
			swayAmplitude:Float = GrassWind.DEFAULT_SWAY_AMPLITUDE, swayFrequency:Float = GrassWind.DEFAULT_SWAY_FREQUENCY, ?random:Void->Float):Void {
		var tufts = GrassModel.scatter(radius, isWalkable, tuftCount, random);
		var points:Array<h3d.Vector> = [];
		var idx = new hxd.IndexBuffer();
		var uvs:Array<h3d.prim.UV> = [];
		for (tuft in tufts) {
			addTuft(points, idx, uvs, tuft);
		}

		var prim = new h3d.prim.Polygon(points, idx);
		prim.uvs = uvs;
		var mesh = new h3d.scene.Mesh(prim, parent);
		// Wind "blows" along world +X, tangent-projected per vertex in the
		// shader itself (see `GrassWind`'s own doc) — a single fixed axis
		// here is enough; the shader is what keeps it looking right across
		// the whole sphere.
		mesh.material.mainPass.addShader(new GrassWind(Colours.GRASS_BASE, Colours.GRASS_TIP, new h3d.Vector(1, 0, 0), swayAmplitude, swayFrequency));
		mesh.material.mainPass.culling = None;
	}

	static function addTuft(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, uvs:Array<h3d.prim.UV>, tuft:Tuft):Void {
		var up = SphereMath.upVectorAt(tuft.pos, new h3d.Vector(0, 0, 0));
		var base = tuft.pos.add(up.scaled(ROOT_LIFT));
		// thetaTangentAt/phiTangentAt are already an orthonormal basis
		// tangent to the sphere at this point (see their own docs) — rotate
		// both together by the tuft's own `rotation` (Rodrigues, around
		// `up`) rather than deriving a fresh basis, so the two blades stay
		// exactly perpendicular for free.
		var dir1 = SphereMath.rotateAroundAxis(SphereMath.thetaTangentAt(tuft.theta, tuft.phi), up, tuft.rotation);
		var dir2 = SphereMath.rotateAroundAxis(SphereMath.phiTangentAt(tuft.phi), up, tuft.rotation);
		addBlade(points, idx, uvs, base, up, dir1, tuft);
		addBlade(points, idx, uvs, base, up, dir2, tuft);
	}

	static function addBlade(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, uvs:Array<h3d.prim.UV>, base:h3d.Vector, up:h3d.Vector, dir:h3d.Vector,
			tuft:Tuft):Void {
		var halfWidth = tuft.width / 2;
		var left = base.sub(dir.scaled(halfWidth));
		var right = base.add(dir.scaled(halfWidth));
		var tip = base.add(up.scaled(tuft.height)).add(dir.scaled(tuft.height * LEAN_FACTOR));

		MeshBuilder.addTriangle(points, idx, left, right, tip);
		uvs.push(new h3d.prim.UV(tuft.phase, 0));
		uvs.push(new h3d.prim.UV(tuft.phase, 0));
		uvs.push(new h3d.prim.UV(tuft.phase, 1));
	}
}
