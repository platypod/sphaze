package entities.player;

import biomes.common.space.sphere.SphereMath;

/**
	Derives a camera's position/orientation from a `PlayerModel`'s own state
	— a stateless utility (matching `game.MeshBuilder`'s own style), kept
	separate from `PlayerModel` itself: where the player *is* and how a
	camera gets placed from that are different concerns, and only the
	latter needs `EYE_HEIGHT` or knows about `h3d.Camera` at all.
**/
class Camera {
	/**
		Camera height above the floor shell, toward the sphere's center.
		Without this the camera sits exactly on the floor mesh — looking up
		then grazes along/through the very floor it's embedded in instead of
		clearing it, which is what made the far side unreachable in practice
		even after the up-vector fix (caught by comparing screenshots at
		different pitches once that fix alone didn't change the picture:
		still a flat, undifferentiated fill, at every pitch above ~0). Kept
		below `biomes.common.grid.GridMesh.WALL_HEIGHT` so walls still read
		as walls.
	**/
	public static inline final EYE_HEIGHT:Float = 6;

	/**
		Positions and orients `camera` at `player`'s location: standing on
		the sphere's interior, looking along `forward` tilted by `pitch`
		toward the sphere's center. The camera's up vector tilts by the same
		pitch (rotated around the same axis as the view direction) rather
		than staying fixed at the sphere-relative "up" — keeping it fixed
		would let it drift toward parallel with the view direction as pitch
		increases, collapsing the camera's effective horizontal FOV toward
		zero well before reaching the pitch clamp (caught by comparing
		rendered screenshots at a few different pitches: the view was
		visibly squeezed to a sliver long before anything looked "wrong").
		@param camera the camera to position.
		@param player the player to position it at.
	**/
	public static function applyTo(camera:h3d.Camera, player:PlayerModel):Void {
		var up = player.surfaceUp;
		var eyePos = player.pos.add(up.scaled(EYE_HEIGHT + player.airborneHeight));
		var right = player.rightVector();
		var viewForward = SphereMath.rotateAroundAxis(player.forward, right, player.pitch);
		var viewUp = SphereMath.rotateAroundAxis(up, right, player.pitch);

		camera.pos.load(eyePos);
		camera.up.load(viewUp);
		camera.target.load(eyePos.add(viewForward));
	}
}
