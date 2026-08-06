package graphics.shaders;

/**
	Tron-style panel for `biomes.conway.ConwayMesh`'s closed-edge walls: a
	dark base (`panelColor`) with an emissive rim hugging the top and bottom
	edges plus periodic vertical seam lines, every line a soft Gaussian
	falloff rather than a hard cutoff — the same technique `TileRingGlow`
	uses for the tower's own ring glow, reused here rather than invented
	fresh.

	Raised directly ("pretty ugly right now, lacking depth or texture") to
	replace the previous flat `h3d.shader.FixedColor` fill, which had no
	edge treatment and no reaction to anything.

	**Brightness reacts to the wall's own activity**, carried in the vertex
	normal's `x` component the same way `GrassWindField` carries its
	per-blade wind direction there (this mesh has no real lighting either —
	see that shader's own doc for why the normal attribute is the cheap
	per-vertex channel to reuse rather than a custom buffer). The value is
	`biomes.conway.ConwayMazeReactivity.edgeActivity` for the edge this
	quad renders: a wall close to opening pulses hot, a quiet one stays
	dim, so the maze's own reactive rule reads visually instead of only
	being felt through collision.

	`uv.x` is the wall's own world-space distance along its length (drives
	the seam spacing at a fixed real-world density, matching
	`game.MeshBuilder.WALL_TEXTURE_TILE_SIZE`'s own "world units, not
	normalized 0-1" convention so seams read the same width regardless of
	how long a given wall segment is); `uv.y` is height, 0 at the base and
	1 at the top.
**/
class ConwayWallGlow extends hxsl.Shader {
	/** Seam lines per world unit of wall length. **/
	public static inline final DEFAULT_SEAM_DENSITY:Float = 0.12;

	/** Glow strength at zero activity — never fully dark, so a quiet wall still reads as a wall rather than disappearing. **/
	public static inline final DEFAULT_REST_BRIGHTNESS:Float = 0.22;

	static var SRC = {
		@input var input:{
			var uv:Vec2;
			var normal:Vec3;
		};
		@global var global:{
			var time:Float;
		};
		@param var panelColor:Vec4;
		@param var glowColor:Vec3;
		@param var seamDensity:Float;
		@param var restBrightness:Float;
		var calculatedUV:Vec2;
		var calculatedActivity:Float;
		var output:{
			var color:Vec4;
		};
		function vertex():Void {
			calculatedUV = input.uv;
			calculatedActivity = input.normal.x;
		}
		function fragment():Void {
			var edgeHaloSq = 0.0025; // narrow: a crisp-ish rim, not a full-height wash
			var rimTop = exp(-((1.0 - calculatedUV.y) * (1.0 - calculatedUV.y)) / edgeHaloSq);
			var rimBottom = exp(-(calculatedUV.y * calculatedUV.y) / edgeHaloSq);

			var seamPos = fract(calculatedUV.x * seamDensity);
			var seamDist = min(seamPos, 1.0 - seamPos);
			var seamHaloSq = 0.0015;
			var seam = exp(-(seamDist * seamDist) / seamHaloSq) * 0.5;

			var structural = clamp(rimTop + rimBottom + seam, 0.0, 1.0);

			// A hotter edge pulses faster as well as brighter, so "about to open" reads as agitated energy, not just a static brightness change.
			var pulse = 0.9 + 0.1 * sin(global.time * (2.0 + calculatedActivity * 6.0));
			var brightness = mix(restBrightness, 1.0, calculatedActivity) * pulse;

			output.color = vec4(panelColor.rgb + glowColor * structural * brightness, panelColor.a);
		}
	}

	/**
		@param panelColor the wall's dark base fill.
		@param glowColor the rim/seam emissive tint.
		@param seamDensity vertical seam lines per world unit of wall length; defaults to `DEFAULT_SEAM_DENSITY`.
		@param restBrightness glow strength at zero activity; defaults to `DEFAULT_REST_BRIGHTNESS`.
		@param opacity output alpha, overriding whatever `panelColor`'s own alpha byte was — the caller's `material.blendMode` still has to be set to `h3d.mat.BlendMode.Alpha` for this to actually blend rather than just writing a translucent value nothing reads; defaults to fully opaque.
	**/
	public function new(panelColor:Int, glowColor:Int, seamDensity:Float = DEFAULT_SEAM_DENSITY, restBrightness:Float = DEFAULT_REST_BRIGHTNESS,
			opacity:Float = 1) {
		super();
		this.panelColor.setColor(panelColor);
		this.panelColor.w = opacity;
		this.glowColor.setColor(glowColor);
		this.seamDensity = seamDensity;
		this.restBrightness = restBrightness;
	}
}
