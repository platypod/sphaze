package biomes.common.space.common;

import biomes.common.space.sphere.SphereMath;

/**
	`Space.turn`/`Space.rightOf` for every space whose model coordinates
	*are* ambient ℝ³ — the sphere inside and out, the plane, the Möbius
	strip. All four behave identically here, and this exists so that they
	agree **by construction** rather than by four copies of the same two
	lines happening to stay in step.

	These are exactly the expressions `entities.player.PlayerModel` carried
	inline before turning became the space's own business (see `Space.turn`
	for why it had to), moved rather than rewritten — so the four spaces
	that used them are provably unchanged by that move, and only
	`hyperbolic.HyperbolicSpace`, whose coordinates are not ambient ℝ³ at
	all, does anything different.
**/
class AmbientFrame {
	/**
		Rotation about the local "up" axis — see `Space.turn`.
		@param forward the current unit tangent.
		@param up the axis to turn about.
		@param angle rotation in radians; positive turns right.
		@return the rotated tangent.
	**/
	public static function turn(forward:h3d.Vector, up:h3d.Vector, angle:Float):h3d.Vector {
		return SphereMath.rotateAroundAxis(forward, up, angle);
	}

	/**
		The ordinary right-handed `forward × up` — see `Space.rightOf`,
		including why its *screen* sense is the opposite of its name.
		@param forward the current unit tangent.
		@param up the local "up".
		@return the unit tangent perpendicular to both.
	**/
	public static function rightOf(forward:h3d.Vector, up:h3d.Vector):h3d.Vector {
		return forward.cross(up).normalized();
	}
}
