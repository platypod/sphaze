package game;

/**
	Generic mesh-assembly helpers with no grid/biome knowledge — extracted
	from what used to be `maze.MazeMesh` specifically because
	`biomes.hub.Hub` already depended on two of them (`addQuad`,
	`WALL_TEXTURE_TILE_SIZE`) despite the hub not being grid-based at all:
	exactly the "reused from a specific biome's own package" pattern this
	restructuring moved away from everywhere else.
**/
class MeshBuilder {
	/** World units per repeat of a tiled wall/panel texture — shared so different biomes' textured surfaces read at a consistent texel density. **/
	public static inline final WALL_TEXTURE_TILE_SIZE:Float = 12;

	/**
		Appends a quad (as two triangles) to `points`/`idx`.
		@param points vertex buffer to append to.
		@param idx index buffer to append to.
		@param a first corner, in perimeter order.
		@param b second corner, in perimeter order.
		@param c third corner, in perimeter order.
		@param d fourth corner, in perimeter order.
	**/
	public static function addQuad(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, a:h3d.Vector, b:h3d.Vector, c:h3d.Vector, d:h3d.Vector):Void {
		var start = points.length;
		points.push(a);
		points.push(b);
		points.push(c);
		points.push(d);

		idx.push(start);
		idx.push(start + 1);
		idx.push(start + 2);
		idx.push(start);
		idx.push(start + 2);
		idx.push(start + 3);
	}

	/**
		Appends a triangle to `points`/`idx` — for a fan/variable-vertex-count
		triangulation (e.g. `grid.GridMesh.addFloor`) rather than `addQuad`'s
		fixed four.
		@param points vertex buffer to append to.
		@param idx index buffer to append to.
		@param a first corner.
		@param b second corner.
		@param c third corner.
	**/
	public static function addTriangle(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, a:h3d.Vector, b:h3d.Vector, c:h3d.Vector):Void {
		var start = points.length;
		points.push(a);
		points.push(b);
		points.push(c);

		idx.push(start);
		idx.push(start + 1);
		idx.push(start + 2);
	}
}
