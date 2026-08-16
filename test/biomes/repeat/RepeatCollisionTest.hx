package biomes.repeat;

import biomes.common.space.flat.FlatSpace;
import entities.player.PlayerModel;
import utest.Assert;
import utest.Test;

/**
	Checks that what the player can walk through matches what the mesh
	draws, and that walking into a wall slides rather than stops.

	The agreement matters more than usual here: `RepeatMesh` and
	`RepeatCollision` both ask `RepeatModel.hasBuilding`, so a divergence
	is guaranteed to be *both* visibly missing and actually walkable —
	but only as long as neither of them starts deciding for itself.
**/
class RepeatCollisionTest extends Test {
	function playerAt(x:Float, z:Float):PlayerModel {
		return new PlayerModel(new h3d.Vector(x, 0, z), new h3d.Vector(0, 0, 1), 0, FlatSpace.INSTANCE);
	}

	/** A building's own centre is never standable. **/
	function testBuildingCentresAreSolid():Void {
		var checked = 0;
		for (plotX in 0...RepeatModel.PLOTS_PER_TILE) {
			for (plotZ in 0...RepeatModel.PLOTS_PER_TILE) {
				if (!RepeatModel.hasBuilding(0, 0, plotX, plotZ)) {
					continue;
				}
				checked++;
				var centre = RepeatModel.plotCentre(0, 0, plotX, plotZ);
				Assert.isFalse(RepeatCollision.isOpen(centre.x, centre.z), 'plot ($plotX, $plotZ) has a building but is standable');
			}
		}
		Assert.isTrue(checked > 0, "the spawn tile has no buildings to check");
	}

	/**
		**A diverged plot really is walkable.** This is the mechanic: the
		difference the player spots must be ground they can then stand on,
		or noticing and reaching stop being the same act.
	**/
	function testADivergedPlotIsWalkable():Void {
		var found = 0;
		for (i in -8...9) {
			for (j in -8...9) {
				var divergence = RepeatModel.divergenceOf(i, j);
				if (divergence == null) {
					continue;
				}
				found++;
				var centre = RepeatModel.plotCentre(i, j, divergence.plotX, divergence.plotZ);
				Assert.isTrue(RepeatCollision.isOpen(centre.x, centre.z), 'the divergence in tile ($i, $j) is not standable');

				// and the same plot of an untouched tile is not
				Assert.isTrue(RepeatModel.referenceHasBuilding(divergence.plotX, divergence.plotZ),
					'the divergence in tile ($i, $j) opens a plot that was open anyway');
			}
		}
		Assert.isTrue(found > 0, "no divergence found to check");
	}

	/** Walking straight into a wall slides along it rather than stopping — the axis-separated move, which a city of right angles needs constantly. **/
	function testWalkingIntoAWallSlidesAlongIt():Void {
		var solid = null;
		for (plotX in 0...RepeatModel.PLOTS_PER_TILE) {
			for (plotZ in 0...RepeatModel.PLOTS_PER_TILE) {
				if (RepeatModel.hasBuilding(0, 0, plotX, plotZ)) {
					solid = RepeatModel.plotCentre(0, 0, plotX, plotZ);
					break;
				}
			}
			if (solid != null) {
				break;
			}
		}
		Assert.notNull(solid, "the spawn tile has no building to walk into");

		// stand just south of the building, then push north-east into it
		var clearance = RepeatModel.buildingHalfExtent() + 6;
		var player = playerAt(solid.x, solid.z - clearance);
		var before = player.pos.x;

		RepeatCollision.tryMove(player, new h3d.Vector(0.7071, 0, 0.7071), 8);

		Assert.isTrue(player.pos.x > before + 1, "the sideways component of the move was lost — the player stuck instead of sliding");
		Assert.floatEquals(solid.z - clearance, player.pos.z, 1e-6, "the player pushed into the wall");
	}

	/** An unobstructed move is not interfered with. **/
	function testAnOpenMoveGoesThrough():Void {
		var spot = null;
		for (plotX in 0...RepeatModel.PLOTS_PER_TILE) {
			for (plotZ in 0...RepeatModel.PLOTS_PER_TILE) {
				var centre = RepeatModel.plotCentre(0, 0, plotX, plotZ);
				if (RepeatCollision.isOpen(centre.x, centre.z) && RepeatCollision.isOpen(centre.x + 2, centre.z)) {
					spot = centre;
					break;
				}
			}
			if (spot != null) {
				break;
			}
		}
		Assert.notNull(spot, "no open plot in the spawn tile");

		var player = playerAt(spot.x, spot.z);
		RepeatCollision.tryMove(player, new h3d.Vector(1, 0, 0), 2);
		Assert.floatEquals(spot.x + 2, player.pos.x, 1e-6, "an unobstructed move was blocked");
	}
}
