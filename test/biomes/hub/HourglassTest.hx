package biomes.hub;

import utest.Test;
import utest.Assert;

/** Covers Hourglass's own pure collision/lean queries — not `build`/`buildDynamic`'s own scene/rendering side (see docs/GUIDELINES.md §1.4/§5.4). **/
class HourglassTest extends Test {
	static inline final RADIUS:Float = 70;

	static final BASIS = HubStructure.anchorAt(Math.PI / 2, 0.3, RADIUS);

	function testBlocksMovementRightAtTheAnchorItself():Void {
		// The pedestal is solid all the way through, so its own local origin
		// - dead center - is well inside its collision boundary.
		Assert.isTrue(Hourglass.blocksMovement(BASIS, BASIS.origin));
	}

	function testBlocksMovementIsFalseWellClearOfThePedestal():Void {
		var farPoint = HubStructure.worldPoint(BASIS, 1000, 1000, 0);
		Assert.isFalse(Hourglass.blocksMovement(BASIS, farPoint));
	}

	function testLeanIsZeroDeadCenter():Void {
		Assert.floatEquals(0, Hourglass.lean(BASIS, BASIS.origin), 1e-9);
	}

	function testLeanIsNegativeOnTheLocalWestSide():Void {
		var westPoint = HubStructure.worldPoint(BASIS, -5, 0, 0);
		Assert.isTrue(Hourglass.lean(BASIS, westPoint) < 0);
	}

	function testLeanIsPositiveOnTheLocalEastSide():Void {
		var eastPoint = HubStructure.worldPoint(BASIS, 5, 0, 0);
		Assert.isTrue(Hourglass.lean(BASIS, eastPoint) > 0);
	}

	function testLeanIsZeroBeyondTheProximityRange():Void {
		var farPoint = HubStructure.worldPoint(BASIS, Hourglass.PROXIMITY_RANGE + 10, 0, 0);
		Assert.floatEquals(0, Hourglass.lean(BASIS, farPoint), 1e-9);
	}

	function testLeanIsClampedToOneAtTheProximityBoundary():Void {
		var boundaryPoint = HubStructure.worldPoint(BASIS, Hourglass.PROXIMITY_RANGE, 0, 0);
		Assert.floatEquals(1, Hourglass.lean(BASIS, boundaryPoint), 1e-6);
	}
}
