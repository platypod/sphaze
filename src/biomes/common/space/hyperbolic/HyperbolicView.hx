package biomes.common.space.hyperbolic;

import geometry.Isometry;

/**
	Bridges the game's own spatial state — a `pos`/`forward` pair, as
	`entities.player.PlayerModel` carries it — to the **view isometry**
	that `geometry.HyperbolicProjection` needs in order to draw anything.

	**Why a bridge exists at all.** The `geometry` package and the game
	arrived at hyperbolic space from opposite ends. `geometry.Isometry`
	stores a frame *as a matrix* (the architecture doc's proposal), while
	`PlayerModel` stores a position and a facing (what the game has always
	done, and what `HyperbolicSpace` deliberately kept so no interface had
	to change). Both are complete descriptions of the same thing; this
	class is the one place that converts between them, so the conversion
	cannot be re-derived — and got subtly wrong — at each rendering site.

	**Why the *view*, not the frame.** In hyperbolic rendering the camera
	never moves: it sits at the model origin facing `+x`, and the world is
	transformed around it. `geometry.HyperbolicWalker` gets this for free
	by tracking the view directly and never inverting anything. Coming
	from a `pos`/`forward` pair there is no such luxury — the pair *is* the
	player's own frame, so an inverse is unavoidable.

	That inverse is exact rather than numerical, which is the point worth
	knowing: a frame is Minkowski-orthogonal, so its inverse is
	`J · Fᵀ · J` with `J = diag(1, 1, -1)` — a transpose and three sign
	flips, no division and no conditioning problem. Naively inverting a
	3×3 whose entries grow exponentially with distance from the origin is
	exactly where precision would have gone, and `HyperbolicWalker`'s own
	doc flags it as the reason that class is shaped the way it is.
**/
class HyperbolicView {
	/**
		The player's own frame: the isometry taking the origin (facing `+x`)
		to `pos` (facing `forward`).

		Its columns are, in order, `forward`, the player's own left, and the
		position — which is what "a frame is three basis vectors" means, and
		is why the identity falls out at the origin facing `+x` rather than
		needing a special case.
		@param pos position on the hyperboloid, scaled by `radius`.
		@param forward unit tangent at `pos`.
		@param radius the curvature radius `pos` is scaled to.
		@return the frame standing at `pos`, facing `forward`.
	**/
	public static function frameOf(pos:h3d.Vector, forward:h3d.Vector, radius:Float):Isometry {
		var unitPos = pos.scaled(1 / radius);
		var f = normalizeTangent(forward);
		var s = sideOf(unitPos, f);
		// column-major data laid out row-major: columns are f, s, unitPos
		return new Isometry([f.x, s.x, unitPos.x, f.y, s.y, unitPos.y, f.z, s.z, unitPos.z]);
	}

	/**
		World → camera-relative, ready to feed
		`geometry.HyperbolicProjection`. The inverse of `frameOf`, computed
		by the Minkowski adjoint rather than by general matrix inversion —
		see this class's own doc for why that distinction matters here.
		@param pos position on the hyperboloid, scaled by `radius`.
		@param forward unit tangent at `pos`.
		@param radius the curvature radius `pos` is scaled to.
		@return the view isometry for a camera standing at `pos`, facing `forward`.
	**/
	public static function viewOf(pos:h3d.Vector, forward:h3d.Vector, radius:Float):Isometry {
		return invert(frameOf(pos, forward, radius));
	}

	/**
		Inverse of a Minkowski-orthogonal matrix: `J · Mᵀ · J`, with
		`J = diag(1, 1, -1)`. Entry `(i, j)` is `M(j, i)` with its sign
		flipped when exactly one of `i`, `j` is the timelike index — which
		is the whole of the computation, and the reason no division appears.
		@param frame the isometry to invert; assumed to be in O(2,1), as everything this package produces is.
		@return its exact inverse.
	**/
	public static function invert(frame:Isometry):Isometry {
		var m = frame.m;
		var out = [for (i in 0...9) 0.0];
		for (row in 0...3) {
			for (col in 0...3) {
				var flip = (row == 2) != (col == 2);
				out[row * 3 + col] = flip ? -m[col * 3 + row] : m[col * 3 + row];
			}
		}
		return new Isometry(out);
	}

	/**
		The tangent to the player's left: the third leg of the frame, fixed
		by requiring the frame to be the identity at the origin facing `+x`.

		Written as a Minkowski cross product (an ordinary cross with the
		last component negated) rather than by Gram-Schmidt, because the
		sign convention is the entire content of this function and a cross
		makes it inspectable: substitute `unitPos = (0, 0, 1)`,
		`f = (1, 0, 0)` and the answer is `(0, 1, 0)` by hand.
		@param unitPos position on the unit hyperboloid.
		@param f unit tangent at `unitPos`.
		@return the unit tangent completing the frame.
	**/
	static function sideOf(unitPos:h3d.Vector, f:h3d.Vector):h3d.Vector {
		return new h3d.Vector(unitPos.y * f.z - unitPos.z * f.y, unitPos.z * f.x - unitPos.x * f.z, -(unitPos.x * f.y - unitPos.y * f.x));
	}

	static function normalizeTangent(v:h3d.Vector):h3d.Vector {
		var norm = Math.sqrt(HyperbolicSpace.inner(v, v));
		return norm == 0 ? v : v.scaled(1 / norm);
	}
}
