package geometry;

/**
	A first-person walker in the hyperbolic plane, stored as **the view
	isometry** — the transform taking world points into the camera's own
	frame, where the camera always sits at the model origin facing `+x`.

	**Why store the view rather than the player's own frame.** In hyperbolic
	rendering the camera does not move through the world; the world moves
	around a camera pinned at the origin. Tracking `view` directly (rather
	than tracking the player's frame `F` and inverting it every frame to get
	`F⁻¹`) means **no matrix inversion anywhere**, which removes both a cost
	and a class of numerical drift — the entries of a hyperbolic boost grow
	exponentially with distance, so inverting one repeatedly is exactly
	where precision would go.

	The bookkeeping is the mirror of the obvious version: where the player's
	own frame would compose *on the right* (`F · T(d)` — "move forward in my
	own local frame"), the view composes **on the left, inverted**
	(`T(-d) · V`). Every operation below is that identity applied once.

	Movement is deliberately expressed in terms of the two primitives only:
	`strafe` is written as turn-move-turn rather than derived independently,
	so there is no second derivation to get wrong.
**/
class HyperbolicWalker {
	/** World → camera-relative. Feed the result of applying this to `geometry.HyperbolicProjection`. **/
	public var view(default, null):Isometry;

	public function new() {
		view = Isometry.identity();
	}

	/**
		Walk forward along the geodesic the camera is facing.
		@param distance arc length; negative walks backwards.
	**/
	public function moveForward(distance:Float):Void {
		view = Isometry.compose(Isometry.translation(Hyperbolic, -distance), view);
	}

	/**
		Turn in place.
		@param angle radians; positive turns the view to the right, once `HyperbolicProjection.toWorld` has accounted for the renderer's handedness.
	**/
	public function turn(angle:Float):Void {
		view = Isometry.compose(Isometry.rotation(-angle), view);
	}

	/**
		Step sideways without turning — composed from `turn`/`moveForward`
		rather than derived separately, so it cannot disagree with them.

		**Positive is to the right**, matching `turn`'s own positive sense
		once `HyperbolicProjection.toWorld` has accounted for Heaps' left-
		handed camera. Committing to a side here rather than leaving it to
		each caller is what stops the sign being rediscovered (and got
		wrong) at every input site.
		@param distance arc length to strafe; positive strafes right.
	**/
	public function strafe(distance:Float):Void {
		turn(Math.PI / 2);
		moveForward(distance);
		turn(-Math.PI / 2);
	}

	/**
		Where a world point lands relative to the camera.
		@param worldPoint a point on the hyperboloid, in world coordinates.
		@return the same point in the camera's own frame.
	**/
	public function toCameraFrame(worldPoint:CurvedSpace.ModelPoint):CurvedSpace.ModelPoint {
		return Isometry.apply(view, worldPoint);
	}

	/**
		How far the camera currently stands from the world origin — the one
		readout that makes hyperbolic distance legible while walking, since
		nothing on screen conveys scale reliably.
		@return geodesic distance from the world origin, in curvature units.
	**/
	public function distanceFromOrigin():Float {
		return HyperbolicProjection.distanceFromCamera(toCameraFrame(CurvedSpace.origin()));
	}
}
