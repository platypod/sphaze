package biomes.common.space.mobius;

import biomes.common.space.common.Space;

/**
	A Möbius ribbon's own `Space`: a twisted band closed into a loop (see
	`MobiusMath`'s own class doc for the geometry). Unlike `biomes.common.space.sphere.SphereSpace`/
	`biomes.common.space.flat.FlatSpace`, this is **not** a shared stateless
	singleton — `twists`/`radius` are per-instance parameters (a biome
	picks its own twist count at construction), so each Möbius-ribbon biome
	owns its own `MobiusSpace` instance rather than reaching for a shared
	`INSTANCE`.

	`moveAlong` steps forward in the ribbon's own `(u, v)` parameter space
	(recovered fresh from `pos` every call via `MobiusMath.paramsAt`, since
	`entities.player.PlayerModel.pos` only ever stores a raw 3D vector, never
	`(u, v)` itself) rather than integrating an exact geodesic — a finite
	Euler step, same pragmatism `biomes.tower.TowerCollision`'s own "block
	the whole step" and `FlatSpace`'s own straight-line translation already
	lean on. This is exact, not approximate, in one respect: `MobiusMath.localFrameAt`'s
	`tu`/`tv`/`normal` are a genuine orthonormal basis at *every* `(u, v)`
	(verified symbolically, not just near the centerline), so decomposing
	`direction`/`forward` against it and reconstructing against the new
	frame carries no basis-skew error — only the step size itself (finite
	vs. infinitesimal) is an approximation.

	Wrapping `u` back into `[0, 2*PI)` when a step crosses the loop's own
	seam also flips `v`'s sign whenever `twists` is odd — not a hack, but
	the same relabeling `MobiusMath`'s own flip identity describes
	(`P(u+2*PI, v) == P(u, v*(-1)^twists)`), applied one loop at a time so
	`u` stays numerically bounded instead of growing without limit over a
	long play session. Two wraps compose back to no net flip, matching the
	identity applied twice.
**/
class MobiusSpace implements Space {
	/** Half-twists over one full lap around the loop — odd keeps this one-sided (a real Möbius strip); even would make it orientable/two-sided instead. **/
	public final twists:Int;

	/** The loop's own centerline radius. **/
	public final radius:Float;

	public function new(twists:Int, radius:Float) {
		this.twists = twists;
		this.radius = radius;
	}

	/**
		See `Space.upAt`. Continuous everywhere except right at the loop's
		own `u = 0` seam, for odd `twists`: a non-orientable surface can't
		have a continuous "up" field over its whole extent, so *something*
		has to carry a sign flip, and this parametrization puts it there —
		not a bug to chase out, just where a Möbius strip's own
		one-sidedness necessarily shows up.
	**/
	public function upAt(pos:h3d.Vector):h3d.Vector {
		var params = MobiusMath.paramsAt(pos, twists, radius);
		return MobiusMath.localFrameAt(params.u, params.v, twists, radius).normal;
	}

	/**
		See `Space.moveAlong` — see class doc for the Euler-step-in-
		parameter-space approach and the wrap-flips-`v` reasoning.
		`radius` (the interface's own parameter) is unused — this instance's
		own `radius` field is used instead, same as `FlatSpace.moveAlong`
		documents for its own unused parameter.
	**/
	public function moveAlong(pos:h3d.Vector, forward:h3d.Vector, direction:h3d.Vector, distance:Float, radius:Float):{pos:h3d.Vector, forward:h3d.Vector} {
		var params = MobiusMath.paramsAt(pos, twists, this.radius);
		var frame = MobiusMath.localFrameAt(params.u, params.v, twists, this.radius);

		// forward's own components against the OLD frame - carried through
		// to the NEW frame unchanged, the discrete parallel-transport this
		// class doc describes. Includes the (normally ~0) normal component
		// too, purely as numerical slack against forward ever drifting
		// slightly out of the tangent plane.
		var forwardU = forward.dot(frame.tu);
		var forwardV = forward.dot(frame.tv);
		var forwardN = forward.dot(frame.normal);

		var alongU = direction.dot(frame.tu);
		var alongV = direction.dot(frame.tv);

		var newU = params.u + distance * alongU / frame.tuLength;
		var newV = params.v + distance * alongV;

		// One loop at a time, not a single mod - see class doc for why two
		// wraps have to compose back to no net flip.
		while (newU >= 2 * Math.PI) {
			newU -= 2 * Math.PI;
			if (twists % 2 != 0) {
				newV = -newV;
			}
		}
		while (newU < 0) {
			newU += 2 * Math.PI;
			if (twists % 2 != 0) {
				newV = -newV;
			}
		}

		var newFrame = MobiusMath.localFrameAt(newU, newV, twists, this.radius);
		var newForward = newFrame.tu.scaled(forwardU).add(newFrame.tv.scaled(forwardV)).add(newFrame.normal.scaled(forwardN));
		var newPos = MobiusMath.pointAt(newU, newV, twists, this.radius);
		return {pos: newPos, forward: newForward};
	}
}
