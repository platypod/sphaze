package geometry;

import geometry.CurvedSpace.ModelPoint;

/**
	A **discrete group of isometries acting on the universal cover** — the
	machinery that turns one flat or hyperbolic plane into a torus, a
	Möbius band, a Klein bottle or a genus-2 surface, without any of those
	needing their own geometry.

	**Why this is one piece of code and not three biomes.** A closed
	surface is not built; it is *quotiented*. You take a plane, pick a
	group of isometries, and declare points in the same orbit to be the
	same point. Every space in
	`docs/game-design/direction/world-and-threads.md` that repeats,
	reverses or wraps is that construction with a different group:

	| Space | Cover | Group |
	|---|---|---|
	| The Repeat | E² | two translations (a lattice) |
	| The Turn | E² | one glide reflection |
	| The Knot | H² | the genus-2 surface group |

	So the interesting work happens once, here, and each space supplies
	four or fewer matrices. That is the same bet the rest of `geometry`
	makes — `docs/game-design/direction/roadmap.md`'s "nine geometries are
	nine parameter sets, not nine hand-built levels" — and this class is
	where most of it is actually collected.

	**The player never leaves the cover.** Movement, collision and
	rendering all happen in the plane, unwrapped, where everything is
	ordinary. The quotient shows up in exactly two places: `canonicalise`,
	which folds a position back near the origin so it cannot run away to
	infinity, and `elementsWithin`, which lists the copies of the world to
	draw so that looking down a corridor shows you the room you are
	standing in. That is why a torus can be walked with no special cases
	anywhere in the movement code.

	Headless and Heaps-free, like the rest of this package.
**/
class DeckGroup {
	/** How far apart two group elements' matrix entries may be and still count as the same element. Generous: the alternative to merging near-duplicates is an enumeration that grows without bound. **/
	static inline final MERGE_PRECISION:Float = 1e4;

	/** A greedy descent that has taken this many steps is cycling rather than converging — see `canonicalise`. **/
	static inline final MAX_REDUCTION_STEPS:Int = 200;

	/** Distance improvement below which a reduction step is not worth taking, and is likely to be floating-point noise oscillating between two equidistant representatives. **/
	static inline final IMPROVEMENT_EPSILON:Float = 1e-9;

	/** Which plane this group acts on. **/
	public final curvature:Curvature;

	/**
		The generators **and their inverses**, which is what every method
		here actually wants: a walk through the group, or a greedy descent
		toward the origin, must be able to step either way along every
		generator. Kept as one flat list rather than pairing them up,
		because nothing downstream cares which is which.
	**/
	public final generators:Array<Isometry>;

	/**
		@param curvature the plane this group acts on.
		@param generators the group's own generators; inverses are added automatically, so pass each one once.
	**/
	public function new(curvature:Curvature, generators:Array<Isometry>) {
		if (generators.length == 0) {
			throw "a deck group needs at least one generator";
		}
		this.curvature = curvature;
		this.generators = [];
		for (g in generators) {
			this.generators.push(g);
			this.generators.push(Isometry.invert(curvature, g));
		}
	}

	/**
		Every group element whose copy of the origin lands within `radius` —
		the list of world copies to draw, and the reason a quotient space
		looks infinite while being finite.

		Breadth-first over words in the generators, merging elements that
		have converged to the same matrix. Expansion continues a little
		past `radius` (`OVERSHOOT` below) rather than stopping at it: a
		word can step out and come back, so pruning exactly at the boundary
		would drop elements reachable only through it.
		@param radius how far out to enumerate, in the cover's own units.
		@return the elements found, identity first.
	**/
	public function elementsWithin(radius:Float):Array<Isometry> {
		// One generator step past the edge — enough for a word to step out
		// and back, without doubling the work.
		var overshoot = radius + longestGeneratorStep();

		var found = [Isometry.identity()];
		var seen = new Map<String, Bool>();
		seen.set(keyOf(Isometry.identity()), true);

		var frontier = [Isometry.identity()];
		while (frontier.length > 0) {
			var next:Array<Isometry> = [];
			for (element in frontier) {
				for (g in generators) {
					var candidate = Isometry.compose(element, g);
					var key = keyOf(candidate);
					if (seen.exists(key)) {
						continue;
					}
					if (displacementOf(candidate) > overshoot) {
						continue;
					}
					seen.set(key, true);
					next.push(candidate);
					if (displacementOf(candidate) <= radius) {
						found.push(candidate);
					}
				}
			}
			frontier = next;
		}
		return found;
	}

	/**
		Folds a point back to the representative of its orbit nearest the
		origin — the **fundamental domain**, taken to be the Dirichlet
		region about the origin, which is that definition rather than a
		hand-drawn shape.

		Greedy: repeatedly apply whichever generator most reduces the
		distance to the origin, until none does. Fast, and enough for every
		group this game uses.

		**It is greedy, and greedy is not always right.** For a badly skewed
		lattice the true nearest representative can need a *combination* of
		generators that no single one improves on, and this would stop at a
		neighbouring cell instead. That is not a hypothetical bound to
		ignore — it is why `canonicaliseBySearch` exists, and why the tests
		check the two against each other for the groups actually shipped
		rather than trusting the argument.
		@param p a point in the cover.
		@return the representative of `p`'s orbit nearest the origin.
	**/
	public function canonicalise(p:ModelPoint):ModelPoint {
		var current = CurvedSpace.normalize(curvature, p);
		var best = distanceFromOrigin(current);

		for (_ in 0...MAX_REDUCTION_STEPS) {
			var improved = false;
			for (g in generators) {
				var candidate = CurvedSpace.normalize(curvature, Isometry.apply(g, current));
				var distance = distanceFromOrigin(candidate);
				if (distance < best - IMPROVEMENT_EPSILON) {
					current = candidate;
					best = distance;
					improved = true;
				}
			}
			if (!improved) {
				return current;
			}
		}
		return current;
	}

	/**
		The same fold, done exhaustively over every element within
		`searchRadius` — **the reference implementation**, and slow enough
		that nothing in a frame should call it.

		It exists so `canonicalise`'s greedy shortcut has something honest
		to be checked against, since a fold that quietly lands one cell
		over produces a world that still looks and walks like a torus and
		is simply the wrong torus.
		@param p a point in the cover.
		@param searchRadius how far out to consider representatives; must comfortably exceed `p`'s own distance from the origin.
		@return the nearest representative found.
	**/
	public function canonicaliseBySearch(p:ModelPoint, searchRadius:Float):ModelPoint {
		var start = CurvedSpace.normalize(curvature, p);
		var best = start;
		var bestDistance = distanceFromOrigin(start);

		for (element in elementsWithin(searchRadius)) {
			var candidate = CurvedSpace.normalize(curvature, Isometry.apply(element, start));
			var distance = distanceFromOrigin(candidate);
			if (distance < bestDistance) {
				best = candidate;
				bestDistance = distance;
			}
		}
		return best;
	}

	/**
		How far an element moves the origin — the natural size of a group
		element, and what `elementsWithin` sorts and prunes by.
		@param element the element to measure.
		@return the distance from the origin to its image.
	**/
	public function displacementOf(element:Isometry):Float {
		return distanceFromOrigin(Isometry.positionOf(element));
	}

	function distanceFromOrigin(p:ModelPoint):Float {
		return CurvedSpace.distance(curvature, CurvedSpace.origin(), p);
	}

	function longestGeneratorStep():Float {
		var longest = 0.0;
		for (g in generators) {
			var step = displacementOf(g);
			if (step > longest) {
				longest = step;
			}
		}
		return longest;
	}

	/**
		Identity key for an element, so two words that reached the same
		place are recognised as the same element.

		Keys on the **whole matrix**, not just where it sends the origin.
		For a group acting freely — which every deck group of a manifold
		does, by definition — those are equivalent, and keying on the
		matrix stays correct if a group with fixed points is ever passed in
		by mistake, instead of silently collapsing a rotation onto the
		identity.
	**/
	function keyOf(element:Isometry):String {
		var parts = [for (v in element.m) Std.string(Math.round(v * MERGE_PRECISION))];
		return parts.join(",");
	}
}
