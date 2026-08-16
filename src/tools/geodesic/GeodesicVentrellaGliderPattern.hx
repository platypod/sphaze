package tools.geodesic;

import tools.geodesic.GeodesicSphere.GeodesicSphereData;
import tools.geodesic.Vec3.Vec3Math;

/**
	The confirmed Ventrella period-2 glider — reusable placement logic, the
	game-code counterpart to `GeodesicVentrellaFigure2`'s own one-off
	verification tool, stripped of its `Sys`-based tracing (unavailable on
	the `-js` game target) down to just the geometry
	`GeodesicVentrellaGliderSpawner` needs at runtime.

	**Shape**: two state-1 ("black") cells two hexes apart in a straight
	line with one empty hex between them, plus one state-3 ("gray") cell
	adjacent to the second black cell, offset `NW_OFFSET` slots around its
	own cyclic neighbor order from the same "south" heading used to place
	it. See `docs/archive/decisions.md`'s 2026-08-09
	entry for the full derivation and the 4-frame self-verification that
	confirmed this shape actually travels — chord drift up to `1.812` on a
	unit sphere (most of the way to antipodal) before looping back around
	and colliding with its own launch site, exactly the "collisions evoke
	state 2" behavior the source paper describes.
**/
class GeodesicVentrellaGliderPattern {
	/** How many slots around a hub's own cyclic neighbor order separate this shape's "south" and "north-west" axial directions — empirically derived, not assumed; see `GeodesicVentrellaFigure2`'s own doc. **/
	public static inline final NW_OFFSET:Int = 4;

	/**
		Seeds one glider onto `state`, anchored at `origin` (must be a
		hexagon — degree `6`) with `southIndex` selecting which of
		`origin`'s own neighbors stands in for "south" this time — see
		`GeodesicVentrellaGliderSpawner`'s own doc for why varying this
		across launch sites matters.
		@param state the layer to seed onto.
		@param sphere the topology `origin`/`state` both live on.
		@param origin the glider's own `black1` cell — must have exactly 6 neighbors.
		@param southIndex which of `origin`'s own neighbors to treat as "south", `0`-based (taken mod 6).
		@return the 3 seeded node ids, `{black1, black2, gray1}` — mainly for tests/logging.
	**/
	public static function seed(state:GeodesicVentrellaState, sphere:GeodesicSphereData, origin:Int, southIndex:Int):{black1:Int, black2:Int, gray1:Int} {
		var neighbors = sphere.neighbors[origin];
		if (neighbors.length != 6) {
			throw 'GeodesicVentrellaGliderPattern.seed needs a hexagon origin, got degree ${neighbors.length} at node $origin';
		}

		var southDir = direction(sphere, origin, neighbors[southIndex % neighbors.length]);
		var nwDir = direction(sphere, origin, neighbors[(southIndex + NW_OFFSET) % neighbors.length]);

		var empty1 = stepToward(sphere, origin, southDir);
		var black2 = stepToward(sphere, empty1, southDir);
		var gray1 = stepToward(sphere, black2, nwDir);

		state.seedSingle(origin, 1);
		state.seedSingle(black2, 1);
		state.seedSingle(gray1, 3);

		return {black1: origin, black2: black2, gray1: gray1};
	}

	static function direction(sphere:GeodesicSphereData, from:Int, to:Int):Vec3 {
		return Vec3Math.normalized(Vec3Math.subtract(sphere.positions[to], sphere.positions[from]));
	}

	/** `from`'s own neighbor whose direction most closely matches `dir` — a greedy geodesic step, good enough over the few hops this pattern needs. Mirrors `GeodesicVentrellaFigure2.stepToward` exactly. **/
	static function stepToward(sphere:GeodesicSphereData, from:Int, dir:Vec3):Int {
		var best = -1;
		var bestDot = -2.0;
		for (neighbor in sphere.neighbors[from]) {
			var dot = Vec3Math.dot(direction(sphere, from, neighbor), dir);
			if (dot > bestDot) {
				bestDot = dot;
				best = neighbor;
			}
		}
		return best;
	}
}
