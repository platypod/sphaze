package biomes.common.tree;

import game.MeshBuilder;

/**
	Builds one tree's own geometry — a plain cylindrical trunk plus two
	stacked, overlapping cones for foliage (a cheap "conifer" silhouette,
	the same "cheapest shape that still reads right" discipline
	`biomes.common.grass.GrassMesh`'s own crossed-blade tufts already use)
	— appended into whatever point/index buffers the caller passes in,
	rather than building its own `h3d.scene.Mesh`. That split exists so a
	whole forest's worth of trees can batch into one trunk mesh and one
	foliage mesh (two draw calls total, regardless of tree count) instead
	of one mesh per tree — same "batch everything into a single
	`h3d.prim.Polygon`" approach `GrassMesh`/`biomes.mobius.MobiusMesh`
	already use for their own many-instance geometry.

	Topology-agnostic: takes a tree's own local frame (`base`/`up`/
	`tangent`/`right`, an orthonormal triple — `up` the trunk's own growth
	axis, `tangent`/`right` spanning the ring perpendicular to it) rather
	than assuming a specific biome's own surface math, so this lives in
	`biomes.common` for any future biome that wants trees too, same
	reasoning `GrassModel`'s own class doc gives for taking `radius`/
	`isWalkable` as parameters instead of reaching into one biome's own
	geometry directly. `biomes.mobius.MobiusMath.localFrameAt`'s own
	`{tu, tv, normal}` already is exactly this triple (`tangent = tu`,
	`right = tv`, `up = normal`) — callers don't need to derive a fresh
	basis.

	No top/bottom caps on the trunk or the foliage cones' own base disks —
	never visible from a player's own eye height looking up at (or across
	at) a tree taller than they are, same "don't build a face nothing will
	ever see" discipline `biomes.tower.TowerMesh`'s own relief walls
	already follow. `culling = None` on whatever mesh the caller builds
	from these buffers sidesteps needing to get each ring's own winding
	order exactly right for backface culling — the same call this
	project's other solid-looking meshes (`biomes.tower.TowerMesh`'s outer
	wall, `biomes.mobius.MobiusMesh`'s own bands) already make.
**/
class TreeMesh {
	/** Trunk cross-section facets — cheap, since a thin trunk reads fine faceted (same reasoning `biomes.hub.HubMesh`'s deliberately 8-sided column already leans on). **/
	static inline final TRUNK_SIDES:Int = 6;

	/** Foliage cone facets — a little smoother than the trunk since the canopy is the tree's own most visible silhouette. **/
	static inline final FOLIAGE_SIDES:Int = 8;

	/** Fraction of the total foliage height the lower (wider) cone spans. **/
	static inline final LOWER_FOLIAGE_FRACTION:Float = 0.6;

	/** How far the upper cone's own base drops down into the lower cone, as a fraction of the lower cone's own height — keeps the two reading as one layered canopy rather than two separate cones stacked tip-to-base with a visible seam. **/
	static inline final FOLIAGE_OVERLAP_FRACTION:Float = 0.35;

	/** The upper cone's own base radius, as a fraction of the lower cone's — narrower, so the silhouette actually tapers going up. **/
	static inline final UPPER_FOLIAGE_RADIUS_FRACTION:Float = 0.62;

	/**
		Appends one trunk's own side wall (no top/bottom caps — see class
		doc) to `points`/`idx`.
		@param points vertex buffer to append to.
		@param idx index buffer to append to.
		@param base the trunk's own root, at ground level.
		@param up unit vector along the trunk's own growth axis.
		@param tangent unit vector perpendicular to `up`, spanning the ring together with `right`.
		@param right unit vector perpendicular to both `up` and `tangent`.
		@param height the trunk's own height, base to top.
		@param radius the trunk's own radius.
	**/
	public static function addTrunk(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, base:h3d.Vector, up:h3d.Vector, tangent:h3d.Vector, right:h3d.Vector,
			height:Float, radius:Float):Void {
		addRing(points, idx, base, up, tangent, right, radius, 0, radius, height, TRUNK_SIDES);
	}

	/**
		Appends one tree's own foliage — two stacked, overlapping cones (see
		class doc) — to `points`/`idx`, sitting directly on top of the
		trunk.
		@param points vertex buffer to append to.
		@param idx index buffer to append to.
		@param base the trunk's own root, at ground level (same origin `addTrunk` used).
		@param up unit vector along the tree's own growth axis.
		@param tangent unit vector perpendicular to `up`, spanning the ring together with `right`.
		@param right unit vector perpendicular to both `up` and `tangent`.
		@param trunkHeight where the trunk ends and the foliage begins.
		@param foliageRadius the lower (wider) cone's own base radius.
		@param foliageHeight the whole foliage's own total height, trunk-top to tip.
	**/
	public static function addFoliage(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, base:h3d.Vector, up:h3d.Vector, tangent:h3d.Vector, right:h3d.Vector,
			trunkHeight:Float, foliageRadius:Float, foliageHeight:Float):Void {
		var lowerHeight = foliageHeight * LOWER_FOLIAGE_FRACTION;
		var lowerBaseY = trunkHeight;
		var lowerTipY = trunkHeight + lowerHeight;
		var upperBaseY = lowerTipY - lowerHeight * FOLIAGE_OVERLAP_FRACTION;
		var upperTipY = trunkHeight + foliageHeight;
		var upperRadius = foliageRadius * UPPER_FOLIAGE_RADIUS_FRACTION;

		addRing(points, idx, base, up, tangent, right, foliageRadius, lowerBaseY, 0, lowerTipY, FOLIAGE_SIDES);
		addRing(points, idx, base, up, tangent, right, upperRadius, upperBaseY, 0, upperTipY, FOLIAGE_SIDES);
	}

	/**
		One ring's own side wall, from a circle of `baseRadius` at height
		`baseY` up to a circle of `tipRadius` at height `tipY` — a plain
		cylinder wall when `baseRadius == tipRadius` (`addTrunk`'s own
		case), or a cone (triangles fanning to a point) when `tipRadius ==
		0` (`addFoliage`'s own case) — the one shape both build from, same
		"one reusable band, different endpoints" discipline
		`biomes.hub.TowerReplica.addFrustumBand`'s own doc already
		describes for its spire.
	**/
	static function addRing(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, base:h3d.Vector, up:h3d.Vector, tangent:h3d.Vector, right:h3d.Vector,
			baseRadius:Float, baseY:Float, tipRadius:Float, tipY:Float, sides:Int):Void {
		var step = 2 * Math.PI / sides;
		for (i in 0...sides) {
			var a0 = i * step;
			var a1 = (i + 1) * step;
			var baseA = ringPoint(base, up, tangent, right, baseRadius, a0, baseY);
			var baseB = ringPoint(base, up, tangent, right, baseRadius, a1, baseY);
			if (tipRadius <= 0) {
				var tip = base.add(up.scaled(tipY));
				MeshBuilder.addTriangle(points, idx, baseA, baseB, tip);
			} else {
				var tipA = ringPoint(base, up, tangent, right, tipRadius, a0, tipY);
				var tipB = ringPoint(base, up, tangent, right, tipRadius, a1, tipY);
				MeshBuilder.addQuad(points, idx, baseA, baseB, tipB, tipA);
			}
		}
	}

	/** A point at `radius`/`angle` around the ring centered on `base`'s own axis, raised `height` along `up`. **/
	static inline function ringPoint(base:h3d.Vector, up:h3d.Vector, tangent:h3d.Vector, right:h3d.Vector, radius:Float, angle:Float, height:Float):h3d.Vector {
		return base.add(up.scaled(height)).add(tangent.scaled(radius * Math.cos(angle))).add(right.scaled(radius * Math.sin(angle)));
	}
}
