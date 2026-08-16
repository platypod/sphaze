package geometry;

import geometry.Curvature.CurvatureMath;
import geometry.CurvedSpace.ModelPoint;

/**
	A finite patch of the regular hyperbolic tiling `{p, q}` — `p`-sided
	faces, `q` of them around every vertex — produced as **an adjacency
	graph**, which is the only thing a cellular automaton needs.

	Built to answer Risk 2 in `docs/game-design/direction/roadmap.md`: the
	Sprawl biome would run its automaton on `{7,3}`, and before designing a
	world around that it is worth knowing the tiling can actually be
	generated and behaves the way the theory says. It is also the first
	consumer of `Isometry`/`CurvedSpace`, and therefore the check that the
	geometry core is *useful* rather than merely correct.

	**Construction.** Start with one face at the origin. Its `p` neighbours
	are reached by rotating by `k·2π/p`, translating by twice the inradius,
	**and then turning to face back** — see the constructor's own comment
	for why that last half-turn is not optional. Apply that to every face,
	breadth-first, and **weld faces whose centres coincide** — the same
	trick `tools.geodesic.GeodesicSphere` already uses for the icosahedral
	sphere, and it works here for the same reason: two different paths to
	the same face arrive at the same point, so position is identity.

	Verified against the known ring populations of `{7,3}` — `1, 7, 21, 56,
	147, 385` — whose growth converges on `φ² ≈ 2.618`.

	**Why this is not the same as the sphere's generator.** A sphere is
	compact, so its tiling closes and is finite by nature. A hyperbolic
	tiling is infinite, so a patch is always a *truncation* — the outermost
	ring is missing neighbours by construction, and callers must treat
	boundary faces as boundary rather than assume degree `p`. That is not a
	defect to fix; it is what "everywhere is edge" means when you try to
	hold a piece of it.

	**Precision.** Hyperbolic coordinates grow exponentially with radius, so
	the welding key's fixed decimal rounding degrades far from the origin.
	Fine for the handful of rings a simulation patch needs; a genuinely
	large patch would want relative-precision keys or a combinatorial
	(Fibonacci-tree) construction instead.
**/
class HyperbolicTiling {
	/** How many decimal places the welding key keeps — see this class's own precision note. **/
	static inline final WELD_DECIMALS:Float = 1e6;

	/** Every face's own centre, indexed by face id. **/
	public final centers:Array<ModelPoint>;

	/** Every face's own edge-adjacent neighbours, indexed by face id. Interior faces have `p`; boundary faces have fewer. **/
	public final neighbors:Array<Array<Int>>;

	/** Which breadth-first ring each face was discovered in — `0` for the seed face. **/
	public final rings:Array<Int>;

	/**
		Each face's own frame — the isometry taking the origin to that face's
		centre, with `+x` pointing at one of its edge midpoints.

		**Safe to keep only the first frame found**, even though welding
		collapses several arrival paths onto one face: every generator
		arrives facing back at the parent, which is always *some* edge
		midpoint, so two paths to the same face give frames differing by a
		multiple of `2π/p` — exactly the rotations a regular `p`-gon is
		symmetric under. Corners derived from either frame land in the same
		places. Needed by anything drawing the faces rather than just
		simulating on them, since a centre alone does not determine where
		the corners are.
	**/
	public final frames:Array<Isometry>;

	/** The tiling's own `p` (sides per face). **/
	public final p:Int;

	/** The tiling's own `q` (faces around a vertex). **/
	public final q:Int;

	/**
		@param p sides per face.
		@param q faces around each vertex — `(p-2)(q-2) > 4` is required, since that is exactly the condition making the tiling hyperbolic rather than spherical or Euclidean.
		@param ringCount how many breadth-first rings to generate around the seed face.
	**/
	public function new(p:Int, q:Int, ringCount:Int) {
		if ((p - 2) * (q - 2) <= 4) {
			throw '{$p,$q} is not a hyperbolic tiling — (p-2)(q-2) must exceed 4';
		}
		this.p = p;
		this.q = q;

		var step = 2 * inradiusOf(p, q);
		// The trailing half-turn is load-bearing, and its absence was a real
		// bug caught by measuring rather than by the tests: without it, a
		// child's own generator set is not oriented to walk *back* to its
		// parent, because for odd `p` none of the `p` directions is the exact
		// reverse (k·2π/p is never π). Nothing ever reconverged, welding never
		// merged anything, and the "tiling" was silently a p-ary tree growing
		// as pⁿ instead of a tiling growing as φ²ⁿ. Turning to face the parent
		// after stepping makes generator 0 the inverse of the step that
		// arrived, so paths meet and the weld has something to do.
		var generators = [
			for (k in 0...p)
				Isometry.compose(Isometry.compose(Isometry.rotation(k * 2 * Math.PI / p), Isometry.translation(Hyperbolic, step)), Isometry.rotation(Math.PI))
		];

		centers = [];
		neighbors = [];
		rings = [];
		frames = [];
		var idByKey = new Map<String, Int>();

		var seed = Isometry.identity();
		var frontier = [seed];
		register(seed, 0, idByKey);

		for (ring in 1...ringCount + 1) {
			var next:Array<Isometry> = [];
			for (frame in frontier) {
				for (g in generators) {
					var candidate = Isometry.compose(frame, g);
					if (register(candidate, ring, idByKey) != null) {
						next.push(candidate);
					}
				}
			}
			frontier = next;
		}

		linkByProximity(step);
	}

	/**
		Adds a face if its centre is not already occupied.
		@return the new face's id, or `null` if this centre was already known.
	**/
	function register(frame:Isometry, ring:Int, idByKey:Map<String, Int>):Null<Int> {
		var center = CurvedSpace.normalize(Hyperbolic, Isometry.positionOf(frame));
		var key = weldKey(center);
		if (idByKey.exists(key)) {
			return null;
		}
		var id = centers.length;
		idByKey.set(key, id);
		centers.push(center);
		neighbors.push([]);
		rings.push(ring);
		frames.push(frame);
		return id;
	}

	/**
		Links every pair of faces whose centres sit at the tiling's own
		edge-crossing distance. Distance-based rather than
		bookkept-during-construction because welding already collapses the
		several paths that reach one face, and reconstructing "which
		generator produced this" across those merges is fiddlier than simply
		asking the geometry — which is the authority anyway.
		@param step the centre-to-centre distance between edge-adjacent faces.
	**/
	function linkByProximity(step:Float):Void {
		var tolerance = step * 1e-6;
		for (a in 0...centers.length) {
			for (b in a + 1...centers.length) {
				if (Math.abs(CurvedSpace.distance(Hyperbolic, centers[a], centers[b]) - step) < tolerance) {
					neighbors[a].push(b);
					neighbors[b].push(a);
				}
			}
		}
	}

	static function weldKey(p:ModelPoint):String {
		var rx = Math.round(p.x * WELD_DECIMALS) / WELD_DECIMALS;
		var ry = Math.round(p.y * WELD_DECIMALS) / WELD_DECIMALS;
		return '$rx,$ry';
	}

	/**
		The inradius (centre to edge midpoint) of a `{p,q}` face, from the
		standard hyperbolic right-triangle relation `cosh(r) = cos(π/q) /
		sin(π/p)` — the triangle with angles `π/p` at the face centre, `π/q`
		at a vertex and a right angle at the edge midpoint.
		@param p sides per face.
		@param q faces around a vertex.
		@return the face's own inradius, in units of curvature `-1`.
	**/
	public static function inradiusOf(p:Int, q:Int):Float {
		return CurvatureMath.hyperbolicAcos(Math.cos(Math.PI / q) / Math.sin(Math.PI / p));
	}

	/**
		The circumradius (centre to vertex) of a `{p,q}` face, from
		`cosh(R) = cot(π/p)·cot(π/q)` on the same triangle.
		@param p sides per face.
		@param q faces around a vertex.
		@return the face's own circumradius.
	**/
	public static function circumradiusOf(p:Int, q:Int):Float {
		var cotP = Math.cos(Math.PI / p) / Math.sin(Math.PI / p);
		var cotQ = Math.cos(Math.PI / q) / Math.sin(Math.PI / q);
		return CurvatureMath.hyperbolicAcos(cotP * cotQ);
	}

	/** Faces with their full complement of `p` neighbours — the ones a simulation can trust, as opposed to the truncated outer boundary. **/
	public function interiorFaces():Array<Int> {
		return [for (id in 0...centers.length) if (neighbors[id].length == p) id];
	}
}
