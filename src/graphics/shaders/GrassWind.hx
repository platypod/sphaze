package graphics.shaders;

/**
	Sways each grass blade sideways from its rest position, plus a flat
	base→tip color gradient — unlit (same reasoning as `UnlitTexture`: this
	mesh never sets per-vertex normals, so PBR's other lighting terms have
	nothing to shade with).

	Recomputes `output.position` itself from `relativePosition` (read-only)
	rather than displacing `relativePosition`/`transformedPosition` in
	`__init__`: hxsl's cross-shader `__init__` merge tracks each shared
	field as a single dependency-graph node, and a statement that both reads
	and writes the *same* field (`relativePosition += ...`) is a self-cycle
	it rejects outright ("Loop in shader dependencies" — hit this the hard
	way first). Doing the whole displacement-and-reproject math inside a
	plain `vertex()` sidesteps that entirely: plain `vertex()`/`fragment()`
	bodies across a pass's shaders just concatenate in shader-list order, so
	this overwrites `h3d.shader.BaseMesh`'s own (undisplaced) `output.position`
	after it runs — the same proven mechanism `UnlitTexture` already uses to
	overwrite `output.color`.

	`windAxis` is one fixed world direction shared by the whole mesh (the
	wind "blows" the same compass direction everywhere in the hub), projected
	onto the tangent plane at each blade's own position so the sway stays
	sideways rather than radial regardless of where on the sphere a blade
	sits — a plain world axis would have a growing radial component near the
	column, stretching blades along their own length instead of swaying them.
	`GrassMesh` packs each vertex's sway weight into `uv.y` (0 at the root,
	so it never moves; 1 at the tip) and a random per-blade phase into
	`uv.x`, desyncing neighboring blades; dotting `relativePosition` against
	`windAxis` adds a travel term so the sway reads as a gust rippling across
	the field rather than every blade waving in place.
**/
class GrassWind extends hxsl.Shader {
	/** Baseline sway tuning — named (rather than left as inline literal defaults) so callers building a biome-specific look (see `GrassMesh.build`) can scale off them instead of hardcoding their own absolute numbers. **/
	public static inline final DEFAULT_SWAY_AMPLITUDE:Float = 0.6;

	public static inline final DEFAULT_SWAY_FREQUENCY:Float = 1.6;

	public static inline final DEFAULT_GUST_SPEED:Float = 0.05;

	static var SRC = {
		@input var input:{
			var uv:Vec2;
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
		@param var windAxis:Vec3;
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
			var windTangent = (windAxis - up * dot(windAxis, up)).normalize();
			var heightWeight = input.uv.y * input.uv.y; // quadratic: tip sways, root stays planted
			var phase = input.uv.x + dot(relativePosition, windAxis) * gustSpeed;
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
		@param windAxis world-space direction the wind blows; only its component tangent to each blade's own position on the sphere is used.
		@param swayAmplitude how far (world units) the tip sways at the peak of its motion.
		@param swayFrequency how fast blades oscillate, in radians/second.
		@param gustSpeed how fast a sway gust visibly travels across the field along `windAxis`.
	**/
	public function new(colorBase:Int, colorTip:Int, windAxis:h3d.Vector, swayAmplitude:Float = DEFAULT_SWAY_AMPLITUDE,
			swayFrequency:Float = DEFAULT_SWAY_FREQUENCY, gustSpeed:Float = DEFAULT_GUST_SPEED) {
		super();
		this.colorBase.setColor(colorBase);
		this.colorTip.setColor(colorTip);
		this.windAxis.set(windAxis.x, windAxis.y, windAxis.z);
		this.swayAmplitude = swayAmplitude;
		this.swayFrequency = swayFrequency;
		this.gustSpeed = gustSpeed;
	}
}
