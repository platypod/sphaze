package tools.geodesic;

import tools.geodesic.Vec3.Vec3Math;

typedef GeodesicSphereData = {
	var positions:Array<Vec3>;
	var neighbors:Array<Array<Int>>;
}

/**
	Subdivides `Icosahedron`'s 20 faces into a triangulated sphere at
	`frequency` steps per edge, welds the vertices shared between adjacent
	faces, and returns the result as plain node positions plus an adjacency
	list — the *geodesic* icosahedron (triangular faces), not yet its
	Goldberg dual.

	Deliberately stops at the triangulated mesh rather than also building
	the dual's hexagon/pentagon polygons: for cell *adjacency* (what
	`GeodesicTopology`, and eventually `biomes.conway`'s own replacement
	grid, actually need), the dual polyhedron's face-adjacency graph is
	identical to this mesh's own vertex-adjacency graph — two dual faces
	(cells) share an edge exactly when their corresponding original
	vertices are connected by a mesh edge. Building the actual
	hexagon/pentagon boundary polygons (for rendering) needs each vertex's
	surrounding triangles in cyclic order, which is a separate, later
	problem this class doesn't need to solve to answer "who's next to whom."

	Every vertex this construction *introduces* during subdivision ends up
	with exactly 6 neighbors; only the 12 original `Icosahedron.VERTICES`
	keep their original 5 — the well-known reason a "Class I" geodesic
	subdivision always produces exactly 12 pentagons in its dual,
	independent of `frequency`. `GeodesicSphereTest` checks this
	algebraically (`10 * frequency² + 2` total nodes) rather than taking it
	on faith.
**/
class GeodesicSphere {
	/**
		@param frequency subdivision steps per icosahedron edge — `1` is the bare icosahedron (12 nodes, all pentagons); density grows as `10 * frequency² + 2` total nodes.
		@return the welded node positions and their adjacency list.
	**/
	public static function generate(frequency:Int):GeodesicSphereData {
		if (frequency < 1) {
			throw 'frequency must be at least 1, got $frequency';
		}

		var positions:Array<Vec3> = [];
		var neighbors:Array<Array<Int>> = [];
		var idOf = new haxe.ds.StringMap<Int>();

		function weldedId(p:Vec3):Int {
			var key = weldKey(p);
			var existing = idOf.get(key);
			if (existing != null) {
				return existing;
			}
			var id = positions.length;
			positions.push(p);
			neighbors.push([]);
			idOf.set(key, id);
			return id;
		}

		function addEdge(a:Int, b:Int):Void {
			if (neighbors[a].indexOf(b) == -1) {
				neighbors[a].push(b);
			}
			if (neighbors[b].indexOf(a) == -1) {
				neighbors[b].push(a);
			}
		}

		for (face in Icosahedron.FACES) {
			var a = Icosahedron.VERTICES[face.a];
			var b = Icosahedron.VERTICES[face.b];
			var c = Icosahedron.VERTICES[face.c];

			// ids[i][j], i + j <= frequency: this face's own barycentric subdivision grid, welded into the global node set as each point is visited.
			var ids:Array<Array<Int>> = [];
			for (i in 0...frequency + 1) {
				var row:Array<Int> = [];
				for (j in 0...frequency - i + 1) {
					row.push(weldedId(barycentricPoint(a, b, c, i, j, frequency)));
				}
				ids.push(row);
			}

			// Two triangles per (i, j) grid cell ("upward" always, "downward" wherever there's room) — standard triangulation of a triangular barycentric grid.
			for (i in 0...frequency) {
				for (j in 0...frequency - i) {
					addEdge(ids[i][j], ids[i + 1][j]);
					addEdge(ids[i + 1][j], ids[i][j + 1]);
					addEdge(ids[i][j + 1], ids[i][j]);
					if (j < frequency - i - 1) {
						addEdge(ids[i + 1][j], ids[i + 1][j + 1]);
						addEdge(ids[i + 1][j + 1], ids[i][j + 1]);
						addEdge(ids[i][j + 1], ids[i + 1][j]);
					}
				}
			}
		}

		return {positions: positions, neighbors: neighbors};
	}

	/**
		Parses the JSON `GeodesicBake` writes back into a `GeodesicSphereData`
		plus the frequency it was baked at (`GeodesicLookup`'s own second
		constructor argument, not part of `GeodesicSphereData` itself). The
		runtime counterpart to `generate` — a `GeodesicConwayBiome` loads the
		checked-in asset through this rather than calling `generate` again,
		per the "generate → score → bake, not lazy-on-boot" requirement this
		package was built against.
		@param json a `GeodesicBake`-produced JSON string.
		@return the sphere it describes, plus its own baked frequency.
	**/
	public static function fromJson(json:String):{sphere:GeodesicSphereData, frequency:Int} {
		var parsed:{frequency:Int, positions:Array<{x:Float, y:Float, z:Float}>, neighbors:Array<Array<Int>>} = haxe.Json.parse(json);
		return {
			sphere: {
				positions: [for (p in parsed.positions) Vec3Math.make(p.x, p.y, p.z)],
				neighbors: parsed.neighbors
			},
			frequency: parsed.frequency
		};
	}

	/** Every node whose degree is `5` rather than `6` — the 12 original `Icosahedron.VERTICES`, unchanged by subdivision (see this class's own doc). **/
	public static function pentagons(sphere:GeodesicSphereData):Array<Int> {
		var result:Array<Int> = [];
		for (id in 0...sphere.neighbors.length) {
			if (sphere.neighbors[id].length == 5) {
				result.push(id);
			}
		}
		return result;
	}

	/** Public — `GeodesicLookup` reuses this exact formula to recompute a candidate grid point's position at query time, rather than baking a separate per-face lookup table. **/
	public static function barycentricPoint(a:Vec3, b:Vec3, c:Vec3, i:Int, j:Int, frequency:Int):Vec3 {
		var u = i / frequency;
		var v = j / frequency;
		var w = 1 - u - v;
		var blended = Vec3Math.add(Vec3Math.add(Vec3Math.scaled(a, w), Vec3Math.scaled(b, u)), Vec3Math.scaled(c, v));
		return Vec3Math.normalized(blended);
	}

	/**
		Rounds a position to 6 decimal places and keys on that — two faces
		subdividing the same shared edge compute the exact same barycentric
		point (same input vertices, same exact `i / frequency` fraction), so
		this reliably welds them into one node without needing to track
		which faces are adjacent to which, or in what orientation, explicitly.

		Public — `GeodesicLookup` reuses it to turn a recomputed candidate
		position back into a baked node id.
	**/
	public static function weldKey(p:Vec3):String {
		function rounded(x:Float):Int {
			return Math.round(x * 1e6);
		}
		return '${rounded(p.x)}:${rounded(p.y)}:${rounded(p.z)}';
	}
}
