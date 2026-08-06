package tools.geodesic;

import tools.geodesic.GeodesicSphere.GeodesicSphereData;
import tools.geodesic.Vec3.Vec3Math;

/**
	Seed-pattern placement, split out from `GeodesicGliderSearch` so this
	part (pure combinatorics/BFS, no I/O) can be `import`ed by
	`GeodesicGliderTracker` without dragging that class's `Sys.println`-based
	`main()` along — `Sys` isn't available on the `-js` target `build.hxml`
	actually ships, and Haxe type-checks a referenced class's every field,
	`main` included, even when nothing calls it.

	**`placeKnownSpaceship` (2026-08-06).** `GeodesicGliderSearch`'s own
	1-ring exhaustive search never found a real traveler under `B2/S34` —
	everything confirmed was a bounded shuttle
	(`GeodesicGliderTrajectory`'s own finding). Web research turned up
	`xq14_0ig5l3z102`: a real, confirmed period-14 spaceship in `B2/S34H`
	(Golly/Catagolue's own name for this exact rule on a hexagonal
	neighborhood), found by Catagolue's own distributed soup search across
	~100 billion random soups — validated on this sphere by
	`GeodesicGliderPort`'s own headless probe: 8 clean periods (112
	generations) of genuinely growing drift (not the shuttles' oscillating
	kind) before it reached a pentagon and dissolved into a small residual
	oscillator. See that class's own doc for the coordinate-convention
	story (an initial wrong guess at which diagonal pair of hex neighbors
	the pattern's `(x,y)` axes use collapsed it to a fragment in 15
	generations; the corrected pair, confirmed on a flat grid first, holds
	for at least 8 periods here).
**/
class GeodesicGliderPatterns {
	/** `xq14_0ig5l3z102`, decoded from its Catagolue apgcode — see `GeodesicGliderPort`'s own doc. Already normalized (min x = min y = 0). **/
	static final KNOWN_SPACESHIP_CELLS:Array<{x:Int, y:Int}> = [
		{x: 1, y: 1}, {x: 1, y: 4}, {x: 2, y: 4}, {x: 3, y: 0}, {x: 3, y: 2}, {x: 4, y: 0}, {x: 4, y: 2}, {x: 4, y: 4}, {x: 5, y: 0}, {x: 5, y: 1},
		{x: 0, y: 5}, {x: 2, y: 6}];

	/** The node farthest (by BFS hop count) from every one of the 12 pentagons — a seed placed here has the most room to translate before its own dynamics run into a pinch-point irregularity. **/
	public static function flattestNode(sphere:GeodesicSphereData):Int {
		var distances = GeodesicShapeSignature.multiSourceBfs(sphere, GeodesicSphere.pentagons(sphere));
		var best = 0;
		var bestDistance = -1;
		for (id in 0...sphere.neighbors.length) {
			var d = distances.get(id);
			if (d != null && d > bestDistance) {
				bestDistance = d;
				best = id;
			}
		}
		return best;
	}

	/** Every non-empty subset of `center`'s own 1-ring (itself plus its 6 neighbors) — 127 patterns, small enough for `GeodesicGliderSearch` to try exhaustively rather than guess at; `GeodesicGliderTracker` regenerates the exact same patterns by mask to look up a specific confirmed glider at a new anchor. **/
	public static function localPatterns(sphere:GeodesicSphereData, center:Int):Array<SeedPattern> {
		var cells = [center].concat(sphere.neighbors[center]);
		var patterns:Array<SeedPattern> = [];
		var total = 1 << cells.length;
		for (mask in 1...total) {
			var subset:Array<Int> = [];
			for (i in 0...cells.length) {
				if (mask & (1 << i) != 0) {
					subset.push(cells[i]);
				}
			}
			patterns.push({mask: mask, cells: subset});
		}
		return patterns;
	}

	/**
		Places `KNOWN_SPACESHIP_CELLS` at `anchor`, or `null` if the walk
		ever runs off the edge of a hexagon-only patch (hits a pentagon —
		the pattern's own bounding box reaches up to 6 hex-steps out, so an
		anchor without enough clearance can fail here even though `anchor`
		itself is fine). Callers should pick anchors with real clearance
		from any pentagon (`GeodesicShapeSignature.multiSourceBfs` against
		`GeodesicSphere.pentagons`) to keep this rare, and be ready to fall
		back to a different anchor when it still happens.
	**/
	public static function placeKnownSpaceship(sphere:GeodesicSphereData, anchor:Int):Null<Array<Int>> {
		var basis = hexBasis(sphere, anchor);
		var result:Array<Int> = [];
		for (offset in KNOWN_SPACESHIP_CELLS) {
			var afterU = walk(sphere, anchor, basis.u, offset.x);
			if (afterU == null) {
				return null;
			}
			var afterV = walk(sphere, afterU, basis.v, offset.y);
			if (afterV == null) {
				return null;
			}
			result.push(afterV);
		}
		var unique = new Map<Int, Bool>();
		for (id in result) {
			unique.set(id, true);
		}
		return Lambda.count(unique) == result.length ? result : null; // curvature drift bent the walk into itself
	}

	/** Two of `anchor`'s own 6 neighbors, chosen by tangent-plane angle so they're genuinely the 120°-apart pair `KNOWN_SPACESHIP_CELLS`' `(1,0)`/`(0,1)` axes need (see this class's own doc) — not just the first two array entries, since `sphere.neighbors` carries no ordering guarantee (`GeodesicTopology.axisOf` is `Irregular` everywhere). **/
	static function hexBasis(sphere:GeodesicSphereData, anchor:Int):{u:Vec3, v:Vec3} {
		var center = sphere.positions[anchor];
		var neighbors = sphere.neighbors[anchor];
		var refDir = tangentDir(center, sphere.positions[neighbors[0]]);
		var sorted = neighbors.copy();
		sorted.sort((a, b) -> {
			var angleA = signedAngle(refDir, tangentDir(center, sphere.positions[a]), center);
			var angleB = signedAngle(refDir, tangentDir(center, sphere.positions[b]), center);
			return angleA < angleB ? -1 : (angleA > angleB ? 1 : 0);
		});
		return {u: tangentDir(center, sphere.positions[sorted[0]]), v: tangentDir(center, sphere.positions[sorted[2]])};
	}

	/** `center`'s own direction toward `target`, with the radial component projected out so it's a genuine tangent-plane vector — `center` is itself the outward normal on a unit sphere. **/
	static function tangentDir(center:Vec3, target:Vec3):Vec3 {
		var d = Vec3Math.subtract(target, center);
		var radial = Vec3Math.scaled(center, Vec3Math.dot(d, center));
		return Vec3Math.normalized(Vec3Math.subtract(d, radial));
	}

	static function signedAngle(a:Vec3, b:Vec3, normal:Vec3):Float {
		var cross = Vec3Math.cross(a, b);
		var sinComponent = Vec3Math.dot(cross, normal);
		var cosComponent = Vec3Math.dot(a, b);
		return Math.atan2(sinComponent, cosComponent);
	}

	/** From `from`, take `steps` hops each re-deriving "which neighbor of the current node best continues toward `direction`" from real 3D positions — `direction` itself stays fixed (not re-parallel-transported per hop), a fair approximation over a patch this small (≤6 hops) on a sphere this size. `null` the moment a step lands on a pentagon, since a 5-neighbor node has no well-defined "continue in this direction" answer. **/
	static function walk(sphere:GeodesicSphereData, from:Int, direction:Vec3, steps:Int):Null<Int> {
		var current = from;
		for (_ in 0...steps) {
			if (sphere.neighbors[current].length != 6) {
				return null;
			}
			var best = -1;
			var bestDot = -2.0;
			for (candidate in sphere.neighbors[current]) {
				var dir = tangentDir(sphere.positions[current], sphere.positions[candidate]);
				var dot = Vec3Math.dot(dir, direction);
				if (dot > bestDot) {
					bestDot = dot;
					best = candidate;
				}
			}
			current = best;
		}
		return current;
	}
}

typedef SeedPattern = {mask:Int, cells:Array<Int>};
