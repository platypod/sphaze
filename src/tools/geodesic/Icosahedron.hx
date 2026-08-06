package tools.geodesic;

import tools.geodesic.Vec3.Vec3Math;

/**
	The regular icosahedron's own 12 vertices and 20 triangular faces — the
	fixed starting shape every geodesic sphere in this package subdivides
	from. Vertex positions follow the standard "three golden rectangles"
	construction; the face list is the well-known winding that goes with
	that vertex order. `IcosahedronTest` checks this is actually a sound
	icosahedron (every vertex touches exactly 5 faces) rather than trusting
	the hand-transcribed indices on faith.
**/
class Icosahedron {
	static inline final GOLDEN_RATIO:Float = 1.618033988749895;

	/** The 12 vertices, unit-length (normalized onto the sphere). **/
	public static final VERTICES:Array<Vec3> = buildVertices();

	/** The 20 triangular faces, each three indices into `VERTICES`. **/
	public static final FACES:Array<{a:Int, b:Int, c:Int}> = [
		{a: 0, b: 11, c: 5},  {a: 0, b: 5, c: 1},   {a: 0, b: 1, c: 7}, {a: 0, b: 7, c: 10}, {a: 0, b: 10, c: 11},
		 {a: 1, b: 5, c: 9}, {a: 5, b: 11, c: 4}, {a: 11, b: 10, c: 2}, {a: 10, b: 7, c: 6},   {a: 7, b: 1, c: 8},
		 {a: 3, b: 9, c: 4},  {a: 3, b: 4, c: 2},   {a: 3, b: 2, c: 6},  {a: 3, b: 6, c: 8},   {a: 3, b: 8, c: 9},
		 {a: 4, b: 9, c: 5}, {a: 2, b: 4, c: 11},  {a: 6, b: 2, c: 10},  {a: 8, b: 6, c: 7},   {a: 9, b: 8, c: 1},
	];

	static function buildVertices():Array<Vec3> {
		var t = GOLDEN_RATIO;
		var raw = [
			Vec3Math.make(-1, t, 0), Vec3Math.make(1, t, 0), Vec3Math.make(-1, -t, 0), Vec3Math.make(1, -t, 0),
			Vec3Math.make(0, -1, t), Vec3Math.make(0, 1, t), Vec3Math.make(0, -1, -t), Vec3Math.make(0, 1, -t),
			Vec3Math.make(t, 0, -1), Vec3Math.make(t, 0, 1), Vec3Math.make(-t, 0, -1), Vec3Math.make(-t, 0, 1),
		];
		return [for (v in raw) Vec3Math.normalized(v)];
	}
}
