package graphics.shaders;

/**
	Multiplies whatever an earlier shader in the same pass already wrote to
	`output.color` by a flat `brightness` factor — dims a mesh's own base
	texture without touching the texture asset itself. Kept out of
	`UnlitTexture` for the same reason `TileRingGlow` is its own shader, not
	folded in there (see `UnlitTexture`'s own class doc): every mesh in the
	project shares that one, so a one-off darkening for a single biome
	belongs in its own shader instead.

	Order within the pass matters: add this *after* whatever samples the
	base texture but *before* any additive effect meant to stay at full
	strength regardless (this project's shaders concatenate in shader-list
	order within a pass, same mechanism `GrassWind`'s own class doc
	documents) — that way the effect reads with more contrast against the
	now-darker base rather than getting dimmed right along with it.

	Built for `biomes.tower.TowerMesh`'s own floor/wall, at hooman's direct
	ask: "tackle the base ambient lighting reduction in the tower... let's
	see where it gets us" — the fall counter's own
	`graphics.shaders.TileRingGlow` glow reads with more contrast against a
	darker stone base.
**/
class Dim extends hxsl.Shader {
	static var SRC = {
		@param var brightness:Float;
		var output:{
			var color:Vec4;
		};
		function fragment():Void {
			output.color = vec4(output.color.rgb * brightness, output.color.a);
		}
	}

	public function new(brightness:Float = 1) {
		super();
		this.brightness = brightness;
	}
}
