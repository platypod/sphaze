package biomes.common.space.sphere;

import biomes.common.space.common.Space;

/**
	The sphere walked on from the *outside*: identical to `SphereSpace` in
	every respect except which way "up" points — away from the centre here,
	toward it there. That one sign is the entire difference between this
	game's core viewpoint and its inversion (see `biomes.exterior.ExteriorBiome`),
	which is exactly the kind of thing extracting `Space` was for.

	Movement is untouched and *not* re-derived: an arc along the surface is the
	same rotation whichever side of the shell you stand on, so `moveAlong`
	delegates to `SphereSpace`'s own implementation rather than repeating
	Rodrigues here.

	Everything downstream picks the flip up for free, because it all reads
	`PlayerModel.surfaceUp` rather than assuming a direction:
	`entities.player.Camera` places the eye and derives the pitch axis from it,
	`biomes.common.Gravity` integrates `airborneHeight` along it, and
	`PlayerModel.turn`/`rightVector` rotate around it. That's why an
	exterior biome needed no changes to player, camera or collision code at
	all — only this class and an outward wall extrusion.
**/
class SphereExteriorSpace implements Space {
	/** The single shared instance — stateless, same as `SphereSpace.INSTANCE`. **/
	public static final INSTANCE:SphereExteriorSpace = new SphereExteriorSpace();

	function new() {}

	/** See `Space.upAt` — away from the sphere's centre, the opposite of `SphereSpace.upAt`. **/
	public function upAt(pos:h3d.Vector):h3d.Vector {
		return pos.normalized();
	}

	/** See `Space.moveAlong` — delegated to `SphereSpace`: which side of the shell you're on doesn't change what an arc is. **/
	public function moveAlong(pos:h3d.Vector, forward:h3d.Vector, direction:h3d.Vector, distance:Float, radius:Float):{pos:h3d.Vector, forward:h3d.Vector} {
		return SphereSpace.INSTANCE.moveAlong(pos, forward, direction, distance, radius);
	}
}
