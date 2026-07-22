package biomes.conway;

import biomes.common.space.sphere.SphereMath;

typedef ConwayCorners = {
	nw:h3d.Vector,
	ne:h3d.Vector,
	se:h3d.Vector,
	sw:h3d.Vector
}

/**
	A Conway-specific latitude/longitude grid over a larger sphere.

	Unlike `biomes.common.grid.GridModel`, this stays local to the Conway biome:
	it needs a much denser tiling and no wall/collision topology at all.
**/
class ConwayGrid {
	/** Twice the maze sphere's radius — this biome wants the extra scale locally only. **/
	public static inline final RADIUS:Float = 174;

	/** Twice the old north/south subdivision, so the doubled-radius sphere keeps the same tile height. **/
	public static inline final ROWS:Int = 24;

	/** Twice the old east/west subdivision, same reasoning as `ROWS`. **/
	public static inline final COLS:Int = 56;

	/** Small physical gap between neighboring tiles, so dead cells read as separate slabs rather than one continuous skin. **/
	public static inline final TILE_GAP:Float = 1.5;

	public static function cornerAt(theta:Float, phi:Float):h3d.Vector {
		return SphereMath.sphericalToCartesian(RADIUS, theta, phi);
	}

	public static function cornersOf(row:Int, col:Int):ConwayCorners {
		var theta0 = Math.PI * row / ROWS;
		var theta1 = Math.PI * (row + 1) / ROWS;
		var phi0 = 2 * Math.PI * col / COLS;
		var phi1 = 2 * Math.PI * (col + 1) / COLS;
		return {
			nw: cornerAt(theta0, phi0),
			ne: cornerAt(theta0, phi1),
			se: cornerAt(theta1, phi1),
			sw: cornerAt(theta1, phi0)
		};
	}

	public static function innerCornersOf(row:Int, col:Int):ConwayCorners {
		var halfTheta = Math.PI / ROWS / 2;
		var halfPhi = Math.PI / COLS;
		var theta = Math.PI * (row + 0.5) / ROWS;
		var phi = 2 * Math.PI * (col + 0.5) / COLS;

		var insetTheta = Math.min(halfTheta * 0.45, TILE_GAP / RADIUS);
		var northTheta = theta - halfTheta;
		var southTheta = theta + halfTheta;
		var insetPhiNorth = Math.min(halfPhi * 0.45, TILE_GAP / (RADIUS * Math.max(0.05, Math.sin(northTheta))));
		var insetPhiSouth = Math.min(halfPhi * 0.45, TILE_GAP / (RADIUS * Math.max(0.05, Math.sin(southTheta))));

		return {
			nw: cornerAt(theta - halfTheta + insetTheta, phi - halfPhi + insetPhiNorth),
			ne: cornerAt(theta - halfTheta + insetTheta, phi + halfPhi - insetPhiNorth),
			se: cornerAt(theta + halfTheta - insetTheta, phi + halfPhi - insetPhiSouth),
			sw: cornerAt(theta + halfTheta - insetTheta, phi - halfPhi + insetPhiSouth)
		};
	}

	public static function eachCell(f:(row:Int, col:Int) -> Void):Void {
		for (row in 0...ROWS) {
			for (col in 0...COLS) {
				f(row, col);
			}
		}
	}

	/**
		Conway's ordinary 8-neighbor Moore neighborhood, wrapping east/west but
		not across the poles.
	**/
	public static function liveNeighborCount(state:ConwayState, row:Int, col:Int):Int {
		var total = 0;
		for (rowOffset in -1...2) {
			for (colOffset in -1...2) {
				if (rowOffset == 0 && colOffset == 0) {
					continue;
				}
				var otherRow = row + rowOffset;
				if (otherRow < 0 || otherRow >= ROWS) {
					continue;
				}
				var otherCol = wrapCol(col + colOffset);
				if (state.isAlive(otherRow, otherCol)) {
					total++;
				}
			}
		}
		return total;
	}

	public static function keyOf(row:Int, col:Int):String {
		return 'cell:$row:$col';
	}

	static function wrapCol(col:Int):Int {
		var wrapped = col % COLS;
		return wrapped < 0 ? wrapped + COLS : wrapped;
	}
}
