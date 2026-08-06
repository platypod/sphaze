package tools.geodesic;

import tools.geodesic.Vec3.Vec3Math;

/** One wall's own two endpoints plus the activity to render it with — the unit `GeodesicWallSimplifier` both consumes and produces. **/
typedef WallSegment = {
	var a:Vec3;
	var b:Vec3;
	var activity:Float;
}

/**
	Straightens a set of wall segments by collapsing every run of them that
	passes straight through, leaving only the real corners — raised
	directly ("I'm not fond of the hex-shaped walls... when two walls are
	adjacent on two hexes, what if we made them straight?").

	**Retracted from `GeodesicMesh` (2026-08-06), kept here rather than
	deleted.** Playing it in the real biome (not just screenshotting the
	preview) surfaced two problems this class's own correctness doesn't
	fix: a merged chord's own endpoints don't correspond to any *one*
	edge's own collision boundary, so a player can be blocked at a point
	the drawn wall doesn't visibly explain; and since nearly every wall on
	this grid is already on the reactive edge set (the core spanning tree
	is never drawn as a wall at all), a chain recomputed fresh every
	generation reshapes visibly whenever any single edge inside it flips —
	not a flaw in the algorithm below, which does exactly what it's
	documented to do, but a mismatch between "merge geometry across
	several edges" and "collision and reactivity are both per-edge." See
	`docs/game-design/design-decisions-records.md`'s own retraction entry.
	The class and its own tests stay, in case a future approach needs a
	correct topological chain-collapse as a building block.

	**What "straight" turned out to mean here, found empirically before
	writing any of this:** the original plan was to bridge a kink only when
	the turn there is shallow, leaving sharp ones (real corners) alone. A
	quick measurement over a real carved maze killed that plan — every
	pass-through kink measures `54°-72°` (median `60°`), with no gap
	separating "shallow" from "sharp." That's not noise, it's the
	tessellation itself: two dual-polygon edges from *different* hexagons
	meet at close to a hexagon's own exterior angle regardless of which
	direction the corridor is actually going, so a per-kink angle
	threshold can't tell a real turn from an artifact of the grid — there
	is no such distinction to find at a single vertex.

	The thing that *does* distinguish a real corner is topological, not
	angular: a maze's own branch points. A vertex where exactly two closed
	walls meet is provably a pass-through — removing it can't change what
	the wall connects to, since nothing else touches it. A vertex where
	one or three-or-more walls meet is a genuine dead end or junction, and
	has to stay exactly where it is. So this collapses every maximal run
	of degree-2 vertices between two such anchors into one straight
	segment, with no angle math and no tunable threshold at all.

	Measured on a real bake (frequency `11`, a `RandomizedDfs` carve):
	`43%` of runs are a single original segment (already anchored on both
	ends, untouched); the rest merge a median of `2` segments, up to `11`
	in the longest observed case. The straight chord is usually close to
	the original zigzag's own path length (median `88%` of it) but can be
	considerably shorter for the rare long run (`24%` in the worst case
	observed) — a long corridor's wall can end up visibly cutting across
	what used to be its own zigzag, an accepted cost of a hard chord
	rather than a curve-preserving simplification (Douglas-Peucker, the
	fuller version this was scoped against but not what was asked for).
	Purely cosmetic either way: `GeodesicCollision` never reads wall
	geometry, only the node graph, so nothing about this can affect where
	a player can actually walk.
**/
class GeodesicWallSimplifier {
	/** One touch a vertex has to a neighboring vertex via a specific segment — kept separate per direction (both endpoints of a segment record a touch to each other) so walking a chain never has to re-derive which segment it arrived on. **/
	static function touch(map:haxe.ds.StringMap<Array<{toKey:String, activity:Float, segmentIndex:Int}>>, key:String, toKey:String, activity:Float,
			segmentIndex:Int):Void {
		if (!map.exists(key)) {
			map.set(key, []);
		}
		map.get(key).push({toKey: toKey, activity: activity, segmentIndex: segmentIndex});
	}

	/**
		@param segments the walls to straighten — order-independent, and safe to call separately per rendering bucket (solid walls, ghost walls) since bridging across two segments that shouldn't visually connect would be wrong.
		@return the same walls, with every maximal pass-through run collapsed to one straight segment between its two real anchors. A run entirely without an anchor (a closed loop of nothing but degree-2 vertices, not observed in practice but not provably impossible) is returned unmodified, segment by segment, rather than dropped or guessed at.
	**/
	public static function simplify(segments:Array<WallSegment>):Array<WallSegment> {
		var pointOf = new haxe.ds.StringMap<Vec3>();
		var touches = new haxe.ds.StringMap<Array<{toKey:String, activity:Float, segmentIndex:Int}>>();

		for (i in 0...segments.length) {
			var segment = segments[i];
			var aKey = GeodesicSphere.weldKey(segment.a);
			var bKey = GeodesicSphere.weldKey(segment.b);
			pointOf.set(aKey, segment.a);
			pointOf.set(bKey, segment.b);
			touch(touches, aKey, bKey, segment.activity, i);
			touch(touches, bKey, aKey, segment.activity, i);
		}

		var consumed = [for (_ in 0...segments.length) false];
		var result:Array<WallSegment> = [];

		for (startKey in touches.keys()) {
			if (touches.get(startKey).length == 2) {
				continue; // pass-through — only ever walked *from* an anchor, never started at
			}
			for (start in touches.get(startKey)) {
				if (consumed[start.segmentIndex]) {
					continue;
				}
				result.push(walkChain(startKey, start, pointOf, touches, consumed));
			}
		}

		// Whatever's left is a closed loop with no anchor anywhere on it — see this function's own doc.
		for (i in 0...segments.length) {
			if (!consumed[i]) {
				result.push(segments[i]);
			}
		}

		return result;
	}

	/** Walks from `startKey` along `start`'s own segment, through however many degree-2 vertices follow, to the next anchor — marking every segment it crosses as consumed so `simplify`'s own outer loop never re-walks it. **/
	static function walkChain(startKey:String, start:{toKey:String, activity:Float, segmentIndex:Int}, pointOf:haxe.ds.StringMap<Vec3>,
			touches:haxe.ds.StringMap<Array<{toKey:String, activity:Float, segmentIndex:Int}>>, consumed:Array<Bool>):WallSegment {
		consumed[start.segmentIndex] = true;
		var maxActivity = start.activity;
		var previousSegment = start.segmentIndex;
		var currentKey = start.toKey;

		while (touches.get(currentKey).length == 2) {
			var options = touches.get(currentKey);
			var next = options[0].segmentIndex == previousSegment ? options[1] : options[0];
			if (consumed[next.segmentIndex]) {
				break; // already walked from the other direction — this run closes a loop with no real anchor
			}
			consumed[next.segmentIndex] = true;
			maxActivity = Math.max(maxActivity, next.activity);
			previousSegment = next.segmentIndex;
			currentKey = next.toKey;
		}

		return {a: pointOf.get(startKey), b: pointOf.get(currentKey), activity: maxActivity};
	}
}
