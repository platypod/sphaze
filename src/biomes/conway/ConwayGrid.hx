package biomes.conway;

import biomes.common.space.sphere.SphereMath;
import biomes.conway.ConwayMaze.ConwayMazeData;
import biomes.conway.ConwayMaze.ConwayNode;
import game.MeshBuilder;

typedef ConwayCorners = {
	nw:h3d.Vector,
	ne:h3d.Vector,
	se:h3d.Vector,
	sw:h3d.Vector
}

enum Pole {
	North;
	South;
}

/**
	A Conway-specific latitude/longitude grid over a larger sphere.

	The north/south poles are single cells of their own, rather than whole rows
	of wedge tiles collapsing into a point.
**/
class ConwayGrid {
	public static inline final RADIUS:Float = 174;

	/** Total latitude bands including the two pole caps. **/
	public static inline final LAT_BANDS:Int = 24;

	/** Ring rows between the two pole cells. **/
	public static inline final RING_ROWS:Int = LAT_BANDS - 2;

	public static inline final COLS:Int = 56;
	public static inline final TILE_GAP:Float = 1.5;

	public static function cornerAt(theta:Float, phi:Float):h3d.Vector {
		return SphereMath.sphericalToCartesian(RADIUS, theta, phi);
	}

	public static function innerCornersOf(row:Int, col:Int):ConwayCorners {
		var halfTheta = Math.PI / LAT_BANDS / 2;
		var halfPhi = Math.PI / COLS;
		var theta = Math.PI * (row + 1.5) / LAT_BANDS;
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

	public static function poleApex(pole:Pole):h3d.Vector {
		return switch pole {
			case North: cornerAt(0, 0);
			case South: cornerAt(Math.PI, 0);
		}
	}

	/** Perimeter of a pole cell, inset slightly from its neighboring ring row. */
	public static function polePerimeter(pole:Pole):Array<h3d.Vector> {
		var halfTheta = Math.PI / LAT_BANDS / 2;
		var insetTheta = Math.min(halfTheta * 0.45, TILE_GAP / RADIUS);
		var theta = switch pole {
			case North: Math.PI / LAT_BANDS - insetTheta;
			case South: Math.PI - Math.PI / LAT_BANDS + insetTheta;
		}

		var points:Array<h3d.Vector> = [];
		for (col in 0...COLS) {
			points.push(cornerAt(theta, 2 * Math.PI * col / COLS));
		}
		return points;
	}

	public static function eachRingCell(f:(row:Int, col:Int) -> Void):Void {
		for (row in 0...RING_ROWS) {
			for (col in 0...COLS) {
				f(row, col);
			}
		}
	}

	public static function eachPole(f:(pole:Pole) -> Void):Void {
		f(North);
		f(South);
	}

	public static function nodeAt(theta:Float, phi:Float):ConwayNode {
		var northBoundary = Math.PI / LAT_BANDS;
		var southBoundary = Math.PI - northBoundary;
		if (theta < northBoundary) {
			return PoleNode(North);
		}
		if (theta > southBoundary) {
			return PoleNode(South);
		}

		var band = Std.int(Math.floor(theta * LAT_BANDS / Math.PI));
		var row = band - 1;
		if (row < 0) {
			row = 0;
		}
		if (row > RING_ROWS - 1) {
			row = RING_ROWS - 1;
		}
		var col = wrapCol(Std.int(Math.floor(phi * COLS / (2 * Math.PI))));
		return RingNode(row, col);
	}

	public static function liveNeighborCount(state:ConwayState, maze:ConwayMazeData, row:Int, col:Int):Int {
		var total = 0;
		for (rowOffset in -1...2) {
			for (colOffset in -1...2) {
				if (rowOffset == 0 && colOffset == 0) {
					continue;
				}
				var otherRow = row + rowOffset;
				if (otherRow < 0 || otherRow >= RING_ROWS) {
					continue;
				}
				var otherCol = wrapCol(col + colOffset);
				if (state.isAlive(otherRow, otherCol) && allowsInfluence(maze, row, col, otherRow, otherCol, rowOffset, colOffset)) {
					total++;
				}
			}
		}

		if (row == 0 && state.isPoleAlive(North) && ConwayMaze.isOpen(maze, RingNode(row, col), PoleNode(North))) {
			total++;
		}
		if (row == RING_ROWS - 1 && state.isPoleAlive(South) && ConwayMaze.isOpen(maze, RingNode(row, col), PoleNode(South))) {
			total++;
		}
		return total;
	}

	public static function liveNeighborCountPole(state:ConwayState, maze:ConwayMazeData, pole:Pole):Int {
		var row = switch pole {
			case North: 0;
			case South: RING_ROWS - 1;
		}
		var total = 0;
		for (col in 0...COLS) {
			if (state.isAlive(row, col) && ConwayMaze.isOpen(maze, PoleNode(pole), RingNode(row, col))) {
				total++;
			}
		}
		return total;
	}

	public static function keyOf(row:Int, col:Int):String {
		return 'cell:$row:$col';
	}

	public static function keyOfPole(pole:Pole):String {
		return switch pole {
			case North: "pole:north";
			case South: "pole:south";
		}
	}

	public static function addPoleFan(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, apex:h3d.Vector, perimeter:Array<h3d.Vector>):Void {
		for (i in 0...perimeter.length) {
			MeshBuilder.addTriangle(points, idx, apex, perimeter[i], perimeter[(i + 1) % perimeter.length]);
		}
	}

	static function wrapCol(col:Int):Int {
		var wrapped = col % COLS;
		return wrapped < 0 ? wrapped + COLS : wrapped;
	}

	static function allowsInfluence(maze:ConwayMazeData, row:Int, col:Int, otherRow:Int, otherCol:Int, rowOffset:Int, colOffset:Int):Bool {
		var here = RingNode(row, col);
		var there = RingNode(otherRow, otherCol);
		if (rowOffset == 0 || colOffset == 0) {
			return ConwayMaze.isOpen(maze, here, there);
		}

		var viaHoriz = RingNode(row, wrapCol(col + colOffset));
		var viaVert = RingNode(otherRow, col);
		return (ConwayMaze.isOpen(maze, here, viaHoriz) && ConwayMaze.isOpen(maze, viaHoriz, there))
			|| (ConwayMaze.isOpen(maze, here, viaVert) && ConwayMaze.isOpen(maze, viaVert, there));
	}
}
