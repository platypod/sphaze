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

	/** `GridMesh`'s flat floor fill. **/
	public static inline final GRID_FLOOR:Int = 0xFF444444;

	/** Checkerboard colors for the hub's outer shell — a solid flat fill gave the room's curvature and the player's own distance from anything no visual cues at all; alternating cells fix that without needing a texture asset. **/
	public static inline final HUB_FLOOR_A:Int = 0xFF3A3A44;

	public static inline final HUB_FLOOR_B:Int = 0xFF4A4A58;
}
