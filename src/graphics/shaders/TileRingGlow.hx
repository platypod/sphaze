package graphics.shaders;

/**
	A soft white light hugging the tower floor's own concentric ring
	boundaries — no color, purely additive brightness — starting confined to
	the center disk's own rim and reaching further rings as `intensity`
	climbs. Layered on top of whatever an earlier shader in the same pass
	already wrote to `output.color` (this project's shaders concatenate in
	shader-list order within a pass, same mechanism `GrassWind`'s own class
	doc documents), rather than sampling or replacing a texture itself.

	Replaces `biomes.tower.TowerMesh`'s earlier attempt at this same
	fall-counter cue, `SparseTint` (since removed) — that one tinted
	individual bricks on the *wall*, and went through four rounds trying to
	get its patches to actually align with the wall texture's own baked
	brick art, never quite landing (the source art itself doesn't divide
	into a whole number of bricks per tile, an unfixable-by-math seam).
	Asked directly for something that sidesteps alignment entirely: "make
	the edges of the tiles glow slightly (no colour, emit white light)...
	start dim, only the edges of the inner circle... grow in both intensity
	and length (reach further rings)" as the fall counter's own percentage
	climbs. Ring boundaries are exact, known geometry (`TowerModel.CENTER_DISK_RADIUS`,
	`ringWidth()`) — a world-space radius comparison, not a texture-grid
	guess — so there is no alignment question here at all.

	Only the floor needs this (see `TowerMesh.build`); it reads world
	position back out of the floor's own existing decal UV
	(`TowerMesh.floorUv`'s inverse: `uv` spans `[0, 1]` linearly across
	`uvToWorldScale` world units, centered on the shaft's own axis) rather
	than needing a second UV channel.

	Follow-up, same ask: "Can you make it on the all of the tiles side? Not
	only the rings edges." — every ring's own tile-to-tile (radial) seams
	glow too now, not just the 5 concentric ring-boundary circles. Same
	"exact known geometry, not a texture guess" reasoning: each ring's own
	tile count/angular shear (`TowerModel.tilesForRing`/`ringAngleOffset`)
	is fixed by this project's own structural constants
	(`BASE_TILES_PER_RING`, `RING_ANGLE_STEP_SLOTS`, `ANGULAR_SEGMENTS`),
	never the generated layout, so each ring's own tile angular width and
	angle offset are hand-computed constants here (`ring0`'s comments show
	the derivation; rings 1-3 follow the same formulas), not read from
	`TowerModel` directly (hxsl can't call into ordinary Haxe code). A
	ring's own radial-seam glow shares its inner boundary circle's own
	strength (`boundary0` lights ring 0's own tile seams, `boundary1` lights
	ring 1's, etc.) so a ring's interior detail appears in step with that
	ring itself being "reached," not on some separate schedule.

	Follow-up, same ask again: "make the light look more like a light? To
	cover the tiles seams with some kind of halo, so it looks less texture
	on texture." The original falloff (`1.0 - smoothstep(0.0, 0.6, d)`) had
	a hard cutoff distance — full brightness right at a seam, exactly zero
	just past it — which reads as a crisp bright line drawn precisely on
	top of the seam rather than a light actually sitting near it. Every
	falloff below is now a Gaussian (`exp(-(d*d) / haloWidthSq)`) instead:
	same peak brightness exactly on the seam, but no fixed distance where
	it suddenly stops — it just keeps fading, asymptotically, the way an
	actual light's falloff does, bleeding softly onto the tile surface on
	both sides of the seam instead of stopping at it.

	`glowColor` defaults to plain white (the fall counter's own reading) —
	`biomes.tower.TowerBiome` overrides it to gold once
	`entities.hourglass.HourglassModel.unlocked`, the hourglass secret's own
	payoff, without needing a second shader just to swap a tint.
**/
class TileRingGlow extends hxsl.Shader {
	static var SRC = {
		@input var input:{
			var uv:Vec2;
		};
		@param var intensity:Float;
		@param var glowColor:Vec3;
		@param var innerRadius:Float;
		@param var ringWidth:Float;
		@param var uvToWorldScale:Float;
		var output:{
			var color:Vec4;
		};
		function fragment():Void {
			var worldX = (input.uv.x - 0.5) * uvToWorldScale;
			var worldZ = (input.uv.y - 0.5) * uvToWorldScale;
			var radius = length(vec2(worldX, worldZ));
			var angle = atan(worldZ, worldX); // atan2(z, x) - same convention TowerModel.slotAt itself uses

			// RING_BOUNDARY_COUNT below (5 = TowerModel.RINGS_PER_LAYER + 1)
			// is hand-unrolled, not a real loop - hxsl's SRC block doesn't
			// support a dynamically-bounded one, and 5 is small/fixed enough
			// (tied to this project's own ring count, not expected to change
			// at runtime) that unrolling by hand is simpler than working
			// around that. Update this by hand if RINGS_PER_LAYER ever does.
			var reach = intensity * 5.0; // how many boundaries are lit, continuously - see class doc
			var boundary0 = clamp(reach - 0.0, 0.0, 1.0);
			var boundary1 = clamp(reach - 1.0, 0.0, 1.0);
			var boundary2 = clamp(reach - 2.0, 0.0, 1.0);
			var boundary3 = clamp(reach - 3.0, 0.0, 1.0);
			var boundary4 = clamp(reach - 4.0, 0.0, 1.0);

			// haloWidthSq (1.4 * 1.4) sets how far the glow bleeds past the
			// exact seam before fading to nothing - see class doc's "more
			// like a light" follow-up. Wider than the old hard 0.6 cutoff,
			// and a Gaussian rather than a clamped band, on purpose: a real
			// light's brightness never just stops dead at a fixed distance.
			var haloWidthSq = 1.96;

			var glow = 0.0;
			var seam0 = abs(radius - (innerRadius + 0.0 * ringWidth));
			glow += boundary0 * exp(-(seam0 * seam0) / haloWidthSq);
			var seam1 = abs(radius - (innerRadius + 1.0 * ringWidth));
			glow += boundary1 * exp(-(seam1 * seam1) / haloWidthSq);
			var seam2 = abs(radius - (innerRadius + 2.0 * ringWidth));
			glow += boundary2 * exp(-(seam2 * seam2) / haloWidthSq);
			var seam3 = abs(radius - (innerRadius + 3.0 * ringWidth));
			glow += boundary3 * exp(-(seam3 * seam3) / haloWidthSq);
			var seam4 = abs(radius - (innerRadius + 4.0 * ringWidth));
			glow += boundary4 * exp(-(seam4 * seam4) / haloWidthSq);

			// Ring 0's own tile-to-tile seams: tilesForRing(0) = 6, so each
			// tile spans 2*PI/6 = PI/3 radians; ringAngleOffset(0) = 0.
			if (radius > innerRadius && radius <= innerRadius + ringWidth) {
				var tileWidth0 = 1.0471975512; // PI / 3
				var frac0 = fract((angle - 0.0) / tileWidth0);
				var distFrac0 = min(frac0, 1.0 - frac0);
				var s0 = distFrac0 * tileWidth0 * radius;
				glow += boundary0 * exp(-(s0 * s0) / haloWidthSq);
			}
			// Ring 1: tilesForRing(1) = 12, tile width = 2*PI/12 = PI/6;
			// ringAngleOffset(1) = 3 slots * (2*PI/72) = PI/12.
			if (radius > innerRadius + ringWidth && radius <= innerRadius + 2.0 * ringWidth) {
				var tileWidth1 = 0.5235987756; // PI / 6
				var frac1 = fract((angle - 0.2617993878) / tileWidth1); // angle offset PI / 12
				var distFrac1 = min(frac1, 1.0 - frac1);
				var s1 = distFrac1 * tileWidth1 * radius;
				glow += boundary1 * exp(-(s1 * s1) / haloWidthSq);
			}
			// Ring 2: tilesForRing(2) = 18, tile width = 2*PI/18 = PI/9;
			// ringAngleOffset(2) = 6 slots * (2*PI/72) = PI/6.
			if (radius > innerRadius + 2.0 * ringWidth && radius <= innerRadius + 3.0 * ringWidth) {
				var tileWidth2 = 0.3490658504; // PI / 9
				var frac2 = fract((angle - 0.5235987756) / tileWidth2); // angle offset PI / 6
				var distFrac2 = min(frac2, 1.0 - frac2);
				var s2 = distFrac2 * tileWidth2 * radius;
				glow += boundary2 * exp(-(s2 * s2) / haloWidthSq);
			}
			// Ring 3: tilesForRing(3) = 24, tile width = 2*PI/24 = PI/12;
			// ringAngleOffset(3) = 9 slots * (2*PI/72) = PI/4.
			if (radius > innerRadius + 3.0 * ringWidth && radius <= innerRadius + 4.0 * ringWidth) {
				var tileWidth3 = 0.2617993878; // PI / 12
				var frac3 = fract((angle - 0.7853981634) / tileWidth3); // angle offset PI / 4
				var distFrac3 = min(frac3, 1.0 - frac3);
				var s3 = distFrac3 * tileWidth3 * radius;
				glow += boundary3 * exp(-(s3 * s3) / haloWidthSq);
			}

			glow = clamp(glow, 0.0, 1.0);
			output.color = vec4(output.color.rgb + glowColor * glow * 0.45,
				output.color.a); // 0.45 - GLOW_MAX_BRIGHTNESS, nudged up slightly from 0.4 since the wider halo reads dimmer at its own peak otherwise
		}
	}

	/**
		@param innerRadius the center disk's own radius (`TowerModel.CENTER_DISK_RADIUS`) — the first, innermost ring boundary.
		@param ringWidth each ring's own radial width (`TowerModel.ringWidth()`) — the spacing between successive boundaries.
		@param uvToWorldScale converts this mesh's own decal UV back to world units — twice `TowerModel.OUTER_RADIUS`, matching `TowerMesh.floorUv`'s own mapping.
		@param intensity glow strength/reach, `0` (nothing lit) to `1` (every ring boundary lit at full brightness) — set directly (a plain shader param) whenever the underlying fall counter changes.
		@param color the glow's own tint — plain white by default (see class doc for why gold overrides it).
	**/
	public function new(innerRadius:Float, ringWidth:Float, uvToWorldScale:Float, intensity:Float = 0, color:Int = 0xFFFFFFFF) {
		super();
		this.innerRadius = innerRadius;
		this.ringWidth = ringWidth;
		this.uvToWorldScale = uvToWorldScale;
		this.intensity = intensity;
		this.glowColor.setColor(color);
	}
}
