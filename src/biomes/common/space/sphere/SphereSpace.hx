package biomes.common.space.sphere;

import biomes.common.space.common.Space;

/**
	The only `Space` implementation today: a sphere centered at the world
	origin, with the walkable surface being its interior. Wraps `SphereMath`'s
	existing rotation-around-axis math unchanged — see `Space`'s own class doc
	for why this logic lives behind an interface at all.

	Stateless (no per-instance radius: `moveAlong` takes it as a call
	parameter, same as `Player`'s own methods already did before this
	extraction), so one shared `instance` covers every sphere-based biome
	regardless of its own radius — `biomes.common.grid.GridGeometry.RADIUS`
	and `biomes.hub.HubModel.RADIUS` both use it as-is.
**/
class SphereSpace implements Space {
	/** The single shared instance — see class doc for why one instance covers every sphere-based biome. **/
	public static final INSTANCE:SphereSpace = new SphereSpace();

	function new() {}

	/** See `Space.upAt` — the sphere's center is always the world origin here. **/
	public function upAt(pos:h3d.Vector):h3d.Vector {
		return SphereMath.upVectorAt(pos, new h3d.Vector(0, 0, 0));
	}

	/** See `Space.moveAlong` — Rodrigues rotation around the axis perpendicular to `pos` and `direction`, exact for any `distance`. **/
	public function moveAlong(pos:h3d.Vector, forward:h3d.Vector, direction:h3d.Vector, distance:Float, radius:Float):{pos:h3d.Vector, forward:h3d.Vector} {
		var posDir = pos.normalized();
		var angle = distance / radius;
		var axis = posDir.cross(direction).normalized();

		var newForward = SphereMath.rotateAroundAxis(forward, axis, angle);
		var newPos = SphereMath.rotateAroundAxis(posDir, axis, angle).scaled(radius);
		return {pos: newPos, forward: newForward};
	}
}
