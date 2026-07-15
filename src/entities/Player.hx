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
		var center = new h3d.Vector(0, 0, 0);
		var pos = SphereMath.sphericalToCartesian(radius, theta, phi);
		var up = SphereMath.upVectorAt(pos, center);
		var forward = SphereMath.rotateAroundAxis(SphereMath.thetaTangentAt(theta, phi), up, facing);

		camera.pos.load(pos);
		camera.up.load(up);
		camera.target.load(pos.add(forward));
	}
}
