package entities;

import game.SphereMath;

/**
	The player's position and facing on the maze sphere's interior surface.
	Position is spherical (theta, phi) rather than Cartesian so movement can
	update it directly with grid-relative deltas; facing is the look
	direction's angle within the local tangent plane, measured from
	thetaTangentAt (facing 0 looks toward increasing theta).

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
	/** Polar angle from +Y, in radians (0 = north pole, pi = south pole). See SphereMath. **/
	public var theta:Float;

	/** Azimuth around Y, in radians. See SphereMath. **/
	public var phi:Float;

	/** Look direction's angle within the local tangent plane, measured from thetaTangentAt. **/
	public var facing:Float;

	public function new(theta:Float, phi:Float, facing:Float) {
		this.theta = theta;
		this.phi = phi;
		this.facing = facing;
	}

	/**
		Positions and orients a camera at this player's location: standing on
		the sphere's interior, "up" toward the sphere's center (raising your
		head looks through the center toward the far side), looking along
		`facing` within the local tangent plane.
		@param camera the camera to position.
		@param radius sphere radius — must match the maze's physical sphere (see MazeGeometry.RADIUS).
	**/
	public function applyToCamera(camera:h3d.Camera, radius:Float):Void {
		var frame = tangentFrame(radius);

		camera.pos.load(frame.pos);
		camera.up.load(frame.up);
		camera.target.load(frame.pos.add(frame.forward));
	}

	/**
		Walks forward (or backward, for a negative distance) along `facing`:
		rotates the current position toward `facing` within the great circle
		it defines, by the angle `distance / radius`. Exact for any distance
		(not a small-step approximation), and always stays exactly on the
		sphere by construction.
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

	function tangentFrame(radius:Float):{pos:h3d.Vector, up:h3d.Vector, forward:h3d.Vector} {
		var center = new h3d.Vector(0, 0, 0);
		var pos = SphereMath.sphericalToCartesian(radius, theta, phi);
		var up = SphereMath.upVectorAt(pos, center);
		var forward = SphereMath.rotateAroundAxis(SphereMath.thetaTangentAt(theta, phi), up, facing);
		return {pos: pos, up: up, forward: forward};
	}
}
