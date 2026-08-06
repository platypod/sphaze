package biomes.conway;

import biomes.conway.ConwayGrid.Pole;
import biomes.conway.ConwayMaze.ConwayMazeData;
import biomes.conway.ConwayMaze.ConwayNode;
import game.MeshBuilder;
import graphics.Colours;
import graphics.shaders.ConwayWallGlow;

/**
	Renders Conway over the sphere grid:
	- every ring cell gets a dim floor tile
	- alive cells add a raised block, all the same hue
	  (`Colours.CONWAY_TILE_LIVE`) at a brightness that depends on
	  `ConwayState.age`/`justDied`: brighter than usual for a freshly born
	  cell (`ConwayGrid.YOUNG_AGE_THRESHOLD` and below), dimmer once it's
	  settled in, dimmer still for the one generation a cell just died in,
	  before it stops being drawn at all — raised directly (first three
	  separate hues, then "too much colours... keep unicolor-cells, but
	  make them brighter when they birth, dimmer when they age, dimmer
	  again when they die"). Height follows the same three stages — a
	  freshly born block (`ConwayGrid.YOUNG_BLOCK_HEIGHT`) is tallest,
	  standing tall enough for a jump off its top to clear a wall; a
	  settled one (`ConwayGrid.AGED_BLOCK_HEIGHT`) is shorter and
	  deliberately falls short of that (see that constant's own doc); the
	  one-generation dying flash (`DYING_BLOCK_HEIGHT`) is shorter still,
	  though purely cosmetic — nothing is ever standable on it.
	- closed maze edges add a `ConwayWallGlow` wall panel, lit by that edge's
	  own `ConwayMazeReactivity.edgeActivity`
	- a non-core edge that's currently open adds the same `ConwayWallGlow`
	  panel as a closed one, just faded to `GHOST_WALL_OPACITY` — raised
	  directly (first "make them red and transparent", then "actually keep
	  them their original color, but make them transparent"), so an opened
	  wall still reads as a former wall rather than looking like it was
	  never there. A core edge (`ConwayMaze.isCore`) never had a wall to
	  begin with, so it stays bare corridor either way.
**/
class ConwayMesh {
	static inline final TILE_LIFT:Float = 0.03;
	static inline final WALL_BASE_LIFT:Float = 0.02;

	/**
		Raised directly ("make the cells more transparent, say 25%
		opacity"): alpha-blended (`h3d.mat.BlendMode.Alpha`, `depthWrite =
		false` — same recipe `entities.hourglass.Hourglass.buildSign` uses
		for its own dim glass/sand fill) rather than opaque, so a live
		block reads as a ghostly presence over the floor tile underneath
		instead of fully hiding it.
	**/
	static inline final LIVE_BLOCK_OPACITY:Float = 0.25;

	/** How faded an opened reactive wall's own `ConwayWallGlow` panel is — see the class doc's own "keep them their original color, but make them transparent" ask. **/
	static inline final GHOST_WALL_OPACITY:Float = 0.15;

	/**
		`Colours.CONWAY_TILE_LIVE`'s own brightness multiplier for a
		freshly-born cell — above `1` so birth reads brighter than the base
		hue, not just "not dimmed yet." Raised directly ("too much
		difference between each state... it goes too dim, nearly
		invisible"): this and the two below it were `1.3`/`0.55`/`0.28` —
		tightened toward `1` and raised as a group so the dimmest state
		stays clearly visible rather than reading as barely-there.
	**/
	static inline final BIRTH_BRIGHTNESS:Float = 1.15;

	/** `Colours.CONWAY_TILE_LIVE`'s own brightness multiplier once a cell has settled in past `ConwayGrid.YOUNG_AGE_THRESHOLD` — see `BIRTH_BRIGHTNESS`'s own doc for why this moved up from `0.55`. **/
	static inline final AGED_BRIGHTNESS:Float = 0.9;

	/** `Colours.CONWAY_TILE_LIVE`'s own brightness multiplier for the one generation a cell just died in — see `BIRTH_BRIGHTNESS`'s own doc for why this moved up from `0.28`. **/
	static inline final DYING_BRIGHTNESS:Float = 0.7;

	/**
		How tall the one-generation "just died" flash block is — raised
		directly alongside `ConwayGrid.YOUNG_BLOCK_HEIGHT`/`AGED_BLOCK_HEIGHT`'s
		own drop ("reduce... the dying one to 1"). Lives here rather than on
		`ConwayGrid` because it's purely cosmetic: a dead cell is never
		`isAlive`, so `groundHeightAt` never returns this value — nothing
		is ever standable at this height, unlike the other two.
	**/
	static inline final DYING_BLOCK_HEIGHT:Float = 1.0;

	public static function build(parent:h3d.scene.Object, state:ConwayState, maze:ConwayMazeData):Void {
		var floorPoints:Array<h3d.Vector> = [];
		var floorIdx:hxd.IndexBuffer = new hxd.IndexBuffer();
		var youngPoints:Array<h3d.Vector> = [];
		var youngIdx:hxd.IndexBuffer = new hxd.IndexBuffer();
		var stalePoints:Array<h3d.Vector> = [];
		var staleIdx:hxd.IndexBuffer = new hxd.IndexBuffer();
		var dyingPoints:Array<h3d.Vector> = [];
		var dyingIdx:hxd.IndexBuffer = new hxd.IndexBuffer();
		var wallPoints:Array<h3d.Vector> = [];
		var wallIdx:hxd.IndexBuffer = new hxd.IndexBuffer();
		var wallUvs:Array<h3d.prim.UV> = [];
		var wallActivity:Array<h3d.col.Point> = [];
		var ghostPoints:Array<h3d.Vector> = [];
		var ghostIdx:hxd.IndexBuffer = new hxd.IndexBuffer();
		var ghostUvs:Array<h3d.prim.UV> = [];
		var ghostActivity:Array<h3d.col.Point> = [];

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
				if (state.ageOf(row, col) <= ConwayGrid.YOUNG_AGE_THRESHOLD) {
					addBlock(youngPoints, youngIdx, tile, ConwayGrid.YOUNG_BLOCK_HEIGHT);
				} else {
					addBlock(stalePoints, staleIdx, tile, ConwayGrid.AGED_BLOCK_HEIGHT);
				}
			} else if (state.justDiedAt(row, col)) {
				addBlock(dyingPoints, dyingIdx, tile, DYING_BLOCK_HEIGHT);
			}

			var eastPhi = 2 * Math.PI * (col + 1) / ConwayGrid.COLS;
			var northTheta = Math.PI * (row + 1) / ConwayGrid.LAT_BANDS;
			var southTheta = Math.PI * (row + 2) / ConwayGrid.LAT_BANDS;
			var westPhi = 2 * Math.PI * col / ConwayGrid.COLS;
			addEdge(state, maze, here, eastNode, ConwayGrid.cornerAt(northTheta, eastPhi), ConwayGrid.cornerAt(southTheta, eastPhi), wallPoints, wallIdx,
				wallUvs, wallActivity, ghostPoints, ghostIdx, ghostUvs, ghostActivity);
			var southOther = southNode != null ? southNode : ConwayNode.PoleNode(South);
			addEdge(state, maze, here, southOther, ConwayGrid.cornerAt(southTheta, westPhi), ConwayGrid.cornerAt(southTheta, eastPhi), wallPoints, wallIdx,
				wallUvs, wallActivity, ghostPoints, ghostIdx, ghostUvs, ghostActivity);
			if (row == 0) {
				addEdge(state, maze, here, ConwayNode.PoleNode(North), ConwayGrid.cornerAt(northTheta, westPhi), ConwayGrid.cornerAt(northTheta, eastPhi),
					wallPoints, wallIdx, wallUvs, wallActivity, ghostPoints, ghostIdx, ghostUvs, ghostActivity);
			}
		});
		ConwayGrid.eachPole((pole) -> addPole(floorPoints, floorIdx, youngPoints, youngIdx, stalePoints, staleIdx, dyingPoints, dyingIdx, state, pole));

		var floorMesh = new h3d.scene.Mesh(new h3d.prim.Polygon(floorPoints, floorIdx), parent);
		floorMesh.material.mainPass.addShader(new h3d.shader.FixedColor(Colours.CONWAY_TILE_DEAD));
		floorMesh.material.mainPass.culling = None;

		addLifecycleMesh(parent, youngPoints, youngIdx, scaledColor(Colours.CONWAY_TILE_LIVE, BIRTH_BRIGHTNESS));
		addLifecycleMesh(parent, stalePoints, staleIdx, scaledColor(Colours.CONWAY_TILE_LIVE, AGED_BRIGHTNESS));
		addLifecycleMesh(parent, dyingPoints, dyingIdx, scaledColor(Colours.CONWAY_TILE_LIVE, DYING_BRIGHTNESS));

		var wallPrim = new h3d.prim.Polygon(wallPoints, wallIdx);
		wallPrim.uvs = wallUvs;
		wallPrim.normals = wallActivity;
		var wallMesh = new h3d.scene.Mesh(wallPrim, parent);
		wallMesh.material.mainPass.addShader(new ConwayWallGlow(Colours.CONWAY_WALL_PANEL, Colours.CONWAY_WALL_GLOW));
		wallMesh.material.mainPass.culling = None;

		var ghostPrim = new h3d.prim.Polygon(ghostPoints, ghostIdx);
		ghostPrim.uvs = ghostUvs;
		ghostPrim.normals = ghostActivity;
		var ghostMesh = new h3d.scene.Mesh(ghostPrim, parent);
		ghostMesh.material.mainPass.addShader(new ConwayWallGlow(Colours.CONWAY_WALL_PANEL, Colours.CONWAY_WALL_GLOW, ConwayWallGlow.DEFAULT_SEAM_DENSITY,
			ConwayWallGlow.DEFAULT_REST_BRIGHTNESS, GHOST_WALL_OPACITY));
		ghostMesh.material.mainPass.culling = None;
		ghostMesh.material.mainPass.depthWrite = false;
		ghostMesh.material.blendMode = h3d.mat.BlendMode.Alpha;
	}

	/**
		Routes one edge to whichever of `ConwayWallGlow`'s solid wall or its
		own faded "ghost" it should render as right now — see the class doc
		for the three cases (closed, open-and-reactive, open-and-core). Both
		are the exact same geometry/UV/activity (`addWall`, just aimed at
		different buffers) — what actually tells them apart on screen is
		which mesh/shader instance (opaque vs. `GHOST_WALL_OPACITY`) ends up
		drawing them.
	**/
	static function addEdge(state:ConwayState, maze:ConwayMazeData, here:ConwayNode, other:ConwayNode, cornerA:h3d.Vector, cornerB:h3d.Vector,
			wallPoints:Array<h3d.Vector>, wallIdx:hxd.IndexBuffer, wallUvs:Array<h3d.prim.UV>, wallActivity:Array<h3d.col.Point>,
			ghostPoints:Array<h3d.Vector>, ghostIdx:hxd.IndexBuffer, ghostUvs:Array<h3d.prim.UV>, ghostActivity:Array<h3d.col.Point>):Void {
		var activity = ConwayMazeReactivity.edgeActivity(state, here, other);
		if (!ConwayMaze.isOpen(maze, here, other)) {
			addWall(wallPoints, wallIdx, wallUvs, wallActivity, cornerA, cornerB, activity);
		} else if (!ConwayMaze.isCore(maze, here, other)) {
			addWall(ghostPoints, ghostIdx, ghostUvs, ghostActivity, cornerA, cornerB, activity);
		}
	}

	/** One of the three lifecycle buckets (young/stale/dying) as its own alpha-blended mesh — same `LIVE_BLOCK_OPACITY` and hue for all three, just a different pre-scaled brightness each (see `scaledColor`). **/
	static function addLifecycleMesh(parent:h3d.scene.Object, points:Array<h3d.Vector>, idx:hxd.IndexBuffer, color:Int):Void {
		var mesh = new h3d.scene.Mesh(new h3d.prim.Polygon(points, idx), parent);
		mesh.material.mainPass.addShader(new h3d.shader.FixedColor(color, LIVE_BLOCK_OPACITY));
		mesh.material.mainPass.culling = None;
		mesh.material.mainPass.depthWrite = false;
		mesh.material.blendMode = h3d.mat.BlendMode.Alpha;
	}

	/**
		`color`'s own RGB channels scaled by `factor` (clamped to stay a
		valid byte), alpha untouched — how the same hue reads brighter or
		dimmer per lifecycle stage without ever becoming a different color.
		@param color the base color to scale.
		@param factor brightness multiplier — `1` leaves it unchanged, `>1` brightens (clamped at white), `<1` dims (clamped at black).
		@return the scaled color, alpha bits zeroed (callers pass alpha separately, e.g. `h3d.shader.FixedColor`'s own second constructor argument).
	**/
	static function scaledColor(color:Int, factor:Float):Int {
		var r = clampByte(((color >> 16) & 0xFF) * factor);
		var g = clampByte(((color >> 8) & 0xFF) * factor);
		var b = clampByte((color & 0xFF) * factor);
		return (r << 16) | (g << 8) | b;
	}

	static function clampByte(value:Float):Int {
		return Std.int(Math.min(255, Math.max(0, value)));
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

	static function addPole(floorPoints:Array<h3d.Vector>, floorIdx:hxd.IndexBuffer, youngPoints:Array<h3d.Vector>, youngIdx:hxd.IndexBuffer,
			stalePoints:Array<h3d.Vector>, staleIdx:hxd.IndexBuffer, dyingPoints:Array<h3d.Vector>, dyingIdx:hxd.IndexBuffer, state:ConwayState,
			pole:Pole):Void {
		var apex = lift(ConwayGrid.poleApex(pole), TILE_LIFT);
		var perimeter = [for (point in ConwayGrid.polePerimeter(pole)) lift(point, TILE_LIFT)];
		ConwayGrid.addPoleFan(floorPoints, floorIdx, apex, perimeter);

		if (state.isPoleAlive(pole)) {
			if (state.poleAgeOf(pole) <= ConwayGrid.YOUNG_AGE_THRESHOLD) {
				addPoleBlock(youngPoints, youngIdx, apex, perimeter, ConwayGrid.YOUNG_BLOCK_HEIGHT);
			} else {
				addPoleBlock(stalePoints, staleIdx, apex, perimeter, ConwayGrid.AGED_BLOCK_HEIGHT);
			}
		} else if (state.poleJustDiedAt(pole)) {
			addPoleBlock(dyingPoints, dyingIdx, apex, perimeter, DYING_BLOCK_HEIGHT);
		}
	}

	static function addPoleBlock(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, apex:h3d.Vector, perimeter:Array<h3d.Vector>, height:Float):Void {
		var topApex = lift(apex, height);
		var topPerimeter = [for (point in perimeter) lift(point, height)];
		ConwayGrid.addPoleFan(points, idx, topApex, topPerimeter);
		for (i in 0...perimeter.length) {
			MeshBuilder.addQuad(points, idx, perimeter[i], perimeter[(i + 1) % perimeter.length], topPerimeter[(i + 1) % perimeter.length], topPerimeter[i]);
		}
	}

	static function lift(point:h3d.Vector, amount:Float):h3d.Vector {
		return point.add(point.normalized().scaled(-amount));
	}

	/**
		Appends one wall quad, plus the `ConwayWallGlow` UVs (`u` = world
		distance along the wall, `v` = height fraction) and per-vertex
		activity (packed into the normal's `x` — see that shader's own doc)
		that make it read as this edge's own current state.
	**/
	static function addWall(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, uvs:Array<h3d.prim.UV>, activityOut:Array<h3d.col.Point>, edgeA:h3d.Vector,
			edgeB:h3d.Vector, activity:Float):Void {
		var baseA = lift(edgeA, WALL_BASE_LIFT);
		var baseB = lift(edgeB, WALL_BASE_LIFT);
		var topA = lift(baseA, ConwayGrid.WALL_HEIGHT);
		var topB = lift(baseB, ConwayGrid.WALL_HEIGHT);
		MeshBuilder.addQuad(points, idx, baseA, baseB, topB, topA);

		var wallLength = baseA.sub(baseB).length();
		uvs.push(new h3d.prim.UV(0, 0));
		uvs.push(new h3d.prim.UV(wallLength, 0));
		uvs.push(new h3d.prim.UV(wallLength, 1));
		uvs.push(new h3d.prim.UV(0, 1));
		for (_ in 0...4) {
			activityOut.push(new h3d.col.Point(activity, activity, activity));
		}
	}

	static function wrapCol(col:Int):Int {
		var wrapped = col % ConwayGrid.COLS;
		return wrapped < 0 ? wrapped + ConwayGrid.COLS : wrapped;
	}
}
