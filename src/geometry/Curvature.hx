package geometry;

/**
	Which of the three constant-curvature 2D geometries a space is.

	The whole point of naming these as one type is that they are *one*
	geometry with a parameter, not three special cases — see
	`docs/rules/architecture.md`. Every formula in this
	package is written once, in terms of `sigmaOf`/`cosK`/`sinK`, and
	specialises to the right thing for each constructor.
**/
enum Curvature {
	/** Positive curvature (κ > 0) — the unit sphere. Compact: finite, closed, no boundary, every geodesic returns. **/
	Spherical;

	/** Zero curvature (κ = 0) — the Euclidean plane. **/
	Flat;

	/** Negative curvature (κ < 0) — the hyperbolic plane. Non-compact, exponentially growing, and (the reason this package exists) **not** isometrically embeddable in ℝ³. **/
	Hyperbolic;
}

/**
	The generalised trigonometry that makes one code path cover all three
	curvatures.

	Everything here is at unit curvature (κ = ±1 or 0); physical scale is a
	separate multiplier the caller applies, exactly the way the existing
	`biomes.common.space.common.Space` already threads a `radius` through
	rather than baking it in.

	**Why these functions exist.** In each geometry the relationship between
	an angle at the origin and an arc length is different — `sin` on a
	sphere, the identity on a plane, `sinh` in hyperbolic space. Naming that
	family once means `Isometry.translation` is a single formula instead of
	a three-way branch, and it is why `docs/game/` can talk
	about "walking down the curvature scale" and have that be a literal
	description of a parameter rather than a metaphor.
**/
class CurvatureMath {
	/**
		The signature of the bilinear form this curvature's model uses:
		`+1`, `0` or `-1`. See `CurvedSpace.inner`.
		@param k the curvature to read.
		@return `+1` spherical, `0` flat, `-1` hyperbolic.
	**/
	public static function sigmaOf(k:Curvature):Float {
		return switch k {
			case Spherical: 1;
			case Flat: 0;
			case Hyperbolic: -1;
		}
	}

	/**
		The curvature-generalised cosine: `cos` / `1` / `cosh`.
		@param k the curvature.
		@param d an arc length.
		@return `cos(d)`, `1`, or `cosh(d)`.
	**/
	public static function cosK(k:Curvature, d:Float):Float {
		return switch k {
			case Spherical: Math.cos(d);
			case Flat: 1;
			case Hyperbolic: hyperbolicCos(d);
		}
	}

	/**
		The curvature-generalised sine: `sin` / the identity / `sinh`.

		The flat case being `d` itself rather than a trigonometric function
		is not a fudge — it is the genuine limit of both other cases as
		curvature approaches zero, which is why the three geometries join up
		continuously instead of merely sitting next to each other.
		@param k the curvature.
		@param d an arc length.
		@return `sin(d)`, `d`, or `sinh(d)`.
	**/
	public static function sinK(k:Curvature, d:Float):Float {
		return switch k {
			case Spherical: Math.sin(d);
			case Flat: d;
			case Hyperbolic: hyperbolicSin(d);
		}
	}

	/** Haxe's standard library has no `cosh`. **/
	public static function hyperbolicCos(x:Float):Float {
		return (Math.exp(x) + Math.exp(-x)) / 2;
	}

	/** Haxe's standard library has no `sinh`. **/
	public static function hyperbolicSin(x:Float):Float {
		return (Math.exp(x) - Math.exp(-x)) / 2;
	}

	/**
		Inverse of `hyperbolicCos`, for recovering a distance from an inner
		product — the hyperbolic counterpart to `Math.acos`. Clamped at `1`
		because floating-point error on a point that should be exactly at
		distance `0` can push the argument marginally below it, where the
		real `arccosh` is undefined.
		@param x a value ≥ 1.
		@return the non-negative `t` with `cosh(t) = x`.
	**/
	public static function hyperbolicAcos(x:Float):Float {
		var safe = x < 1 ? 1.0 : x;
		return Math.log(safe + Math.sqrt(safe * safe - 1));
	}
}
