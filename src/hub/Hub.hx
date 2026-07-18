package hub;

import maze.MazeMesh;
import world.Painting;

/**
	The hub: a large sphere with a freestanding octagonal column through its
	middle — the diegetic menu space reached by walking into a painting
	instead of a UI overlay (see `docs/PROJECT_LOG.md`'s 2026-07-17 entry for
	the decision and its rejected alternative, and its later entry for this
	bigger redesign).

	The player is always confined to this sphere's own surface (same
	`Player`/`SphereMath` convention biomes use), which rules out a column
	shaped like a smaller *concentric* sphere: the true nearest-point
	distance from any point on the outer sphere to a sphere concentric with
	it is the constant `RADIUS - innerRadius` everywhere, so walking around
	never gets any closer to one. A column with a *constant* cross-section
	radius (a straight prism, not scaled by `sin(theta)` the way the outer
	sphere's own cross-section is) doesn't have that problem: the player's
	own distance from the column's axis shrinks as they walk toward a pole,
	so it eventually meets the prism's fixed radius somewhere — a real,
	walkable, touchable wall.

	`COLUMN_RADIUS`/`COLUMN_HALF_HEIGHT` are chosen so the column's flat end
	caps sit exactly flush against the sphere's own inner wall — no gap, no
	poking through — rather than tapering to the literal pole points, which
	would need a hand-profiled bicone/capsule mesh generator for a purely
	architectural centerpiece. The same single `isInside` check blocks the
	player from ever reaching either sealed-off polar cap beyond it, without
	needing a separate latitude check.
**/
class Hub {
	/**
		This sphere's own radius — no longer `maze.MazeGeometry.RADIUS`; the
		hub isn't biome-scale. Doubled from an initial `35` after hooman
		found that scale disorienting.
	**/
	public static inline final RADIUS:Float = 70;

	/**
		The column's fixed distance from its own pole-to-pole axis. Halved
		from an initial `42` (a 3-4-5-ratio fit against `RADIUS`) after
		hooman found the column too large relative to the room — no longer
		lands on a clean integer ratio, but "flush against the sphere, no
		gap" (see `COLUMN_HALF_HEIGHT`) doesn't require one, just the right
		formula.
	**/
	public static inline final COLUMN_RADIUS:Float = 21;

	/** Half the column's length along its axis — chosen (with RADIUS/COLUMN_RADIUS) so its end caps sit exactly flush against the sphere's inner wall: `sqrt(RADIUS^2 - COLUMN_RADIUS^2)`. **/
	static inline final COLUMN_HALF_HEIGHT:Float = 66.7757;

	static inline final COLUMN_SIDES = 8;

	/** Segment counts for the outer shell's `h3d.prim.Sphere` — smooth enough to not read as faceted, unlike the deliberately 8-sided column. **/
	static inline final SHELL_SEGS_W = 32;

	static inline final SHELL_SEGS_H = 24;

	/** Checkerboard colors for the outer shell — a solid flat fill gave the room's curvature and the player's own distance from anything no visual cues at all; alternating cells fix that without needing a texture asset. **/
	static inline final FLOOR_COLOR_A:Int = 0xFF3A3A44;

	static inline final FLOOR_COLOR_B:Int = 0xFF4A4A58;

	/** Checkerboard density: cells around the equator, and pole to pole — chosen so cells read roughly square (the equator's circumference is about twice the pole-to-pole distance). **/
	static inline final FLOOR_CHECKER_U = 40;

	static inline final FLOOR_CHECKER_V = 20;

	/** Which of the column's 8 faces holds the painting back to the one existing biome — arbitrary, just needs to be a real face index. **/
	static inline final TO_BIOME_FACE_INDEX = 0;

	/** Extra margin `isInside` blocks at, short of the column's actual rendered face — same role as `MazeGeometry.COLLISION_CLEARANCE` plays for biomes. **/
	static inline final COLLISION_CLEARANCE:Float = 1;

	/**
		Height (along the column's own axis) a face painting mounts at —
		deliberately *not* 0 (equatorial, the column's widest cross-section
		and so the room's most spacious walking band): the player's own
		distance from the column's axis and their height are the same
		function of `theta` (`RADIUS*sin(theta)` and `RADIUS*cos(theta)`
		respectively), so the closest they can ever get to the column at all
		is right at the collision boundary itself — near the *top* of the
		walkable band, not the middle. A painting mounted at the equator
		would sit a full corridor-width (14 units) away from anywhere the
		player can actually stand.

		Every time `RADIUS`/`COLUMN_RADIUS` changes, this is re-derived from
		scratch, not scaled from whatever it was before: `Painting`'s own
		`BASE_HEIGHT`/`HEIGHT` are fixed absolute constants (a painting is a
		physical object with its own natural size, not something that
		should balloon just because the room around it did), so naively
		scaling `PAINTING_HEIGHT` alone while that fixed offset stays put
		has overshot the reachable zone before. `57` puts the quad's own top
		edge (`57+9=66`) just under `COLUMN_HALF_HEIGHT` (`66.7757`), the
		highest this anchor can go, putting its visual center (`57+6=63`)
		as close as that allows to the collision boundary's own height
		(`RADIUS*cos(asin((COLUMN_RADIUS+COLLISION_CLEARANCE)/RADIUS))`) —
		confirmed numerically (a scratch script computing the true closest
		distance from the nearest reachable player position to this exact
		point), not assumed.
		`PAINTING_TRIGGER_DISTANCE` is sized against that same measurement
		rather than reusing `Painting.TRIGGER_DISTANCE`, since how close the
		player can physically get to a mounting point scales with the room,
		not with a fixed constant tuned for biome-scale walls.
	**/
	static inline final PAINTING_HEIGHT:Float = 57;

	/**
		How close the player needs to walk to trigger the to-biome painting
		— `Painting.TRIGGER_DISTANCE` (4) doesn't clear the gap at this
		scale (confirmed numerically — see `PAINTING_HEIGHT`'s own doc), so
		the hub's own painting gets its own value instead of that shared
		constant.
	**/
	static inline final PAINTING_TRIGGER_DISTANCE:Float = 6;

	/** Where the player spawns entering the hub: the equator — the room's widest, most open point, not particularly close to the column (see `PAINTING_HEIGHT`'s own doc for why that's the *least* reachable latitude, not the most). **/
	public static final SPAWN_THETA:Float = Math.PI / 2;

	public static final SPAWN_PHI:Float = Math.PI / COLUMN_SIDES;

	/**
		The hub's one painting back to a biome, mounted on `TO_BIOME_FACE_INDEX`
		at `PAINTING_HEIGHT` — matches exactly where `buildColumn` renders it.
		Takes the destination biome's id rather than hardcoding one so `Hub`
		itself stays biome-agnostic — see `biomes.HubBiome`, which is what
		actually knows which biome that is.
		@param destinationBiomeId the `game.Biome.id()` this painting leads to.
		@return the hub's exit painting.
	**/
	public static function toBiomePainting(destinationBiomeId:String):Painting {
		var left = toBiomeFaceEdge(true);
		var right = toBiomeFaceEdge(false);
		return new Painting(Painting.centerOf(left, right, new h3d.Vector(0, 1, 0)), destinationBiomeId, PAINTING_TRIGGER_DISTANCE);
	}

	/** `TO_BIOME_FACE_INDEX`'s left or right edge, at `PAINTING_HEIGHT` — the shared reference both `toBiomePainting` and `buildColumn` mount the painting from, so the trigger position always matches where it's actually rendered. **/
	static function toBiomeFaceEdge(left:Bool):h3d.Vector {
		var edge = columnEdge(TO_BIOME_FACE_INDEX + (left ? 0 : 1));
		return new h3d.Vector(edge.top.x, PAINTING_HEIGHT, edge.top.z);
	}

	/**
		Whether `pos` is still on the walkable side of the column, a
		`COLLISION_CLEARANCE` margin short of its actual rendered face —
		checked via distance from the column's own axis (the Y axis), which
		for any point *on this sphere* is exactly `RADIUS * sin(theta)`. The
		same check blocks the player well before either polar cap too: as
		`theta` approaches 0 or PI, this distance shrinks below the
		column's radius long before reaching the pole itself.
		@param pos the position to check.
		@return true if `pos` hasn't crossed into the column.
	**/
	public static function isInside(pos:h3d.Vector):Bool {
		var theta = game.SphereMath.thetaOf(pos);
		var distanceFromAxis = RADIUS * Math.sin(theta);
		return distanceFromAxis > COLUMN_RADIUS + COLLISION_CLEARANCE;
	}

	/**
		Builds the hub's outer shell (an `h3d.prim.Sphere`, checkerboarded —
		see `UnlitChecker`'s own doc for why a flat fill wasn't enough here)
		and its central 8-sided column (side panels textured like biome
		walls, the to-biome painting mounted as an inset overlay on one of them).
		@param parent the scene object to attach the meshes under.
	**/
	public static function build(parent:h3d.scene.Object):Void {
		// h3d.prim.Sphere's own poles sit on the Z axis (built from
		// cos/sin(t) into x/y, cos(t) into z) — rotated here to match this
		// project's Y-axis pole convention (SphereMath.sphericalToCartesian)
		// instead. Now that the shell is checkerboarded rather than a flat
		// fill, this also keeps its cells aligned with the column's own
		// pole-to-pole axis instead of running crosswise to it.
		var shellPrim = new h3d.prim.Sphere(RADIUS, SHELL_SEGS_W, SHELL_SEGS_H);
		shellPrim.addUVs();
		var shellMesh = new h3d.scene.Mesh(shellPrim, parent);
		shellMesh.setRotation(-Math.PI / 2, 0, 0);
		shellMesh.material.mainPass.addShader(new game.shader.UnlitChecker(FLOOR_COLOR_A, FLOOR_COLOR_B, FLOOR_CHECKER_U, FLOOR_CHECKER_V));
		shellMesh.material.mainPass.culling = None;

		buildColumn(parent);
	}

	static function buildColumn(parent:h3d.scene.Object):Void {
		var points:Array<h3d.Vector> = [];
		var idx = new hxd.IndexBuffer();
		var uvs:Array<h3d.prim.UV> = [];

		for (i in 0...COLUMN_SIDES) {
			var a = columnEdge(i);
			var b = columnEdge(i + 1);

			var uRepeat = a.top.sub(b.top).length() / MazeMesh.WALL_TEXTURE_TILE_SIZE;
			var vHeight = 2 * COLUMN_HALF_HEIGHT / MazeMesh.WALL_TEXTURE_TILE_SIZE;
			MazeMesh.addQuad(points, idx, a.top, b.top, b.bottom, a.bottom);
			uvs.push(new h3d.prim.UV(0, vHeight));
			uvs.push(new h3d.prim.UV(uRepeat, vHeight));
			uvs.push(new h3d.prim.UV(uRepeat, 0));
			uvs.push(new h3d.prim.UV(0, 0));
		}

		addCap(points, idx, uvs, true);
		addCap(points, idx, uvs, false);

		var prim = new h3d.prim.Polygon(points, idx);
		prim.uvs = uvs;
		var texture = hxd.Res.textures.wall_stone.toTexture();
		texture.wrap = Repeat;
		var mesh = new h3d.scene.Mesh(prim, parent);
		mesh.material.mainPass.addShader(new game.shader.UnlitTexture(texture));
		mesh.material.mainPass.culling = None;

		// The painting mounts as an inset overlay on top of its face's own
		// wall texture, same as a biome return painting sits in front of
		// MazeMesh's already-built wall — not a replacement for it (an
		// earlier version skipped the whole face's own panel here, leaving
		// everything except the small painting quad itself unrendered).
		var left = toBiomeFaceEdge(true);
		var right = toBiomeFaceEdge(false);
		var mid = Painting.midpointOf(left, right);
		var outward = new h3d.Vector(mid.x, 0, mid.z).normalized();
		var outwardRef = mid.add(outward.scaled(COLUMN_RADIUS));
		Painting.buildQuad(parent, left, right, outwardRef, Painting.TO_BIOME_COLOR, new h3d.Vector(0, 1, 0));
	}

	/** A triangle fan closing off the column's top (`top = true`) or bottom end. **/
	static function addCap(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, uvs:Array<h3d.prim.UV>, top:Bool):Void {
		var apex = new h3d.Vector(0, top ? COLUMN_HALF_HEIGHT : -COLUMN_HALF_HEIGHT, 0);
		for (i in 0...COLUMN_SIDES) {
			var a = columnEdge(i);
			var b = columnEdge(i + 1);
			var rimA = top ? a.top : a.bottom;
			var rimB = top ? b.top : b.bottom;
			var start = points.length;
			if (top) {
				points.push(apex);
				points.push(rimA);
				points.push(rimB);
			} else {
				points.push(apex);
				points.push(rimB);
				points.push(rimA);
			}
			idx.push(start);
			idx.push(start + 1);
			idx.push(start + 2);
			uvs.push(new h3d.prim.UV(0.5, 0.5));
			uvs.push(new h3d.prim.UV(0, 0));
			uvs.push(new h3d.prim.UV(1, 0));
		}
	}

	/** The column's `i`th vertical edge (wrapping every `COLUMN_SIDES`): top and bottom points at that angle around the axis. **/
	static function columnEdge(i:Int):{top:h3d.Vector, bottom:h3d.Vector} {
		var angle = (i % COLUMN_SIDES) * (2 * Math.PI / COLUMN_SIDES);
		var x = COLUMN_RADIUS * Math.cos(angle);
		var z = COLUMN_RADIUS * Math.sin(angle);
		return {top: new h3d.Vector(x, COLUMN_HALF_HEIGHT, z), bottom: new h3d.Vector(x, -COLUMN_HALF_HEIGHT, z)};
	}
}
