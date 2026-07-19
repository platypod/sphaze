package graphics;

/**
	Placeholder flat-fill colors used across biomes and entities, gathered
	here so a project-wide palette pass (real art, not flat placeholders)
	has one place to start from instead of several scattered constants.
**/
class Colours {
	/** `GrassMesh`'s blade gradient — darker at the root, lighter/yellower at the tip. **/
	public static inline final GRASS_BASE:Int = 0xFF2E5C2E;

	public static inline final GRASS_TIP:Int = 0xFF7AA648;

	/** `entities.painting.PaintingModel.buildFrame`'s own moulding — a plain wood-brown placeholder, no real art for it yet either. **/
	public static inline final PAINTING_FRAME:Int = 0xFF7A5C3E;

	/** `entities.painting.PaintingModel.buildFrame`'s own thin edge bands — flat unlit shading has no real lighting to read the frame's relief from, so a traced black keyline along its inner/outer border stands in for one. **/
	public static inline final PAINTING_FRAME_OUTLINE:Int = 0xFF000000;

	/** `entities.hourglass.Hourglass`'s own top/bottom caps — a dark wood placeholder, darker than `PAINTING_FRAME` so it reads as a sturdy base rather than a picture frame. **/
	public static inline final HOURGLASS_WOOD:Int = 0xFF3B2417;

	/** `entities.hourglass.Hourglass`'s own reinforcing spiral — a brushed-pewter placeholder. **/
	public static inline final HOURGLASS_METAL:Int = 0xFFAEB4BD;

	/** `entities.hourglass.Hourglass.buildGlass`'s own bulbs — a faint icy tint, alpha-blended (see `Hourglass.GLASS_ALPHA`) rather than opaque, so the sand/spiral read through it. **/
	public static inline final HOURGLASS_GLASS:Int = 0xFFDDF0FA;

	/** `entities.hourglass.Hourglass.buildGlassHighlights`'s own rim/neck bands — brighter than `HOURGLASS_GLASS`, standing in for a specular glint (see that method's own doc for why brightness rather than real reflection). **/
	public static inline final HOURGLASS_GLASS_HIGHLIGHT:Int = 0xFFF4FBFF;

	/**
		`entities.hourglass.Hourglass`'s own sand (and, sharing the same
		fill, its two signs) — a clear light blue, not an ordinary warm sand
		color. `0xFF7FD4EC`, not the original near-white `0xFFE6F2FB`:
		reported directly as wanting it "light blue by default," the glow
		overlays (`HOURGLASS_SAND_GLOW`, still plain white) doing the actual
		emitting-light work untouched.
	**/
	public static inline final HOURGLASS_SAND:Int = 0xFF7FD4EC;

	/** `entities.hourglass.Hourglass`'s own additive glow overlay (`addGlowOverlay`), for the sand and the `+`/`-` signs both — plain white, same "no colour, emit white light" choice `graphics.shaders.TileRingGlow` already made for the tower floor's own glow. **/
	public static inline final HOURGLASS_SAND_GLOW:Int = 0xFFFFFFFF;

	/** `entities.hourglass.Hourglass`'s own sand once `HourglassModel.unlocked` — the hidden mechanic's own visible payoff, "changing the colour of the sand to... say, golden," per the ask. **/
	public static inline final HOURGLASS_SAND_GOLD:Int = 0xFFE8B84B;

	/** The gold sand's own additive glow overlay — a warmer tint than the plain `HOURGLASS_SAND_GLOW`, so the glow itself reads as gold too rather than washing the gold fill back toward white. **/
	public static inline final HOURGLASS_SAND_GOLD_GLOW:Int = 0xFFFFE9A8;
}
