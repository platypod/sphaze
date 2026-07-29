package graphics.shaders;

/**
	`GrassWind`, except the wind direction varies *per blade* instead of being
	one world axis for the whole mesh — the shader behind
	`biomes.wind.WindBiome`, where the draft flows outward from the maze's exit
	along the corridors, so the grass across the whole sphere traces a field
	pointing home.

	Two deliberate choices worth knowing about:

	**The per-blade direction rides in the vertex normal attribute.** Not
	because it's a normal — this mesh has no lighting whatsoever (see
	`GrassWind`'s own doc on why grass is unlit) — but because
	`h3d.prim.Polygon` already knows how to upload `normals` alongside `uvs`,
	so a per-vertex direction costs one array instead of a custom buffer, and
	the whole field still draws in a single call. The alternative was one mesh
	per corridor, i.e. a few hundred draw calls to say the same thing.

	**It's a separate shader rather than a flag on `GrassWind`.** An hxsl
	`@const` branch would still declare `input.normal` in the shared input
	struct, which every *other* grass mesh in the game (the hub's, the maze's)
	would then have to supply normals for. Duplicating a dozen lines of sway
	math is the cheaper mistake; if a third variant ever appears, that's the
	point to factor the common part out properly.

	Everything else — the quadratic root-to-tip weighting, the per-blade phase,
	recomputing `output.position` inside `vertex()` rather than displacing
	`relativePosition` (which hxsl rejects as a dependency cycle) — is
	`GrassWind`'s, unchanged. Read its class doc first; this one only replaces
	where the direction comes from.
**/
class GrassWindField extends hxsl.Shader {
	static var SRC = {
		@input var input:{
			var uv:Vec2;
			var normal:Vec3;
		};
		@global var global:{
			var time:Float;
			@perObject var modelView:Mat4;
		};
		@global var camera:{
			var viewProj:Mat4;
			var projFlip:Float;
		};
		@param var colorBase:Vec4;
		@param var colorTip:Vec4;
		@param var swayAmplitude:Float;
		@param var swayFrequency:Float;
		@param var gustSpeed:Float;
		var relativePosition:Vec3;
		var calculatedUV:Vec2;
		var output:{
			var position:Vec4;
			var color:Vec4;
		};
		function vertex():Void {
			calculatedUV = input.uv;

			var up = relativePosition.normalize();
			// Same tangent projection GrassWind does, applied to this blade's
			// own direction rather than a shared axis: a raw world direction
			// would gain a radial component away from wherever on the sphere
			// the blade stands, stretching it along its length instead of
			// swaying it sideways.
			var windTangent = (input.normal - up * dot(input.normal, up)).normalize();
			var heightWeight = input.uv.y * input.uv.y;
			var phase = input.uv.x + dot(relativePosition, input.normal) * gustSpeed;
			var sway = sin(global.time * swayFrequency + phase) * swayAmplitude * heightWeight;
			var swayed = relativePosition + windTangent * sway;

			var worldPos = swayed * global.modelView.mat3x4();
			output.position = (vec4(worldPos, 1) * camera.viewProj) * vec4(1, camera.projFlip, 1, 1);
		}
		function fragment():Void {
			output.color = mix(colorBase, colorTip, calculatedUV.y);
		}
	}

	/**
		@param colorBase blade color at the root.
		@param colorTip blade color at the tip.
		@param swayAmplitude how far (world units) the tip sways at the peak of its motion.
		@param swayFrequency how fast blades oscillate, in radians/second.
		@param gustSpeed how fast a sway gust visibly travels along a blade's own wind direction.
	**/
	public function new(colorBase:Int, colorTip:Int, swayAmplitude:Float = GrassWind.DEFAULT_SWAY_AMPLITUDE,
			swayFrequency:Float = GrassWind.DEFAULT_SWAY_FREQUENCY, gustSpeed:Float = GrassWind.DEFAULT_GUST_SPEED) {
		super();
		this.colorBase.setColor(colorBase);
		this.colorTip.setColor(colorTip);
		this.swayAmplitude = swayAmplitude;
		this.swayFrequency = swayFrequency;
		this.gustSpeed = gustSpeed;
	}
}
