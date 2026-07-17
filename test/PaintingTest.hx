import utest.Test;
import utest.Assert;
import hub.Painting;

/** Covers Painting's pure trigger/placement math — not its scene/rendering side (see docs/GUIDELINES.md §1.4/§5.4). **/
class PaintingTest extends Test {
	function testMidpointOfIsHalfwayBetweenBothEnds():Void {
		var a = new h3d.Vector(0, 0, 0);
		var b = new h3d.Vector(10, 4, -6);

		var mid = Painting.midpointOf(a, b);

		Assert.floatEquals(5, mid.x, 1e-9);
		Assert.floatEquals(2, mid.y, 1e-9);
		Assert.floatEquals(-3, mid.z, 1e-9);
	}

	function testTriggeredByIsTrueExactlyAtItsOwnPosition():Void {
		var position = new h3d.Vector(3, 4, 0);
		var painting = new Painting(position, ToBiome);

		Assert.isTrue(painting.triggeredBy(position));
	}

	function testTriggeredByIsTrueJustInsideTheTriggerDistance():Void {
		var position = new h3d.Vector(0, 0, 0);
		var painting = new Painting(position, ToHub);

		var justInside = new h3d.Vector(Painting.TRIGGER_DISTANCE - 0.1, 0, 0);

		Assert.isTrue(painting.triggeredBy(justInside));
	}

	function testTriggeredByIsFalseJustOutsideTheTriggerDistance():Void {
		var position = new h3d.Vector(0, 0, 0);
		var painting = new Painting(position, ToHub);

		var justOutside = new h3d.Vector(Painting.TRIGGER_DISTANCE + 0.1, 0, 0);

		Assert.isFalse(painting.triggeredBy(justOutside));
	}

	function testTriggeredByMeasuresStraightLineDistanceRegardlessOfDirection():Void {
		var position = new h3d.Vector(10, 10, 10);
		var painting = new Painting(position, ToBiome);

		// 3-4-5-ish diagonal offset, well past TRIGGER_DISTANCE.
		var far = new h3d.Vector(10 + 30, 10 + 40, 10);

		Assert.isFalse(painting.triggeredBy(far));
	}
}
