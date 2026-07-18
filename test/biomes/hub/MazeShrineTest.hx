package biomes.hub;

import utest.Test;
import utest.Assert;
import biomes.maze.MazeBiome;

/** Covers MazeShrine's own pure collision/painting-placement queries — not `build`'s own scene/rendering side (see docs/GUIDELINES.md §1.4/§5.4). **/
class MazeShrineTest extends Test {
	static inline final RADIUS:Float = 70;

	static final BASIS = HubStructure.anchorAt(Math.PI / 2, 1.0, RADIUS);

	function testBlocksMovementRightAtTheAnchorItself():Void {
		// Wall 1 starts exactly at the shrine's own local origin - the
		// anchor point is inside the spiral's own first wall, not open floor.
		Assert.isTrue(MazeShrine.blocksMovement(BASIS, BASIS.origin));
	}

	function testBlocksMovementIsFalseWellClearOfEveryWall():Void {
		var farPoint = HubStructure.worldPoint(BASIS, 1000, 1000, 0);
		Assert.isFalse(MazeShrine.blocksMovement(BASIS, farPoint));
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
