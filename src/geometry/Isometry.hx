package geometry;

import geometry.Curvature.CurvatureMath;
import geometry.CurvedSpace.ModelPoint;

/**
	A distance-preserving transformation of a constant-curvature space,
	stored as a 3×3 matrix over the model coordinates — and, in the
	architecture proposed in `docs/game-design/direction/architecture.md`,
	**the player's entire spatial state**.

	That is the significant change from the current `PlayerModel`, which
	carries a `pos` and a `forward` as separate ambient-ℝ³ vectors. Here a
	frame *is* an isometry: the one that maps the origin, facing along +x,
	to where you are and how you face. Walking forward is
	`compose(frame, translation(k, d))`; turning is
	`compose(frame, rotation(θ))`. Position is `apply(frame, origin())`.

	Two things fall out of that for free, and both are recorded in
	`PROJECT_LOG.md` as problems that cost real debugging time:

	- **No coordinate singularities.** `PlayerModel`'s doc describes ripping
	  out `(theta, phi)` because latitude coordinates go singular at the
	  poles and the view "pivoted at mach-speed like a spinner". An isometry
	  has no coordinates to be singular in — the fix that was found
	  empirically for the sphere is structural here, and holds in every
	  curvature.
	- **One representation for all three geometries**, since only
	  `translation` reads the curvature at all.
**/
class Isometry {
	/** Row-major 3×3. Kept as a flat array rather than nine named fields so composition is a loop rather than 27 hand-written products. **/
	public final m:Array<Float>;

	public function new(m:Array<Float>) {
		if (m.length != 9) {
			throw "an Isometry is a 3x3 matrix and needs exactly 9 entries";
		}
		this.m = m;
	}

	/** The frame that changes nothing: at the origin, facing +x. **/
	public static function identity():Isometry {
		return new Isometry([1, 0, 0, 0, 1, 0, 0, 0, 1]);
	}

	/**
		Move forward by `d` along the +x geodesic — **the one operation that
		reads the curvature**, and therefore the entire difference between
		the three geometries in this package.

		It specialises to a rotation on the sphere, a shear on the plane and
		a Lorentz boost in hyperbolic space, and the three are the same
		formula because of `CurvatureMath`'s generalised trigonometry. A
		reader checking this against a reference should note the `-σ` in the
		lower-left entry: that is what keeps the matrix in the isometry
		group of this curvature's own bilinear form.
		@param k the curvature to move through.
		@param d arc length; negative moves backwards.
		@return the isometry translating the origin by `d` along +x.
	**/
	public static function translation(k:Curvature, d:Float):Isometry {
		var c = CurvatureMath.cosK(k, d);
		var s = CurvatureMath.sinK(k, d);
		var sigma = CurvatureMath.sigmaOf(k);
		return new Isometry([c, 0, s, 0, 1, 0, -sigma * s, 0, c]);
	}

	/**
		Rotate by `angle` radians about the origin. Curvature-independent:
		the tangent plane at a point is Euclidean in every geometry, which
		is precisely what "a manifold looks flat close up" means.
		@param angle rotation in radians, counter-clockwise.
		@return the rotating isometry.
	**/
	public static function rotation(angle:Float):Isometry {
		var c = Math.cos(angle);
		var s = Math.sin(angle);
		return new Isometry([c, -s, 0, s, c, 0, 0, 0, 1]);
	}

	/**
		Matrix product — the composition of two isometries, applied left to
		right in the sense that `compose(frame, translation(...))` moves
		*in the frame's own local coordinates*, which is what "walk forward
		from where I am, facing where I face" means.
		@param a the first isometry.
		@param b the isometry to apply in `a`'s local frame.
		@return their composition.
	**/
	public static function compose(a:Isometry, b:Isometry):Isometry {
		var out = [for (i in 0...9) 0.0];
		for (row in 0...3) {
			for (col in 0...3) {
				var sum = 0.0;
				for (k in 0...3) {
					sum += a.m[row * 3 + k] * b.m[k * 3 + col];
				}
				out[row * 3 + col] = sum;
			}
		}
		return new Isometry(out);
	}

	/**
		Apply this isometry to a point.
		@param iso the transformation.
		@param p the point to move.
		@return the transformed point.
	**/
	public static function apply(iso:Isometry, p:ModelPoint):ModelPoint {
		return {
			x: iso.m[0] * p.x + iso.m[1] * p.y + iso.m[2] * p.z,
			y: iso.m[3] * p.x + iso.m[4] * p.y + iso.m[5] * p.z,
			z: iso.m[6] * p.x + iso.m[7] * p.y + iso.m[8] * p.z,
		};
	}

	/**
		Where a frame is standing.
		@param frame the frame to read.
		@return the point at the frame's own origin.
	**/
	public static function positionOf(frame:Isometry):ModelPoint {
		return apply(frame, CurvedSpace.origin());
	}

	/**
		The frame's own facing, as the angle its +x direction makes in the
		tangent plane at its position — recovered rather than stored, since
		the matrix already holds it. Only meaningful relative to some other
		frame at the same point, which is exactly what holonomy measures
		(see `CurvedSpaceTest`'s own square-walk test, and `The Defect` in
		`docs/game-design/direction/world-and-threads.md`).
		@param frame the frame to read.
		@return its rotation component, in radians.
	**/
	public static function headingOf(frame:Isometry):Float {
		return Math.atan2(frame.m[3], frame.m[0]);
	}
}
