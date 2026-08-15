package geometry;

import geometry.Curvature.CurvatureMath;

/**
	A point in the homogeneous model — deliberately *not* `h3d.Vector`, and
	deliberately not a position in the world.

	These three numbers are coordinates in a model of a 2D surface, not a
	place in ambient 3D space. That distinction is the entire reason this
	package exists: the previous architecture stored positions as ambient
	ℝ³ points, which works for a sphere and provably cannot work for the
	hyperbolic plane (Hilbert's theorem — no complete C² isometric
	immersion of H² into ℝ³ exists). Converting to something renderable is
	the rendering layer's job, later and lossily.
**/
typedef ModelPoint = {
	var x:Float;
	var y:Float;
	var z:Float;
}

/**
	Constant-curvature 2D geometry, in one implementation parameterised by
	`Curvature` — the replacement for `biomes.common.space.common.Space`
	proposed in `docs/game-design/direction/architecture.md`.

	**The model.** Points live in ℝ³ carrying the bilinear form

	```
	⟨u, v⟩ = u.x·v.x + u.y·v.y + σ·u.z·v.z        σ = sigmaOf(curvature)
	```

	and the surface is that form's unit quadric: `⟨p,p⟩ = 1` (sphere),
	the affine plane `z = 1` (Euclidean), or the forward sheet of
	`⟨p,p⟩ = -1` (hyperboloid). The origin is `(0, 0, 1)` in all three.

	**Why the hyperboloid rather than Poincaré or Klein.** Isometries are
	plain matrix multiplications here, the numerics are well behaved far
	from the origin (a Poincaré disc crowds everything into a unit circle
	and loses precision exactly where the interesting hyperbolic distances
	live), and it is what HyperRogue uses. Projecting to a disc model is a
	*rendering* concern, applied last.

	**Scale.** Everything is at unit curvature. A biome's physical size is
	the caller's multiplier, matching how the existing `Space` already
	threads `radius` through rather than baking it in.

	Headless and dependency-free on purpose: no Heaps import, so all of it
	is testable without a renderer. That is the whole reason this is safe
	to build first — see the migration plan in the direction folder.
**/
class CurvedSpace {
	/** Where every frame starts: `(0, 0, 1)`, on the surface in all three geometries. **/
	public static function origin():ModelPoint {
		return {x: 0, y: 0, z: 1};
	}

	/**
		The model's bilinear form. Note the third term's sign flip in the
		hyperbolic case — that single minus sign is the whole difference
		between a sphere and a hyperbolic plane, and therefore (see the
		direction folder) between a world that can account for you and one
		that cannot.
		@param k the curvature whose form to use.
		@param a first operand.
		@param b second operand.
		@return `a.x*b.x + a.y*b.y + σ*a.z*b.z`.
	**/
	public static function inner(k:Curvature, a:ModelPoint, b:ModelPoint):Float {
		return a.x * b.x + a.y * b.y + CurvatureMath.sigmaOf(k) * a.z * b.z;
	}

	/**
		Geodesic distance between two points on the surface — the intrinsic
		metric, which is what collision and gameplay must use. Straight-line
		distance between the same two *coordinate triples* is meaningless
		here and would be a bug.
		@param k the curvature.
		@param a first point, assumed on the surface.
		@param b second point, assumed on the surface.
		@return the arc length of the geodesic joining them.
	**/
	public static function distance(k:Curvature, a:ModelPoint, b:ModelPoint):Float {
		return switch k {
			case Spherical:
				var dot = inner(k, a, b);
				Math.acos(dot < -1 ? -1 : (dot > 1 ? 1 : dot));
			case Flat:
				// z is the homogeneous coordinate and is always 1 here, so it carries no length
				var dx = a.x - b.x;
				var dy = a.y - b.y;
				Math.sqrt(dx * dx + dy * dy);
			case Hyperbolic:
				CurvatureMath.hyperbolicAcos(-inner(k, a, b));
		}
	}

	/**
		Pulls a point back onto the surface, undoing the floating-point
		drift that accumulates over many composed isometries — the
		curvature-aware counterpart to normalising a unit vector.

		`PlayerModel`'s own doc notes that the existing code deliberately
		*doesn't* re-orthogonalise, having never needed to. That was a
		reasonable call for rotations of unit vectors; it is a much riskier
		one for hyperbolic boosts, whose entries grow exponentially with
		distance, so this exists from the start rather than being retrofitted
		after a drift bug.
		@param k the curvature.
		@param p a point near the surface.
		@return the corresponding point exactly on it.
	**/
	public static function normalize(k:Curvature, p:ModelPoint):ModelPoint {
		return switch k {
			case Spherical:
				var n = Math.sqrt(p.x * p.x + p.y * p.y + p.z * p.z);
				n == 0 ? origin() : {x: p.x / n, y: p.y / n, z: p.z / n};
			case Flat:
				// the model is the affine plane z = 1; x and y are already honest
				p.z == 0 ? {x: p.x, y: p.y, z: 1.0} : {x: p.x / p.z, y: p.y / p.z, z: 1.0};
			case Hyperbolic:
				// restore ⟨p,p⟩ = -1 by recomputing z from x and y, which is exact on the forward sheet
				{x: p.x, y: p.y, z: Math.sqrt(1 + p.x * p.x + p.y * p.y)};
		}
	}

	/**
		The circumference of a circle of geodesic radius `r` — `2π·sinK(r)`.

		Not needed by gameplay directly; it is here because it is the
		cleanest expression of the fact the whole direction rests on. Flat
		space grows linearly, spherical space grows and then *shrinks* back
		to nothing at the antipode, and hyperbolic space grows
		**exponentially** — which is what non-amenability means concretely,
		and therefore why the boundary of any region there is as large as
		its interior, and therefore why nothing in it can be fully
		accounted for — which is what lets an uncaused pattern there go
		unpaid-for. See `docs/game-design/direction/README.md`.
		@param k the curvature.
		@param r a geodesic radius.
		@return the circumference of that circle.
	**/
	public static function circleCircumference(k:Curvature, r:Float):Float {
		return 2 * Math.PI * CurvatureMath.sinK(k, r);
	}
}
