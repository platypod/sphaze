package biomes.hub;

import biomes.common.grid.GridGeometry;
import biomes.hub.HubStructure.StructureBasis;
import entities.painting.PaintingModel;
import entities.player.PlayerModel;
import game.MeshBuilder;
import graphics.shaders.UnlitTexture;

/**
	A small landmark reminding the player of the maze, standing wherever
	`HubBiome` anchors it: seven straight `wall_stone` walls, laid out as a
	single continuous square spiral (each wall longer than the last, turning
	the same way every time) rather than the maze's own lat/long grid — that
	grid exists to wrap a whole biome around a sphere; a decorative structure
	this size doesn't need it, just something that reads as "a maze" at a
	glance.

	Built and collided against entirely in `HubStructure`'s own local
	`(u, v)` frame — see its class doc for why that's a reasonable
	approximation at this scale. Wall 1 (the shortest, drawn first) sits
	right at the local origin; each numbered wall after it is one arm
	further out. The player walks in from the wide-open end of wall 7 and
	follows the spiral inward to wall 2, where the maze's own painting
	mounts on the inner face — matching "the second from the center."

	Its own walls have real, standable-on-top collision (`blocksMovement`'s
	own `playerHeight` parameter, `wallTopHeightAt`) — hooman, directly:
	"make sure the top part of the wall has a hitbox too, so the player can
	jump and walk on a wall."
**/
class MazeShrine {
	/**
		Deliberately its own value, not `biomes.common.grid.GridMesh.WALL_HEIGHT`
		(12, what this landmark's walls used to match) — tall and imposing.
		Went `2` (a previous round, specifically so a jump could reach the
		top) → `5` ("nearly as tall as the camera is high," `entities.player.Camera.EYE_HEIGHT`
		`6`) → `10` ("make it twice as high," directly) → `12` ("20% higher
		again," directly). The jump-and-stand-on-top collision itself
		(`blocksMovement`'s own `playerHeight` parameter, `wallTopHeightAt`)
		stays regardless of how unreachable this makes it — a jump only
		clears `game.GameLoop.JUMP_IMPULSE`/hub `GRAVITY`'s own
		`impulse² / (2 × gravity) ≈ 2.7` — kept on purpose, not an oversight:
		"leave the jump mechanic even if it becomes unreachable. It might be
		useful later."
	**/
	static inline final WALL_HEIGHT:Float = 12;

	/**
		How far a world point's own `HubStructure.localUV`-reported `height`
		can be from this structure's local ground before a query treats it
		as nowhere near the shrine at all, regardless of what its `(u, v)`
		happens to read — the guard against the antipodal-collapse bug
		`localUV`'s own class doc describes (a point diametrically opposite
		`basis.origin` projects to local `(u, v) = (0, 0)`, indistinguishable
		from standing right on top of the shrine, unless something also
		checks `height`). Comfortably bigger than anything about this small
		structure (`WALL_HEIGHT` plus the tallest reachable jump) ever needs,
		comfortably smaller than `2 * HubModel.RADIUS` (the antipodal
		point's own `height`) — not a tuned value, just "obviously one, not
		the other."
	**/
	static inline final HEIGHT_SANITY_BOUND:Float = 30;

	/** How much longer each successive wall is than the last — also the spiral's own radial growth per arm. Tripled from an initial `2.4` (hooman: "still much too small... make them thrice bigger") — the wall's own footprint scales with this; height (`WALL_HEIGHT`) is unrelated and doesn't. **/
	static inline final ARM_UNIT:Float = 7.2;

	/** Half a wall's own real thickness (`GridGeometry.WALL_THICKNESS`, matching the real maze's own walls), plus `GridGeometry.COLLISION_CLEARANCE` beyond that face — collision blocks within this distance of any wall segment's own centerline, mirroring `biomes.common.grid.GridModel.wallZoneNeighbor`'s own "thickness plus clearance past the visible face" reasoning. Also doubles as the top surface's own half-width (`wallTopHeightAt`) — the same footprint, just queried from above instead of the side. **/
	static inline final WALL_CLEARANCE:Float = GridGeometry.WALL_THICKNESS / 2 + GridGeometry.COLLISION_CLEARANCE;

	/** How far past wall 7's own tip the player reappears when returning from the maze, arc-length in the spiral's own local frame — mirrors `biomes.maze.MazeBiome.RETURN_SPAWN_OFFSET`'s own role. **/
	static inline final RETURN_SPAWN_OFFSET:Float = 4;

	/** One local `(u, v)` per turn: east, south, west, north, repeating — the spiral always turns the same way. **/
	static final DIRECTIONS:Array<{u:Float, v:Float}> = [{u: 0, v: 1}, {u: 1, v: 0}, {u: 0, v: -1}, {u: -1, v: 0}];

	/**
		The spiral's own 7 wall segments, in local `(u, v)`, walked once from
		the center outward — wall `i` (1-indexed here via the returned
		array's own index) is `i * ARM_UNIT` long. Pure geometry, shared by
		`build` and `blocksMovement` so rendering and collision can never
		disagree about where a wall actually is.
		@return each wall's own two endpoints, center-out.
	**/
	static function wallSegments():Array<{
		aU:Float,
		aV:Float,
		bU:Float,
		bV:Float
	}> {
		var segments = [];
		var u = 0.0;
		var v = 0.0;
		for (i in 0...7) {
			var dir = DIRECTIONS[i % DIRECTIONS.length];
			var length = (i + 1) * ARM_UNIT;
			var nextU = u + dir.u * length;
			var nextV = v + dir.v * length;
			segments.push({
				aU: u,
				aV: v,
				bU: nextU,
				bV: nextV
			});
			u = nextU;
			v = nextV;
		}
		return segments;
	}

	/**
		Builds the shrine's own 7 walls plus the maze's painting, anchored
		at `basis`.
		@param parent the scene object to attach the meshes under.
		@param basis the shrine's own local frame (see `HubStructure.anchorAt`).
		@param texture the maze's own painting art.
	**/
	public static function build(parent:h3d.scene.Object, basis:StructureBasis, texture:h3d.mat.Texture):Void {
		var points:Array<h3d.Vector> = [];
		var idx = new hxd.IndexBuffer();
		var uvs:Array<h3d.prim.UV> = [];

		for (segment in wallSegments()) {
			addWallBox(basis, segment, points, idx, uvs);
		}

		var prim = new h3d.prim.Polygon(points, idx);
		prim.uvs = uvs;
		var wallTexture = hxd.Res.textures.wall_stone.toTexture();
		wallTexture.wrap = Repeat;
		var mesh = new h3d.scene.Mesh(prim, parent);
		mesh.material.mainPass.addShader(new UnlitTexture(wallTexture));
		mesh.material.mainPass.culling = None;

		buildPainting(parent, basis, texture);
	}

	/**
		One wall segment's own solid box — inner face, outer face, a top
		cap, and end caps at both extremities — real thickness
		(`GridGeometry.WALL_THICKNESS`, the same as the real maze's own
		walls), not the flat single-sided quad this used to be (reported
		directly as reading as 2D next to the real maze's own walls).

		Each segment extends its own two ends by half that thickness before
		offsetting perpendicular to its own length, so consecutive walls'
		boxes overlap slightly at the spiral's own 90-degree turns rather
		than leaving a gap there — invisible either way, since both
		are solid opaque stone (the same "never actually visible" reasoning
		`biomes.common.grid.GridMesh`'s own `WallBuilder` already relies on
		for its own redundant faces, just traded here for a simpler,
		corner-agnostic segment shape rather than that class's own
		per-cell mitred corners).
	**/
	static function addWallBox(basis:StructureBasis, segment:{
		aU:Float,
		aV:Float,
		bU:Float,
		bV:Float
	}, points:Array<h3d.Vector>, idx:hxd.IndexBuffer, uvs:Array<h3d.prim.UV>):Void {
		var dirU = segment.bU - segment.aU;
		var dirV = segment.bV - segment.aV;
		var length = Math.sqrt(dirU * dirU + dirV * dirV);
		dirU /= length;
		dirV /= length;
		var perpU = -dirV;
		var perpV = dirU;
		var half = GridGeometry.WALL_THICKNESS / 2;

		var extAU = segment.aU - dirU * half;
		var extAV = segment.aV - dirV * half;
		var extBU = segment.bU + dirU * half;
		var extBV = segment.bV + dirV * half;

		var outerA = HubStructure.worldPoint(basis, extAU + perpU * half, extAV + perpV * half, 0);
		var outerB = HubStructure.worldPoint(basis, extBU + perpU * half, extBV + perpV * half, 0);
		var innerA = HubStructure.worldPoint(basis, extAU - perpU * half, extAV - perpV * half, 0);
		var innerB = HubStructure.worldPoint(basis, extBU - perpU * half, extBV - perpV * half, 0);

		var outerATop = outerA.add(basis.up.scaled(WALL_HEIGHT));
		var outerBTop = outerB.add(basis.up.scaled(WALL_HEIGHT));
		var innerATop = innerA.add(basis.up.scaled(WALL_HEIGHT));
		var innerBTop = innerB.add(basis.up.scaled(WALL_HEIGHT));

		var uRepeat = length / MeshBuilder.WALL_TEXTURE_TILE_SIZE;
		var vRepeat = WALL_HEIGHT / MeshBuilder.WALL_TEXTURE_TILE_SIZE;
		var tRepeat = GridGeometry.WALL_THICKNESS / MeshBuilder.WALL_TEXTURE_TILE_SIZE;

		addTexturedQuad(points, idx, uvs, innerA, innerB, innerBTop, innerATop, uRepeat, vRepeat);
		addTexturedQuad(points, idx, uvs, outerB, outerA, outerATop, outerBTop, uRepeat, vRepeat);
		addTexturedQuad(points, idx, uvs, outerATop, outerBTop, innerBTop, innerATop, uRepeat, tRepeat);
		addTexturedQuad(points, idx, uvs, outerA, innerA, innerATop, outerATop, tRepeat, vRepeat);
		addTexturedQuad(points, idx, uvs, innerB, outerB, outerBTop, innerBTop, tRepeat, vRepeat);
	}

	/** Appends a quad plus matching UVs — `a`/`d` at u=0, `b`/`c` at u=uRepeat, `a`/`b` at v=vSpan, `c`/`d` at v=0 — same convention `biomes.common.grid.GridMesh`'s own private `WallBuilder.addTexturedQuad` uses. **/
	static function addTexturedQuad(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, uvs:Array<h3d.prim.UV>, a:h3d.Vector, b:h3d.Vector, c:h3d.Vector,
			d:h3d.Vector, uRepeat:Float, vSpan:Float):Void {
		MeshBuilder.addQuad(points, idx, a, b, c, d);
		uvs.push(new h3d.prim.UV(0, vSpan));
		uvs.push(new h3d.prim.UV(uRepeat, vSpan));
		uvs.push(new h3d.prim.UV(uRepeat, 0));
		uvs.push(new h3d.prim.UV(0, 0));
	}

	/**
		Wall 2's own two edges, offset half a wall's own thickness toward
		the shrine's own local origin — the actual inner face a painting
		mounts flush against now that walls have real thickness, not the
		centerline `wallSegments` itself returns (which `buildPainting`/
		`exitPainting` used directly back when a wall's visible face and
		its centerline were the same thing).
	**/
	static function wall2InnerFaceEdge(basis:StructureBasis):{a:h3d.Vector, b:h3d.Vector} {
		var wall2 = wallSegments()[1];
		var dirU = wall2.bU - wall2.aU;
		var dirV = wall2.bV - wall2.aV;
		var length = Math.sqrt(dirU * dirU + dirV * dirV);
		dirU /= length;
		dirV /= length;
		var perpU = -dirV;
		var perpV = dirU;

		var midU = (wall2.aU + wall2.bU) / 2;
		var midV = (wall2.aV + wall2.bV) / 2;
		// Flip perp so it points toward the shrine's own local origin (0, 0) - the inner, room-facing side - regardless of this particular wall's own direction.
		if (perpU * (0 - midU) + perpV * (0 - midV) < 0) {
			perpU = -perpU;
			perpV = -perpV;
		}

		var half = GridGeometry.WALL_THICKNESS / 2;
		var a = HubStructure.worldPoint(basis, wall2.aU + perpU * half, wall2.aV + perpV * half, 0);
		var b = HubStructure.worldPoint(basis, wall2.bU + perpU * half, wall2.bV + perpV * half, 0);
		return {a: a, b: b};
	}

	/** The maze's own painting, mounted on wall 2's inner (center-facing) side. **/
	static function buildPainting(parent:h3d.scene.Object, basis:StructureBasis, texture:h3d.mat.Texture):Void {
		var edge = wall2InnerFaceEdge(basis);
		var roomCenter = basis.origin;
		var size = PaintingModel.fillWall(WALL_HEIGHT);
		PaintingModel.buildQuad(parent, edge.a, edge.b, roomCenter, texture, size.baseHeight, size.height, basis.up);
	}

	/**
		Whether a position `playerHeight` above `worldPos`'s own local ground
		is too close to any of the shrine's own 7 walls to be walked into —
		a flat clearance check per segment (`HubStructure.distanceToSegment`),
		same discipline `biomes.hub.HubCollision` already uses for the
		(now-removed) column, now also bounded to `[0, WALL_HEIGHT]` so a
		player standing at or above the walls' own top (having actually
		climbed up there) is never blocked sideways by a wall they're now
		standing on rather than walking into — see `wallTopHeightAt` for the
		matching landing surface that makes getting up there possible.
		@param basis the shrine's own local frame.
		@param worldPos the position to check — typically the player's own tentative new position.
		@param playerHeight how far above `worldPos`'s own local ground the player currently stands — typically `PlayerModel.airborneHeight`.
		@return true if this position is blocked by a wall.
	**/
	public static function blocksMovement(basis:StructureBasis, worldPos:h3d.Vector, playerHeight:Float):Bool {
		var local = HubStructure.localUV(basis, worldPos);
		if (Math.abs(local.height) > HEIGHT_SANITY_BOUND) {
			return false; // nowhere near the shrine at all - see localUV's own doc for why (u, v) alone can't tell
		}
		var effectiveHeight = local.height + playerHeight;
		if (effectiveHeight < 0 || effectiveHeight > WALL_HEIGHT) {
			return false;
		}
		for (segment in wallSegments()) {
			if (HubStructure.distanceToSegment(local.u, local.v, segment.aU, segment.aV, segment.bU, segment.bV) < WALL_CLEARANCE) {
				return true;
			}
		}
		return false;
	}

	/**
		The standable ground height at `worldPos`, if it sits over any of
		the shrine's own 7 walls (their top surface, `WALL_HEIGHT` above the
		shrine's own local ground) — `null` if it's clear of every wall, so
		`biomes.hub.HubBiome.applyGravity` falls back to the hub's own bare
		floor (height `0`) instead. Purely horizontal (the same footprint
		`blocksMovement` blocks sideways within `[0, WALL_HEIGHT]`), since
		this is computing a height, not comparing against one the caller
		already has.
		@param basis the shrine's own local frame.
		@param worldPos the position to check — typically the player's own current position.
		@return the wall-top height standable there, or `null` if clear of every wall.
	**/
	public static function wallTopHeightAt(basis:StructureBasis, worldPos:h3d.Vector):Null<Float> {
		var local = HubStructure.localUV(basis, worldPos);
		if (Math.abs(local.height) > HEIGHT_SANITY_BOUND) {
			return null; // nowhere near the shrine at all - see localUV's own doc for why (u, v) alone can't tell
		}
		for (segment in wallSegments()) {
			if (HubStructure.distanceToSegment(local.u, local.v, segment.aU, segment.aV, segment.bU, segment.bV) < WALL_CLEARANCE) {
				return WALL_HEIGHT;
			}
		}
		return null;
	}

	/**
		The maze's own painting as a trigger — floor-level (`midpointOf`),
		matching every other painting in this project (see
		`docs/PROJECT_LOG.md`'s own entry on why the hub's former column-face
		paintings didn't, until fixed).
		@param basis the shrine's own local frame.
		@param destinationBiomeId `biomes.maze.MazeBiome.ID`.
		@return the shrine's own exit painting.
	**/
	public static function exitPainting(basis:StructureBasis, destinationBiomeId:String):PaintingModel {
		var edge = wall2InnerFaceEdge(basis);
		return new PaintingModel(PaintingModel.midpointOf(edge.a, edge.b), destinationBiomeId);
	}

	/**
		A `PlayerModel` standing `RETURN_SPAWN_OFFSET` past wall 7's own
		tip, facing away from the spiral — where the player reappears
		coming back out of the maze. Faces *away* (continuing outward,
		the same direction `outDir` already points), not back toward the
		shrine: walking into the maze's own painting to get here is itself
		a walk *further into* the spiral, so facing that same way again on
		arrival would have the player immediately retracing their own
		steps back the way they came, rather than emerging into the open
		hub the way walking through an ordinary doorway keeps you moving
		forward on the other side (hooman: "when we enter through a
		painting, I'd like to face the opposite direction when exiting the
		other painting").

		Re-projected onto the hub's true sphere (`normalized().scaled(radius)`)
		since `HubStructure`'s own flat local frame is only an
		approximation away from the anchor itself — same correction
		`biomes.maze.MazeBiome.playerInFrontOfExitWall` already makes for
		the same reason.
		@param basis the shrine's own local frame.
		@param radius the hub's own sphere radius.
		@return the spawned player.
	**/
	public static function returnSpawn(basis:StructureBasis, radius:Float):PlayerModel {
		var outermost = wallSegments()[6];
		var tipU = outermost.bU;
		var tipV = outermost.bV;
		var outDir = DIRECTIONS[6 % DIRECTIONS.length];
		var spawnU = tipU + outDir.u * RETURN_SPAWN_OFFSET;
		var spawnV = tipV + outDir.v * RETURN_SPAWN_OFFSET;

		var tentativePos = HubStructure.worldPoint(basis, spawnU, spawnV, 0);
		var pos = tentativePos.normalized().scaled(radius);

		var outOfSpiral = basis.uAxis.scaled(outDir.u).add(basis.vAxis.scaled(outDir.v));
		var posDir = pos.normalized();
		var forward = outOfSpiral.sub(posDir.scaled(outOfSpiral.dot(posDir))).normalized();
		return new PlayerModel(pos, forward);
	}
}
