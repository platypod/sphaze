package biomes.defect;

/**
	A **cone point**: a plane that is flat absolutely everywhere except at
	one spot, where a wedge of angle `DEFECT_ANGLE` has been cut out and
	the edges glued.

	**Why this needed new code rather than `geometry.CurvedSpace`.** That
	package covers the three *uniform*-curvature geometries; a cone is
	curvature **concentrated at a single point** in an otherwise flat
	plane, which is a genuinely different construction —
	`docs/game-design/direction/world-and-threads.md` says so, and it was
	right. It is also not a `geometry.DeckGroup` quotient: the group would
	be rotations about the apex, which have a *fixed point*, so
	`elementsWithin` (which prunes by how far an element moves the origin)
	would enumerate infinitely many elements all of displacement zero.

	What it *is* structurally is the Möbius seam again, and the design
	named that precedent correctly: the cone minus one ray is isometric to
	a wedge of the ordinary plane, so the player walks flat coordinates
	and gets rotated about the apex when they cross the seam. Everything
	interesting follows from that one rule.

	**The whole lesson, in one sentence.** A closed loop that encloses the
	apex crosses the seam and comes back turned by the defect angle; a
	closed loop that does not, does not. Curvature is concentrated, and
	parallel transport is path-dependent — which is also, retroactively,
	what the Fold's twelve pentagons have been doing all along.
**/
class DefectModel {
	/**
		The angle cut out of the plane.

		Not `inline`, because `Math.PI / 2` is not a compile-time constant
		in Haxe — the same reason `tools.geodesic.GeodesicMesh.HEX_FACE_PERIOD`
		is a plain `static final`.

		A quarter turn: large enough that one loop around the apex is
		unmistakable rather than a subtlety, and small enough that the
		space still reads as an ordinary plain. The mechanism the design
		wants is a *continuous dial* — loop twice and get twice the angle —
		and that falls out for free, since each crossing applies its own
		rotation.
	**/
	public static final DEFECT_ANGLE:Float = Math.PI / 2;

	/** How much angle there actually is around the apex — `2π` minus the defect. **/
	public static final CONE_ANGLE:Float = 2 * Math.PI - DEFECT_ANGLE;

	/**
		How close to the apex the player may get.

		The apex is a genuine singularity — the one point where the space
		is not flat and no tangent plane exists — so standing on it is
		meaningless. It also protects the seam-crossing test, which
		distinguishes a forward crossing from a backward one by *how far*
		past the seam the step landed, and needs a step to be small in
		angle. At this radius a normal step subtends well under the margin
		that test allows.
	**/
	public static inline final APEX_EXCLUSION:Float = 14;

	/** How far the walkable plain extends from the apex. **/
	public static inline final PLAIN_RADIUS:Float = 620;

	/** World angle of a position about the apex, in `[0, 2π)`. **/
	public static function angleOf(x:Float, z:Float):Float {
		var angle = Math.atan2(z, x);
		return angle < 0 ? angle + 2 * Math.PI : angle;
	}

	public static function radiusOf(x:Float, z:Float):Float {
		return Math.sqrt(x * x + z * z);
	}

	/**
		Which way, if either, a position has crossed the seam — `-1` if it
		went out past the far edge of the wedge (walking "forward" round
		the apex), `+1` if it went out past the near edge, `0` if it is
		still inside.

		**The two cases have to be told apart by where the step landed,
		not by the raw angle.** Both leave the wedge into the same
		`[CONE_ANGLE, 2π)` band: stepping forward past `CONE_ANGLE` lands
		just above it, and stepping backward past `0` wraps to just below
		`2π`. Splitting that band down the middle separates them, and is
		correct as long as one step never subtends more than half the
		defect angle — which `APEX_EXCLUSION` is what guarantees.
		@param x world x.
		@param z world z.
		@return the rotation to apply, in units of `CONE_ANGLE`.
	**/
	public static function seamCrossing(x:Float, z:Float):Int {
		var angle = angleOf(x, z);
		if (angle < CONE_ANGLE) {
			return 0;
		}
		return angle < CONE_ANGLE + DEFECT_ANGLE / 2 ? -1 : 1;
	}

	/**
		Rotates a world point about the apex by `angle` — the identification
		itself, and the only thing in this space that is not ordinary flat
		geometry.
		@param x world x.
		@param z world z.
		@param angle rotation, in radians.
		@return the rotated pair.
	**/
	public static function rotate(x:Float, z:Float, angle:Float):{x:Float, z:Float} {
		var c = Math.cos(angle);
		var s = Math.sin(angle);
		return {x: x * c - z * s, z: x * s + z * c};
	}

	/**
		Where a marker standing at cone coordinates `(radius, coneAngle)`
		should be **drawn**, given where the player currently stands.

		A cone cannot be flattened, so something has to give. This places
		every marker exactly once, within a window of `CONE_ANGLE` centred
		on the player's own bearing from the apex — so the geometry the
		player can see is continuous and correct, and the unavoidable gap
		of `DEFECT_ANGLE` sits directly *behind the apex* from where they
		are standing, which is the least visible place available.

		The ground itself is drawn as a full disc regardless: it is
		featureless, so a wedge of it repeated or omitted is
		indistinguishable either way, and a hole in the floor would be far
		more conspicuous than the honest gap in the markers.
		@param coneAngle the marker's own angle around the apex, in `[0, CONE_ANGLE)`.
		@param playerAngle where the player currently stands, as a world angle.
		@return the world angle to draw it at.
	**/
	public static function drawAngleFor(coneAngle:Float, playerAngle:Float):Float {
		var relative = coneAngle - playerAngle;
		// bring into (-CONE_ANGLE/2, CONE_ANGLE/2]
		relative -= CONE_ANGLE * Math.floor(relative / CONE_ANGLE + 0.5);
		return playerAngle + relative;
	}
}
