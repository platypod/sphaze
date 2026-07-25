package biomes.conway;

import biomes.conway.ConwayGrid.Pole;
import biomes.conway.ConwayMaze.ConwayMazeData;
import biomes.conway.ConwayMaze.ConwayNode;
import game.MeshBuilder;
import graphics.Colours;

/**
	Renders Conway over the sphere grid:
	- every ring cell gets a dim floor tile
	- alive cells add a raised block
	- closed maze edges add neon wall planes
**/
class ConwayMesh {
	static inline final TILE_LIFT:Float = 0.03;
	static inline final LIVE_BLOCK_HEIGHT:Float = 5.0;
	static inline final WALL_HEIGHT:Float = 7.5;
	static inline final WALL_BASE_LIFT:Float = 0.02;

	public static function build(parent:h3d.scene.Object, state:ConwayState, maze:ConwayMazeData):Void {
		var floorPoints:Array<h3d.Vector> = [];
		var floorIdx:hxd.IndexBuffer = new hxd.IndexBuffer();
		var livePoints:Array<h3d.Vector> = [];
		var liveIdx:hxd.IndexBuffer = new hxd.IndexBuffer();
		var wallPoints:Array<h3d.Vector> = [];
		var wallIdx:hxd.IndexBuffer = new hxd.IndexBuffer();

		ConwayGrid.eachRingCell((row, col) -> {
			var cell = ConwayGrid.innerCornersOf(row, col);
			var here = ConwayNode.RingNode(row, col);
			var eastCol = wrapCol(col + 1);
			var eastNode = ConwayNode.RingNode(row, eastCol);
			var southRow = row + 1;
			var southNode = southRow < ConwayGrid.RING_ROWS ? ConwayNode.RingNode(southRow, col) : null;
			var tile = [
				lift(cell.nw, TILE_LIFT),
				lift(cell.ne, TILE_LIFT),
				lift(cell.se, TILE_LIFT),
				lift(cell.sw, TILE_LIFT),
			];
			MeshBuilder.addQuad(floorPoints, floorIdx, tile[0], tile[1], tile[2], tile[3]);
			if (state.isAlive(row, col)) {
				addBlock(livePoints, liveIdx, tile, LIVE_BLOCK_HEIGHT);
			}

			if (!ConwayMaze.isOpen(maze, here, eastNode)) {
				var eastPhi = 2 * Math.PI * (col + 1) / ConwayGrid.COLS;
				var northTheta = Math.PI * (row + 1) / ConwayGrid.LAT_BANDS;
				var southTheta = Math.PI * (row + 2) / ConwayGrid.LAT_BANDS;
				addWall(wallPoints, wallIdx, ConwayGrid.cornerAt(northTheta, eastPhi), ConwayGrid.cornerAt(southTheta, eastPhi));
			}
			if (southNode != null) {
				if (!ConwayMaze.isOpen(maze, here, southNode)) {
					var southTheta = Math.PI * (row + 2) / ConwayGrid.LAT_BANDS;
					var westPhi = 2 * Math.PI * col / ConwayGrid.COLS;
					var eastPhi = 2 * Math.PI * (col + 1) / ConwayGrid.COLS;
					addWall(wallPoints, wallIdx, ConwayGrid.cornerAt(southTheta, westPhi), ConwayGrid.cornerAt(southTheta, eastPhi));
				}
			} else if (!ConwayMaze.isOpen(maze, here, ConwayNode.PoleNode(South))) {
				var southTheta = Math.PI * (row + 2) / ConwayGrid.LAT_BANDS;
				var westPhi = 2 * Math.PI * col / ConwayGrid.COLS;
				var eastPhi = 2 * Math.PI * (col + 1) / ConwayGrid.COLS;
				addWall(wallPoints, wallIdx, ConwayGrid.cornerAt(southTheta, westPhi), ConwayGrid.cornerAt(southTheta, eastPhi));
			}
			if (row == 0 && !ConwayMaze.isOpen(maze, here, ConwayNode.PoleNode(North))) {
				var northTheta = Math.PI * (row + 1) / ConwayGrid.LAT_BANDS;
				var westPhi = 2 * Math.PI * col / ConwayGrid.COLS;
				var eastPhi = 2 * Math.PI * (col + 1) / ConwayGrid.COLS;
				addWall(wallPoints, wallIdx, ConwayGrid.cornerAt(northTheta, westPhi), ConwayGrid.cornerAt(northTheta, eastPhi));
			}
		});
		ConwayGrid.eachPole((pole) -> addPole(floorPoints, floorIdx, livePoints, liveIdx, state, pole));

		var floorMesh = new h3d.scene.Mesh(new h3d.prim.Polygon(floorPoints, floorIdx), parent);
		floorMesh.material.mainPass.addShader(new h3d.shader.FixedColor(Colours.CONWAY_TILE_DEAD));
		floorMesh.material.mainPass.culling = None;

		var liveMesh = new h3d.scene.Mesh(new h3d.prim.Polygon(livePoints, liveIdx), parent);
		liveMesh.material.mainPass.addShader(new h3d.shader.FixedColor(Colours.CONWAY_TILE_LIVE));
		liveMesh.material.mainPass.culling = None;

		var wallMesh = new h3d.scene.Mesh(new h3d.prim.Polygon(wallPoints, wallIdx), parent);
		wallMesh.material.mainPass.addShader(new h3d.shader.FixedColor(Colours.CONWAY_WALL_NEON));
		wallMesh.material.mainPass.culling = None;
	}

	static function addBlock(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, base:Array<h3d.Vector>, height:Float):Void {
		var top = [
			base[0].add(base[0].normalized().scaled(-height)),
			base[1].add(base[1].normalized().scaled(-height)),
			base[2].add(base[2].normalized().scaled(-height)),
			base[3].add(base[3].normalized().scaled(-height)),
		];

		MeshBuilder.addQuad(points, idx, top[0], top[1], top[2], top[3]);
		MeshBuilder.addQuad(points, idx, base[0], base[1], top[1], top[0]);
		MeshBuilder.addQuad(points, idx, base[1], base[2], top[2], top[1]);
		MeshBuilder.addQuad(points, idx, base[2], base[3], top[3], top[2]);
		MeshBuilder.addQuad(points, idx, base[3], base[0], top[0], top[3]);
	}

	static function addPole(floorPoints:Array<h3d.Vector>, floorIdx:hxd.IndexBuffer, livePoints:Array<h3d.Vector>, liveIdx:hxd.IndexBuffer, state:ConwayState,
			pole:Pole):Void {
		var apex = lift(ConwayGrid.poleApex(pole), TILE_LIFT);
		var perimeter = [for (point in ConwayGrid.polePerimeter(pole)) lift(point, TILE_LIFT)];
		ConwayGrid.addPoleFan(floorPoints, floorIdx, apex, perimeter);
		if (!state.isPoleAlive(pole)) {
			return;
		}

		var topApex = lift(apex, LIVE_BLOCK_HEIGHT);
		var topPerimeter = [for (point in perimeter) lift(point, LIVE_BLOCK_HEIGHT)];
		ConwayGrid.addPoleFan(livePoints, liveIdx, topApex, topPerimeter);
		for (i in 0...perimeter.length) {
			MeshBuilder.addQuad(livePoints, liveIdx, perimeter[i], perimeter[(i + 1) % perimeter.length], topPerimeter[(i + 1) % perimeter.length],
				topPerimeter[i]);
		}
	}

	static function lift(point:h3d.Vector, amount:Float):h3d.Vector {
		return point.add(point.normalized().scaled(-amount));
	}

	static function addWall(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, edgeA:h3d.Vector, edgeB:h3d.Vector):Void {
		var baseA = lift(edgeA, WALL_BASE_LIFT);
		var baseB = lift(edgeB, WALL_BASE_LIFT);
		var topA = lift(baseA, WALL_HEIGHT);
		var topB = lift(baseB, WALL_HEIGHT);
		MeshBuilder.addQuad(points, idx, baseA, baseB, topB, topA);
	}

	static function wrapCol(col:Int):Int {
		var wrapped = col % ConwayGrid.COLS;
		return wrapped < 0 ? wrapped + ConwayGrid.COLS : wrapped;
	}
}
