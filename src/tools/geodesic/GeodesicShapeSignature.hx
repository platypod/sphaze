package tools.geodesic;

import tools.geodesic.GeodesicSphere.GeodesicSphereData;
import tools.geodesic.Vec3.Vec3Math;

/**
	Coordinate-free "what shape is this set of live cells, and where is it"
	utilities — factored out of `GeodesicGliderSearch` once
	`GeodesicConwayBiome`'s own glider tracking (following a spawned glider
	generation to generation so it can be drawn in its own color) needed
	the exact same signature/BFS logic a second time, rather than a
	one-off private to the search tool.

	The core idea, used by both callers: a live-cell set's own shape is the
	sorted multiset of pairwise graph-BFS distances between its members —
	invariant under any isometry of the mesh (translation across the hex
	lattice, rotation, reflection), so two generations sharing a signature
	are the same shape wherever they actually sit. See
	`GeodesicGliderSearch`'s own class doc for the full reasoning (no
	`(theta, phi)` coordinates exist here to compare positions directly).
**/
class GeodesicShapeSignature {
	/** The live set's own shape signature — see this class's own doc. **/
	public static function of(sphere:GeodesicSphereData, alive:Array<Int>):String {
		var pairwise:Array<Int> = [];
		for (i in 0...alive.length) {
			var distances = bfsDistances(sphere, alive[i], alive);
			for (j in i + 1...alive.length) {
				pairwise.push(distances.get(alive[j]));
			}
		}
		pairwise.sort((a, b) -> a - b);
		return '${alive.length}|${pairwise.join(",")}';
	}

	/** BFS out from `source`, stopping as soon as every other id in `targets` has been reached — cheap as long as the queried set stays compact. **/
	public static function bfsDistances(sphere:GeodesicSphereData, source:Int, targets:Array<Int>):Map<Int, Int> {
		var distances = new Map<Int, Int>();
		distances.set(source, 0);
		var queue = [source];
		var remaining = 0;
		for (target in targets) {
			if (target != source) {
				remaining++;
			}
		}
		var head = 0;
		while (head < queue.length && remaining > 0) {
			var current = queue[head++];
			var d = distances.get(current);
			for (neighbor in sphere.neighbors[current]) {
				if (!distances.exists(neighbor)) {
					distances.set(neighbor, d + 1);
					queue.push(neighbor);
					if (targets.indexOf(neighbor) != -1) {
						remaining--;
					}
				}
			}
		}
		return distances;
	}

	/** Every node's own BFS distance to its nearest `sources` entry — one flood fill from all sources at once, rather than one BFS per node. **/
	public static function multiSourceBfs(sphere:GeodesicSphereData, sources:Array<Int>):Map<Int, Int> {
		var distances = new Map<Int, Int>();
		var queue = [];
		for (source in sources) {
			distances.set(source, 0);
			queue.push(source);
		}
		var head = 0;
		while (head < queue.length) {
			var current = queue[head++];
			var d = distances.get(current);
			for (neighbor in sphere.neighbors[current]) {
				if (!distances.exists(neighbor)) {
					distances.set(neighbor, d + 1);
					queue.push(neighbor);
				}
			}
		}
		return distances;
	}

	public static function aliveNodes(state:GeodesicLifeState, sphere:GeodesicSphereData):Array<Int> {
		var alive = [];
		for (id in 0...sphere.neighbors.length) {
			if (state.isAlive(id)) {
				alive.push(id);
			}
		}
		return alive;
	}

	public static function sameNodes(a:Array<Int>, b:Array<Int>):Bool {
		if (a.length != b.length) {
			return false;
		}
		var sortedA = a.copy();
		var sortedB = b.copy();
		sortedA.sort((x, y) -> x - y);
		sortedB.sort((x, y) -> x - y);
		for (i in 0...sortedA.length) {
			if (sortedA[i] != sortedB[i]) {
				return false;
			}
		}
		return true;
	}

	public static function centroid(sphere:GeodesicSphereData, ids:Array<Int>):Vec3 {
		var sum = Vec3Math.make(0, 0, 0);
		for (id in ids) {
			sum = Vec3Math.add(sum, sphere.positions[id]);
		}
		return Vec3Math.scaled(sum, 1 / ids.length);
	}

	public static function centroidDistance(sphere:GeodesicSphereData, a:Array<Int>, b:Array<Int>):Float {
		return Vec3Math.length(Vec3Math.subtract(centroid(sphere, a), centroid(sphere, b)));
	}
}
