package biomes.common.space.hyperbolic;

import biomes.common.space.common.Space;

/**
	The hyperbolic plane as a walkable `Space` — **the first
	non-embeddable surface in the game, and the reason the spatial
	refactor in `docs/game-design/direction/architecture.md` exists.**

	**Why this needs no interface change, contrary to that document.**
	`architecture.md` argued the current `Space` abstraction provably
	cannot hold hyperbolic space, because Hilbert's theorem forbids an
	isometric embedding of H² in ℝ³. The theorem is right and the
	conclusion was too strong: `Space`'s signature never actually *says*
	`h3d.Vector` means "a point in ambient Euclidean 3-space". It says
	three floats. Nothing stops those three floats being **hyperboloid
	model coordinates** — a point on `⟨p,p⟩ = -1` under the Minkowski form
	— which is an intrinsic, singularity-free description of H² that
	happens to need exactly three numbers.

	Which is the same trick the sphere has been quietly using all along:
	`SphereSpace`'s own `pos` is a unit 3-vector, and unit 3-vectors *are*
	the natural model of S², not an embedding of it. This class is that
	idea with one sign flipped.

	**Coordinates.** `pos` lies on the forward sheet of the hyperboloid,
	scaled by `radius` the same way `SphereSpace` scales its own unit
	vectors — so `radius` means "curvature radius" in both, and a caller
	that already threads it through needs no new concept. `forward` is a
	tangent at `pos`, Minkowski-orthogonal to it.

	**`upAt` returns render-space up**, `(0, 1, 0)`, and that is not a
	fudge: the game's spaces are *product* geometries (H²×ℝ), so height is
	a Euclidean factor that simply is not expressible in the three
	coordinates describing the surface. `FlatSpace` already returns a
	constant for the same reason. Only `SphereSpace`, where the model
	coordinates and the render coordinates coincide, can afford to derive
	"up" from position.

	**What still cannot come along.** Anything that treats `pos` as an
	ordinary Euclidean point — straight-line distance, `h3d.Vector.length`,
	naive interpolation — is meaningless here and will silently produce
	nonsense rather than failing. A hyperbolic biome must use this class's
	own `distance`, and must render through
	`geometry.HyperbolicProjection` rather than by handing `pos` to a
	camera.
**/
class HyperbolicSpace implements Space {
	/** Curvature radius. Kept per-instance rather than shared, like `biomes.common.space.mobius.MobiusSpace` and unlike the stateless singletons, since a biome picks its own scale. **/
	public final radius:Float;

	public function new(radius:Float) {
		this.radius = radius;
	}

	/**
		The Minkowski form for signature `(+, +, -)` — the one line that
		makes this hyperbolic rather than spherical. `SphereSpace`'s
		equivalent is the ordinary dot product; flipping the third sign is
		the entire difference between a world that closes and one that
		never does.
		@param a first operand.
		@param b second operand.
		@return `a.x*b.x + a.y*b.y - a.z*b.z`.
	**/
	public static function inner(a:h3d.Vector, b:h3d.Vector):Float {
		return a.x * b.x + a.y * b.y - a.z * b.z;
	}

	/**
		See `Space.upAt`. Constant, because height is the Euclidean factor
		of H²×ℝ and does not live in the surface coordinates at all — see
		this class's own doc.
		@param pos ignored; present for the interface.
		@return render-space up.
	**/
	public function upAt(pos:h3d.Vector):h3d.Vector {
		return new h3d.Vector(0, 1, 0);
	}

	/**
		See `Space.moveAlong`. Structurally identical to `SphereSpace`'s
		own implementation — move along a geodesic and parallel-transport
		`forward` by the same motion — with circular functions replaced by
		hyperbolic ones, which is exactly the substitution
		`geometry.CurvatureMath` names.

		The geodesic through `pos` in direction `d` is
		`p·cosh(t) + d·sinh(t)`, and its own tangent transports to
		`p·sinh(t) + d·cosh(t)`. An arbitrary tangent is split into its
		component along `d` (which transports with it) and the perpendicular
		remainder (which a 2D parallel transport leaves alone).
		@param pos the point to move from, on the hyperboloid, scaled by `radius`.
		@param forward the tangent to carry along.
		@param direction unit tangent at `pos` to move along.
		@param distance arc length; negative moves the opposite way.
		@param radius the curvature radius this `pos` is scaled to.
		@return the new position and transported forward.
	**/
	public function moveAlong(pos:h3d.Vector, forward:h3d.Vector, direction:h3d.Vector, distance:Float, radius:Float):{pos:h3d.Vector, forward:h3d.Vector} {
		var unitPos = pos.scaled(1 / radius);
		var dir = normalizeTangent(direction);
		var t = distance / radius;
		var cosh = (Math.exp(t) + Math.exp(-t)) / 2;
		var sinh = (Math.exp(t) - Math.exp(-t)) / 2;

		var movedUnit = unitPos.scaled(cosh).add(dir.scaled(sinh));
		var movedDir = unitPos.scaled(sinh).add(dir.scaled(cosh));

		// split forward into "along dir" (transports with it) + perpendicular (untouched)
		var along = inner(forward, dir);
		var perpendicular = forward.sub(dir.scaled(along));
		var newForward = movedDir.scaled(along).add(perpendicular);

		return {pos: onSheet(movedUnit).scaled(radius), forward: newForward};
	}

	/**
		Geodesic distance between two points — the intrinsic metric, which
		is what any collision or proximity check here must use. Straight-line
		`h3d.Vector` distance between the same two triples is meaningless.
		@param a first point, scaled by `radius`.
		@param b second point, scaled by `radius`.
		@return the arc length between them.
	**/
	public function distance(a:h3d.Vector, b:h3d.Vector):Float {
		var product = -inner(a.scaled(1 / radius), b.scaled(1 / radius));
		var safe = product < 1 ? 1.0 : product;
		return radius * Math.log(safe + Math.sqrt(safe * safe - 1));
	}

	/**
		See `Space.turn`. **The reason `turn` is on the interface at all**:
		the ambient version rotates `forward` about the local "up" axis,
		which is correct wherever the model coordinates are ambient ℝ³ and
		is meaningless here, since `upAt` returns render-space up and has
		nothing to do with these coordinates.

		A rotation in this space is a rotation *within the Minkowski tangent
		plane at `pos`* — the ordinary 2D rotation, taken in the basis
		`(forward, side)` that `HyperbolicView` already fixes. Positive
		turns right, matching every other space, because
		`HyperbolicView.sideOf` is screen-right once the projection's
		handedness flip is applied (see its own doc).
		@param pos the position being turned at, on the hyperboloid, scaled by this instance's `radius`.
		@param forward the current unit tangent.
		@param up ignored — see above.
		@param angle rotation in radians; positive turns right.
		@return the rotated unit tangent.
	**/
	public function turn(pos:h3d.Vector, forward:h3d.Vector, up:h3d.Vector, angle:Float):h3d.Vector {
		var unitPos = pos.scaled(1 / radius);
		var f = normalizeTangent(forward);
		var side = HyperbolicView.sideOf(unitPos, f);
		return f.scaled(Math.cos(angle)).add(side.scaled(Math.sin(angle)));
	}

	/**
		See `Space.rightOf`, and in particular its note that the convention
		is **inverted relative to the screen** and deliberately kept that
		way. There is no ambient cross product to take here, so this returns
		the negative of `HyperbolicView.sideOf` — which is screen-right — so
		that `game.GameLoop`'s single existing negation at the strafe site
		lands on screen-right in this space too, with no change there.

		Pinned by `HyperbolicSpaceTest`'s own agreement test against
		`geometry.HyperbolicWalker.strafe` rather than left to this
		reasoning, because a sign argued in prose is a sign nobody can
		check.
		@param pos the position to find "right" at, scaled by this instance's `radius`.
		@param forward the current unit tangent.
		@param up ignored — see `turn`.
		@return the unit tangent perpendicular to `forward`, in the inverted convention `Space.rightOf` documents.
	**/
	public function rightOf(pos:h3d.Vector, forward:h3d.Vector, up:h3d.Vector):h3d.Vector {
		var unitPos = pos.scaled(1 / radius);
		return HyperbolicView.sideOf(unitPos, normalizeTangent(forward)).scaled(-1);
	}

	/** Pulls a unit-scale point back onto `⟨p,p⟩ = -1`, undoing the drift that accumulates over many boosts — whose entries grow exponentially with distance, so this matters more here than the sphere's own normalisation ever did. **/
	static function onSheet(p:h3d.Vector):h3d.Vector {
		return new h3d.Vector(p.x, p.y, Math.sqrt(1 + p.x * p.x + p.y * p.y));
	}

	/** Rescales a tangent to Minkowski-unit length; a tangent to the hyperboloid is always spacelike, so its own norm is positive. **/
	static function normalizeTangent(v:h3d.Vector):h3d.Vector {
		var norm = Math.sqrt(inner(v, v));
		return norm == 0 ? v : v.scaled(1 / norm);
	}
}
