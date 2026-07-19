package biomes.common.space.mobius;

/**
	Möbius-ribbon geometry: a band of half-width `v` closed into a loop of
	centerline radius `radius`, twisted `twists` half-turns over one full
	lap. Pure math, engine-agnostic, same role `biomes.common.space.sphere.SphereMath`
	plays for the sphere.

	Parametrized by `u` (angle around the loop, radians) and `v` (across-
	width offset from the centerline, in `[-halfWidth, halfWidth]`):

	```
	theta(u) = twists * u / 2
	P(u, v) = ( (radius + v*cos(theta))*cos(u), v*sin(theta), (radius + v*cos(theta))*sin(u) )
	```

	Loop flat in the X-Z plane, twist wobble in Y, matching this project's
	Y-up convention.

	Key identity (exact, for integer `twists`): `pointAt(u + 2*PI, v, ...) ==
	pointAt(u, v * (-1)^twists, ...)`. For odd `twists` (the actual Möbius
	case — one-sided, non-orientable) that's `pointAt(u+2*PI, v) ==
	pointAt(u, -v)`: walking once around the loop at a fixed `v` arrives
	where `-v` would be, relative to the start — the defining "walk far
	enough, come back mirrored" property, falling straight out of the
	formula with no special-casing. Even `twists` degenerates to an
	orientable, two-sided band instead (still a valid surface, just not a
	Möbius strip) — not the intended use here, but the formula handles it
	the same way.

	Precondition every caller relies on: `halfWidth` well under `radius`, so
	`radius + v*cos(theta)` never approaches 0 for any reachable `v` — both
	what keeps `paramsAt`'s own inversion well-defined and what keeps the
	ribbon from self-intersecting.
**/
class MobiusMath {
	/**
		A point on the ribbon at parameter `(u, v)`.
		@param u angle around the loop, in radians (not required to be wrapped into any particular range — the formula is smooth and well-defined for any real `u`).
		@param v across-width offset from the centerline.
		@param twists half-twists over one full lap around the loop.
		@param radius the loop's own centerline radius.
		@return the corresponding point on the ribbon.
	**/
	public static function pointAt(u:Float, v:Float, twists:Int, radius:Float):h3d.Vector {
		var theta = twists * u / 2;
		var r = radius + v * Math.cos(theta);
		return new h3d.Vector(r * Math.cos(u), v * Math.sin(theta), r * Math.sin(u));
	}

	/**
		The ribbon's own local orthonormal frame at `(u, v)`: `tu` (unit
		tangent along the loop's own length, i.e. increasing `u`), `tv`
		(unit tangent across the width, i.e. increasing `v` — already unit
		length and independent of `v` by construction, unlike `tu`), and
		`normal` (`tu` cross `tv`, the surface normal). These three are
		mutually perpendicular at *every* `(u, v)`, not just an
		approximation near `v = 0` — `Pu . Pv = 0` holds identically for
		this parametrization, verified symbolically. `tuLength` is `tu`'s
		own pre-normalization length (`|dP/du|`), needed by
		`biomes.common.space.mobius.MobiusSpace.moveAlong` to convert a
		world-distance step along `tu` into the matching change in `u`.
		@param u angle around the loop, in radians.
		@param v across-width offset from the centerline.
		@param twists half-twists over one full lap around the loop.
		@param radius the loop's own centerline radius.
		@return the local frame at `(u, v)`.
	**/
	public static function localFrameAt(u:Float, v:Float, twists:Int, radius:Float):{
		tu:h3d.Vector,
		tv:h3d.Vector,
		normal:h3d.Vector,
		tuLength:Float
	} {
		var theta = twists * u / 2;
		var k = twists / 2;
		var cosT = Math.cos(theta);
		var sinT = Math.sin(theta);
		var cosU = Math.cos(u);
		var sinU = Math.sin(u);
		var f = radius + v * cosT;
		var dfdu = -v * k * sinT;

		var pu = new h3d.Vector(dfdu * cosU - f * sinU, v * k * cosT, dfdu * sinU + f * cosU);
		var pv = new h3d.Vector(cosT * cosU, sinT, cosT * sinU);

		var tuLength = pu.length();
		var tu = pu.normalized();
		var normal = tu.cross(pv).normalized();
		return {
			tu: tu,
			tv: pv,
			normal: normal,
			tuLength: tuLength
		};
	}

	/**
		Inverse of `pointAt`: recovers `(u, v)` for a point already on the
		ribbon (e.g. `entities.player.PlayerModel.pos`, which stores a raw
		3D vector rather than `(u, v)` directly — see
		`biomes.common.space.mobius.MobiusSpace`'s own class doc for why
		this has to be re-derived fresh every call rather than cached).

		`u` comes straight off `atan2` (exact); `v` is recovered from
		whichever of `(r - radius) / cos(theta)` or `pos.y / sin(theta)` has
		the larger-magnitude denominator — `cos(theta)^2 + sin(theta)^2 ==
		1` guarantees at least one is `>= 1/sqrt(2)`, so this never divides
		by anything close to 0, including exactly at `cos(theta) == 0`.
		@param pos a point on the ribbon.
		@param twists half-twists over one full lap around the loop.
		@param radius the loop's own centerline radius.
		@return the `(u, v)` parameter pair for `pos`, `u` normalized to `[0, 2*PI)`.
	**/
	public static function paramsAt(pos:h3d.Vector, twists:Int, radius:Float):{u:Float, v:Float} {
		var u = Math.atan2(pos.z, pos.x);
		if (u < 0) {
			u += 2 * Math.PI;
		}
		var theta = twists * u / 2;
		var cosT = Math.cos(theta);
		var sinT = Math.sin(theta);
		var r = Math.sqrt(pos.x * pos.x + pos.z * pos.z);
		var v = Math.abs(cosT) >= Math.abs(sinT) ? (r - radius) / cosT : pos.y / sinT;
		return {u: u, v: v};
	}
}
