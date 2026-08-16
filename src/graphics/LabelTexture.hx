package graphics;

/**
	Renders a short string into a texture, so text can be mounted on
	world geometry — the project has no 3D text of any kind otherwise, and
	`biomes.debug.DebugHubBiome`'s portals are unusable without a way to tell
	which is which.

	Deliberately a *texture* rather than a `h2d` overlay: an overlay would be
	the easy answer, but it would also be the project's first piece of UI
	chrome, which the diegetic-over-chrome pillar
	(`docs/rules/philosophy.md`) exists to avoid. A rendered sign is a
	thing in the world, and it reuses `entities.painting.PaintingModel`'s own
	quad building unchanged. (The pillar is about the *game*; a dev-only hub
	could get away with chrome. Doing it this way costs one small class and
	keeps the option of real in-world signage later.)

	Uses `hxd.res.DefaultFont` — the built-in bitmap font, no asset to add —
	drawn at whatever scale fits the requested texture, and paints its own
	background rather than relying on the render target's initial contents,
	which `h2d.Object.drawTo` doesn't promise anything about.
**/
class LabelTexture {
	/** Fraction of the texture's width the text is allowed to fill, leaving a visible margin either side. **/
	static inline final WIDTH_FILL:Float = 0.86;

	/** Fraction of the texture's height the text is allowed to fill. **/
	static inline final HEIGHT_FILL:Float = 0.7;

	/**
		@param text the string to render; short — this is a sign, not a paragraph.
		@param width the texture's width in pixels.
		@param height the texture's height in pixels.
		@param background the sign's own fill, as `0xAARRGGBB`.
		@param textColor the text's own color, as `0xAARRGGBB`.
		@return a texture with `text` centred on a `background` field.
	**/
	public static function build(text:String, width:Int, height:Int, background:Int, textColor:Int):h3d.mat.Texture {
		var texture = new h3d.mat.Texture(width, height, [Target]);

		var root = new h2d.Object();
		new h2d.Bitmap(h2d.Tile.fromColor(background, width, height), root);

		var label = new h2d.Text(hxd.res.DefaultFont.get(), root);
		label.text = text;
		label.textColor = textColor;
		// DefaultFont is a small fixed-size bitmap font, so filling a sign
		// means scaling the glyphs up rather than asking for a bigger size.
		var scale = Math.min(width * WIDTH_FILL / Math.max(1, label.textWidth), height * HEIGHT_FILL / Math.max(1, label.textHeight));
		label.setScale(scale);
		label.x = (width - label.textWidth * scale) / 2;
		label.y = (height - label.textHeight * scale) / 2;

		root.drawTo(texture);
		return texture;
	}
}
