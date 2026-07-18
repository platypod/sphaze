package entities.painting;

import biomes.common.space.sphere.SphereMath;
import entities.Entity;
import game.MeshBuilder;
import graphics.Colours;
import graphics.shaders.UnlitTexture;

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

	An `Entity` since it's a thing that exists in the game world with a
	position — but only the warp-linked shape is built here
	(`destinationBiomeId`/`triggerDistance`); a purely decorative painting
	with no mechanism behind it isn't a real use case yet, so this doesn't
	try to anticipate what that would look like (same discipline as
	`CreatureSpawnTable`'s own doc).
**/
class PaintingModel extends Entity {
	/** How close the player needs to walk for this painting to trigger. **/
	public static inline final TRIGGER_DISTANCE:Float = 4;

	/**
		How far up from the floor a painting's bottom edge sits. `3` read as
		sitting right on the ground from a standing player's eye line
		(`entities.player.Camera.EYE_HEIGHT` is `6`, so the old bottom edge
		was only half an eye-height up) — raised so the whole piece reads as
		mounted at a normal wall height instead.
	**/
	static inline final BASE_HEIGHT:Float = 4.5;

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

	/**
		How far beyond the painting's own edge `buildFrame`'s moulding
		extends, as a fraction of that edge's own span — not a fixed world
		distance, so the border reads the same relative thickness whether
		it's mounted on a narrow wall or spans a wide one, instead of
		looking razor-thin against a wide painting and oversized against a
		narrow one.
	**/
	static inline final FRAME_BORDER_FRACTION:Float = 0.07;

	/**
		How much the frame's own depth varies from its outer edge (nearer
		the wall) to its inner edge (nearer the painting) — subtracted from
		`SURFACE_INSET` at the outer edge, so the frame reads as a bevel
		rising from wall-depth up to flush with the painting's own surface,
		not a flat painted border. The inner edge sits at exactly
		`SURFACE_INSET` (see `buildFrame`) — matching `buildQuad`'s own
		painting inset exactly, not offset further out from it, since a
		frame proud of the *painting itself* left a gap at the seam with
		nothing built to fill the resulting step (reported directly as
		visible space between the painting and its frame).
	**/
	static inline final FRAME_DEPTH:Float = 0.35;

	/**
		How wide the frame's two thin black outline bands (see
		`buildOutline`) are, as a fraction of the frame's own border width
		— eaten out of the frame's own band, not added beyond it, so
		outer/inner outline plus the main band exactly fill the same
		footprint the frame always had with no gap or overlap between them.
	**/
	static inline final OUTLINE_WIDTH_FRACTION:Float = 0.2;

	public final position:h3d.Vector;

	/** The `biomes.common.Biome.id()` of whichever biome walking into this painting leads to. **/
	public final destinationBiomeId:String;

	final triggerDistance:Float;

	/**
		@param position where this painting sits.
		@param destinationBiomeId the `biomes.common.Biome.id()` walking into this painting leads to.
		@param triggerDistance how close the player needs to walk for it to trigger — defaults to `TRIGGER_DISTANCE`; a larger scene (e.g. a bigger hub) may need its own, since how close a player can physically get to a given mounting point scales with the room, not with this constant.
	**/
	public function new(position:h3d.Vector, destinationBiomeId:String, ?triggerDistance:Float) {
		super();
		this.position = position;
		this.destinationBiomeId = destinationBiomeId;
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
		var upDir = up != null ? up : SphereMath.upVectorAt(mid, new h3d.Vector(0, 0, 0));
		return mid.add(upDir.scaled(BASE_HEIGHT + HEIGHT / 2));
	}

	/**
		Builds a painting's actual visible quad — textured with `texture`
		(the destination biome's own artwork, see `res/sprites/`) centered
		on the wall segment's midpoint, inset slightly off the wall's own
		face so it doesn't z-fight with the wall texture directly behind
		it.

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
		@param texture the destination biome's own artwork, shown flat across the quad's face.
		@param up which way "up the wall" is — defaults to radially inward (`SphereMath.upVectorAt`), correct for a wall on a sphere's surface; pass an explicit direction (e.g. `(0,1,0)`) for a wall whose own "up" isn't radial, like a straight column's side face.
	**/
	public static function buildQuad(parent:h3d.scene.Object, wallA:h3d.Vector, wallB:h3d.Vector, roomCenter:h3d.Vector, texture:h3d.mat.Texture,
			?up:h3d.Vector):Void {
		var mid = midpointOf(wallA, wallB);
		var upDir = up != null ? up : SphereMath.upVectorAt(mid, new h3d.Vector(0, 0, 0));
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

		var prim = new h3d.prim.Polygon(points, idx);
		// Matches points' own bottomA/bottomB/topB/topA order — bottom edge
		// at v=1, top edge at v=0. Loaded images come in row-0-at-top, and
		// unlike `HubMesh.buildColumn`'s own wall UVs (top=v-max, bottom=0
		// — never actually noticed as backwards since a tileable stone
		// texture doesn't have an "up"), a painting's own artwork very
		// visibly does: v=0 has to land on the texture's own top row.
		prim.uvs = [
			new h3d.prim.UV(0, 1),
			new h3d.prim.UV(1, 1),
			new h3d.prim.UV(1, 0),
			new h3d.prim.UV(0, 0)
		];

		var mesh = new h3d.scene.Mesh(prim, parent);
		mesh.material.mainPass.addShader(new UnlitTexture(texture));
		mesh.material.mainPass.culling = None;

		buildFrame(parent, mid, along, upDir, faceNormal, halfWidth);
	}

	/**
		Builds the raised frame "moulding" around a painting's quad: a
		sloped band running all the way around, recessed toward the wall
		(`SURFACE_INSET - FRAME_DEPTH`) on its outer edge and rising to
		meet the painting exactly flush (`SURFACE_INSET`, matching
		`buildQuad`'s own inset precisely) on its inner edge — no gap at
		that seam, since inner-edge depth and extent both match the
		painting's own edge exactly. Two thin black outline bands
		(`buildOutline`) are eaten out of the same footprint, right along
		the frame's own outer and inner borders, standing in for the edge
		definition this project's flat/unlit shading has no real lighting
		to produce on its own.
		@param parent the scene object to attach the mesh under.
		@param mid the painting's own wall-segment midpoint (`midpointOf`).
		@param along the wall's own length axis — normalized.
		@param upDir the wall's own height axis — normalized.
		@param faceNormal the wall's own outward face normal — normalized, pointing into the room.
		@param halfWidth half the painting's own width, along `along`.
	**/
	static function buildFrame(parent:h3d.scene.Object, mid:h3d.Vector, along:h3d.Vector, upDir:h3d.Vector, faceNormal:h3d.Vector, halfWidth:Float):Void {
		// Each axis' own border is a fraction of that axis' own span — see
		// `FRAME_BORDER_FRACTION`'s own doc for why not a fixed distance.
		var horizontalBorder = 2 * halfWidth * FRAME_BORDER_FRACTION;
		var verticalBorder = HEIGHT * FRAME_BORDER_FRACTION;
		var outerHalfWidth = halfWidth + horizontalBorder;
		var outerBottom = BASE_HEIGHT - verticalBorder;
		var outerTop = BASE_HEIGHT + HEIGHT + verticalBorder;
		var wallInset = faceNormal.scaled(SURFACE_INSET - FRAME_DEPTH);
		var peakInset = faceNormal.scaled(SURFACE_INSET);

		// The main band's own inner/outer edges each give up
		// OUTLINE_WIDTH_FRACTION of the border's width to the two outline
		// bands below — shrinking, not shrinking-then-re-extending, so
		// all three bands share exact boundary points with no gap or
		// overlap between them.
		var innerHalfWidth = halfWidth + horizontalBorder * OUTLINE_WIDTH_FRACTION;
		var innerBottom = BASE_HEIGHT - verticalBorder * OUTLINE_WIDTH_FRACTION;
		var innerTop = BASE_HEIGHT + HEIGHT + verticalBorder * OUTLINE_WIDTH_FRACTION;
		var mainOuterHalfWidth = outerHalfWidth - horizontalBorder * OUTLINE_WIDTH_FRACTION;
		var mainOuterBottom = outerBottom + verticalBorder * OUTLINE_WIDTH_FRACTION;
		var mainOuterTop = outerTop - verticalBorder * OUTLINE_WIDTH_FRACTION;

		var points:Array<h3d.Vector> = [];
		var idx = new hxd.IndexBuffer();
		addRingBand(points, idx, mid, along, upDir, innerHalfWidth, innerBottom, innerTop, peakInset, mainOuterHalfWidth, mainOuterBottom, mainOuterTop,
			wallInset);
		var mesh = new h3d.scene.Mesh(new h3d.prim.Polygon(points, idx), parent);
		mesh.material.mainPass.addShader(new h3d.shader.FixedColor(Colours.PAINTING_FRAME));
		mesh.material.mainPass.culling = None;

		buildOutline(parent, mid, along, upDir, halfWidth, innerHalfWidth, mainOuterHalfWidth, outerHalfWidth, outerBottom, outerTop, wallInset, peakInset);
	}

	/**
		The frame's own two thin black outline bands — flat (no depth
		ramp, unlike the main band), one right where the frame meets the
		painting (at `peakInset`, the same depth *and* extent as the
		painting's own edge — flush, continuing `buildFrame`'s own
		gap-free seam) and one right where it meets the wall (at
		`wallInset`, the main band's own outer depth). Each shares its
		outer boundary points exactly with the main band's own inner/outer
		edge (see `buildFrame`), so neither overlaps nor gaps against it.
		@param parent the scene object to attach the mesh under.
		@param mid the painting's own wall-segment midpoint.
		@param along the wall's own length axis — normalized.
		@param upDir the wall's own height axis — normalized.
		@param halfWidth half the painting's own width — the inner outline's own inner edge.
		@param innerOutlineOuterHalfWidth the inner outline's own outer edge — `buildFrame`'s own (shrunk) inner edge.
		@param outerOutlineInnerHalfWidth the outer outline's own inner edge — `buildFrame`'s own (shrunk) outer edge.
		@param outerHalfWidth the outer outline's own outer edge — the frame's true outer boundary.
		@param outerBottom the frame's true outer boundary, bottom.
		@param outerTop the frame's true outer boundary, top.
		@param wallInset the outer outline's own depth — `buildFrame`'s own outer-edge inset.
		@param peakInset the inner outline's own depth — `buildQuad`'s own painting inset.
	**/
	static function buildOutline(parent:h3d.scene.Object, mid:h3d.Vector, along:h3d.Vector, upDir:h3d.Vector, halfWidth:Float,
			innerOutlineOuterHalfWidth:Float, outerOutlineInnerHalfWidth:Float, outerHalfWidth:Float, outerBottom:Float, outerTop:Float, wallInset:h3d.Vector,
			peakInset:h3d.Vector):Void {
		var innerBorder = innerOutlineOuterHalfWidth - halfWidth;
		var outerBorder = outerHalfWidth - outerOutlineInnerHalfWidth;

		var points:Array<h3d.Vector> = [];
		var idx = new hxd.IndexBuffer();
		addRingBand(points, idx, mid, along, upDir, halfWidth, BASE_HEIGHT, BASE_HEIGHT
			+ HEIGHT, peakInset, innerOutlineOuterHalfWidth,
			BASE_HEIGHT
			- innerBorder, BASE_HEIGHT
			+ HEIGHT
			+ innerBorder, peakInset);
		addRingBand(points, idx, mid, along, upDir, outerOutlineInnerHalfWidth, outerBottom + outerBorder, outerTop - outerBorder, wallInset, outerHalfWidth,
			outerBottom, outerTop, wallInset);

		var mesh = new h3d.scene.Mesh(new h3d.prim.Polygon(points, idx), parent);
		mesh.material.mainPass.addShader(new h3d.shader.FixedColor(Colours.PAINTING_FRAME_OUTLINE));
		mesh.material.mainPass.culling = None;
	}

	/**
		Four quads forming a rectangular ring band around `mid` — the
		shared shape `buildFrame`'s own main band and `buildOutline`'s two
		bands are all built from, just with different extents/depths.
		Winding order doesn't matter for visibility (`culling = None`) or
		shading (`FixedColor` ignores normals entirely).
		@param points appended to — the mesh's own vertex buffer.
		@param idx appended to — the mesh's own index buffer.
		@param mid the ring's own center — a painting's wall-segment midpoint.
		@param along the wall's own length axis — normalized.
		@param upDir the wall's own height axis — normalized.
		@param innerHalfWidth the ring's own inner edge, along `along`.
		@param innerBottom the ring's own inner edge, bottom.
		@param innerTop the ring's own inner edge, top.
		@param innerInset the ring's own inner edge, depth off the wall (along the face normal).
		@param outerHalfWidth the ring's own outer edge, along `along`.
		@param outerBottom the ring's own outer edge, bottom.
		@param outerTop the ring's own outer edge, top.
		@param outerInset the ring's own outer edge, depth off the wall.
	**/
	static function addRingBand(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, mid:h3d.Vector, along:h3d.Vector, upDir:h3d.Vector, innerHalfWidth:Float,
			innerBottom:Float, innerTop:Float, innerInset:h3d.Vector, outerHalfWidth:Float, outerBottom:Float, outerTop:Float, outerInset:h3d.Vector):Void {
		var innerBottomA = mid.add(along.scaled(-innerHalfWidth)).add(upDir.scaled(innerBottom)).add(innerInset);
		var innerBottomB = mid.add(along.scaled(innerHalfWidth)).add(upDir.scaled(innerBottom)).add(innerInset);
		var innerTopA = mid.add(along.scaled(-innerHalfWidth)).add(upDir.scaled(innerTop)).add(innerInset);
		var innerTopB = mid.add(along.scaled(innerHalfWidth)).add(upDir.scaled(innerTop)).add(innerInset);

		var outerBottomA = mid.add(along.scaled(-outerHalfWidth)).add(upDir.scaled(outerBottom)).add(outerInset);
		var outerBottomB = mid.add(along.scaled(outerHalfWidth)).add(upDir.scaled(outerBottom)).add(outerInset);
		var outerTopA = mid.add(along.scaled(-outerHalfWidth)).add(upDir.scaled(outerTop)).add(outerInset);
		var outerTopB = mid.add(along.scaled(outerHalfWidth)).add(upDir.scaled(outerTop)).add(outerInset);

		MeshBuilder.addQuad(points, idx, outerBottomA, outerBottomB, innerBottomB, innerBottomA);
		MeshBuilder.addQuad(points, idx, outerBottomB, outerTopB, innerTopB, innerBottomB);
		MeshBuilder.addQuad(points, idx, outerTopB, outerTopA, innerTopA, innerTopB);
		MeshBuilder.addQuad(points, idx, outerTopA, outerBottomA, innerBottomA, innerTopA);
	}

	/**
		`res/sprites/painting--biome-hub-*.png`'s own newest variant —
		every non-hub biome's own return/exit painting shows this, since
		they all lead to the same place (the hub's own to-biome paintings
		instead pick their own biome-specific art; see
		`biomes.hub.HubBiome.DESTINATIONS`). Picked manually — bump the
		suffix here when a newer hub variant is added.
		@return the hub's own painting texture.
	**/
	public static function toHubTexture():h3d.mat.Texture {
		return hxd.Res.sprites.painting__biome_hub_03.toTexture();
	}
}
