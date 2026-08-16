package biomes.turn;

import game.BoxBatch;
import geometry.Isometry;

/**
	The band, its two rails, and the obstacles along it — drawn once per
	copy of the fundamental domain, so looking down the band shows the
	next lap already mirrored.

	**The two rails read differently, and that is the mechanic rather than
	decoration.**
	`docs/game/world.md` gives this space a
	legibility law — your handedness is readable *only relative to
	something you left behind* — and leaves open, explicitly, "how the
	player actually discovers their own current state cheaply enough that
	testing it isn't itself the boring part". This is an answer that costs
	one glance.

	**How it actually works, which is not what I first wrote.** A Möbius
	band has **one** boundary curve, not two: the glide identifies the
	line `y = +HALF_WIDTH` with `y = -HALF_WIDTH`, so what look like two
	rails are one rail of twice the band's own period, traversed in two
	passes. Painting it pale for the first period and dashed for the
	second is therefore a perfectly consistent decoration of a single
	curve — and it makes *which rail is beside me* a direct readout of
	**which of the two lifts the player is currently on**, which is
	exactly their handedness.

	The first version of this comment claimed the bright rail simply
	"moves to your other side" after a lap. That reading treats the edges
	as two independent objects, which the geometry does not; the top-down
	view where the rails visibly change places at the seam is the same
	fact stated correctly.

	Proposed here rather than settled in the design doc — it wants a
	playtest before it earns a place in `world-and-threads.md`.

	Colour is value only: κ = 0 is bone, slate and ash, and hue belongs to
	curvature alone.
**/
class TurnMesh {
	static inline final FLOOR_COLOR:Int = 0x24282E;

	/** The bright rail — the one that tells the player which way round they currently are. **/
	static inline final RAIL_BRIGHT_COLOR:Int = 0xE4E0D6;

	/**
		Its opposite.

		Raised from `0x4A5058` after looking at the first build, where it
		was invisible: against a dark floor and a darker void, the far rail
		simply was not there, and a tell that depends on *two* references
		does not work with one.
	**/
	static inline final RAIL_DARK_COLOR:Int = 0x646C77;

	static inline final OBSTACLE_COLOR:Int = 0x9098A2;

	static inline final RAIL_HALF_WIDTH:Float = 3;
	static inline final RAIL_HEIGHT:Float = 11;

	/** Dashes in the dark rail per copy — enough to give that edge a rhythm to read speed against, which a smooth wall does not. **/
	static inline final RAIL_SEGMENTS:Int = 60;

	/** Fraction of a dash's own slot that is solid; the rest is the gap. **/
	static inline final RAIL_SEGMENT_FILL:Float = 0.62;

	/**
		Builds the band and every copy of it within `copies` laps either
		way.
		@param parent the scene object to build under.
		@param copies how many copies of the fundamental domain to draw on each side; one is enough to fill the view at this period.
	**/
	public static function build(parent:h3d.scene.Object, copies:Int):Void {
		var floors = new BoxBatch(parent, FLOOR_COLOR);
		var bright = new BoxBatch(parent, RAIL_BRIGHT_COLOR);
		var dark = new BoxBatch(parent, RAIL_DARK_COLOR);
		var obstacles = new BoxBatch(parent, OBSTACLE_COLOR);

		for (copy in -copies...copies + 1) {
			var placement = copyTransform(copy);
			addFloor(floors, placement);
			addRails(bright, dark, placement);
			addObstacles(obstacles, placement);
		}

		floors.flush();
		bright.flush();
		dark.flush();
		obstacles.flush();
	}

	/**
		The isometry placing copy `n` of the fundamental domain — the glide
		composed with itself `n` times, which for odd `n` is a reflection.

		Built by repeated composition rather than by writing
		`(x + n·period, ±y)` directly, so the mirroring of odd copies comes
		out of the group rather than out of a sign somebody has to
		remember.
	**/
	static function copyTransform(n:Int):Isometry {
		var step = n >= 0 ? TurnModel.glide() : TurnModel.glideBack();
		var placement = Isometry.identity();
		for (_ in 0...(n < 0 ? -n : n)) {
			placement = Isometry.compose(placement, step);
		}
		return placement;
	}

	/** The walkable strip, as one flat slab per copy. **/
	static function addFloor(floors:BoxBatch, placement:Isometry):Void {
		var centre = Isometry.apply(placement, {x: 0, y: 0, z: 1});
		floors.add(centre.x, centre.y, TurnModel.PERIOD / 2, TurnModel.HALF_WIDTH, -1, 1);
	}

	/**
		Both edges — **and they differ in shape as well as in value.**

		One rail is continuous and pale; the other is a dashed line, darker.
		Two independent channels carrying the same fact, because the tell
		this space rests on has to survive being read in a glance at speed:
		*which edge am I next to?* Value alone nearly failed on the first
		build, where the darker rail vanished against the void. Silhouette
		is also what
		`docs/game/art-and-audio.md` says should carry a
		flat biome, and a dashed edge has the side benefit of visibly
		streaming past, which a smooth wall does not.

		The rails are placed at fixed *model* offsets and then transformed
		by the copy's own placement, which is what makes them swap sides on
		odd copies — the whole point. Placing them "left" and "right" in
		world terms would defeat it.
	**/
	static function addRails(bright:BoxBatch, dark:BoxBatch, placement:Isometry):Void {
		var continuous = Isometry.apply(placement, {x: 0, y: TurnModel.HALF_WIDTH, z: 1});
		bright.add(continuous.x, continuous.y, TurnModel.PERIOD / 2, RAIL_HALF_WIDTH, 0, RAIL_HEIGHT);

		var slot = TurnModel.PERIOD / RAIL_SEGMENTS;
		var halfLength = slot * RAIL_SEGMENT_FILL / 2;
		for (segment in 0...RAIL_SEGMENTS) {
			var along = -TurnModel.PERIOD / 2 + (segment + 0.5) * slot;
			var at = Isometry.apply(placement, {x: along, y: -TurnModel.HALF_WIDTH, z: 1});
			dark.add(at.x, at.y, halfLength, RAIL_HALF_WIDTH, 0, RAIL_HEIGHT);
		}
	}

	/** The obstacles to weave through — the per-lap skill, and the thing whose rhythm arrives mirrored. **/
	static function addObstacles(obstacles:BoxBatch, placement:Isometry):Void {
		for (index in 0...TurnModel.OBSTACLE_COUNT) {
			var at = Isometry.apply(placement, {x: TurnModel.obstacleAlong(index), y: TurnModel.obstacleAcross(index), z: 1});
			obstacles.add(at.x, at.y, TurnModel.OBSTACLE_HALF_DEPTH, TurnModel.OBSTACLE_HALF_WIDTH, 0, TurnModel.obstacleHeight(index));
		}
	}
}
