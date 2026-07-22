package biomes.conway;

import biomes.common.grid.GridMesh;
import biomes.common.grid.GridModel;
import game.MeshBuilder;
import graphics.Colours;

/**
	Renders Conway over the sphere grid:
	- every ring cell gets a dim floor tile
	- alive cells add a raised block
**/
class ConwayMesh {
	static inline final TILE_LIFT:Float = 0.03;
	static inline final LIVE_BLOCK_HEIGHT:Float = 5.0;

	public static function build(parent:h3d.scene.Object, state:ConwayState):Void {
		var floorPoints:Array<h3d.Vector> = [];
		var floorIdx:hxd.IndexBuffer = new hxd.IndexBuffer();
		var livePoints:Array<h3d.Vector> = [];
		var liveIdx:hxd.IndexBuffer = new hxd.IndexBuffer();

		for (row in 1...(GridModel.ROWS - 1)) {
			for (col in 0...GridModel.colsForRow(row)) {
				var cell = GridMesh.innerCornersOf(row, col);
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
			}
		}

		var floorMesh = new h3d.scene.Mesh(new h3d.prim.Polygon(floorPoints, floorIdx), parent);
		floorMesh.material.mainPass.addShader(new h3d.shader.FixedColor(Colours.CONWAY_TILE_DEAD));
		floorMesh.material.mainPass.culling = None;

		var liveMesh = new h3d.scene.Mesh(new h3d.prim.Polygon(livePoints, liveIdx), parent);
		liveMesh.material.mainPass.addShader(new h3d.shader.FixedColor(Colours.CONWAY_TILE_LIVE));
		liveMesh.material.mainPass.culling = None;
	}

	static function addBlock(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, base:Array<h3d.Vector>, height:Float):Void {
		var top = [
			base[0].add(base[0].normalized().scaled(-height)),
			base[1].add(base[1].normalized().scaled(-height)),
			base[2].add(base[2].normalized().scaled(-height)),
			base[3].add(base[3].normalized().scaled(-height)),
		];

		// Top face
		MeshBuilder.addQuad(points, idx, top[0], top[1], top[2], top[3]);
		// Side faces
		MeshBuilder.addQuad(points, idx, base[0], base[1], top[1], top[0]);
		MeshBuilder.addQuad(points, idx, base[1], base[2], top[2], top[1]);
		MeshBuilder.addQuad(points, idx, base[2], base[3], top[3], top[2]);
		MeshBuilder.addQuad(points, idx, base[3], base[0], top[0], top[3]);
	}

	static function lift(point:h3d.Vector, amount:Float):h3d.Vector {
		return point.add(point.normalized().scaled(-amount));
	}
}
