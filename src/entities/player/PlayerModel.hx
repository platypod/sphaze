package entities.player;

import biomes.common.space.common.Space;
import biomes.common.space.sphere.SphereMath;
import biomes.common.space.sphere.SphereSpace;
import entities.Entity;

/**
	The player's position and facing direction on the maze sphere's interior
	surface, plus a pitch for looking up toward the center. Both `pos` and
	`forward` are plain 3D vectors — not spherical coordinates (theta, phi)
	— updated by direct rotation as the player moves or turns, never
	reconstructed from a (theta, phi) parameterization.

	That's a deliberate fix, not a style choice: (theta, phi) is singular at
	the poles — circles of latitude shrink to zero circumference there, so a
	tiny physical step near a pole corresponds to a huge change in phi, even
	though the actual 3D position barely moved. `facing` used to be a scalar
	angle measured against a tangent basis derived fresh from phi every
	frame (`thetaTangentAt(theta, phi)`), so that phi instability showed up
	as the *view* spinning wildly near a pole — reported directly as
	"pivoting at mach-speed like a spinner" while walking through one.
	Storing `pos`/`forward` as vectors and rotating them directly has no
	such singularity anywhere on the sphere, poles included.

	An `Entity` (CLAUDE.md "Architecture") — the first one, now that
	cross-biome creatures and NPCs are the second use case the foundation
	was deferred pending (see docs/GUIDELINES.md §1.3). Doesn't override
	`onFixedUpdate`: its own movement stays driven by `GameLoop`'s explicit
	input handling, not automatic per-tick behavior, so being an `Entity`
	today only means it can be parented in a `Process` tree — nothing about
	how it moves has changed.

	Rotation math (local "up", moving `pos`/`forward` along a tangent) is
	delegated through `space:Space` rather than hardcoded here — every method
	below still reads as sphere math today because `SphereSpace` is the only
	implementation, but a future biome with a different topology would spawn
	its `PlayerModel` with its own `Space` instead of this class needing to
	know about it.

	Camera placement (`applyToCamera`, `EYE_HEIGHT`) lives on `Camera`, not
	here — this class is the player's own state and movement, not how a
	camera gets derived from it.

	Doesn't re-orthogonalize `pos`/`forward` against accumulated floating-
	point drift over many small rotations — each rotation preserves their
	relationship exactly in theory, and this hasn't shown up as a problem in
	practice. Revisit (e.g. a periodic Gram-Schmidt pass) if it ever does.
**/
class PlayerModel extends Entity {
	/**
		Clamped just short of pi/2: at exactly pi/2 the view direction would
		be exactly parallel to the camera's up vector, which is a degenerate
		lookAt (no well-defined "right"). Visually indistinguishable from a
		true 90 degrees.
	**/
	public static inline final MAX_PITCH:Float = 1.55; // ~88.8 degrees

	/** Position on the sphere's interior surface. **/
	public var pos:h3d.Vector;

	/** Unit tangent vector at `pos`: the horizontal look/walk direction. **/
	public var forward:h3d.Vector;

	/** View tilt from horizontal (0) toward the sphere's center (+MAX_PITCH) or the floor (-MAX_PITCH). **/
	public var pitch:Float;

	/**
		Which biome's topology `pos`/`forward` live in — defaults to
		`SphereSpace`, the only implementation that exists today, so every
		existing call site (spawning, tests) is unaffected by this field's
		presence. A future non-spherical biome would spawn its own
		`PlayerModel` with its own `Space` instead.
	**/
	public final space:Space;

	/**
		A continuous choice of local "up" at `pos`, used for camera roll,
		turning, and strafing. `space.upAt(pos)` alone is enough on orientable
		surfaces (sphere, plane), but not on the Möbius strip: there, the same
		physical point has two equally valid opposite normals, and
		`MobiusSpace.upAt` necessarily picks one branch discontinuously at the
		seam. Keeping the branch closest to the previous tick's own choice
		preserves a stable local frame while the player walks through that
		wrap.
	**/
	public var surfaceUp:h3d.Vector;

	/**
		Current vertical speed — positive moves away from the ground,
		negative toward it. Shared physics state that any biome's own
		`biomes.common.Biome.applyGravity` integrates every fixed step;
		*where* that motion actually shows up (`airborneHeight` here, or a
		biome tracking real world height in `pos` directly, like the tower)
		is that biome's own concern, not this class's.
	**/
	public var verticalVelocity:Float = 0;

	/**
		Whether the player is currently standing on solid ground, per
		whichever biome's own `biomes.common.Biome.applyGravity` last
		decided. `jump` only takes effect while this is true, so holding the
		key doesn't stack impulses in mid-air.
	**/
	public var grounded:Bool = true;

	/**
		How far above the surface `pos` sits, along `space.upAt(pos)` — a
		cosmetic offset for a biome whose floor is present everywhere (see
		`biomes.common.Gravity.fallToSurface`), so a jump never has to touch
		`pos` itself and none of the horizontal collision math built against
		a fixed `pos` (e.g. `biomes.common.grid.GridCollision`'s theta/phi
		lookups) needs to change while airborne. A biome with real
		multi-level falling (the tower) tracks height in `pos` directly
		instead and leaves this at 0, unused.
	**/
	public var airborneHeight:Float = 0;

	public function new(pos:h3d.Vector, forward:h3d.Vector, pitch:Float = 0, ?space:Space) {
		super();
		this.pos = pos;
		this.forward = forward;
		this.pitch = clampPitch(pitch);
		this.space = space != null ? space : SphereSpace.INSTANCE;
		this.surfaceUp = this.space.upAt(pos);
	}

	/**
		Builds a PlayerModel standing at a spherical (theta, phi) position,
		facing `facing` radians around from thetaTangentAt (0 = toward
		increasing theta). Only ever used once, at spawn — see the class
		doc for why PlayerModel's own state afterward is plain 3D vectors,
		never theta/phi again.
		@param theta polar angle from +Y, in radians.
		@param phi azimuth around Y, in radians.
		@param facing initial look direction, in radians from thetaTangentAt.
		@param radius sphere radius — must match the biome's physical sphere (see GridGeometry.RADIUS).
		@return a PlayerModel at that position and facing.
	**/
	public static function spawnAt(theta:Float, phi:Float, facing:Float, radius:Float):PlayerModel {
		var spawnPos = SphereMath.sphericalToCartesian(radius, theta, phi);
		var up = SphereMath.upVectorAt(spawnPos, new h3d.Vector(0, 0, 0));
		var spawnForward = SphereMath.rotateAroundAxis(SphereMath.thetaTangentAt(theta, phi), up, facing);
		return new PlayerModel(spawnPos, spawnForward);
	}

	/**
		Unit tangent to the right of `forward`, ignoring pitch — the same
		computation `Camera.applyTo` already needs for its own pitch-rotation
		axis, exposed here too for strafing (see `GridCollision`), which
		moves sideways without turning to face that direction.
		@return unit tangent at `pos`, perpendicular to `forward`, pointing right.
	**/
	public function rightVector():h3d.Vector {
		return forward.cross(surfaceUp).normalized();
	}

	/**
		Walks forward (or backward, for a negative distance) along
		`forward` — pitch doesn't affect movement. Rotates `pos` and
		`forward` together, by the same angle around the same axis, within
		the great circle they define: exact for any distance (not a
		small-step approximation), and always stays exactly on the sphere
		and tangent to it by construction — including straight through a
		pole, since this never touches theta/phi.
		@param distance arc length to walk; negative walks backward.
		@param radius sphere radius — must match the biome's physical sphere (see GridGeometry.RADIUS).
	**/
	public function moveForward(distance:Float, radius:Float):Void {
		applyMoveResult(space.moveAlong(pos, forward, forward, distance, radius));
	}

	/**
		Translates `pos` by `distance` along `direction` — a unit tangent at
		`pos`, not necessarily `forward`. For sliding along a wall (see
		`GridCollision`), where the player's body gets redirected without
		them actively choosing to turn.

		`forward` is parallel-transported by the same rotation as `pos`
		(exactly like `moveForward` does for its own direction), *not* left
		untouched: `forward` staying a valid unit tangent at `pos` is a hard
		invariant every other method here relies on (`SphereSpace.moveAlong`'s
		own `axis = posDir.cross(direction)`, `Camera.applyTo`'s `right =
		forward.cross(up)`, ...). An earlier version skipped this to keep the
		view from "snapping" during a slide — reasonable-sounding, but it let
		`forward` drift out of the tangent plane over repeated slides, since
		nothing ever re-aligned it to the position's own tangent plane as
		that plane rotated out from under it; a few ticks of sliding was
		enough to visibly break movement (reported directly as gliding that
		"stops working after a really short time"). Transporting it this way
		keeps the angle between `forward` and the slide direction fixed,
		which is the correct minimal adjustment on a curved surface — not a
		re-orientation toward the wall, just what staying tangent costs.
		@param direction unit tangent at `pos` to move along.
		@param distance arc length to move; negative moves the opposite way.
		@param radius sphere radius — must match the biome's physical sphere (see GridGeometry.RADIUS).
	**/
	public function moveAlong(direction:h3d.Vector, distance:Float, radius:Float):Void {
		applyMoveResult(space.moveAlong(pos, forward, direction, distance, radius));
	}

	/**
		Rotates `forward` by `deltaAngle` radians around the local "up" axis
		(toward the sphere's center).
		@param deltaAngle angle to turn by, in radians.
	**/
	public function turn(deltaAngle:Float):Void {
		forward = SphereMath.rotateAroundAxis(forward, surfaceUp, deltaAngle);
	}

	/**
		Tilts `pitch` by `deltaAngle` radians, clamped to +-MAX_PITCH
		(positive looks up, toward the sphere's center).
		@param deltaAngle angle to tilt by, in radians.
	**/
	public function lookUp(deltaAngle:Float):Void {
		pitch = clampPitch(pitch + deltaAngle);
	}

	/**
		Launches the player upward at `impulse` — a no-op unless `grounded`.
		Leaving the ground from here on (gravity's pull, landing) is each
		biome's own `biomes.common.Biome.applyGravity`, not this method's
		concern.
		@param impulse initial upward speed.
	**/
	public function jump(impulse:Float):Void {
		if (!grounded) {
			return;
		}
		verticalVelocity = impulse;
		grounded = false;
	}

	function applyMoveResult(result:{pos:h3d.Vector, forward:h3d.Vector}):Void {
		var previousUp = surfaceUp;
		pos = result.pos;
		forward = result.forward;

		var newUp = space.upAt(pos);
		if (newUp.dot(previousUp) < 0) {
			newUp = newUp.scaled(-1);
		}
		surfaceUp = newUp;
	}

	static function clampPitch(p:Float):Float {
		return hxd.Math.clamp(p, -MAX_PITCH, MAX_PITCH);
	}
}
