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

	/** `biomes.tower.TowerMesh`'s own floor glow once `entities.hourglass.HourglassModel.unlocked` — the hourglass secret's own payoff bleeding into the tower, same gold as `HOURGLASS_SAND_GOLD_GLOW` rather than a second, unrelated gold. **/
	public static inline final TOWER_SECRET_GLOW:Int = HOURGLASS_SAND_GOLD_GLOW;

	/** `biomes.mobius.MobiusMesh`'s own alternating across-width color bands — a placeholder pair chosen purely so the ribbon's own twist(s) read clearly as you walk it (no real art for this biome yet either). **/
	public static inline final MOBIUS_BAND_A:Int = 0xFFB0473C;

	/** See `MOBIUS_BAND_A`. **/
	public static inline final MOBIUS_BAND_B:Int = 0xFF3C6EB0;

	/** `biomes.common.tree.TreeMesh`'s own trunks, at the root (`graphics.shaders.HeightGradient`'s own base color) — a plain bark-brown placeholder, no real art yet either. **/
	public static inline final TREE_TRUNK_BASE:Int = 0xFF3E2E20;

	/** `biomes.common.tree.TreeMesh`'s own trunks, at the top (`graphics.shaders.HeightGradient`'s own tip color) — lighter than `TREE_TRUNK_BASE`, so the trunk reads with some depth instead of one flat fill. **/
	public static inline final TREE_TRUNK_TIP:Int = 0xFF6B4E36;

	/** `biomes.common.tree.TreeMesh`'s own foliage, at the trunk-top collar (`graphics.shaders.HeightGradient`'s own base color) — a deep conifer green, distinct from `GRASS_BASE`/`GRASS_TIP` so a forest's canopy reads apart from the ground cover beneath it. **/
	public static inline final TREE_FOLIAGE_BASE:Int = 0xFF16351F;

	/** `biomes.common.tree.TreeMesh`'s own foliage, at the very tip (`graphics.shaders.HeightGradient`'s own tip color) — lighter/yellower than `TREE_FOLIAGE_BASE`, catching more light at the canopy's own top. **/
	public static inline final TREE_FOLIAGE_TIP:Int = 0xFF3D7A45;
}
