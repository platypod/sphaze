package tools.geodesic;

/**
	A plain 3D point/vector — deliberately not `h3d.Vector`: this package is
	pure geometry generation with no Heaps/rendering dependency, so its own
	bake tool (`GeodesicBake`) can run on a lightweight native target (file
	I/O needs `sys.io.File`, which this project's usual `-js` target doesn't
	have) without pulling the game engine in along with it. Converting to
	`h3d.Vector` is the consuming (rendering) side's own job, later.
**/
typedef Vec3 = {
	var x:Float;
	var y:Float;
	var z:Float;
}

class Vec3Math {
	public static function make(x:Float, y:Float, z:Float):Vec3 {
		return {x: x, y: y, z: z};
	}

	public static function add(a:Vec3, b:Vec3):Vec3 {
		return {x: a.x + b.x, y: a.y + b.y, z: a.z + b.z};
	}

	public static function subtract(a:Vec3, b:Vec3):Vec3 {
		return {x: a.x - b.x, y: a.y - b.y, z: a.z - b.z};
	}

	public static function scaled(v:Vec3, factor:Float):Vec3 {
		return {x: v.x * factor, y: v.y * factor, z: v.z * factor};
	}

	public static function dot(a:Vec3, b:Vec3):Float {
		return a.x * b.x + a.y * b.y + a.z * b.z;
	}

	public static function cross(a:Vec3, b:Vec3):Vec3 {
		return {x: a.y * b.z - a.z * b.y, y: a.z * b.x - a.x * b.z, z: a.x * b.y - a.y * b.x};
	}

	public static function length(v:Vec3):Float {
		return Math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
	}

	public static function distanceSquared(a:Vec3, b:Vec3):Float {
		var dx = a.x - b.x;
		var dy = a.y - b.y;
		var dz = a.z - b.z;
		return dx * dx + dy * dy + dz * dz;
	}

	/** `v` scaled to unit length — `v` itself (not a zero vector) if it's already zero-length, since there's no direction to normalize a zero vector to. **/
	public static function normalized(v:Vec3):Vec3 {
		var len = length(v);
		return len > 0 ? scaled(v, 1 / len) : v;
	}
}
