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

	/**
		How tall a *freshly born* live cell's own standable block rises
		above the base surface — shared between `ConwayMesh` (the visual
		block) and `groundHeightAt`/`ConwayCollision` (the real
		standing/jump-clearance height), so the two can never disagree
		about where a player's feet actually land. Combined with a second
		jump's own apex (`ConwayBiome.GRAVITY`'s own doc has the
		arithmetic — `~5.8`), `2 + 5.8 = 7.8` just clears `WALL_HEIGHT`
		(`7.5`) — raised directly ("reduce the newly-born cell as well,
		say 2 units high"), down from an earlier `5` that cleared with
		`3.3` to spare. `0.3` units of margin is tight (flagged directly
		when asked for): if the fixed-step physics' own discretization
		ever eats into it, `YOUNG_BLOCK_HEIGHT` is the first thing to nudge
		back up.
	**/
	public static inline final YOUNG_BLOCK_HEIGHT:Float = 2.0;

	/**
		How tall a live cell's own standable block rises once it's aged
		past `YOUNG_AGE_THRESHOLD` — raised directly ("only newly-born
		cells are big enough for the player to jump over a wall. The
		others are slightly shorter, which is not enough"), then nudged
		from `1` to `1.5` alongside `YOUNG_BLOCK_HEIGHT`'s own drop. A
		second jump's own apex is `~5.8`, so `1.5 + 5.8 = 7.3` stays `0.2`
		short of `WALL_HEIGHT` (`7.5`) — correctly insufficient, but with
		a thinner margin than the `1` this replaced (`0.71` short) for the
		same reason `YOUNG_BLOCK_HEIGHT`'s own doc flags.
	**/
	public static inline final AGED_BLOCK_HEIGHT:Float = 1.5;

	/**
		A cell's own age (`ConwayState.ageOf`), in generations, at or under
		which it still counts as "freshly born" (`YOUNG_BLOCK_HEIGHT`)
		rather than "settled" (`AGED_BLOCK_HEIGHT`) — shared between
		`ConwayMesh` (so a shorter block actually looks shorter) and
		`groundHeightAt` (so it actually stands shorter too). `4`
		generations (~3s at `ConwayBiome.STEP_INTERVAL`) is long enough
		that a fast-oscillating pattern (a blinker, period 2) stays tall
		the whole time it keeps oscillating — it never actually settles —
		while a cell that's part of a genuine still life ages past it and
		shrinks.
	**/
	public static inline final YOUNG_AGE_THRESHOLD:Int = 4;

	/**
		How tall a closed edge's own wall rises above the base surface —
		shared the same way `YOUNG_BLOCK_HEIGHT` is, between `ConwayMesh`'s
		visual wall and `ConwayCollision`'s "high enough to clear it" gate.
	**/
	public static inline final WALL_HEIGHT:Float = 7.5;

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

	/**
		The standable ground height directly below `(theta, phi)` — `0`
		unless the cell/pole here is alive, in which case
		`YOUNG_BLOCK_HEIGHT` or `AGED_BLOCK_HEIGHT` depending on its own
		age. Read fresh every tick by `ConwayBiome.applyGravity` (never
		cached), so a cell dying out from under a standing player drops them
		the same way any other biome's own vanishing floor would (`biomes.hub.HubBiome.applyGravity`'s
		`MazeShrine.wallTopHeightAt` is the same pattern, over an unmoving
		obstacle instead of a live one).
		@param state the Life layer to query.
		@param theta polar angle, see `biomes.common.space.sphere.SphereMath`.
		@param phi azimuth, see `biomes.common.space.sphere.SphereMath`.
		@return `0` if nothing's alive here, `YOUNG_BLOCK_HEIGHT`/`AGED_BLOCK_HEIGHT` otherwise.
	**/
	public static function groundHeightAt(state:ConwayState, theta:Float, phi:Float):Float {
		return switch nodeAt(theta, phi) {
			case PoleNode(pole): state.isPoleAlive(pole) ? blockHeightFor(state.poleAgeOf(pole)) : 0;
			case RingNode(row, col): state.isAlive(row, col) ? blockHeightFor(state.ageOf(row, col)) : 0;
		}
	}

	static function blockHeightFor(age:Int):Float {
		return age <= YOUNG_AGE_THRESHOLD ? YOUNG_BLOCK_HEIGHT : AGED_BLOCK_HEIGHT;
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
