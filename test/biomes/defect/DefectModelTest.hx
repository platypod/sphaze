package biomes.defect;

import biomes.common.space.flat.FlatSpace;
import entities.player.PlayerModel;
import utest.Assert;
import utest.Test;

/**
	Checks the holonomy directly — that a loop enclosing the apex comes
	back turned by the defect angle, and a loop that does not, does not.

	That contrast **is** the space, and it is the sort of thing that would
	be invisible while broken: a defect applied on every step, or on none,
	or with the wrong sign, all produce a plain that walks perfectly
	normally. The player would simply never learn anything, with no
	symptom to notice.
**/
class DefectModelTest extends Test {
	static inline final EPSILON:Float = 1e-9;

	function playerAt(x:Float, z:Float, facingX:Float, facingZ:Float):PlayerModel {
		return new PlayerModel(new h3d.Vector(x, 0, z), new h3d.Vector(facingX, 0, facingZ), 0, FlatSpace.INSTANCE);
	}

	/** The heading angle of a player, in `[0, 2π)`. **/
	function headingOf(player:PlayerModel):Float {
		return DefectModel.angleOf(player.forward.x, player.forward.z);
	}

	/**
		Walks one full loop of the cone, carrying the heading.

		**One loop is `CONE_ANGLE` of chart angle, not `2π`** — that is
		what a cone *is*, and getting it wrong is how the first version of
		this test failed. It also stepped by overwriting the position on a
		fixed circle, which threw away each wrap's own rotation of the
		position; the player has to continue from where the identification
		put them.

		Between wraps the heading is simply held constant, which in flat
		space *is* parallel transport — so every bit of the rotation this
		measures comes from crossing the seam.
		@param loops how many times round.
		@return how far the heading turned, in `[0, 2π)`.
	**/
	function turnAfterLoops(loops:Int):Float {
		var radius = 120.0;
		var player = playerAt(radius * Math.cos(0.05), radius * Math.sin(0.05), 0, 1);
		var startHeading = headingOf(player);

		var steps = 900 * loops;
		var stepAngle = DefectModel.CONE_ANGLE * loops / steps;
		for (_ in 0...steps) {
			var moved = DefectModel.rotate(player.pos.x, player.pos.z, stepAngle);
			player.pos = new h3d.Vector(moved.x, player.pos.y, moved.z);
			DefectCollision.wrapIfNeeded(player);
		}

		var turned = headingOf(player) - startHeading;
		return ((turned % (2 * Math.PI)) + 2 * Math.PI) % (2 * Math.PI);
	}

	/**
		**Walking all the way round the apex turns you by the defect
		angle** — the whole lesson, measured.

		The heading is parallel-transported the entire way, so all of the
		rotation comes from the one seam crossing. That is exactly what
		"curvature concentrated at a point" means.
	**/
	function testCirclingTheApexTurnsYouByTheDefectAngle():Void {
		Assert.floatEquals(DefectModel.DEFECT_ANGLE, turnAfterLoops(1), 1e-6, "a full circuit of the apex should turn you by exactly the defect angle");
	}

	/** **And going round twice turns you by twice as much** — the continuous dial the design asks for, rather than a coin flip. **/
	function testCirclingTwiceTurnsYouTwiceAsFar():Void {
		Assert.floatEquals(2 * DefectModel.DEFECT_ANGLE, turnAfterLoops(2), 1e-6, "two circuits should compose into twice the defect");
	}

	/**
		**A loop that does not enclose the apex changes nothing** — the
		other half of the claim, and the half that makes the space *flat*
		rather than merely strange. Without it, "curvature is concentrated"
		would be untested and the space could be uniformly curved for all
		anyone could tell.
	**/
	function testALoopBesideTheApexChangesNothing():Void {
		// a circle of radius 40 centred well off the apex, nowhere near enclosing it
		var centreX = 260.0;
		var centreZ = 0.0;
		var player = playerAt(centreX + 40, centreZ, 0, 1);
		var startHeading = headingOf(player);

		for (i in 1...361) {
			var angle = 2 * Math.PI * i / 360;
			player.pos = new h3d.Vector(centreX + 40 * Math.cos(angle), 0, centreZ + 40 * Math.sin(angle));
			DefectCollision.wrapIfNeeded(player);
		}

		Assert.floatEquals(startHeading, headingOf(player), 1e-9, "a loop not enclosing the apex should leave you exactly as you were");
	}

	/** Crossing the seam and crossing back is an exact round trip, so the player can always retrace their steps. **/
	function testCrossingAndReturningIsExact():Void {
		var start = playerAt(100 * Math.cos(0.01), 100 * Math.sin(0.01), 1, 0);

		// step backwards over the seam at angle 0, then forwards again
		var out = playerAt(100 * Math.cos(-0.01), 100 * Math.sin(-0.01), 1, 0);
		DefectCollision.wrapIfNeeded(out);
		Assert.notEquals(0, DefectModel.seamCrossing(100 * Math.cos(-0.01), 100 * Math.sin(-0.01)), "stepping below angle 0 should be a crossing");

		var back = DefectModel.rotate(out.pos.x, out.pos.z, -DefectModel.CONE_ANGLE);
		Assert.floatEquals(100 * Math.cos(-0.01), back.x, 1e-9);
		Assert.floatEquals(100 * Math.sin(-0.01), back.z, 1e-9);
		Assert.floatEquals(100, DefectModel.radiusOf(start.pos.x, start.pos.z), 1e-9, "the wedge should not change anyone's distance from the apex");
	}

	/** The two ways out of the wedge are told apart, which is the one place this could silently pick the wrong rotation. **/
	function testTheTwoSeamCrossingsAreDistinguished():Void {
		var justPastFarEdge = DefectModel.CONE_ANGLE + 0.01;
		var justBelowZero = 2 * Math.PI - 0.01;

		Assert.equals(-1, DefectModel.seamCrossing(Math.cos(justPastFarEdge), Math.sin(justPastFarEdge)), "stepping past the far edge should rotate back");
		Assert.equals(1, DefectModel.seamCrossing(Math.cos(justBelowZero), Math.sin(justBelowZero)), "stepping below zero should rotate forward");
		Assert.equals(0, DefectModel.seamCrossing(Math.cos(1.0), Math.sin(1.0)), "a position inside the wedge is not a crossing");
	}

	/** Wrapping preserves distance from the apex — a rotation is an isometry, and the player must never be teleported nearer or further. **/
	function testWrappingPreservesTheDistanceFromTheApex():Void {
		var angle = DefectModel.CONE_ANGLE + 0.05;
		var player = playerAt(83 * Math.cos(angle), 83 * Math.sin(angle), 1, 0);
		DefectCollision.wrapIfNeeded(player);

		Assert.floatEquals(83, DefectModel.radiusOf(player.pos.x, player.pos.z), 1e-9);
		Assert.floatEquals(1, player.forward.length(), 1e-9, "facing stopped being a unit vector");
	}

	/**
		Every marker is drawn exactly once, inside a window of one cone
		angle centred on the player — see `DefectModel.drawAngleFor`. A
		marker drawn twice would put the same place in two spots at once,
		which is precisely the illusion this space must not create.
	**/
	function testEveryMarkerIsPlacedOnceWithinTheWindow():Void {
		for (playerAngle in [0.0, 1.3, Math.PI, 5.9]) {
			for (i in 0...48) {
				var coneAngle = DefectModel.CONE_ANGLE * i / 48;
				var drawn = DefectModel.drawAngleFor(coneAngle, playerAngle);
				var offset = drawn - playerAngle;

				Assert.isTrue(offset > -DefectModel.CONE_ANGLE / 2 - EPSILON && offset <= DefectModel.CONE_ANGLE / 2 + EPSILON,
					'marker at $coneAngle fell outside the window for a player at $playerAngle');
				// and it is genuinely the same point on the cone
				var difference = (drawn - coneAngle) / DefectModel.CONE_ANGLE;
				Assert.floatEquals(Math.round(difference), difference, 1e-9, "the drawn angle is not a whole number of cone angles from the marker's own");
			}
		}
	}
}
