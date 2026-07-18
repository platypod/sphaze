package graphics.shaders;

/**
	Samples a texture straight to the fragment output, bypassing the PBR
	pipeline entirely — the textured equivalent of `h3d.shader.FixedColor`
	(see `biomes.common.grid.GridMesh`'s class doc for why: `enableLights =
	false` alone still leaves PBR's other lighting/falloff terms running, and
	those depend on per-vertex normals this mesh never sets). `h3d.shader.Texture`
	multiplies into `pixelColor` for use *within* that pipeline instead of
	replacing it, so it doesn't fit here.
**/
class UnlitTexture extends hxsl.Shader {
	static var SRC = {
		@input var input:{
			var uv:Vec2;
		};
		@param var texture:Sampler2D;
		var calculatedUV:Vec2;
		var output:{
			var color:Vec4;
		};
		function vertex():Void {
			calculatedUV = input.uv;
		}
		function fragment():Void {
			output.color = texture.get(calculatedUV);
		}
	}

	public function new(?tex:h3d.mat.Texture) {
		super();
		this.texture = tex;
	}
}
