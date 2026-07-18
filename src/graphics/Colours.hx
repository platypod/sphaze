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
}
