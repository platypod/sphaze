package hub;

/** Which way walking into a painting sends the player. **/
enum PaintingDestination {
	ToHub;
	ToBiome;
}

/**
	A painting mounted on a wall — the diegetic warp mechanism: walking
	close enough triggers the transition, no interact-key confirmation, on
	purpose (see `docs/PROJECT_LOG.md`'s 2026-07-17 entry — finding one
	should still take some searching rather than being telegraphed by a
	prompt; flagged there as revisitable later).

	Pure data plus the trigger check — actually building a painting's
	visible quad is scene/rendering code (see `buildQuad`), kept separate so
	the trigger math itself stays unit-testable without needing a scene
	graph (`docs/GUIDELINES.md` §1.4/§5.4).
**/
class Painting {
	/** How close the player needs to walk for this painting to trigger. **/
	public static inline final TRIGGER_DISTANCE:Float = 4;

	/** Shared placeholder colors so every painting leading to the hub — or back to the biome — reads consistently regardless of which one the player finds first. **/
	public static inline final TO_HUB_COLOR:Int = 0xFF4488CC;

	public static inline final TO_BIOME_COLOR:Int = 0xFFCC8844;

	/** How far up from the floor a painting's bottom edge sits. **/
	static inline final BASE_HEIGHT:Float = 3;

	/** A painting's height, floor-clearance to top edge. **/
	static inline final HEIGHT:Float = 6;

	/** Fraction of the wall's own length a painting's width spans. **/
	static inline final WIDTH_FRACTION:Float = 0.5;

	/**
		How far off the wall's surface a painting's quad sits, so it doesn't
		z-fight with the wall texture behind it. `0.1` wasn't enough — even
		with a mathematically-correct perpendicular offset direction, that
		thin a gap still lost the depth-buffer fight at ordinary viewing
		distance (confirmed: the hub's own column-face painting never had
		the direction bug — `along.cross(upDir)` and the old
		`roomCenter.sub(mid)` approximation agree exactly for a flat vertical
		column face — yet showed the identical jagged edge, meaning
		magnitude, not direction, was the actual remaining cause).
	**/
	static inline final SURFACE_INSET:Float = 0.4;

	public final position:h3d.Vector;
	public final destination:PaintingDestination;

	final triggerDistance:Float;

	/**
		@param position where this painting sits.
		@param destination where walking into it leads.
		@param triggerDistance how close the player needs to walk for it to trigger — defaults to `TRIGGER_DISTANCE`; a larger scene (e.g. a bigger hub) may need its own, since how close a player can physically get to a given mounting point scales with the room, not with this constant.
	**/
	public function new(position:h3d.Vector, destination:PaintingDestination, ?triggerDistance:Float) {
		this.position = position;
		this.destination = destination;
		this.triggerDistance = triggerDistance != null ? triggerDistance : TRIGGER_DISTANCE;
	}

	/**
		Whether `pos` is close enough to this painting to trigger its warp.
		@param pos the position to check — typically the player's own current position.
		@return true if `pos` is within this painting's own trigger distance.
	**/
	public function triggeredBy(pos:h3d.Vector):Bool {
		return pos.sub(position).length() <= triggerDistance;
	}

	/**
		Where a painting mounted on the wall segment `wallA`-`wallB` sits —
		its own trigger position, and the point `buildQuad`'s visual is
		centered on. Just the segment's midpoint; pulled out on its own so
		it's testable independent of any scene graph.
		@param wallA one end of the wall segment.
		@param wallB the other end.
		@return the painting's position.
	**/
	public static function midpointOf(wallA:h3d.Vector, wallB:h3d.Vector):h3d.Vector {
		return wallA.add(wallB).scaled(0.5);
	}

	/**
		The actual center of the quad `buildQuad` renders for this wall
		segment — unlike `midpointOf` alone, this accounts for
		`BASE_HEIGHT`/`HEIGHT`, so a painting's trigger position (which
		should use this, not `midpointOf`) actually lines up with where the
		painting visually is instead of the wall's own floor-level
		reference point, well below it.
		@param wallA one end of the wall segment.
		@param wallB the other end.
		@param up which way "up the wall" is (see `buildQuad`'s own doc) — defaults to radially inward.
		@return the quad's true center point.
	**/
	public static function centerOf(wallA:h3d.Vector, wallB:h3d.Vector, ?up:h3d.Vector):h3d.Vector {
		var mid = midpointOf(wallA, wallB);
		var upDir = up != null ? up : game.SphereMath.upVectorAt(mid, new h3d.Vector(0, 0, 0));
		return mid.add(upDir.scaled(BASE_HEIGHT + HEIGHT / 2));
	}

	/**
		Builds a painting's placeholder visual: a single flat, solid-colored
		quad (no frame/art yet — matches the project's existing "flat-
		shaded placeholder" aesthetic, same reasoning `wall_stone.png` was
		procedurally generated for) centered on the wall segment's midpoint,
		inset slightly off the wall's own face so it doesn't z-fight with
		the wall texture directly behind it.

		The inset direction is `along.cross(upDir)` — perpendicular to both
		the wall's own length and height axes by construction, i.e. the
		wall's *true* face normal — not `roomCenter.sub(mid)` (an earlier
		version's approximation). That approximation is only actually
		perpendicular to the face for walls where "toward the room's
		center" happens to line up with the face normal; for a west/east
		biome wall it's nearly *parallel* to the face instead (a sideways
		phi-direction shift, since the cell center sits at the same radius
		and theta as the wall, just a different phi), barely lifting the
		inset off the wall at all — visible as the painting reading as
		flush with, and z-fighting against, the wall behind it. `roomCenter`
		still matters here, just for one bit: which of the normal's two
		possible directions actually points into the room.
		@param parent the scene object to attach the mesh under.
		@param wallA one end of the wall segment this painting is mounted on.
		@param wallB the other end.
		@param roomCenter a point on the room's own side of the wall — only used to pick which way the face normal points, not for exact positioning.
		@param color the placeholder's flat fill color.
		@param up which way "up the wall" is — defaults to radially inward (`SphereMath.upVectorAt`), correct for a wall on a sphere's surface; pass an explicit direction (e.g. `(0,1,0)`) for a wall whose own "up" isn't radial, like a straight column's side face.
	**/
	public static function buildQuad(parent:h3d.scene.Object, wallA:h3d.Vector, wallB:h3d.Vector, roomCenter:h3d.Vector, color:Int, ?up:h3d.Vector):Void {
		var mid = midpointOf(wallA, wallB);
		var upDir = up != null ? up : game.SphereMath.upVectorAt(mid, new h3d.Vector(0, 0, 0));
		var along = wallB.sub(wallA).normalized();

		var faceNormal = along.cross(upDir).normalized();
		if (faceNormal.dot(roomCenter.sub(mid)) < 0) {
			faceNormal = faceNormal.scaled(-1);
		}

		var halfWidth = wallA.sub(wallB).length() * WIDTH_FRACTION / 2;
		var inset = faceNormal.scaled(SURFACE_INSET);

		var bottomA = mid.sub(along.scaled(halfWidth)).add(upDir.scaled(BASE_HEIGHT)).add(inset);
		var bottomB = mid.add(along.scaled(halfWidth)).add(upDir.scaled(BASE_HEIGHT)).add(inset);
		var topA = bottomA.add(upDir.scaled(HEIGHT));
		var topB = bottomB.add(upDir.scaled(HEIGHT));

		var points = [bottomA, bottomB, topB, topA];
		var idx = new hxd.IndexBuffer();
		idx.push(0);
		idx.push(1);
		idx.push(2);
		idx.push(0);
		idx.push(2);
		idx.push(3);

		var mesh = new h3d.scene.Mesh(new h3d.prim.Polygon(points, idx), parent);
		mesh.material.mainPass.addShader(new h3d.shader.FixedColor(color));
		mesh.material.mainPass.culling = None;
	}
}
