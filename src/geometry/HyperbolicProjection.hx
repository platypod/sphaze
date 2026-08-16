package geometry;

import geometry.Curvature.CurvatureMath;
import geometry.CurvedSpace.ModelPoint;

/**
	Projects a hyperbolic point into something a normal Euclidean rasteriser
	can draw — the **Beltrami-Klein** projection, and the reason a
	first-person view of hyperbolic space looks like a place rather than a
	smear.

	**The one property that matters.** Klein maps geodesics to *straight
	lines*, so a hyperbolic polygon projects to a Euclidean polygon and the
	rasteriser's own assumptions survive intact. Poincaré would bend every
	wall into an arc and force curved-primitive rendering; Klein keeps
	triangles triangles. This is why `docs/rules/architecture.md`
	recommends it for the shipping renderer.

	**Two facts worth knowing before looking at output:**

	- **Bearing is exact.** A point at hyperbolic bearing θ from the camera
	  projects to Klein bearing θ, unchanged. Angles at the viewer are
	  correct, which is what makes the view read as first-person at all.
	- **Distance compresses to `tanh`.** A point at hyperbolic distance `d`
	  lands at Klein radius `tanh(d) < 1`, so the *entire infinite plane*
	  fits inside a unit disk and everything far away piles up against its
	  rim. That is not a rendering artifact to fight — it is
	  [the Sprawl's own legibility law](../../docs/game/world.md)
	  ("see near, not far") arriving for free out of correct mathematics.
	  Depth ordering still works, because `tanh` is monotonic in `d`.

	Deliberately CPU-side and pure, so it can be unit-tested without a
	renderer. The production path moves this same arithmetic into an HxSL
	fragment (see `architecture.md`); doing it here first means the *maths*
	is verified before the plumbing is, which matters because the plumbing
	cannot be verified in this environment at all.
**/
class HyperbolicProjection {
	/**
		How far a Klein radius of `1` (hyperbolic infinity) sits from the
		camera in rendered world units. Everything visible lands inside this
		radius, so the near/far planes and any fog want to be set against it.

		**The one scale knob**, and worth understanding before changing it.
		In *any* hyperbolic tiling a cell is inherently of order one
		curvature radius across — `{7,3}`'s own centre-to-centre step is
		`≈1.09`, so a neighbouring cell already sits at `tanh(1.09) ≈ 0.8`,
		four fifths of the way to the horizon. That is not a scale mistake to
		tune away; it is what hyperbolic space *is*, and it is the whole
		reason "see near, not far" needs no authoring. This value only sets
		how large the near field renders: at `10`, a cell's own inradius
		lands about 5 units out, so a cell reads as a room-sized plaza
		against a `1.7` eye height.
	**/
	public static inline final HORIZON:Float = 10.0;

	/**
		Klein radius is `tanh(d) < 1` by construction, but floating point at
		large `d` can round to exactly `1` and put a vertex *on* the horizon
		circle, where perspective division misbehaves. Clamping just inside
		costs nothing visible — the difference is far below a pixel at any
		distance where it triggers.
	**/
	static inline final MAX_RADIUS:Float = 0.99999;

	/**
		Projects a **camera-relative** hyperbolic point to rendered world
		space.

		The input must already have the view isometry applied — see
		`HyperbolicWalker.view`. This function assumes the camera sits at the
		model origin `(0, 0, 1)` facing `+x`, which is what makes it a pure
		projection rather than a camera transform.

		Rendered axes follow this project's Y-up convention (same as
		`biomes.common.space.mobius.MobiusMath`): the hyperbolic surface maps
		to world X/Z, and `height` is world Y, untouched — the surface is a
		product geometry H²×ℝ, so the height factor is Euclidean and passes
		straight through.
		@param cameraRelative a point on the hyperboloid, already transformed into the camera's own frame.
		@param height the point's own height above the surface, in world units.
		@return the world-space position to hand the rasteriser.
	**/
	public static function toWorld(cameraRelative:ModelPoint, height:Float):h3d.Vector {
		var k = klein(cameraRelative);
		// Z is negated because Heaps' camera is left-handed
		// (`s3d.camera.rightHanded == false`), so its on-screen right is the
		// opposite of the right-handed `forward.cross(up)` — the same gotcha
		// `game.GameLoop`'s own strafe code documents. Without this, turning
		// and strafing both come out mirrored, which is how it was first
		// reported. Fixed here, at the model-to-render boundary, rather than
		// by flipping signs at each input.
		return new h3d.Vector(k.u * HORIZON, height, -k.v * HORIZON);
	}

	/**
		The raw Klein disk coordinates of a camera-relative point: `(x/z,
		y/z)`, always strictly inside the unit disk.
		@param cameraRelative a point on the hyperboloid, in the camera's own frame.
		@return its Klein coordinates.
	**/
	public static function klein(cameraRelative:ModelPoint):{u:Float, v:Float} {
		// z = cosh(distance) >= 1 on the forward sheet; guard only against
		// drift below that, never against a legitimate value.
		var z = cameraRelative.z < 1 ? 1.0 : cameraRelative.z;
		var u = cameraRelative.x / z;
		var v = cameraRelative.y / z;

		var radius = Math.sqrt(u * u + v * v);
		if (radius > MAX_RADIUS) {
			var shrink = MAX_RADIUS / radius;
			u *= shrink;
			v *= shrink;
		}
		return {u: u, v: v};
	}

	/**
		Geodesic distance from the camera to a camera-relative point —
		`arccosh(z)`, since the camera is at the origin. Useful for distance
		culling and for fog that matches the real metric rather than the
		compressed one.
		@param cameraRelative a point on the hyperboloid, in the camera's own frame.
		@return its hyperbolic distance from the camera.
	**/
	public static function distanceFromCamera(cameraRelative:ModelPoint):Float {
		return CurvatureMath.hyperbolicAcos(cameraRelative.z);
	}
}
