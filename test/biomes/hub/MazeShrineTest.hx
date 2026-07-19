package biomes.hub;

import utest.Test;
import utest.Assert;
import biomes.common.space.sphere.SphereMath;
import biomes.maze.MazeBiome;

/** Covers MazeShrine's own pure collision/painting-placement queries — not `build`'s own scene/rendering side (see docs/GUIDELINES.md §1.4/§5.4). **/
class MazeShrineTest extends Test {
	static inline final RADIUS:Float = 70;

	static final THETA:Float = Math.PI / 2;

	static final PHI:Float = 1.0;

	static final BASIS = HubStructure.anchorAt(THETA, PHI, RADIUS);

	function testBlocksMovementRightAtTheAnchorItself():Void {
		// Wall 1 starts exactly at the shrine's own local origin - the
		// anchor point is inside the spiral's own first wall, not open floor.
		Assert.isTrue(MazeShrine.blocksMovement(BASIS, BASIS.origin, 0));
	}

	function testBlocksMovementIsFalseWellClearOfEveryWall():Void {
		var farPoint = HubStructure.worldPoint(BASIS, 1000, 1000, 0);
		Assert.isFalse(MazeShrine.blocksMovement(BASIS, farPoint, 0));
	}

	function testBlocksMovementIsFalseAtTheAntipodalPointOnTheRealSphere():Void {
		// Regression test for the bug this session actually reported: the
		// point diametrically opposite the shrine's own anchor projects to
		// local (u, v) = (0, 0) - indistinguishable from standing right on
		// top of the shrine - unless height is also checked. Real point on
		// the real sphere (not a flat worldPoint offset), so this only
		// catches the bug if `blocksMovement` actually uses `height`.
		var antipode = SphereMath.sphericalToCartesian(RADIUS, Math.PI - THETA, PHI + Math.PI);
		Assert.isFalse(MazeShrine.blocksMovement(BASIS, antipode, 0));
	}

	function testBlocksMovementIsFalseAboveTheWallsOwnTop():Void {
		// Standing (or having jumped) above WALL_HEIGHT over wall 1's own
		// footprint isn't "walking into" the wall - nothing solid is up
		// there to bump into once past its own top.
		Assert.isFalse(MazeShrine.blocksMovement(BASIS, BASIS.origin, 100));
	}

	function testWallTopHeightAtIsNonNullOverAWall():Void {
		Assert.isTrue(MazeShrine.wallTopHeightAt(BASIS, BASIS.origin) != null);
	}

	function testWallTopHeightAtIsNullWellClearOfEveryWall():Void {
		var farPoint = HubStructure.worldPoint(BASIS, 1000, 1000, 0);
		Assert.isNull(MazeShrine.wallTopHeightAt(BASIS, farPoint));
	}

	function testWallTopHeightAtIsNullAtTheAntipodalPointOnTheRealSphere():Void {
		var antipode = SphereMath.sphericalToCartesian(RADIUS, Math.PI - THETA, PHI + Math.PI);
		Assert.isNull(MazeShrine.wallTopHeightAt(BASIS, antipode));
	}

	function testExitPaintingTriggersAtItsOwnPosition():Void {
		var painting = MazeShrine.exitPainting(BASIS, MazeBiome.ID);
		Assert.isTrue(painting.triggeredBy(painting.position));
	}

	function testExitPaintingDoesNotTriggerWellClearOfTheShrine():Void {
		var painting = MazeShrine.exitPainting(BASIS, MazeBiome.ID);
		var farPoint = HubStructure.worldPoint(BASIS, 1000, 1000, 0);
		Assert.isFalse(painting.triggeredBy(farPoint));
	}

	function testReturnSpawnPositionLiesOnTheHubSphere():Void {
		var player = MazeShrine.returnSpawn(BASIS, RADIUS);
		Assert.floatEquals(RADIUS, player.pos.length(), 1e-6);
	}

	function testReturnSpawnForwardIsAUnitVector():Void {
		var player = MazeShrine.returnSpawn(BASIS, RADIUS);
		Assert.floatEquals(1, player.forward.length(), 1e-6);
	}

	function testReturnSpawnForwardIsTangentToTheSphereAtItsOwnPosition():Void {
		var player = MazeShrine.returnSpawn(BASIS, RADIUS);
		Assert.floatEquals(0, player.forward.dot(player.pos.normalized()), 1e-6);
	}

	function testReturnSpawnDoesNotImmediatelyRetriggerTheExitPainting():Void {
		var painting = MazeShrine.exitPainting(BASIS, MazeBiome.ID);
		var player = MazeShrine.returnSpawn(BASIS, RADIUS);
		Assert.isFalse(painting.triggeredBy(player.pos));
	}

	function testReturnSpawnFacesAwayFromTheShrineNotBackTowardIt():Void {
		// Walking into the maze's own painting to get here is itself a walk
		// further into the spiral - facing that same way again on arrival
		// would retrace those steps rather than continuing out into the hub.
		var player = MazeShrine.returnSpawn(BASIS, RADIUS);
		var outward = player.pos.sub(BASIS.origin).normalized();
		Assert.isTrue(player.forward.dot(outward) > 0);
	}
}
