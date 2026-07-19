package biomes.hub;

import biomes.common.space.sphere.SphereMath;

/**
	A local flat frame anchored at one point on the hub sphere — what both
	`MazeShrine` and `TowerReplica` build (and collide against) themselves
	in, rather than in world coordinates directly. Both are small structures
	(on the order of tens of units) against a `HubModel.RADIUS`-70 sphere,
	so the curvature across either one's own footprint is negligible; a
	single fixed tangent-plane frame at each structure's own anchor point is
	a reasonable, much simpler approximation than wrapping either structure
	around the sphere the way a full biome's own geometry has to.

	`uAxis`/`vAxis` come straight from `SphereMath.phiTangentAt`/`thetaTangentAt`
	— already unit tangents at the anchor, already perpendicular to each
	other and to `up`, so there's no separate basis-construction step needed.
**/
typedef StructureBasis = {
	/** The anchor point itself — on the sphere's own walkable surface, i.e. this structure's own ground level. **/
	var origin:h3d.Vector;

	/** Local "up" at the anchor — toward the sphere's center, matching every other convention in this project. **/
	var up:h3d.Vector;

	/** Local "east," increasing phi. **/
	var uAxis:h3d.Vector;

	/** Local "north," increasing theta. **/
	var vAxis:h3d.Vector;
}

class HubStructure {
	/**
		The local frame for a structure anchored at `(theta, phi)`.
		@param theta polar angle from +Y, in radians.
		@param phi azimuth around Y, in radians.
		@param radius the hub's own sphere radius (`HubModel.RADIUS`).
		@return the structure's own local frame.
	**/
	public static function anchorAt(theta:Float, phi:Float, radius:Float):StructureBasis {
		var origin = SphereMath.sphericalToCartesian(radius, theta, phi);
		var up = SphereMath.upVectorAt(origin, new h3d.Vector(0, 0, 0));
		return {
			origin: origin,
			up: up,
			uAxis: SphereMath.phiTangentAt(phi),
			vAxis: SphereMath.thetaTangentAt(theta, phi)
		};
	}

	/**
		A world point at local offset `(u, v)` from `basis.origin`, raised
		`height` along `basis.up`.
		@param basis the structure's own local frame.
		@param u local east/west offset.
		@param v local north/south offset.
		@param height how far up from the structure's own ground level.
		@return the corresponding world point.
	**/
	public static function worldPoint(basis:StructureBasis, u:Float, v:Float, height:Float):h3d.Vector {
		return basis.origin.add(basis.uAxis.scaled(u)).add(basis.vAxis.scaled(v)).add(basis.up.scaled(height));
	}

	/**
		The local `(u, v)` of a world point, projected onto `basis`'s own
		tangent plane (the inverse of `worldPoint`'s own `u`/`v`), plus that
		same point's own `height` along `basis.up` — *not* ignored the way
		`worldPoint`'s doc used to describe, and not a player's jump height
		either: purely how far `worldPos` itself sits off `basis`'s flat
		tangent plane. For any point actually near the structure this is
		negligible (the same "curvature is negligible at this scale"
		approximation `HubStructure`'s own class doc already leans on), but
		it grows large fast moving away — the point diametrically opposite
		`basis.origin` on the real sphere projects to local `(u, v) = (0, 0)`
		*exactly*, regardless of the structure's own position (its
		displacement from the anchor is purely radial, and radial is exactly
		what `uAxis`/`vAxis` are perpendicular to by construction) while its
		`height` comes out to `2 * radius`. A caller that only ever checked
		`(u, v)` against a small local footprint (see `MazeShrine.blocksMovement`'s
		own history) read that antipodal point as sitting right on top of the
		structure — reported directly as "on the opposite side of the sphere,
		you still get blocked by the wall's hitbox" — so any such caller
		needs to also bound `height` to reject points this far from its own
		local ground, not just check `(u, v)`.
		@param basis the structure's own local frame.
		@param worldPos the world point to project.
		@return that point's local `(u, v, height)`.
	**/
	public static function localUV(basis:StructureBasis, worldPos:h3d.Vector):{u:Float, v:Float, height:Float} {
		var relative = worldPos.sub(basis.origin);
		return {u: relative.dot(basis.uAxis), v: relative.dot(basis.vAxis), height: relative.dot(basis.up)};
	}

	/**
		Distance from local point `(u, v)` to the line segment `(aU, aV)`-`(bU, bV)`
		— standard clamped point-to-segment distance, shared by any
		structure whose collision is "don't get too close to any of these
		wall segments" (see `MazeShrine.blocksMovement`).
		@param u the point's own local u.
		@param v the point's own local v.
		@param aU the segment's first endpoint, u.
		@param aV the segment's first endpoint, v.
		@param bU the segment's second endpoint, u.
		@param bV the segment's second endpoint, v.
		@return the shortest distance from `(u, v)` to the segment.
	**/
	public static function distanceToSegment(u:Float, v:Float, aU:Float, aV:Float, bU:Float, bV:Float):Float {
		var abU = bU - aU;
		var abV = bV - aV;
		var lengthSq = abU * abU + abV * abV;
		var t = lengthSq > 0 ? hxd.Math.clamp(((u - aU) * abU + (v - aV) * abV) / lengthSq, 0, 1) : 0.0;
		var closestU = aU + abU * t;
		var closestV = aV + abV * t;
		var dU = u - closestU;
		var dV = v - closestV;
		return Math.sqrt(dU * dU + dV * dV);
	}
}
