package biomes.debug;

/**
	The debug room's own view of
	`docs/game-design/direction/world-and-threads.md`'s numbering — which
	space is `1`, which is `2`, and what each is actually called.

	**Why this exists at all.** The registry knows biome *ids* (`conway`,
	`weft`, `sprawl`), which are implementation names and carry no order.
	The design numbers its spaces `0` to `9` along the curvature scale,
	and that ordering is the whole shape of the world — asked for directly
	(2026-08-16: "add numbers to the warp-gates"). Putting the mapping
	here rather than on `Biome` keeps design metadata out of the runtime
	contract: nothing in the game needs to know a biome's place in a
	reading order, and only this dev room does.

	**Unnumbered biomes are not an oversight.** `maze`, `tower`, `mobius`,
	`wind`, `exterior` and `twosided` predate the direction and have no
	place on the curvature scale. They keep their plain ids and sort after
	the numbered ones, which is also the honest signal that they are
	older work rather than part of the nine.

	Move this out of `biomes.debug` if anything but the debug room ever
	needs it — per `docs/GUIDELINES.md`, on the second use case, not the
	first.
**/
class DebugHubOrder {
	/**
		Design number and name per biome id, in the order
		`world-and-threads.md` lists them.

		Names drop the design's own leading "The". `graphics.LabelTexture`
		scales text to fit a fixed-width sign, so a long label renders in
		much smaller glyphs than a short one — "0. The Still Life" beside
		"wind" was a quarter the size and barely readable across the room.
		Dropping four characters from the longest name evens the row out
		and loses nothing: nobody will fail to recognise "5. Defect".

		`conway` is the Fold: the geodesic sphere kept the original biome's
		registry id when it was swapped in (see `game.GameLoop`), so the
		implementation name and the design name genuinely differ here.
	**/
	static final NUMBERED:Map<String, {number:Int, name:String}> = [
		"hub" => {number: 0, name: "Still Life"},
		"conway" => {number: 1, name: "Fold"},
		"weft" => {number: 2, name: "Weft"},
		"repeat" => {number: 3, name: "Repeat"},
		"turn" => {number: 4, name: "Turn"},
		"defect" => {number: 5, name: "Defect"},
		"ribbon" => {number: 6, name: "Ribbon"},
		"sprawl" => {number: 7, name: "Sprawl"},
	];

	/**
		What a portal to this biome should read.
		@param id the biome's own registry id.
		@return `"5. Defect"` for one of the nine, or the bare id for anything else.
	**/
	public static function labelFor(id:String):String {
		var entry = NUMBERED.get(id);
		return entry == null ? id : '${entry.number}. ${entry.name}';
	}

	/**
		Sorts biome ids into ring order: the nine by their design number
		first, then everything else alphabetically.

		Sorting rather than just labelling, because a number that does not
		match the order you walk past them in is worse than no number —
		the point of the numbering is that the ring reads as the curvature
		scale.
		@param ids the ids to order; not modified.
		@return a new array in ring order.
	**/
	public static function sorted(ids:Array<String>):Array<String> {
		var ordered = ids.copy();
		ordered.sort((a, b) -> {
			var na = NUMBERED.get(a);
			var nb = NUMBERED.get(b);
			if (na != null && nb != null) {
				return na.number - nb.number;
			}
			if (na != null) {
				return -1;
			}
			if (nb != null) {
				return 1;
			}
			return a < b ? -1 : (a > b ? 1 : 0);
		});
		return ordered;
	}
}
