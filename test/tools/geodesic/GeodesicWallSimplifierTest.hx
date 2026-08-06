package tools.geodesic;

import tools.geodesic.GeodesicWallSimplifier.WallSegment;
import tools.geodesic.Vec3.Vec3Math;
import utest.Assert;
import utest.Test;

class GeodesicWallSimplifierTest extends Test {
	function testAnIsolatedSegmentIsUnchanged():Void {
		var a = Vec3Math.make(0, 0, 0);
		var b = Vec3Math.make(1, 0, 0);
		var segments:Array<WallSegment> = [{a: a, b: b, activity: 0.7}];

		var result = GeodesicWallSimplifier.simplify(segments);

		Assert.equals(1, result.length);
		Assert.isTrue(sameChord(result[0], a, b));
		Assert.equals(0.7, result[0].activity);
	}

	/** Both ends anchored by a dead end (degree 1): the whole run collapses to one chord, carrying the hottest activity along it. **/
	function testAChainBetweenTwoDeadEndsCollapsesToOneChord():Void {
		var p0 = Vec3Math.make(0, 0, 0);
		var p1 = Vec3Math.make(1, 0, 0);
		var p2 = Vec3Math.make(2, 0, 0);
		var p3 = Vec3Math.make(3, 0, 0);
		var segments:Array<WallSegment> = [
			{a: p0, b: p1, activity: 0.1},
			{a: p1, b: p2, activity: 0.5},
			{a: p2, b: p3, activity: 0.2},
		];

		var result = GeodesicWallSimplifier.simplify(segments);

		Assert.equals(1, result.length);
		Assert.isTrue(sameChord(result[0], p0, p3));
		Assert.equals(0.5, result[0].activity);
	}

	/**
		A branch point (degree 3) is a real anchor, same as a dead end — it
		must never be walked through, so each arm stays its own chain,
		terminating exactly at the junction.
	**/
	function testAJunctionStopsEveryChainThatMeetsIt():Void {
		var p0 = Vec3Math.make(0, 0, 0);
		var p1 = Vec3Math.make(1, 0, 0); // the junction: p0, p2, p4 all meet here
		var p2 = Vec3Math.make(2, 0, 0);
		var p3 = Vec3Math.make(3, 0, 0);
		var p4 = Vec3Math.make(1, 1, 0);
		var segments:Array<WallSegment> = [
			{a: p0, b: p1, activity: 0.1},
			{a: p1, b: p2, activity: 0.5},
			{a: p2, b: p3, activity: 0.2},
			{a: p1, b: p4, activity: 0.9},
		];

		var result = GeodesicWallSimplifier.simplify(segments);

		Assert.equals(3, result.length);
		Assert.isTrue(anyChord(result, p0, p1, 0.1), "the p0-p1 arm should be untouched: it's already anchored on both ends");
		Assert.isTrue(anyChord(result, p1, p3, 0.5), "the p1-p2-p3 arm should collapse to a single p1-p3 chord");
		Assert.isTrue(anyChord(result, p1, p4, 0.9), "the p1-p4 arm should be untouched");
	}

	/** No vertex in the whole loop has degree != 2, so there's no anchor to walk from at all — every original segment is returned exactly as given. **/
	function testAClosedLoopWithNoAnchorIsReturnedUnmodified():Void {
		var p0 = Vec3Math.make(0, 0, 0);
		var p1 = Vec3Math.make(1, 0, 0);
		var p2 = Vec3Math.make(1, 1, 0);
		var p3 = Vec3Math.make(0, 1, 0);
		var segments:Array<WallSegment> = [
			{a: p0, b: p1, activity: 0.1},
			{a: p1, b: p2, activity: 0.2},
			{a: p2, b: p3, activity: 0.3},
			{a: p3, b: p0, activity: 0.4},
		];

		var result = GeodesicWallSimplifier.simplify(segments);

		Assert.equals(4, result.length);
		for (segment in segments) {
			Assert.isTrue(anyChord(result, segment.a, segment.b, segment.activity),
				'expected the original ${segment.a}-${segment.b} segment to survive untouched');
		}
	}

	function testAnEmptyListStaysEmpty():Void {
		Assert.equals(0, GeodesicWallSimplifier.simplify([]).length);
	}

	static function sameChord(segment:WallSegment, a:Vec3, b:Vec3):Bool {
		var forward = closeEnough(segment.a, a) && closeEnough(segment.b, b);
		var reversed = closeEnough(segment.a, b) && closeEnough(segment.b, a);
		return forward || reversed;
	}

	static function anyChord(segments:Array<WallSegment>, a:Vec3, b:Vec3, activity:Float):Bool {
		for (segment in segments) {
			if (sameChord(segment, a, b) && segment.activity == activity) {
				return true;
			}
		}
		return false;
	}

	static function closeEnough(p:Vec3, q:Vec3):Bool {
		return Vec3Math.distanceSquared(p, q) < 1e-9;
	}
}
