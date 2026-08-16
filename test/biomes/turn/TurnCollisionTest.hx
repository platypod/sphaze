package biomes.turn;

import biomes.common.space.flat.FlatSpace;
import entities.player.PlayerModel;
import utest.Assert;
import utest.Test;

/**
	Checks the one thing that makes this space a Möbius band rather than a
	long corridor: **going round once comes back mirrored, and going round
	twice does not**.

	That property cannot be seen. A wrap with the reflection accidentally
	dropped produces a cylinder, which walks identically, looks identical
	from any single vantage, and quietly teaches nothing — the space's
	entire lesson would be missing with no symptom. Everything else here
	(staying on the band, sliding past obstacles) is ordinary collision;
	the wrap is the part that needs proving.
**/
class TurnCollisionTest extends Test {
	static inline final EPSILON:Float = 1e-6;

	function playerAt(x:Float, z:Float, ?forward:h3d.Vector):PlayerModel {
		return new PlayerModel(new h3d.Vector(x, 0, z), forward != null ? forward : new h3d.Vector(1, 0, 0), 0, FlatSpace.INSTANCE);
	}

	/** Walking one full period returns to the same place along the band, on the **opposite** side of it. **/
	function testOneLapComesBackMirrored():Void {
		var across = 17.0;
		var player = playerAt(TurnModel.PERIOD / 2 + 1, across);
		TurnCollision.wrapIfNeeded(player);

		Assert.floatEquals(-TurnModel.PERIOD / 2 + 1, player.pos.x, EPSILON, "the wrap did not land a period back");
		Assert.floatEquals(-across, player.pos.z, EPSILON, "the wrap did not mirror across the band — this is a cylinder, not a Mobius band");
	}

	/** Two laps come back unmirrored, which is the other half of the same claim — a wrap that mirrored every time would be as wrong as one that never did. **/
	function testTwoLapsComeBackUnmirrored():Void {
		var across = 17.0;
		var player = playerAt(TurnModel.PERIOD / 2 + 1, across);

		TurnCollision.wrapIfNeeded(player);
		player.pos = new h3d.Vector(player.pos.x + TurnModel.PERIOD, player.pos.y, player.pos.z);
		TurnCollision.wrapIfNeeded(player);

		Assert.floatEquals(across, player.pos.z, EPSILON, "two laps should return the player to their original side");
	}

	/** Wrapping the other way is the exact inverse, so walking backwards over the seam and forwards again is a no-op. **/
	function testWrappingBothWaysCancels():Void {
		var start = playerAt(-TurnModel.PERIOD / 2 - 1, 12.0);
		TurnCollision.wrapIfNeeded(start);

		Assert.floatEquals(TurnModel.PERIOD / 2 - 1, start.pos.x, EPSILON, "the backward wrap did not land a period forward");
		Assert.floatEquals(-12.0, start.pos.z, EPSILON, "the backward wrap did not mirror");
	}

	/**
		**Facing is carried through the seam as a direction, not a point.**
		Transforming `forward` with the glide's translation included would
		fling it a full period away and leave it far from unit length,
		which would not crash — it would just make the camera point
		somewhere absurd on the frame the player crosses.
	**/
	function testFacingIsMirroredButStaysUnit():Void {
		var facing = new h3d.Vector(0.6, 0, 0.8);
		var player = playerAt(TurnModel.PERIOD / 2 + 1, 5.0, facing);
		TurnCollision.wrapIfNeeded(player);

		Assert.floatEquals(0.6, player.forward.x, EPSILON, "the along-band component of facing should be untouched");
		Assert.floatEquals(-0.8, player.forward.z, EPSILON, "the across-band component of facing should be mirrored");
		Assert.floatEquals(1, player.forward.length(), EPSILON, "facing stopped being a unit vector");
	}

	/** A position comfortably inside the band is left exactly alone. **/
	function testNoWrapInsideTheDomain():Void {
		var player = playerAt(10, 5);
		TurnCollision.wrapIfNeeded(player);

		Assert.floatEquals(10, player.pos.x, EPSILON);
		Assert.floatEquals(5, player.pos.z, EPSILON);
	}

	/** The rails are solid — the band has edges, and walking off them is not allowed. **/
	function testTheRailsHoldThePlayerOn():Void {
		Assert.isFalse(TurnCollision.isOpen(0, TurnModel.HALF_WIDTH), "the player can stand in the rail");
		Assert.isFalse(TurnCollision.isOpen(0, -TurnModel.HALF_WIDTH), "the player can stand in the other rail");
		Assert.isTrue(TurnCollision.isOpen(0, 0), "the band's own axis is not standable");
	}

	/**
		**Every obstacle can be got past on at least one side.** The band is
		narrow and the obstacles are wide; a layout that ever spanned the
		full width would be a wall, and at this biome's speed a wall is a
		dead stop rather than a challenge.
	**/
	function testEveryObstacleLeavesAWayPast():Void {
		for (index in 0...TurnModel.OBSTACLE_COUNT) {
			var along = TurnModel.obstacleAlong(index);
			var passable = false;
			var probe = -TurnModel.HALF_WIDTH;
			while (probe <= TurnModel.HALF_WIDTH) {
				if (TurnCollision.isOpen(along, probe)) {
					passable = true;
					break;
				}
				probe += 1;
			}
			Assert.isTrue(passable, 'obstacle $index blocks the whole band');
		}
	}

	/** The obstacle layout is genuinely asymmetric, or a lap would come back looking exactly like the last one and the mirroring would teach nothing. **/
	function testTheObstacleRhythmIsAsymmetric():Void {
		var offAxis = 0;
		for (index in 0...TurnModel.OBSTACLE_COUNT) {
			if (Math.abs(TurnModel.obstacleAcross(index)) > 4) {
				offAxis++;
			}
		}
		Assert.isTrue(offAxis > TurnModel.OBSTACLE_COUNT / 2, 'only $offAxis obstacles sit off the axis — the mirrored lap would look the same');
	}

	/**
		**The band has one edge, not two** — the fact the rail decoration
		rests on. The glide carries the line `y = +HALF_WIDTH` onto
		`y = -HALF_WIDTH`, so the two apparent rails are one curve of twice
		the period, and painting the halves differently is a consistent
		decoration of a single object rather than two objects that
		mysteriously swap.
	**/
	function testTheBandHasASingleBoundaryCurve():Void {
		var onOneEdge = {x: 120.0, y: TurnModel.HALF_WIDTH, z: 1.0};
		var carried = geometry.Isometry.apply(TurnModel.glide(), onOneEdge);

		Assert.floatEquals(120 + TurnModel.PERIOD, carried.x, EPSILON, "the glide did not advance along the band");
		Assert.floatEquals(-TurnModel.HALF_WIDTH, carried.y, EPSILON, "the glide should carry one edge onto the other — they are the same edge");
	}

	/** Sliding past an obstacle keeps the along-band motion, so a graze costs speed rather than the lap. **/
	function testGrazingAnObstacleSlides():Void {
		var along = TurnModel.obstacleAlong(3);
		var across = TurnModel.obstacleAcross(3);
		// stand just short of it, dead in line, and push forward-and-sideways
		var player = playerAt(along - TurnModel.OBSTACLE_HALF_DEPTH - 6, across);
		var before = player.pos.z;

		TurnCollision.tryMove(player, new h3d.Vector(0.7071, 0, 0.7071), 4);

		Assert.floatEquals(along - TurnModel.OBSTACLE_HALF_DEPTH - 6, player.pos.x, EPSILON, "the player pushed into the obstacle");
		Assert.isTrue(Math.abs(player.pos.z - before) > 1, "the sideways component was lost — the player stuck instead of sliding");
	}
}
