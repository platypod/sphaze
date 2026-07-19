package graphics.shaders;

/**
	Samples a texture straight to the fragment output, bypassing the PBR
	pipeline entirely — the textured equivalent of `h3d.shader.FixedColor`
	(see `biomes.common.grid.GridMesh`'s class doc for why: `enableLights =
	false` alone still leaves PBR's other lighting/falloff terms running, and
	those depend on per-vertex normals this mesh never sets). `h3d.shader.Texture`
	multiplies into `pixelColor` for use *within* that pipeline instead of
	replacing it, so it doesn't fit here.

	`scaleU`/`scaleV` repeat the UVs before sampling (paired with the
	texture's own `wrap = Repeat`) — for a mesh like `HubMesh`'s shell whose
	UVs come from `h3d.prim.Sphere.addUVs()` at a fixed [0,1] range rather
	than baked-in tiling the way `HubMesh.buildColumn`'s own manually-built
	UVs already are. Default to 1 (no-op) so existing single-repeat callers
	don't need to change.

	Kept deliberately plain — every mesh in the project shares this shader
	(`HubMesh`, `Hourglass`, `PaintingModel`, `GridMesh`, …), so a one-off
	effect for a single biome (see `biomes.tower.TowerMesh`'s own fall-counter
	glow, `graphics.shaders.TileRingGlow`) belongs in its own shader, added
	only to the meshes that actually want it, not folded in here where a bug
	in it could show up anywhere `UnlitTexture` is used at all — which is
	exactly what happened the first time a version of that glow was tried
	directly in here (see `docs/PROJECT_LOG.md`'s own entry on it).
**/
class UnlitTexture extends hxsl.Shader {
	static var SRC = {
		@input var input:{
			var uv:Vec2;
		};
		@param var texture:Sampler2D;
		@param var scaleU:Float;
		@param var scaleV:Float;
		var calculatedUV:Vec2;
		var output:{
			var color:Vec4;
		};
		function vertex():Void {
			calculatedUV = vec2(input.uv.x * scaleU, input.uv.y * scaleV);
		}
		function fragment():Void {
			output.color = texture.get(calculatedUV);
		}
	}

	public function new(?tex:h3d.mat.Texture, scaleU:Float = 1, scaleV:Float = 1) {
		super();
		this.texture = tex;
		this.scaleU = scaleU;
		this.scaleV = scaleV;
	}
}
