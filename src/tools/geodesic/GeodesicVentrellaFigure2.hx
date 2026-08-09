package tools.geodesic;

import tools.geodesic.GeodesicVentrellaRule.GeodesicVentrellaRules;
import tools.geodesic.GeodesicSphere.GeodesicSphereData;
import tools.geodesic.Vec3.Vec3Math;

/**
	Direct reproduction attempt for the source paper's own Figure 2 glider
	(`https://www.ventrella.com/SphereCA/`) — every search this package has
	tried so far (`GeodesicVentrellaReport`'s ambient soup,
	`GeodesicVentrellaGliderSearch`'s exhaustive small hand-placed patterns)
	was indirect: hoping to *find* a traveler, never *placing* the one
	traveler the source actually documents. This seeds that exact shape,
	hand-reconstructed from a description of the figure's own 4 frames
	(2026-08-09) and self-verified before trusting it: both mirror-crossing
	checks the description implies (frame 2's gray cell lands exactly on
	frame 1's southern black cell; frame 4's does the same relative to frame
	3) hold exactly under axial-hex arithmetic, and frame 3/4 land exactly
	one hex south of frame 1/2 respectively — genuine period-2 drift by
	construction, not assumed.

	**Shape** (3 cells): two state-1 ("black") cells two hexes apart in a
	straight line with one empty hex between them, plus one state-3
	("gray") cell adjacent to the *southern* black cell, on the side facing
	away from the line.

	**Mapping onto the real mesh**: the sphere has no built-in compass, so
	an arbitrary hex node's own neighbor geometry stands in for one. Pick
	`origin` as `black1`; take one of its neighbors as the "south" direction
	and another (offset 4 slots around the cyclic neighbor order — the
	empirically-derived 240° separation between this reconstruction's own
	`S` and `NW` axial vectors) as the "north-west" direction; walk two
	hops south for `black2`, then one hop north-west from there for `gray1`.
	Which literal compass heading this ends up matching Ventrella's own
	image is irrelevant: `GeodesicVentrellaState.liveNeighborStateCount`
	counts neighbor *states*, never neighbor *direction*, so the rule itself
	is fully isotropic — a consistent local frame (even a mirrored one)
	tests the identical shape.

	Run by hand (`neko` target) and read — not part of the permanent test
	suite or the regular build/bake pipeline.
**/
class GeodesicVentrellaFigure2 {
	static inline final FREQUENCY:Int = 10;
	static inline final TRACE_GENERATIONS:Int = 110;
	static inline final TRACE_CHECKPOINT:Int = 10;

	/** How many slots around a hub's own cyclic neighbor order separate this reconstruction's `S` and `NW` axial directions — see this class's own doc. **/
	static inline final NW_OFFSET:Int = 4;

	public static function main():Void {
		var sphere = GeodesicSphere.generate(FREQUENCY);
		var black1 = GeodesicGliderPatterns.flattestNode(sphere);
		var neighbors = sphere.neighbors[black1];
		if (neighbors.length != 6) {
			throw 'expected a hexagon at $black1, got degree ${neighbors.length}';
		}

		var southDir = direction(sphere, black1, neighbors[0]);
		var nwDir = direction(sphere, black1, neighbors[NW_OFFSET % neighbors.length]);

		var empty1 = stepToward(sphere, black1, southDir);
		var black2 = stepToward(sphere, empty1, southDir);
		var gray1 = stepToward(sphere, black2, nwDir);

		Sys.println('black1=$black1 (empty)=$empty1 black2=$black2 gray1=$gray1');
		Sys.println('adjacency sanity: black1-empty1 adjacent=${sphere.neighbors[black1].indexOf(empty1) != -1}, empty1-black2 adjacent=${sphere.neighbors[empty1].indexOf(black2) != -1}, black2-gray1 adjacent=${sphere.neighbors[black2].indexOf(gray1) != -1}, black1-black2 NOT adjacent=${sphere.neighbors[black1].indexOf(black2) == -1}\n');

		var state = new GeodesicVentrellaState(sphere, GeodesicVentrellaRules.SPHERE_CA);
		state.seedSingle(black1, 1);
		state.seedSingle(black2, 1);
		state.seedSingle(gray1, 3);

		var pentagonDistances = GeodesicShapeSignature.multiSourceBfs(sphere, GeodesicSphere.pentagons(sphere));

		var origin = [black1, black2, gray1];
		var noMutation = () -> 1.0;
		var maxDrift = 0.0;
		var lastDrift = 0.0;
		var stillGrowing = false;
		for (generation in 0...TRACE_GENERATIONS) {
			var alive = aliveNodes(state, sphere);
			if (alive.length == 0) {
				Sys.println('gen $generation: died out');
				break;
			}
			if (generation < 20 || (generation + 1) % TRACE_CHECKPOINT == 0 || generation > 85) {
				var drift = GeodesicShapeSignature.centroidDistance(sphere, origin, alive);
				var states = [for (id in alive) state.stateOf(id)];
				var nearestPentagon = minPentagonDistance(alive, pentagonDistances);
				Sys.println('gen $generation: population=${alive.length} drift=${round(drift)} nearestPentagonHops=$nearestPentagon cells=$alive states=$states');
				stillGrowing = drift > maxDrift + 0.01;
				maxDrift = Math.max(maxDrift, drift);
				lastDrift = drift;
			}
			state.step(noMutation);
		}
		Sys.println('\nfinal: maxDrift=${round(maxDrift)} lastDrift=${round(lastDrift)} stillGrowingAtCheckpoint=$stillGrowing — ${stillGrowing && lastDrift > 0.3 ? "CONFIRMED TRAVELER" : "bounded/inconclusive"}');
	}

	static function minPentagonDistance(alive:Array<Int>, pentagonDistances:Map<Int, Int>):Int {
		var min = 999;
		for (id in alive) {
			var d = pentagonDistances.get(id);
			if (d != null && d < min) {
				min = d;
			}
		}
		return min;
	}

	static function direction(sphere:GeodesicSphereData, from:Int, to:Int):Vec3 {
		return Vec3Math.normalized(Vec3Math.subtract(sphere.positions[to], sphere.positions[from]));
	}

	/** `from`'s own neighbor whose direction most closely matches `dir` — a greedy geodesic step, good enough over the few hops this pattern needs. **/
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

	static function aliveNodes(state:GeodesicVentrellaState, sphere:GeodesicSphereData):Array<Int> {
		var alive = [];
		for (id in 0...sphere.neighbors.length) {
			if (state.isAlive(id)) {
				alive.push(id);
			}
		}
		return alive;
	}

	static function round(value:Float):String {
		return Std.string(Math.round(value * 1000) / 1000);
	}
}
