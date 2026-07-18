package biomes.common.grass;

import biomes.common.space.sphere.SphereMath;

/** One grass tuft's placement and per-instance variation — everything `GrassMesh` needs to build its two crossed blades and everything `GrassWind` needs to sway them differently from their neighbors. **/
typedef Tuft = {
	var pos:h3d.Vector;
	var theta:Float;
	var phi:Float;
	var rotation:Float;
	var height:Float;
	var width:Float;
	var phase:Float;
}

/**
	Scatters grass tuft placements across a sphere's own walkable surface —
	pure data/geometry, no scene graph (see `GrassMesh` for the actual mesh
	building), same `Model`/`Mesh` split every other biome piece uses. Takes
	`radius`/`isWalkable` as parameters rather than reaching into a specific
	biome's own geometry (`HubModel`, `GridModel`, ...) directly — this lives
	in `biomes.common` precisely so any biome can grow grass on whatever
	"walkable" means for its own shape, not just the hub's.
**/
class GrassModel {
	/** Baseline tuft count — a first-pass density, not a derived constant. Callers (see `GrassMesh.build`) scale it per biome rather than each hardcoding their own absolute count. **/
	public static inline final DEFAULT_TUFT_COUNT:Int = 1200;

	static inline final HEIGHT_MIN:Float = 2;
	static inline final HEIGHT_MAX:Float = 4;
	static inline final WIDTH_MIN:Float = 0.8;
	static inline final WIDTH_MAX:Float = 1.4;

	/**
		Scatters `count` tufts uniformly by surface area over a sphere of the
		given `radius`, rejecting draws `isWalkable` rejects — cheap as long
		as the unwalkable fraction of the sphere stays small, since this is
		plain rejection sampling, not an exact walkable-area parametrization.
		@param radius the sphere's own radius (must match whatever `isWalkable` was built against).
		@param isWalkable whether a candidate world position is a valid place to grow a tuft — a biome's own notion of "not inside a wall/column/etc.".
		@param count how many tufts to scatter; defaults to `DEFAULT_TUFT_COUNT`.
		@param random source of randomness in [0, 1); defaults to Math.random.
		@return the scattered tufts.
	**/
	public static function scatter(radius:Float, isWalkable:h3d.Vector->Bool, count:Int = DEFAULT_TUFT_COUNT, ?random:Void->Float):Array<Tuft> {
		var rng = random != null ? random : Math.random;
		var tufts:Array<Tuft> = [];
		while (tufts.length < count) {
			// Uniform-by-area sampling over a full sphere: theta from
			// acos(1 - 2u), not a plain acos(u), which would bunch points
			// toward the poles (equal-theta bands don't cover equal area).
			var theta = Math.acos(1 - 2 * rng());
			var phi = 2 * Math.PI * rng();
			var pos = SphereMath.sphericalToCartesian(radius, theta, phi);
			if (!isWalkable(pos)) {
				continue;
			}

			tufts.push({
				pos: pos,
				theta: theta,
				phi: phi,
				rotation: rng() * Math.PI,
				height: HEIGHT_MIN + rng() * (HEIGHT_MAX - HEIGHT_MIN),
				width: WIDTH_MIN + rng() * (WIDTH_MAX - WIDTH_MIN),
				phase: rng() * 2 * Math.PI
			});
		}
		return tufts;
	}
}
