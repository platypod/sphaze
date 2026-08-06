package biomes.conway;

import biomes.common.space.sphere.SphereMath;
import biomes.conway.ConwayMaze.ConwayMazeData;
import entities.player.PlayerModel;
import utest.Assert;
import utest.Test;

/**
	Covers `ConwayCollision.tryMove`'s "airborne above `ConwayGrid.WALL_HEIGHT`
	clears a closed edge" gate — the mechanic behind standing on a live
	cell's own top and jumping over a wall from there.
**/
class ConwayCollisionTest extends Test {
	static inline final ROW:Int = 5;
	static inline final COL:Int = 10;

	function testTryMoveBlocksAStepAcrossAClosedEdgeAtGroundHeight():Void {
		var player = playerAtCellCenter(ROW, COL);

		var moved = ConwayCollision.tryMove(player, eastDirection(), stepAcrossOneColumn(), ConwayGrid.RADIUS, closedMaze());

		Assert.isFalse(moved);
	}

	function testTryMoveBlocksAStepWhenAirborneBelowWallHeight():Void {
		var player = playerAtCellCenter(ROW, COL);
		player.airborneHeight = ConwayGrid.YOUNG_BLOCK_HEIGHT; // standing on a freshly-born cell's own top, but short of the wall

		var moved = ConwayCollision.tryMove(player, eastDirection(), stepAcrossOneColumn(), ConwayGrid.RADIUS, closedMaze());

		Assert.isFalse(moved);
	}

	function testTryMoveAllowsAStepAcrossAClosedEdgeOnceAirborneAtWallHeight():Void {
		var player = playerAtCellCenter(ROW, COL);
		player.airborneHeight = ConwayGrid.WALL_HEIGHT;

		var moved = ConwayCollision.tryMove(player, eastDirection(), stepAcrossOneColumn(), ConwayGrid.RADIUS, closedMaze());

		Assert.isTrue(moved);
	}

	static function playerAtCellCenter(row:Int, col:Int):PlayerModel {
		var theta = Math.PI * (row + 1.5) / ConwayGrid.LAT_BANDS;
		var phi = 2 * Math.PI * (col + 0.5) / ConwayGrid.COLS;
		return new PlayerModel(ConwayGrid.cornerAt(theta, phi), eastDirectionAt(phi));
	}

	static function eastDirection():h3d.Vector {
		return eastDirectionAt(2 * Math.PI * (COL + 0.5) / ConwayGrid.COLS);
	}

	static function eastDirectionAt(phi:Float):h3d.Vector {
		return SphereMath.phiTangentAt(phi);
	}

	/** 0.75 of a column's own arc width at `ROW`'s colatitude — past the boundary into the neighbor cell, short of its own far edge. **/
	static function stepAcrossOneColumn():Float {
		var theta = Math.PI * (ROW + 1.5) / ConwayGrid.LAT_BANDS;
		var columnWidth = ConwayGrid.RADIUS * Math.sin(theta) * (2 * Math.PI / ConwayGrid.COLS);
		return columnWidth * 0.75;
	}

	static function closedMaze():ConwayMazeData {
		return {openEdges: new haxe.ds.StringMap(), coreEdges: new haxe.ds.StringMap()};
	}
}
