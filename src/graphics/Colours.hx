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

	/** `biomes.hub.Hourglass`'s own frame (caps + corner posts) — a dark wood/metal placeholder, same discipline as `PAINTING_FRAME`. **/
	public static inline final HOURGLASS_FRAME:Int = 0xFF3A3A40;

	/** `biomes.hub.Hourglass`'s own sand — "white/blue-ish" per the ask, a pale icy tint rather than an ordinary warm sand color. **/
	public static inline final HOURGLASS_SAND:Int = 0xFFE6F2FB;
}
