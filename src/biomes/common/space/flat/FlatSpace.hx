package biomes.common.space.flat;

import biomes.common.space.common.Space;

/**
	The first non-spherical `Space`: an ordinary flat Cartesian topology,
	`up` fixed at world-`+Y` everywhere rather than varying by position (see
	`sphere.SphereSpace`, the only other implementation, where `up` is
	toward a sphere's center and changes with `pos`). Introduced for the
	tower biome's vertical shaft, which needs real straight-line movement
	and free-fall through open space rather than a curved walkable surface.

	Stateless, same shape as `SphereSpace.INSTANCE` — nothing here depends
	on which particular flat biome is asking, just the topology itself.
**/
class FlatSpace implements Space {
	/** The single shared instance — see class doc for why one instance covers every flat biome. **/
	public static final INSTANCE:FlatSpace = new FlatSpace();

	static final UP:h3d.Vector = new h3d.Vector(0, 1, 0);

	function new() {}

	/** See `Space.upAt` — always world-`+Y`, regardless of `pos`. **/
	public function upAt(pos:h3d.Vector):h3d.Vector {
		return UP;
	}

	/**
		See `Space.moveAlong` — no curvature to rotate around, so this is
		just a straight translation; `forward` is returned unchanged (unlike
		`SphereSpace.moveAlong`, nothing here ever pulls it out of tangent
		with anything, since every direction is already "tangent" to a flat
		space). `radius` is unused — a flat space has no physical scale to
		measure a rotation angle against — but stays in the signature to
		satisfy `Space`, same as every other implementation would for a
		parameter it happens not to need.
	**/
	public function moveAlong(pos:h3d.Vector, forward:h3d.Vector, direction:h3d.Vector, distance:Float, radius:Float):{pos:h3d.Vector, forward:h3d.Vector} {
		return {pos: pos.add(direction.scaled(distance)), forward: forward};
	}
}
