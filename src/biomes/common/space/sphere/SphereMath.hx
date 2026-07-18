package biomes.common.space.sphere;

/**
	Sphere geometry helpers: local "up" on the interior surface, tangent
	vectors along the lat/long grid, and axis rotation. Ported from the
	Babylon.js prototype (old/src/scene/sphereMath.ts) — pure math, engine-
	agnostic, so the algorithms carried over unchanged. h3d.Vector's
	add/sub/scaled/normalized/cross/dot all return new vectors rather than
	mutating, matching the semantics the original code relied on.
**/
class SphereMath {
	/**
		Local "up" for a point standing on the sphere's interior surface: the
		direction from that point back toward the sphere's center.
		@param pointOnSphere the point on the sphere's surface.
		@param sphereCenter the sphere's center.
		@return unit vector pointing from `pointOnSphere` toward `sphereCenter`.
	**/
	public static function upVectorAt(pointOnSphere:h3d.Vector, sphereCenter:h3d.Vector):h3d.Vector {
		return sphereCenter.sub(pointOnSphere).normalized();
	}

	/**
		Rotates `vector` by `angle` radians around `axis` (Rodrigues' rotation
		formula). `axis` must be a unit vector.
		@param vector the vector to rotate.
		@param axis unit vector to rotate around.
		@param angle rotation angle, in radians.
		@return `vector` rotated by `angle` around `axis`.
	**/
	public static function rotateAroundAxis(vector:h3d.Vector, axis:h3d.Vector, angle:Float):h3d.Vector {
		var cos = Math.cos(angle);
		var sin = Math.sin(angle);
		var cross = axis.cross(vector);
		var dot = axis.dot(vector);
		return vector.scaled(cos).add(cross.scaled(sin)).add(axis.scaled(dot * (1 - cos)));
	}

	/**
		Converts spherical coordinates — theta: polar angle from +Y, 0 at the
		north pole, pi at the south pole; phi: azimuth around Y — to a
		Cartesian point on a sphere of the given radius centered at the world
		origin. Lays the maze grid out on the sphere's surface.
		@param radius sphere radius.
		@param theta polar angle from +Y, in radians (0 = north pole, pi = south pole).
		@param phi azimuth around Y, in radians.
		@return the corresponding Cartesian point.
	**/
	public static function sphericalToCartesian(radius:Float, theta:Float, phi:Float):h3d.Vector {
		return new h3d.Vector(radius * Math.sin(theta) * Math.cos(phi), radius * Math.cos(theta), radius * Math.sin(theta) * Math.sin(phi));
	}

	/**
		Unit tangent in the direction of increasing theta at a given spherical
		position — independent of radius.
		@param theta polar angle from +Y, in radians.
		@param phi azimuth around Y, in radians.
		@return unit tangent vector.
	**/
	public static function thetaTangentAt(theta:Float, phi:Float):h3d.Vector {
		return new h3d.Vector(Math.cos(theta) * Math.cos(phi), -Math.sin(theta), Math.cos(theta) * Math.sin(phi));
	}

	/**
		Unit tangent in the direction of increasing phi (independent of theta
		and radius).
		@param phi azimuth around Y, in radians.
		@return unit tangent vector.
	**/
	public static function phiTangentAt(phi:Float):h3d.Vector {
		return new h3d.Vector(-Math.sin(phi), 0, Math.cos(phi));
	}

	/**
		Inverse of `sphericalToCartesian`'s theta: the polar angle from +Y of
		a point relative to the world origin, independent of the point's
		distance from it (so it works for points not exactly on the maze's
		sphere, e.g. a tentative position mid-collision-check).
		@param point the point to find theta of.
		@return polar angle from +Y, in radians (0 = north pole, pi = south pole).
	**/
	public static function thetaOf(point:h3d.Vector):Float {
		return Math.acos(hxd.Math.clamp(point.y / point.length(), -1, 1));
	}

	/**
		Inverse of `sphericalToCartesian`'s phi: the azimuth around Y of a
		point relative to the world origin, normalized to [0, 2*pi) to match
		the range `Maze.nodeAt` expects.
		@param point the point to find phi of.
		@return azimuth around Y, in radians, in [0, 2*pi).
	**/
	public static function phiOf(point:h3d.Vector):Float {
		var phi = Math.atan2(point.z, point.x);
		return phi < 0 ? phi + 2 * Math.PI : phi;
	}
}
