package game;

/**
	How a biome's walkable surface behaves: the local "up" at a position, and
	how a position+forward pair moves along a tangent direction by an arc
	distance. `Player` delegates its rotation math through this instead of
	hardcoding "sphere centered at the world origin" directly — `SphereSpace`
	is the only implementation today, but this is the seam a future
	non-spherical biome would need, extracted now rather than after a second
	topology already exists to retrofit against.
**/
interface Space {
	/**
		Local "up" at a position on this space's walkable surface — for a
		sphere, the direction back toward its center.
		@param pos the position to find local "up" at.
		@return unit vector pointing "up" from `pos`.
	**/
	function upAt(pos:h3d.Vector):h3d.Vector;

	/**
		Moves `pos`/`forward` together along `direction` (a unit tangent at
		`pos`) by `distance` (arc length; negative moves the opposite way),
		returning the new pair. `forward` is parallel-transported by the same
		motion, not left untouched — see `SphereSpace.moveAlong`'s doc for why
		that matters.
		@param pos the position to move from.
		@param forward the forward vector to transport along with `pos`.
		@param direction unit tangent at `pos` to move along.
		@param distance arc length to move; negative moves the opposite way.
		@param radius this space's own physical scale (e.g. sphere radius) — must match whichever biome's own scale `pos` belongs to.
		@return the new `pos`/`forward` pair.
	**/
	function moveAlong(pos:h3d.Vector, forward:h3d.Vector, direction:h3d.Vector, distance:Float, radius:Float):{pos:h3d.Vector, forward:h3d.Vector};
}
