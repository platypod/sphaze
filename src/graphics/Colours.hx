package graphics;

/**
	Placeholder flat-fill colors used across biomes and entities, gathered
	here so a project-wide palette pass (real art, not flat placeholders)
	has one place to start from instead of several scattered constants.
**/
class Colours {
	/** Shared placeholder colors so every painting leading to the hub — or back to the biome — reads consistently regardless of which one the player finds first. **/
	public static inline final TO_HUB:Int = 0xFF4488CC;

	public static inline final TO_BIOME:Int = 0xFFCC8844;

	/** `GrassMesh`'s blade gradient — darker at the root, lighter/yellower at the tip. **/
	public static inline final GRASS_BASE:Int = 0xFF2E5C2E;

	public static inline final GRASS_TIP:Int = 0xFF7AA648;
}
