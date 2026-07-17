package game.shader;

/**
	Flat-shaded (no lighting — see `maze.MazeMesh`'s own doc for why:
	`enableLights = false` alone still leaves PBR's other lighting/falloff
	terms running, and those depend on per-vertex normals this project's
	`Polygon` meshes never set) checkerboard: two alternating flat colors by
	UV, same idea as Heaps' own `h3d.shader.Checker` but writing directly to
	`output.color` instead of `pixelColor` (which only feeds *into* the PBR
	pipeline `h3d.shader.Texture` already doesn't fit into either — see
	`UnlitTexture`'s own doc). Gives an otherwise-featureless surface actual
	visual structure to read curvature, orientation, and distance from —
	`hub.Hub`'s outer shell was a solid flat fill with zero cues for either.
**/
class UnlitChecker extends hxsl.Shader {
	static var SRC = {
		@input var input:{
			var uv:Vec2;
		};
		@param var colorA:Vec4;
		@param var colorB:Vec4;
		@param var scaleU:Float;
		@param var scaleV:Float;
		var calculatedUV:Vec2;
		var output:{
			var color:Vec4;
		};
		function vertex():Void {
			calculatedUV = input.uv;
		}
		function fragment():Void {
			var cell = vec2(calculatedUV.x * scaleU, calculatedUV.y * scaleV).fract();
			if ((cell.x - 0.5) * (cell.y - 0.5) > 0.0) {
				output.color = colorA;
			} else {
				output.color = colorB;
			}
		}
	}

	/**
		@param colorA one checker color.
		@param colorB the other checker color.
		@param scaleU how many checker cells wrap around the U axis (longitude, for a sphere's own UVs).
		@param scaleV how many checker cells span the V axis (latitude).
	**/
	public function new(colorA:Int, colorB:Int, scaleU:Float, scaleV:Float) {
		super();
		this.colorA.setColor(colorA);
		this.colorB.setColor(colorB);
		this.scaleU = scaleU;
		this.scaleV = scaleV;
	}
}
