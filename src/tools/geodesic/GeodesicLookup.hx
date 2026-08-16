package tools.geodesic;

import tools.geodesic.GeodesicSphere.GeodesicSphereData;
import tools.geodesic.Vec3.Vec3Math;

/**
	Position → cell lookup: given any 3D point (any magnitude — it's
	normalized internally), finds the baked node nearest to it. Built
	against a baked `GeodesicSphereData` at load time, then answers queries
	in cost bounded by `Icosahedron.FACES.length` (`20`, fixed) — never by
	how many nodes the sphere has, however fine `frequency` is. This is the
	same three-step shape Uber's H3 uses on its own icosahedral grid:
	pick a candidate face, work out local coordinates on it, resolve those
	coordinates to a real cell.

	**Two things this class does differently from the plan in
	`docs/building/notes/geodesic-sphere-engineering.md`, both found
	while actually building it, not anticipated on paper:**

	1. That note describes picking the *single* nearest face by face-center
	   distance, then working only within it. That has a real correctness
	   gap — a query point near a seam between two faces can have its true
	   nearest node sitting in the *other* face's own subdivision grid, one
	   a single `nearestFace` step would never look at. Rather than track
	   explicit face-to-face edge adjacency to patch that, this class
	   checks all 20 faces' own candidate every query and keeps whichever
	   is actually closest in 3D.
	2. Rounding the gnomonic-projected barycentric weights to the single
	   nearest `(i, j)` grid index is *not* the same as finding the
	   nearest node by real 3D distance — barycentric space and the
	   sphere's own curved surface aren't linearly related once
	   `GeodesicSphere.barycentricPoint`'s own normalize step is applied,
	   so the naive rounding can land one grid step away from the actual
	   nearest node (caught by `GeodesicLookupTest`: two nodes' own shared
	   edge midpoint resolved to a *third*, objectively farther node,
	   because neither original endpoint was ever generated as any face's
	   rounded candidate for that query). Fixed by checking the rounded
	   point's own immediate 6-neighbor ring too (`CANDIDATE_OFFSETS`) —
	   still a fixed handful of checks per face, not a search that grows
	   with grid resolution.

	Both fixes keep the same complexity property: total cost is bounded by
	`Icosahedron.FACES.length` (`20`) times a small fixed constant (`7`
	grid points each) — `140` position lookups worst case, never `O(node
	count)`, however fine `frequency` is.
**/
class GeodesicLookup {
	final frequency:Int;
	final idByWeldKey:haxe.ds.StringMap<Int>;

	/** A gnomonic projection's own denominator too close to zero to trust — the query point is edge-on to that face's plane, so that face contributes no candidate this query. **/
	static inline final DEGENERATE_PROJECTION_EPSILON:Float = 1e-9;

	/** The rounded grid point itself, plus its 6 triangular-lattice neighbors (the same six offsets `GeodesicSphere.generate`'s own triangulation connects) — see this class's own doc, point 2, for why checking only the rounded point isn't enough. **/
	static final CANDIDATE_OFFSETS:Array<{di:Int, dj:Int}> = [
		{di: 0, dj: 0},
		{di: 1, dj: 0},
		{di: -1, dj: 0},
		{di: 0, dj: 1},
		{di: 0, dj: -1},
		{di: 1, dj: -1},
		{di: -1, dj: 1},
	];

	public function new(sphere:GeodesicSphereData, frequency:Int) {
		this.frequency = frequency;
		idByWeldKey = new haxe.ds.StringMap();
		for (id in 0...sphere.positions.length) {
			idByWeldKey.set(GeodesicSphere.weldKey(sphere.positions[id]), id);
		}
	}

	/**
		@param query any point whose direction from the sphere's own center is what matters — magnitude is ignored (normalized internally), so a world-space position at any radius works directly.
		@return the id of the baked node nearest `query`.
	**/
	public function nodeAt(query:Vec3):Int {
		var q = Vec3Math.normalized(query);
		var bestId = -1;
		var bestDistSq = Math.POSITIVE_INFINITY;

		for (face in Icosahedron.FACES) {
			var a = Icosahedron.VERTICES[face.a];
			var b = Icosahedron.VERTICES[face.b];
			var c = Icosahedron.VERTICES[face.c];

			var bary = gnomonicBarycentric(q, a, b, c);
			if (bary == null) {
				continue;
			}
			var grid = nearestGridPoint(bary, frequency);

			for (offset in CANDIDATE_OFFSETS) {
				var i = grid.i + offset.di;
				var j = grid.j + offset.dj;
				if (i < 0 || j < 0 || i + j > frequency) {
					continue;
				}
				var point = GeodesicSphere.barycentricPoint(a, b, c, i, j, frequency);
				var id = idByWeldKey.get(GeodesicSphere.weldKey(point));
				if (id == null) {
					continue; // shouldn't happen against a sound bake, but never crash a movement-frame query over it
				}

				var distSq = Vec3Math.distanceSquared(point, q);
				if (distSq < bestDistSq) {
					bestDistSq = distSq;
					bestId = id;
				}
			}
		}

		if (bestId == -1) {
			throw "GeodesicLookup.nodeAt found no candidate face — every face's own projection was degenerate, which should be geometrically impossible for a well-formed query";
		}
		return bestId;
	}

	/**
		Gnomonic projection: the point where the ray from the sphere's own
		center through `q` crosses the plane through `a`, `b`, `c`, expressed
		as that plane's own barycentric weights (`u + v + w = 1`) — the
		inverse of `GeodesicSphere.barycentricPoint`'s own blend-then-normalize.
		`null` if `q` is edge-on to this face's plane (see
		`DEGENERATE_PROJECTION_EPSILON`).
	**/
	static function gnomonicBarycentric(q:Vec3, a:Vec3, b:Vec3, c:Vec3):Null<{u:Float, v:Float, w:Float}> {
		var normal = Vec3Math.cross(Vec3Math.subtract(b, a), Vec3Math.subtract(c, a));
		var denom = Vec3Math.dot(normal, q);
		if (Math.abs(denom) < DEGENERATE_PROJECTION_EPSILON) {
			return null;
		}
		var t = Vec3Math.dot(normal, a) / denom;
		var projected = Vec3Math.scaled(q, t);
		return cartesianToBarycentric(projected, a, b, c);
	}

	/** Standard 3D barycentric-coordinate solve for a point already known to lie in the plane of `a`, `b`, `c`. **/
	static function cartesianToBarycentric(p:Vec3, a:Vec3, b:Vec3, c:Vec3):{u:Float, v:Float, w:Float} {
		var v0 = Vec3Math.subtract(b, a);
		var v1 = Vec3Math.subtract(c, a);
		var v2 = Vec3Math.subtract(p, a);
		var d00 = Vec3Math.dot(v0, v0);
		var d01 = Vec3Math.dot(v0, v1);
		var d11 = Vec3Math.dot(v1, v1);
		var d20 = Vec3Math.dot(v2, v0);
		var d21 = Vec3Math.dot(v2, v1);
		var denom = d00 * d11 - d01 * d01;
		var v = (d11 * d20 - d01 * d21) / denom;
		var w = (d00 * d21 - d01 * d20) / denom;
		var u = 1 - v - w;
		return {u: u, v: v, w: w};
	}

	/**
		The `(i, j)` grid point closest to `bary`'s own weights, clamped into
		the valid `i >= 0, j >= 0, i + j <= frequency` triangle — the face
		boundary tie-break: a query that projects slightly outside this
		face's own triangle (negative `u`, `v`, or `w` — it actually belongs
		to a neighboring face) still resolves to *this* face's own nearest
		edge grid point rather than an invalid index, so it always produces
		a real candidate for `nodeAt` to compare against the other 19 faces'
		own candidates, never a crash.
	**/
	static function nearestGridPoint(bary:{u:Float, v:Float, w:Float}, frequency:Int):{i:Int, j:Int} {
		var i = Math.round(bary.v * frequency);
		var j = Math.round(bary.w * frequency);
		if (i < 0) {
			i = 0;
		}
		if (j < 0) {
			j = 0;
		}
		if (i > frequency) {
			i = frequency;
		}
		if (j > frequency) {
			j = frequency;
		}
		if (i + j > frequency) {
			var excess = i + j - frequency;
			var half = Std.int(excess / 2);
			i -= half;
			j -= excess - half;
			// Belt and suspenders: the algebra above should never drive either negative given both started in [0, frequency], but this is a per-frame query on player movement — worth the two cheap comparisons rather than trusting it silently.
			if (i < 0) {
				i = 0;
			}
			if (j < 0) {
				j = 0;
			}
		}
		return {i: i, j: j};
	}
}
