package entities;

import game.SphereMath;

/**
	The player's position, facing, and pitch on the maze sphere's interior
	surface. Position is spherical (theta, phi) rather than Cartesian so
	movement can update it directly with grid-relative deltas; facing is the
	look direction's angle within the local tangent plane, measured from
	thetaTangentAt (facing 0 looks toward increasing theta); pitch tilts the
	view between that horizontal direction (pitch 0) and straight toward
	the sphere's center (pitch +MAX_PITCH) — raising your head to see across
	to the far side, the game's core mechanic. Movement always uses the
	horizontal direction regardless of pitch, same as any FPS: looking up
	and pressing forward doesn't launch you toward the center.

	Standalone rather than an `Entity` subclass for now — the Entity/Process
	foundation (CLAUDE.md "Architecture") doesn't exist yet and shouldn't be
	built ahead of a second use case that actually needs it (see
	docs/GUIDELINES.md §1.3).

	Movement doesn't parallel-transport `facing` as the local tangent basis
	twists with position — it's kept as raw stored state instead. Fine for
	small per-frame steps; revisit if turning drifts noticeably once this is
	actually playable.
**/
class Player {
	/**
		Clamped just short of pi/2: at exactly pi/2 the view direction would
		be exactly parallel to the camera's up vector, which is a degenerate
		lookAt (no well-defined "right"). Visually indistinguishable from a
		true 90 degrees.
	**/
	public static inline final MAX_PITCH:Float = 1.55; // ~88.8 degrees

	/**
		Camera height above the floor shell, toward the sphere's center.
		Without this the camera sits exactly on the floor mesh — looking up
		then grazes along/through the very floor it's embedded in instead of
		clearing it, which is what made the far side unreachable in practice
		even after the up-vector fix above (caught by comparing screenshots
		at different pitches once that fix alone didn't change the picture:
		still a flat, undifferentiated fill, at every pitch above ~0).
		Kept below WALL_HEIGHT (see MazeMesh) so walls still read as walls.
	**/
	public static inline final EYE_HEIGHT:Float = 6;

	/** Polar angle from +Y, in radians (0 = north pole, pi = south pole). See SphereMath. **/
	public var theta:Float;

	/** Azimuth around Y, in radians. See SphereMath. **/
	public var phi:Float;

	/** Look direction's angle within the local tangent plane, measured from thetaTangentAt. **/
	public var facing:Float;

	/** View tilt from horizontal (0) toward the sphere's center (+MAX_PITCH) or the floor (-MAX_PITCH). **/
	public var pitch:Float;

	public function new(theta:Float, phi:Float, facing:Float, pitch:Float = 0) {
		this.theta = theta;
		this.phi = phi;
		this.facing = facing;
		this.pitch = clampPitch(pitch);
	}

	/**
		Positions and orients a camera at this player's location: standing on
		the sphere's interior, looking along `facing` tilted by `pitch`
		toward the sphere's center. The camera's up vector tilts by the same
		pitch (rotated around the same axis as the view direction) rather
		than staying fixed at the sphere-relative "up" — keeping it fixed
		would let it drift toward parallel with the view direction as pitch
		increases, collapsing the camera's effective horizontal FOV toward
		zero well before reaching the pitch clamp (caught by comparing
		rendered screenshots at a few different pitches: the view was
		visibly squeezed to a sliver long before anything looked "wrong").
		@param camera the camera to position.
		@param radius sphere radius — must match the maze's physical sphere (see MazeGeometry.RADIUS).
	**/
	public function applyToCamera(camera:h3d.Camera, radius:Float):Void {
		var frame = tangentFrame(radius);
		var eyePos = frame.pos.add(frame.up.scaled(EYE_HEIGHT));
		var right = frame.forward.cross(frame.up).normalized();
		var viewForward = SphereMath.rotateAroundAxis(frame.forward, right, pitch);
		var viewUp = SphereMath.rotateAroundAxis(frame.up, right, pitch);

		camera.pos.load(eyePos);
		camera.up.load(viewUp);
		camera.target.load(eyePos.add(viewForward));
	}

	/**
		Walks forward (or backward, for a negative distance) along the
		horizontal `facing` direction — pitch doesn't affect movement.
		Rotates the current position toward that direction within the great
		circle it defines, by the angle `distance / radius`. Exact for any
		distance (not a small-step approximation), and always stays exactly
		on the sphere by construction.
		@param distance arc length to walk; negative walks backward.
		@param radius sphere radius — must match the maze's physical sphere (see MazeGeometry.RADIUS).
	**/
	public function moveForward(distance:Float, radius:Float):Void {
		var frame = tangentFrame(radius);
		var angle = distance / radius;
		var moved = frame.pos.scaled(Math.cos(angle)).add(frame.forward.scaled(radius * Math.sin(angle)));

		theta = Math.acos(moved.y / radius);
		phi = Math.atan2(moved.z, moved.x);
	}

	/**
		Rotates `facing` by `deltaAngle` radians (positive turns from
		thetaTangentAt toward phiTangentAt).
		@param deltaAngle angle to turn by, in radians.
	**/
	public function turn(deltaAngle:Float):Void {
		facing += deltaAngle;
	}

	/**
		Tilts `pitch` by `deltaAngle` radians, clamped to +-MAX_PITCH
		(positive looks up, toward the sphere's center).
		@param deltaAngle angle to tilt by, in radians.
	**/
	public function lookUp(deltaAngle:Float):Void {
		pitch = clampPitch(pitch + deltaAngle);
	}

	static function clampPitch(p:Float):Float {
		return hxd.Math.clamp(p, -MAX_PITCH, MAX_PITCH);
	}

	function tangentFrame(radius:Float):{pos:h3d.Vector, up:h3d.Vector, forward:h3d.Vector} {
		var center = new h3d.Vector(0, 0, 0);
		var pos = SphereMath.sphericalToCartesian(radius, theta, phi);
		var up = SphereMath.upVectorAt(pos, center);
		var forward = SphereMath.rotateAroundAxis(SphereMath.thetaTangentAt(theta, phi), up, facing);
		return {pos: pos, up: up, forward: forward};
	}
}
