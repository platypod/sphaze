package graphics.shaders;

/**
	A flat base-to-tip color gradient, no vertex motion — the color-mixing
	half of `GrassWind` (`mix(colorBase, colorTip, uv.y)`) on its own,
	for solid geometry that shouldn't sway (`biomes.common.tree.TreeMesh`'s
	trunks/foliage): a single flat fill per mesh (`h3d.shader.FixedColor`)
	reads flat and plasticky at this project's usual scale, same complaint
	that never came up for grass since its own tip color already gives it
	visible depth for free. `uv.y` is base(0)/tip(1) height fraction, same
	convention `biomes.common.grass.GrassMesh` already packs.
**/
class HeightGradient extends hxsl.Shader {
	static var SRC = {
		@input var input:{
			var uv:Vec2;
		};
		@param var colorBase:Vec4;
		@param var colorTip:Vec4;
		var calculatedUV:Vec2;
		var output:{
			var color:Vec4;
		};
		function vertex():Void {
			calculatedUV = input.uv;
		}
		function fragment():Void {
			output.color = mix(colorBase, colorTip, calculatedUV.y);
		}
	}

	/**
		@param colorBase fill color at height fraction 0 (the root/base).
		@param colorTip fill color at height fraction 1 (the tip).
	**/
	public function new(colorBase:Int, colorTip:Int) {
		super();
		this.colorBase.setColor(colorBase);
		this.colorTip.setColor(colorTip);
	}
}
