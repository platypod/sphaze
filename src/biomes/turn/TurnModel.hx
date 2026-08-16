package biomes.turn;

import geometry.CurvedSpace.ModelPoint;
import geometry.DeckGroup;
import geometry.DeckGroups;
import geometry.Isometry;

/**
	The Turn's band: a flat strip of the plane, identified with itself by
	a single glide reflection.

	**This is the honest Möbius band, and `biomes.mobius.MobiusBiome` is
	not.** That biome embeds a strip in ℝ³ and twists it, which looks
	right and *is not flat* — an embedded twisted strip carries real
	curvature everywhere, so walking it teaches the wrong lesson for a
	space `docs/game-design/direction/world-and-threads.md` files under
	κ = 0. Quotienting a flat strip by a glide reflection puts the twist
	in the **identification** rather than in the geometry: intrinsically
	flat, genuinely non-orientable, which is exactly the distinction the
	space exists to teach. The two biomes are left side by side rather
	than one replacing the other, since the embedded one is a different
	(and prettier) thing to look at.

	**The first real customer of `geometry.DeckGroup`.** The Repeat, built
	for the same framework, turned out to need separate-but-identical
	tiles rather than a quotient — see `biomes.repeat.RepeatModel`. Here
	the quotient is the point, and the group is doing genuine work: the
	glide's own sign conventions come from tested code rather than from a
	hand-written `(x + period, −y)` that would be one typo away from an
	orientable cylinder.

	**Coordinates.** The band lies in the world's XZ plane, so model `x`
	runs *along* the band and model `y` runs *across* it, mapping to world
	`z`. World `y` is height, which the quotient never touches.
**/
class TurnModel {
	/**
		How far along the band before it closes on itself, reversed.

		Long enough that a lap is about thirty seconds at this biome's own
		speed — the design demands unusually high tolerance for repeated
		traversal, and a lap short enough to be memorised in one pass
		leaves nothing to get better at.
	**/
	public static inline final PERIOD:Float = 1200;

	/** Half the band's own width. Wide enough to weave across at speed, narrow enough that the far rail is always in view. **/
	public static inline final HALF_WIDTH:Float = 44;

	/** Obstacles per lap. At `PERIOD` and this biome's speed, one about every two seconds — a rhythm rather than a queue. **/
	public static inline final OBSTACLE_COUNT:Int = 16;

	/** Distance along the band between consecutive obstacles. **/
	public static inline final OBSTACLE_SPACING:Float = PERIOD / OBSTACLE_COUNT;

	/**
		Half an obstacle's own width across the band.

		Pulled in from `13` after looking at the first build: at eye height
		these are things you pass *beside*, and a block a quarter of the
		band wide standing head-high fills the frame from twenty-five units
		away, which reads as a wall rather than as a thing to weave past.
	**/
	public static inline final OBSTACLE_HALF_WIDTH:Float = 11;

	/** Half an obstacle's own depth along the band. **/
	public static inline final OBSTACLE_HALF_DEPTH:Float = 5;

	public static inline final OBSTACLE_HEIGHT:Float = 14;

	/** How far an obstacle's centre may sit from the band's own axis — kept clear of the rails so there is always a way past on either side. **/
	static inline final MAX_LATERAL_OFFSET:Float = HALF_WIDTH - OBSTACLE_HALF_WIDTH - 8;

	/** The glide-reflection group this band is the quotient by. **/
	public static final GROUP:DeckGroup = DeckGroups.mobiusBand(PERIOD);

	/** The generator itself — the identification, applied when the player walks off one end. **/
	public static function glide():Isometry {
		return GROUP.generators[0];
	}

	/** Its inverse, for walking off the other end. **/
	public static function glideBack():Isometry {
		return GROUP.generators[1];
	}

	/** Where along the band an obstacle sits, in the fundamental domain `[-PERIOD/2, PERIOD/2)`. **/
	public static function obstacleAlong(index:Int):Float {
		return -PERIOD / 2 + (index + 0.5) * OBSTACLE_SPACING;
	}

	/**
		How far across the band an obstacle sits — **the whole chirality
		tell, and the reason the layout is asymmetric on purpose.**

		Go round once and the glide reflects the band, so the rhythm the
		player has just learned ("left, left, right, centre") arrives as
		its mirror. A layout symmetric about the axis would come back
		identical and the space would teach nothing.
		@param index which obstacle.
		@return its offset from the axis; positive and negative are opposite sides.
	**/
	public static function obstacleAcross(index:Int):Float {
		return (noise(index, 1) * 2 - 1) * MAX_LATERAL_OFFSET;
	}

	/** How tall an obstacle stands — varied only so the band does not read as a row of identical teeth. **/
	public static function obstacleHeight(index:Int):Float {
		return OBSTACLE_HEIGHT * (0.7 + noise(index, 2) * 0.6);
	}

	/** A world position as a point of the model plane. **/
	public static function toModel(pos:h3d.Vector):ModelPoint {
		return {x: pos.x, y: pos.z, z: 1};
	}

	/** A world *direction* as a model vector — `z = 0`, so an isometry's translation part drops out and only its linear part applies. **/
	public static function directionToModel(direction:h3d.Vector):ModelPoint {
		return {x: direction.x, y: direction.z, z: 0};
	}

	/** A model point back to a world position at the given height. **/
	public static function toWorld(p:ModelPoint, height:Float):h3d.Vector {
		return new h3d.Vector(p.x, height, p.y);
	}

	/**
		Whether a position has walked off the end of the fundamental
		domain, and which way — `1` past the far end, `-1` past the near
		one, `0` inside.
		@param pos a world position on the band.
		@return which identification to apply, if any.
	**/
	public static function wrapDirection(pos:h3d.Vector):Int {
		if (pos.x >= PERIOD / 2) {
			return 1;
		}
		return pos.x < -PERIOD / 2 ? -1 : 0;
	}

	/**
		A deterministic value in `[0, 1)`. Same hash as
		`biomes.repeat.RepeatModel`'s, for the same reason: callers need to
		ask about an arbitrary obstacle without having generated its
		neighbours.
	**/
	static function noise(a:Int, salt:Int):Float {
		var h = a * 374761393 + salt * 1274126177;
		h = (h ^ (h >> 13)) * 1274126177;
		h = h ^ (h >> 16);
		return (h & 0x7FFFFFFF) / 2147483648.0;
	}
}
