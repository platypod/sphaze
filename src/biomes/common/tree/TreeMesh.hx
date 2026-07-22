package biomes.common.tree;

import game.MeshBuilder;

/**
	Builds one tree's own geometry — a trunk, plus one of three interchangeable
	foliage/branch treatments (see `addConiferFoliage`/`addRoundFoliage`/
	`addDeadBranches`) — appended into whatever point/index/UV buffers the
	caller passes in, rather than building its own `h3d.scene.Mesh`. That
	split exists so a whole forest's worth of trees can batch into a couple
	of meshes (one per color/gradient, not one per tree) — same "batch
	everything into a single `h3d.prim.Polygon`" approach `biomes.common.grass.GrassMesh`/
	`biomes.mobius.MobiusMesh` already use for their own many-instance
	geometry.

	Every ring segment's own base radius exactly matches the previous
	segment's own tip radius (`addTrunk`'s own top always feeds directly
	into whichever foliage/branch treatment sits above it) — no separate
	"how far do these overlap" fudge factor to get right, unlike an earlier
	version of this class that tried to hide a radius mismatch by overlapping
	two disconnected cones and still left a visible gap at the seam
	(reported directly as looking "awful"). A continuous silhouette, base to
	tip, is what actually guarantees no gap, not a large-enough overlap.

	UVs pack a height fraction into `v` (0 at the trunk's own root, 1 at
	the very tip of whatever sits above it) for `graphics.shaders.HeightGradient`
	to shade base-to-tip, same convention `GrassMesh` already uses for its
	own wind shader; `u` is unused (left at 0).

	Topology-agnostic: takes a tree's own local frame (`base`/`up`/
	`tangent`/`right`, an orthonormal triple — `up` the trunk's own growth
	axis, `tangent`/`right` spanning the ring perpendicular to it) rather
	than assuming a specific biome's own surface math, so this lives in
	`biomes.common` for any future biome that wants trees too, same
	reasoning `biomes.common.grass.GrassModel`'s own class doc gives for
	taking `radius`/`isWalkable` as parameters instead of reaching into one
	biome's own geometry directly. `biomes.mobius.MobiusMath.localFrameAt`'s
	own `{tu, tv, normal}` already is exactly this triple (`tangent = tu`,
	`right = tv`, `up = normal`) — callers don't need to derive a fresh
	basis, just rotate `tangent`/`right` together around `up` first if they
	want a per-tree facet/branch rotation (see `biomes.mobius.MobiusMesh`'s
	own call site).

	No top/bottom caps anywhere (never visible from a player's own eye
	height looking up at, or across at, a tree taller than they are, same
	discipline `biomes.tower.TowerMesh`'s own relief walls already follow)
	— including the very top tip, which is a real zero-radius point, not a
	capped flat disk, so there's nothing to cap there either. `culling =
	None` on whatever mesh the caller builds from these buffers sidesteps
	needing to get each ring's own winding order exactly right for backface
	culling — the same call this project's other solid-looking meshes
	(`biomes.tower.TowerMesh`'s outer wall, `biomes.mobius.MobiusMesh`'s own
	bands) already make.
**/
class TreeMesh {
	/** Trunk cross-section facets — cheap, since a thin trunk reads fine faceted (same reasoning `biomes.hub.HubMesh`'s deliberately 8-sided column already leans on). **/
	static inline final TRUNK_SIDES:Int = 6;

	/** Foliage cross-section facets — a little smoother than the trunk since the canopy is the tree's own most visible silhouette. **/
	static inline final FOLIAGE_SIDES:Int = 8;

	/** Branch cross-section facets — thin enough that even a hard-faceted cone reads fine. **/
	static inline final BRANCH_SIDES:Int = 4;

	/** Fraction of the whole foliage height `addConiferFoliage`'s own collar (trunk radius flaring out to the full foliage radius) takes up. **/
	static inline final CONIFER_COLLAR_FRACTION:Float = 0.15;

	/** Fraction of the whole foliage height `addConiferFoliage`'s own first (lower, wider) tier takes up, after the collar. **/
	static inline final CONIFER_TIER_FRACTION:Float = 0.45;

	/** The upper tier's own base radius, as a fraction of the full foliage radius — narrower, so the silhouette actually tapers going up through both tiers rather than just the very top point. **/
	static inline final CONIFER_UPPER_TIER_RADIUS_FRACTION:Float = 0.55;

	/** First widening point for the broad summer-canopy silhouette (`addRoundFoliage`) — low enough that the foliage reads squat and chunky rather than a tall teardrop. **/
	static inline final SUMMER_LOWER_BULGE_FRACTION:Float = 0.22;

	/** Widest shoulder of the summer canopy — later than the first flare, so the silhouette keeps a broad midsection for a while. **/
	static inline final SUMMER_MAIN_BULGE_FRACTION:Float = 0.58;

	/** Where the canopy starts tapering decisively toward the tip. **/
	static inline final SUMMER_UPPER_TAPER_FRACTION:Float = 0.82;

	/** Radius at the lower flare, as a fraction of the full canopy width. **/
	static inline final SUMMER_LOWER_RADIUS_FRACTION:Float = 0.82;

	/** Radius near the top, still fairly broad before the final tip. **/
	static inline final SUMMER_UPPER_RADIUS_FRACTION:Float = 0.62;

	/** How many stub branches `addDeadBranches` adds. **/
	static inline final BRANCH_COUNT:Int = 3;

	/** Angular spacing between successive branches, in radians — the golden angle, so `BRANCH_COUNT`-many branches (or more, if this ever grows) spread around the trunk without any two lining up. **/
	static inline final BRANCH_ANGLE_STEP:Float = 2.399963229728653;

	/** How far up the trunk (as a fraction of its own height) the lowest branch sprouts. **/
	static inline final BRANCH_BASE_HEIGHT_FRACTION:Float = 0.55;

	/** How much higher up the trunk each successive branch sprouts, as a fraction of the trunk's own height. **/
	static inline final BRANCH_HEIGHT_STEP_FRACTION:Float = 0.12;

	/** A branch's own length, as a fraction of the trunk's own height. **/
	static inline final BRANCH_LENGTH_FRACTION:Float = 0.35;

	/** A branch's own base radius, as a fraction of the trunk's own radius — noticeably thinner than the trunk it grows from. **/
	static inline final BRANCH_RADIUS_FRACTION:Float = 0.35;

	/** How far off horizontal a branch tilts upward, in radians. **/
	static inline final BRANCH_ELEVATION:Float = 0.6;

	/**
		Appends one trunk's own side wall to `points`/`idx`/`uvs`.
		@param points vertex buffer to append to.
		@param idx index buffer to append to.
		@param uvs UV buffer to append to (see class doc for the height-fraction convention).
		@param base the trunk's own root, at ground level.
		@param up unit vector along the trunk's own growth axis.
		@param tangent unit vector perpendicular to `up`, spanning the ring together with `right`.
		@param right unit vector perpendicular to both `up` and `tangent`.
		@param height the trunk's own height, base to top.
		@param radius the trunk's own radius.
	**/
	public static function addTrunk(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, uvs:Array<h3d.prim.UV>, base:h3d.Vector, up:h3d.Vector, tangent:h3d.Vector,
			right:h3d.Vector, height:Float, radius:Float):Void {
		addRing(points, idx, uvs, base, up, tangent, right, radius, 0, 0, radius, height, 1, TRUNK_SIDES);
	}

	/**
		Appends a layered-conifer foliage treatment on top of a trunk of
		`trunkRadius`/`trunkHeight` (see `addTrunk`) — a short collar
		flaring from the trunk's own radius out to `foliageRadius`, then two
		narrowing tiers up to a point, all one continuous silhouette (see
		class doc for why that matters).
		@param points vertex buffer to append to.
		@param idx index buffer to append to.
		@param uvs UV buffer to append to.
		@param base the trunk's own root (same origin `addTrunk` used).
		@param up unit vector along the tree's own growth axis.
		@param tangent unit vector perpendicular to `up`, spanning the ring together with `right`.
		@param right unit vector perpendicular to both `up` and `tangent`.
		@param trunkHeight/trunkRadius the trunk this sits on top of.
		@param foliageRadius the collar's own outer radius, and the widest point of the whole foliage.
		@param foliageHeight the whole foliage's own total height, trunk-top to tip.
	**/
	public static function addConiferFoliage(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, uvs:Array<h3d.prim.UV>, base:h3d.Vector, up:h3d.Vector,
			tangent:h3d.Vector, right:h3d.Vector, trunkHeight:Float, trunkRadius:Float, foliageRadius:Float, foliageHeight:Float):Void {
		var totalHeight = trunkHeight + foliageHeight;
		var collarY = trunkHeight + foliageHeight * CONIFER_COLLAR_FRACTION;
		var tierY = collarY + foliageHeight * CONIFER_TIER_FRACTION;
		var upperRadius = foliageRadius * CONIFER_UPPER_TIER_RADIUS_FRACTION;

		addRing(points, idx, uvs, base, up, tangent, right, trunkRadius, trunkHeight, heightFraction(trunkHeight, totalHeight), foliageRadius, collarY,
			heightFraction(collarY, totalHeight), FOLIAGE_SIDES);
		addRing(points, idx, uvs, base, up, tangent, right, foliageRadius, collarY, heightFraction(collarY, totalHeight), upperRadius, tierY,
			heightFraction(tierY, totalHeight), FOLIAGE_SIDES);
		addRing(points, idx, uvs, base, up, tangent, right, upperRadius, tierY, heightFraction(tierY, totalHeight), 0, totalHeight, 1, FOLIAGE_SIDES);
	}

	/**
		Appends a broad low-poly summer-canopy treatment on top of a trunk of
		`trunkRadius`/`trunkHeight` (see `addTrunk`) — widening in two steps
		into a chunky crown, holding that width through the middle, then
		tapering back to a point. More like a stylized authored "summer tree"
		silhouette than the previous simple teardrop.
		@param points vertex buffer to append to.
		@param idx index buffer to append to.
		@param uvs UV buffer to append to.
		@param base the trunk's own root (same origin `addTrunk` used).
		@param up unit vector along the tree's own growth axis.
		@param tangent unit vector perpendicular to `up`, spanning the ring together with `right`.
		@param right unit vector perpendicular to both `up` and `tangent`.
		@param trunkHeight/trunkRadius the trunk this sits on top of.
		@param foliageRadius the canopy's own widest radius, at its equator.
		@param foliageHeight the whole canopy's own total height, trunk-top to tip.
	**/
	public static function addRoundFoliage(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, uvs:Array<h3d.prim.UV>, base:h3d.Vector, up:h3d.Vector,
			tangent:h3d.Vector, right:h3d.Vector, trunkHeight:Float, trunkRadius:Float, foliageRadius:Float, foliageHeight:Float):Void {
		var totalHeight = trunkHeight + foliageHeight;
		var lowerY = trunkHeight + foliageHeight * SUMMER_LOWER_BULGE_FRACTION;
		var mainY = trunkHeight + foliageHeight * SUMMER_MAIN_BULGE_FRACTION;
		var upperY = trunkHeight + foliageHeight * SUMMER_UPPER_TAPER_FRACTION;
		var lowerRadius = foliageRadius * SUMMER_LOWER_RADIUS_FRACTION;
		var upperRadius = foliageRadius * SUMMER_UPPER_RADIUS_FRACTION;

		addRing(points, idx, uvs, base, up, tangent, right, trunkRadius, trunkHeight, heightFraction(trunkHeight, totalHeight), lowerRadius, lowerY,
			heightFraction(lowerY, totalHeight), FOLIAGE_SIDES);
		addRing(points, idx, uvs, base, up, tangent, right, lowerRadius, lowerY, heightFraction(lowerY, totalHeight), foliageRadius, mainY,
			heightFraction(mainY, totalHeight), FOLIAGE_SIDES);
		addRing(points, idx, uvs, base, up, tangent, right, foliageRadius, mainY, heightFraction(mainY, totalHeight), upperRadius, upperY,
			heightFraction(upperY, totalHeight), FOLIAGE_SIDES);
		addRing(points, idx, uvs, base, up, tangent, right, upperRadius, upperY, heightFraction(upperY, totalHeight), 0, totalHeight, 1, FOLIAGE_SIDES);
	}

	/**
		Appends a handful of bare stub branches directly onto the trunk's
		own side wall (no foliage at all) — the third, "dead tree" species,
		into the same buffers `addTrunk` used so they share its own trunk
		color. Branch placement is entirely derived from `trunkHeight`/
		`trunkRadius` and `rotation` (the same per-tree rotation
		`biomes.mobius.MobiusMesh` already applies to `tangent`/`right`
		before calling any of this class), not extra stored randomness —
		one fewer field `biomes.mobius.MobiusForestGenerator.PlacedTree`
		needs to carry.
		@param points vertex buffer to append to.
		@param idx index buffer to append to.
		@param uvs UV buffer to append to.
		@param base the trunk's own root (same origin `addTrunk` used).
		@param up unit vector along the tree's own growth axis.
		@param tangent unit vector perpendicular to `up`, spanning the ring together with `right`.
		@param right unit vector perpendicular to both `up` and `tangent`.
		@param trunkHeight/trunkRadius the trunk these branches grow from.
		@param rotation this tree's own per-instance rotation, in radians — reused as the first branch's own azimuth so a dead tree's branches still vary tree-to-tree.
	**/
	public static function addDeadBranches(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, uvs:Array<h3d.prim.UV>, base:h3d.Vector, up:h3d.Vector,
			tangent:h3d.Vector, right:h3d.Vector, trunkHeight:Float, trunkRadius:Float, rotation:Float):Void {
		var branchLength = trunkHeight * BRANCH_LENGTH_FRACTION;
		var branchRadius = trunkRadius * BRANCH_RADIUS_FRACTION;

		for (i in 0...BRANCH_COUNT) {
			var azimuth = rotation + i * BRANCH_ANGLE_STEP;
			var attachHeight = trunkHeight * (BRANCH_BASE_HEIGHT_FRACTION + i * BRANCH_HEIGHT_STEP_FRACTION);
			var outward = tangent.scaled(Math.cos(azimuth)).add(right.scaled(Math.sin(azimuth)));
			var direction = outward.scaled(Math.cos(BRANCH_ELEVATION)).add(up.scaled(Math.sin(BRANCH_ELEVATION))).normalized();

			var attachPoint = base.add(up.scaled(attachHeight)).add(outward.scaled(trunkRadius));
			var branchUp = direction;
			var branchTangent = outward.cross(branchUp).normalized();
			var branchRight = branchUp.cross(branchTangent).normalized();

			var branchV = heightFraction(attachHeight, trunkHeight);
			addRing(points, idx, uvs, attachPoint, branchUp, branchTangent, branchRight, branchRadius, 0, branchV, 0, branchLength, branchV, BRANCH_SIDES);
		}
	}

	/**
		One ring's own side wall, from a circle of `baseRadius` at height
		`baseY` up to a circle of `tipRadius` at height `tipY` — a plain
		cylinder wall when `baseRadius == tipRadius` (`addTrunk`'s own
		case), or a cone (triangles fanning to a point) when `tipRadius ==
		0` — the one shape every species builds from, same "one reusable
		band, different endpoints" discipline `biomes.hub.TowerReplica.addFrustumBand`'s
		own doc already describes for its spire. `baseV`/`tipV` are this
		ring's own UV.y at each end — the caller's job to keep continuous
		across a multi-ring stack (see `addConiferFoliage`/`addRoundFoliage`),
		not derived locally, since a single ring has no idea where it sits
		within its own tree's overall height.
	**/
	static function addRing(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, uvs:Array<h3d.prim.UV>, base:h3d.Vector, up:h3d.Vector, tangent:h3d.Vector,
			right:h3d.Vector, baseRadius:Float, baseY:Float, baseV:Float, tipRadius:Float, tipY:Float, tipV:Float, sides:Int):Void {
		var step = 2 * Math.PI / sides;
		for (i in 0...sides) {
			var a0 = i * step;
			var a1 = (i + 1) * step;
			var baseA = ringPoint(base, up, tangent, right, baseRadius, a0, baseY);
			var baseB = ringPoint(base, up, tangent, right, baseRadius, a1, baseY);
			if (tipRadius <= 0) {
				var tip = base.add(up.scaled(tipY));
				MeshBuilder.addTriangle(points, idx, baseA, baseB, tip);
				uvs.push(new h3d.prim.UV(0, baseV));
				uvs.push(new h3d.prim.UV(0, baseV));
				uvs.push(new h3d.prim.UV(0, tipV));
			} else {
				var tipA = ringPoint(base, up, tangent, right, tipRadius, a0, tipY);
				var tipB = ringPoint(base, up, tangent, right, tipRadius, a1, tipY);
				MeshBuilder.addQuad(points, idx, baseA, baseB, tipB, tipA);
				uvs.push(new h3d.prim.UV(0, baseV));
				uvs.push(new h3d.prim.UV(0, baseV));
				uvs.push(new h3d.prim.UV(0, tipV));
				uvs.push(new h3d.prim.UV(0, tipV));
			}
		}
	}

	/** A point at `radius`/`angle` around the ring centered on `base`'s own axis, raised `height` along `up`. **/
	static inline function ringPoint(base:h3d.Vector, up:h3d.Vector, tangent:h3d.Vector, right:h3d.Vector, radius:Float, angle:Float, height:Float):h3d.Vector {
		return base.add(up.scaled(height)).add(tangent.scaled(radius * Math.cos(angle))).add(right.scaled(radius * Math.sin(angle)));
	}

	/** `y` as a fraction of `totalHeight`, for the UV height-gradient convention (see class doc). **/
	static inline function heightFraction(y:Float, totalHeight:Float):Float {
		return y / totalHeight;
	}
}
