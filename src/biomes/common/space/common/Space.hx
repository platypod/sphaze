package biomes.common.space.common;

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

	/**
		Rotates `forward` in place by `angle` radians, keeping it a unit
		tangent at `pos`. Positive turns the player to their right, matching
		`game.Keybinds.TURN_RIGHT`.

		**Why this is on the interface at all**, having lived in
		`entities.player.PlayerModel` as a single line of Euclidean rotation
		since long before any of this existed: that line is
		`rotateAroundAxis(forward, up, angle)`, which is correct in every
		space whose model coordinates *are* ambient ℝ³ — the sphere, the
		plane, the Möbius strip — and meaningless in one whose coordinates
		are not. `hyperbolic.HyperbolicSpace` stores hyperboloid coordinates
		under a Minkowski form, where "rotate about the up axis" is not a
		rotation of anything. Turning had to become the space's own business,
		exactly as moving already was.
		@param pos the position being turned at.
		@param forward the current unit tangent.
		@param up the local "up" to turn about, as `entities.player.PlayerModel.surfaceUp` maintains it — passed in rather than recomputed, so the Möbius strip's own sign-continuity choice is respected. A space whose coordinates make this meaningless (`hyperbolic.HyperbolicSpace`) ignores it.
		@param angle rotation in radians; positive turns right.
		@return the rotated unit tangent.
	**/
	function turn(pos:h3d.Vector, forward:h3d.Vector, up:h3d.Vector, angle:Float):h3d.Vector;

	/**
		The unit tangent at `pos` perpendicular to `forward`, for strafing
		(see `biomes.common.grid.GridCollision`) and for
		`entities.player.Camera.applyTo`'s own pitch axis.

		**Its screen sense is inverted, and always has been.** This returns
		`forward × up`, the standard right-handed "right" — but Heaps'
		camera is left-handed (`s3d.camera.rightHanded == false`), so what
		lands on the *screen's* right is the negative of this, and
		`game.GameLoop` has negated it at the strafe site since that was
		found. The convention is preserved here rather than fixed, because
		flipping it would also flip which way `PlayerModel.lookUp` tilts in
		every existing biome; a space with no ambient cross product to take
		(`hyperbolic.HyperbolicSpace`) therefore returns the vector matching
		this same inverted convention, so that one negation in `GameLoop`
		keeps working unchanged. Logged as a wart in `docs/open/bug-tracker.md`.
		@param pos the position to find "right" at.
		@param forward the current unit tangent.
		@param up the local "up", as `entities.player.PlayerModel.surfaceUp` maintains it — see `turn`'s own parameter doc.
		@return the unit tangent perpendicular to `forward`, in the inverted convention described above.
	**/
	function rightOf(pos:h3d.Vector, forward:h3d.Vector, up:h3d.Vector):h3d.Vector;
}
