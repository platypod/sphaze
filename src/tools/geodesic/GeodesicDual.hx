package tools.geodesic;

import tools.geodesic.GeodesicSphere.GeodesicSphereData;
import tools.geodesic.Vec3.Vec3Math;

/**
	The Goldberg dual's own hexagon/pentagon boundary polygons —
	deliberately not computed in `GeodesicSphere` itself (see that class's
	own doc: cell *adjacency* never needed this, only rendering does, and
	rendering is a separate, later concern). One polygon per node: the
	circumcenters of the triangles surrounding it, in cyclic order, each
	one vertex of that cell's own hexagon (or pentagon, for the 12 nodes
	`GeodesicSphere.pentagons` reports) — see `cellBoundary`'s own doc for
	why circumcenter, not the simpler centroid.
**/
class GeodesicDual {
	/**
		Every node's own boundary polygon, indexed the same way `sphere`'s
		own `positions`/`neighbors` are.
		@param sphere the sphere to compute boundaries for.
		@return one polygon (5 or 6 points, unit-sphere) per node.
	**/
	public static function cellBoundaries(sphere:GeodesicSphereData):Array<Array<Vec3>> {
		return [for (id in 0...sphere.neighbors.length) cellBoundary(sphere, id)];
	}

	/**
		`nodeId`'s own boundary: for each consecutive pair of neighbors in
		cyclic order (`cyclicNeighbors`), the *circumcenter* of the triangle
		`(nodeId, neighborK, neighborK+1)`, normalized onto the sphere — the
		actual corner of the hexagon/pentagon at that point.

		Circumcenter, not the simpler centroid (triangle-vertex average) —
		found necessary while building `GeodesicDualTest`: the centroid is
		only equidistant from a triangle's own three vertices when that
		triangle happens to be equilateral, which the ones bordering a
		pentagon (5-neighbor node) generally aren't. A centroid-based
		boundary point could end up measurably closer to a *neighboring*
		cell's own center than to the cell it was supposed to be a corner
		of — worst exactly around the 12 pentagons, which matter most here.
		The circumcenter is equidistant from all three triangle vertices by
		definition, so this can't happen for the two neighbors that
		actually form each corner.
	**/
	public static function cellBoundary(sphere:GeodesicSphereData, nodeId:Int):Array<Vec3> {
		var ring = cyclicNeighbors(sphere, nodeId);
		var v = sphere.positions[nodeId];
		var boundary:Array<Vec3> = [];
		for (k in 0...ring.length) {
			var n1 = sphere.positions[ring[k]];
			var n2 = sphere.positions[ring[(k + 1) % ring.length]];
			boundary.push(Vec3Math.normalized(circumcenter(v, n1, n2)));
		}
		return boundary;
	}

	/**
		The triangle `(a, b, c)`'s own circumcenter, in 3D — the point in
		the triangle's own plane equidistant from all three vertices. Falls
		back to the plain centroid for a degenerate (near-collinear)
		triangle, where a circumcenter isn't well-defined (the denominator
		below goes to zero) — shouldn't occur for any real triangle this
		package's own subdivision produces, but a graceful fallback beats a
		division by zero.
	**/
	static function circumcenter(a:Vec3, b:Vec3, c:Vec3):Vec3 {
		var ab = Vec3Math.subtract(b, a);
		var ac = Vec3Math.subtract(c, a);
		var abXac = Vec3Math.cross(ab, ac);
		var abXacLenSq = Vec3Math.dot(abXac, abXac);
		if (abXacLenSq < 1e-18) {
			return Vec3Math.scaled(Vec3Math.add(Vec3Math.add(a, b), c), 1 / 3);
		}

		var term1 = Vec3Math.scaled(Vec3Math.cross(abXac, ab), Vec3Math.dot(ac, ac));
		var term2 = Vec3Math.scaled(Vec3Math.cross(ac, abXac), Vec3Math.dot(ab, ab));
		var toCircumcenter = Vec3Math.scaled(Vec3Math.add(term1, term2), 1 / (2 * abXacLenSq));
		return Vec3Math.add(a, toCircumcenter);
	}

	/**
		The two boundary points shared between `nodeId`'s own cell and its
		neighbor `neighborId`'s — the actual wall segment for that maze
		edge, rather than an approximation.

		`cellBoundary`'s own `boundary[k]` is the circumcenter of the
		triangle `(nodeId, ring[k], ring[k+1])`, which is shared by three
		cells: `nodeId`, `ring[k]`, and `ring[k+1]`. So the polygon edge
		between `boundary[k-1]` and `boundary[k]` is shared by exactly
		`nodeId` and `ring[k]` — the two boundary vertices flanking
		`neighborId` in the ring. Verified independent of which endpoint
		asks: querying from `neighborId`'s own side returns the same two
		points (in either order) — see `GeodesicDualTest`'s own check.
		@param sphere the sphere `nodeId`/`neighborId` belong to.
		@param boundaries every node's own boundary, as returned by `cellBoundaries` — passed in rather than recomputed, since a mesh builder calling this once per edge already has it.
		@param nodeId one endpoint of the maze edge.
		@param neighborId the other endpoint — must be one of `nodeId`'s own neighbors.
		@return the two points bounding the shared wall segment.
	**/
	public static function sharedEdge(sphere:GeodesicSphereData, boundaries:Array<Array<Vec3>>, nodeId:Int, neighborId:Int):{a:Vec3, b:Vec3} {
		var ring = cyclicNeighbors(sphere, nodeId);
		var k = ring.indexOf(neighborId);
		if (k == -1) {
			throw 'sharedEdge: $neighborId is not one of node $nodeId\'s own neighbors';
		}
		var boundary = boundaries[nodeId];
		var previous = (k - 1 + ring.length) % ring.length;
		return {a: boundary[previous], b: boundary[k]};
	}

	/**
		`nodeId`'s own neighbors, walked in the order they actually ring
		around it — `sphere.neighbors[nodeId]` itself carries no such
		guarantee (just insertion order from `GeodesicSphere.generate`'s own
		triangulation loop). Starting from an arbitrary neighbor, each next
		step is "whichever of `current`'s own neighbors is also one of
		`nodeId`'s neighbors, and isn't the one just visited" — for a sound
		triangulated 2-manifold (every edge borders exactly two triangles),
		exactly one such node exists at each step, so this always terminates
		having visited every neighbor exactly once.
	**/
	public static function cyclicNeighbors(sphere:GeodesicSphereData, nodeId:Int):Array<Int> {
		var neighbors = sphere.neighbors[nodeId];
		if (neighbors.length == 0) {
			return [];
		}

		var neighborSet = new haxe.ds.IntMap<Bool>();
		for (n in neighbors) {
			neighborSet.set(n, true);
		}

		var ordered = [neighbors[0]];
		var previous = -1;
		var current = neighbors[0];
		while (ordered.length < neighbors.length) {
			var next = -1;
			for (candidate in sphere.neighbors[current]) {
				if (candidate == previous || candidate == nodeId || !neighborSet.exists(candidate)) {
					continue;
				}
				next = candidate;
				break;
			}
			if (next == -1) {
				throw 'cyclicNeighbors could not complete the ring around node $nodeId — not a sound triangulated 2-manifold there';
			}
			ordered.push(next);
			previous = current;
			current = next;
		}
		return ordered;
	}
}
