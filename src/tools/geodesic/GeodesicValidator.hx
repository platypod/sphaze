package tools.geodesic;

import tools.geodesic.GeodesicSphere.GeodesicSphereData;

/**
	The concrete checks a generated `GeodesicSphereData` has to pass before
	it's trusted enough to bake — see
	`docs/building/notes/geodesic-sphere-engineering.md`'s own Phase 1
	"exit check" for why these specific things. A broader cell-uniformity
	score (area/edge-length variance) is still an open follow-up, not
	implemented here — this only checks the invariants that were already
	promised: the node-count formula, and the 12 pentagons.
**/
class GeodesicValidator {
	/**
		@param sphere the instance to check.
		@param frequency the frequency it was generated at — the expected node count is a closed-form function of this alone.
		@return every problem found, empty if the instance is sound.
	**/
	public static function validate(sphere:GeodesicSphereData, frequency:Int):Array<String> {
		var problems:Array<String> = [];

		var expectedNodes = 10 * frequency * frequency + 2;
		if (sphere.neighbors.length != expectedNodes) {
			problems.push('expected $expectedNodes nodes at frequency $frequency, got ${sphere.neighbors.length}');
		}
		if (sphere.positions.length != sphere.neighbors.length) {
			problems.push('positions (${sphere.positions.length}) and neighbors (${sphere.neighbors.length}) length mismatch');
		}

		var pentagons = GeodesicSphere.pentagons(sphere);
		if (pentagons.length != 12) {
			problems.push('expected exactly 12 pentagons, got ${pentagons.length}');
		}
		for (problem in adjacentPentagonProblems(sphere, pentagons)) {
			problems.push(problem);
		}

		for (id in 0...sphere.neighbors.length) {
			var degree = sphere.neighbors[id].length;
			if (degree != 5 && degree != 6) {
				problems.push('node $id has degree $degree — every node should be a pentagon (5) or hexagon (6)');
			}
		}

		if (!isConnected(sphere)) {
			problems.push("sphere is not fully connected");
		}

		return problems;
	}

	static function adjacentPentagonProblems(sphere:GeodesicSphereData, pentagons:Array<Int>):Array<String> {
		var pentagonSet = new haxe.ds.IntMap<Bool>();
		for (id in pentagons) {
			pentagonSet.set(id, true);
		}
		var problems:Array<String> = [];
		for (id in pentagons) {
			for (neighbor in sphere.neighbors[id]) {
				if (pentagonSet.exists(neighbor)) {
					problems.push('pentagon $id is adjacent to pentagon $neighbor — they should never touch');
				}
			}
		}
		return problems;
	}

	static function isConnected(sphere:GeodesicSphereData):Bool {
		if (sphere.neighbors.length == 0) {
			return false;
		}
		var visited = new haxe.ds.IntMap<Bool>();
		visited.set(0, true);
		var stack = [0];
		var count = 1;
		while (stack.length > 0) {
			var current = stack.pop();
			if (current == null) {
				continue;
			}
			for (neighbor in sphere.neighbors[current]) {
				if (!visited.exists(neighbor)) {
					visited.set(neighbor, true);
					count++;
					stack.push(neighbor);
				}
			}
		}
		return count == sphere.neighbors.length;
	}
}
