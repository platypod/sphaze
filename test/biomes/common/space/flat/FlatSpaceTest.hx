package biomes.common.space.flat;

import utest.Test;
import utest.Assert;

/** Covers FlatSpace's own Space contract — see sphere.SphereMathTest for the curved topology this contrasts with. **/
class FlatSpaceTest extends Test {
	function testUpAtIsAlwaysWorldPlusYRegardlessOfPosition():Void {
		var up = FlatSpace.INSTANCE.upAt(new h3d.Vector(12, -4, 7));

		Assert.floatEquals(0, up.x);
		Assert.floatEquals(1, up.y);
		Assert.floatEquals(0, up.z);
	}

	function testMoveAlongTranslatesStraightAlongDirection():Void {
		var pos = new h3d.Vector(1, 2, 3);
		var forward = new h3d.Vector(0, 0, 1);
		var direction = new h3d.Vector(1, 0, 0);

		var result = FlatSpace.INSTANCE.moveAlong(pos, forward, direction, 5, 1);

		Assert.floatEquals(6, result.pos.x);
		Assert.floatEquals(2, result.pos.y);
		Assert.floatEquals(3, result.pos.z);
	}

	function testMoveAlongLeavesForwardUnrotated():Void {
		var pos = new h3d.Vector(0, 0, 0);
		var forward = new h3d.Vector(0, 0, 1);
		var direction = new h3d.Vector(1, 0, 0);

		var result = FlatSpace.INSTANCE.moveAlong(pos, forward, direction, 5, 1);

		Assert.floatEquals(0, result.forward.x);
		Assert.floatEquals(0, result.forward.y);
		Assert.floatEquals(1, result.forward.z);
	}

	function testMoveAlongNegativeDistanceMovesTheOppositeWay():Void {
		var pos = new h3d.Vector(5, 0, 0);
		var forward = new h3d.Vector(0, 0, 1);
		var direction = new h3d.Vector(1, 0, 0);

		var result = FlatSpace.INSTANCE.moveAlong(pos, forward, direction, -5, 1);

		Assert.floatEquals(0, result.pos.x);
	}
}
