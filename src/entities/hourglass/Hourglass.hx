package entities.hourglass;

import biomes.common.space.sphere.SphereMath;
import biomes.hub.HubStructure;
import biomes.hub.HubStructure.StructureBasis;
import game.MeshBuilder;
import graphics.Colours;
import graphics.shaders.UnlitTexture;

/**
	Which of the hourglass's own two signs (see `Hourglass.buildSigns`/`addSign`)
	`triggerSide` currently reads the player as standing in front of —
	`Plus` speeds the game up a step, `Minus` slows it down a step (see
	`HourglassModel.tick`'s own doc for the edge-triggered "walk up, walk
	away, walk up again" rule this feeds).
**/
enum TriggerSide {
	None;
	Plus;
	Minus;
}

/**
	The hub's own tiltable hourglass, standing on a pedestal — a third hub
	landmark alongside `biomes.hub.MazeShrine`/`biomes.hub.TowerReplica`, but
	not a portal: no painting, no `exitPainting`/`returnSpawn`, just a solid
	obstacle and a diegetic game-speed control (see `HourglassModel`'s own
	class doc for the actual mechanic).

	Lives under `entities` (not `biomes.hub`, despite only the hub actually
	placing one) since it's a self-contained decorative object, not
	hub-shape-generation code — the same reasoning `entities.painting.PaintingModel`
	already follows. It still leans on `biomes.hub.HubStructure`'s own local
	`(u, v)` frame (see that class's doc for why a fixed tangent-plane frame
	is a reasonable approximation at this size), the one piece of hub-specific
	machinery it can't avoid depending on. Most of what this class builds
	changes every tick — the tilt/sand directly, and now the two signs'
	own glow indirectly (see `buildSigns`'s own doc for why they rebuild too
	despite never tilting) — so `build` (the static pedestal, once) and
	`buildDynamic` (everything else — caps, glass, spiral, sand, signs —
	rebuilt fresh every tick from the current `HourglassModel`) are
	deliberately separate entry points rather than one `build` like a portal
	structure's — `biomes.hub.HubBiome` owns a dedicated container object it
	clears and repopulates with `buildDynamic` every tick; the pedestal
	itself is never touched again once built.

	Rebuilding the caps/glass/spiral/sand geometry from scratch every tick
	(rather than, say, `graphics.shaders.GrassWind`'s own shader-driven
	approach) is a deliberate choice for this one small object: its own
	triangle count is tiny, and reusing this project's existing "build
	geometry from world-space points computed off a local frame" style
	(`HubStructure.worldPoint`) — just fed a *tilted* frame each tick — reads
	far more consistently with the rest of the hub's own landmarks than
	inventing a bespoke rotate-around-an-arbitrary-axis vertex shader would,
	for a single small decorative object.
**/
class Hourglass {
	static inline final PEDESTAL_RADIUS:Float = 2.2;

	/** Pedestal height, above `basis.origin` — the tilt pivot itself sits `LEVITATION_HEIGHT` higher still, not right on top of it (see that constant's own doc). `4.5`, not the original `3.5`: reported directly as wanting "a bit higher," alongside `LEVITATION_HEIGHT`'s own bump — also gives `addSign` more pedestal face to mount the two signs on. **/
	static inline final PEDESTAL_HEIGHT:Float = 4.5;

	static inline final PEDESTAL_SEGMENTS:Int = 16;

	/**
		Shrinks every size below (never `PEDESTAL_RADIUS`/`PEDESTAL_HEIGHT` —
		the pedestal itself wasn't asked to change) by this factor, proportions
		untouched — reported directly as too big for the pedestal it stands
		on. Applied at each constant's own definition rather than baked into
		one recomputed number per constant, so the original, pre-shrink value
		each was tuned at stays visible right there for the next adjustment.
	**/
	static inline final SCALE:Float = 0.7;

	/** How high the neck sits above the pivot — also half the whole assembly's own total height (`0` to `BULB_HEIGHT * 2`, base to top cap). **/
	static inline final BULB_HEIGHT:Float = 4 * SCALE;

	/** Radius of the two wood caps (top and bottom) — also where `glassRadiusAt` tops out, a hair inside this so a thin rim of visible wood always shows around the glass's own edge (see the reference photo this was built against: the glass sits recessed *into* the wood, not flush with its outer rim). **/
	static inline final CAP_RADIUS:Float = 2.6 * SCALE;

	static inline final CAP_SEGMENTS:Int = 16;

	/** How far each wood cap extends beyond the glass's own rim plane (`0` and `BULB_HEIGHT * 2`) — outward, away from the glass, not into it, so thickening this never touches `buildGlass`/`buildSand`/`buildSpiral`'s own geometry at all. Reported directly as too thin/plate-like; a real hourglass' turned-wood base reads as a solid block, not a coin. **/
	static inline final CAP_THICKNESS:Float = 0.9 * SCALE;

	/** How far above the pedestal's own top the assembly's own base (local height `0`) rests at neutral tilt — a visible gap "as if a force field kept it up there," per the ask, rather than resting flush on the stone. Comfortably more than `CAP_THICKNESS` so the gap reads clearly under the (now thicker) bottom cap at any tilt this object ever reaches. `2.0`, not the original `1.4`: reported directly as wanting it raised "a bit higher" too, alongside `PEDESTAL_HEIGHT`'s own bump. **/
	static inline final LEVITATION_HEIGHT:Float = 2.0;

	/**
		How far up the pedestal's own face the two signs (`addSign`) sit —
		a fraction of `PEDESTAL_HEIGHT` rather than a fixed distance, so they
		stay proportionally placed if the pedestal's own height ever changes
		again. Comfortably clear of the ground (a player standing right at
		the pedestal shouldn't have to look sharply down) and of the top rim.
	**/
	static inline final SIGN_HEIGHT:Float = PEDESTAL_HEIGHT * 0.55;

	/** Each sign's own bar length, along whichever axis it runs. **/
	static inline final SIGN_BAR_LENGTH:Float = 1.5;

	static inline final SIGN_BAR_THICKNESS:Float = 0.35;

	/**
		How far proud of the pedestal's own true curved surface a sign's
		bars sit — just enough to clear z-fighting against the stone
		texture underneath, not to compensate for any chord-vs-arc gap:
		`addHorizontalBar` sweeps real points on that curve (`ringPoint`,
		same helper the pedestal's own geometry uses) rather than a flat
		approximation of it, so there's no sagitta left to clear. Reported
		directly as wanting the signs "in contact with [the pedestal], or
		so close it looks like it's in contact" — this is that, as close as
		floating-point geometry can get without literally sharing vertices
		with the stone mesh underneath.
	**/
	static inline final SIGN_INSET:Float = 0.02;

	/**
		How many facets `addHorizontalBar` sweeps its own bar across —
		"bend along the pedestal," per the ask, rather than the flat single
		chord the earlier version used. `10`, not the original `6` — a
		visibly faceted bend read as part of what made the `+` look
		"poorly adjusted," reported directly; more facets read as a smooth
		curve instead. The vertical bar of a `+` needs none of this: it
		runs along `up`, which a cylinder has no curvature in at all, so it
		stays flat quads (see `addVerticalBar`'s own doc).
	**/
	static inline final SIGN_ARC_SEGMENTS:Int = 10;

	/**
		How far beyond the pedestal's own collision boundary (`PEDESTAL_RADIUS
		+ COLLISION_CLEARANCE`) `triggerSide` still counts as "as close as
		collisions permit" — a player's own resting distance after being
		stopped by `blocksMovement` can land a little past the exact boundary
		depending on their last step size, not exactly on it.
	**/
	static inline final SIGN_TRIGGER_DISTANCE_MARGIN:Float = 1.0;

	/**
		How far off a sign's own exact bearing (straight out from the
		pedestal's center, through that sign) `triggerSide` still counts as
		"walked toward it" — per the ask, "straight ahead," but a generous
		enough cone that a player doesn't have to hit an exact compass
		heading to trigger a step.
	**/
	public static final SIGN_ANGLE_TOLERANCE:Float = Math.PI / 6;

	/**
		The floor `signIntensity` scales from — `1` stays the ceiling
		("real bright"), but the dim end no longer reaches all the way to
		`0`. Reported directly, after seeing the neutral-tilt screenshot:
		"I don't want the sign to disappear entirely either" — a genuinely
		invisible sign at the far end of the range isn't what "nearly
		imperceptible" was actually asking for, just close to it.
	**/
	public static inline final SIGN_MIN_INTENSITY:Float = 0.15;

	/** How far in from `CAP_RADIUS` the glass's own rim sits at each cap — see `CAP_RADIUS`'s own doc. **/
	static inline final GLASS_RIM_RADIUS:Float = 2.35 * SCALE;

	/** The glass's own radius at the neck (waist) — a real (if narrow) cylindrical opening, not a point, so the neck reads as an actual passage rather than the two bulbs meeting at a mathematical apex. **/
	static inline final GLASS_NECK_RADIUS:Float = 0.4 * SCALE;

	static inline final GLASS_SEGMENTS:Int = 20;

	/** Base opacity of the glass body — low enough that the sand/spiral read clearly through it, per "make the glass look more like glass" rather than a solid shell. **/
	static inline final GLASS_ALPHA:Float = 0.3;

	/** A brighter, thinner band right at each rim/neck circle — cheap stand-in for a specular glint given this project's flat unlit shading has no real lighting to produce one from (same discipline `entities.painting.PaintingModel.buildOutline` uses a traced keyline for, just brightness instead of a dark line). **/
	static inline final GLASS_HIGHLIGHT_ALPHA:Float = 0.55;

	static inline final GLASS_HIGHLIGHT_BAND:Float = 0.12 * SCALE;

	/** How many full turns the metal spiral winds from bottom cap to top cap — per "optionally reinforced with metal filaments spiraling around," close enough together to read as wound wire rather than a few bare loops. **/
	static inline final SPIRAL_TURNS:Float = 6;

	static inline final SPIRAL_SEGMENTS_PER_TURN:Int = 10;

	/** Cross-section width of the spiral's own ribbon. **/
	static inline final SPIRAL_THICKNESS:Float = 0.16 * SCALE;

	/** How far outside the glass's own surface (`glassRadiusAt`) the spiral sits — just enough clearance that the two don't z-fight. **/
	static inline final SPIRAL_GAP:Float = 0.14 * SCALE;

	/**
		How far from the neck the physically-upper bulb's own remaining-sand
		surface can sit when full — short of reaching that bulb's own outer
		cap (a full `BULB_HEIGHT` away) so it never pokes through it. Shared
		by whichever local region (top or bottom) is currently playing the
		"draining, hanging from the neck" role — see `buildSand`'s own doc
		for why that's not always the same one.
	**/
	static inline final SAND_HANGING_MAX_HEIGHT:Float = 3.2 * SCALE;

	static inline final SAND_HANGING_MAX_RADIUS:Float = 2.1 * SCALE;

	/** How far off its own bulb's outer cap the physically-lower mound's own base sits with nothing piled yet — a hair off `0` so a razor-thin mound still reads as sitting on the cap rather than through it. **/
	static inline final SAND_MOUND_BASE_OFFSET:Float = 0.4 * SCALE;

	/** How far past `SAND_MOUND_BASE_OFFSET` the mound's own peak can reach toward the neck when full — short of the neck (a full `BULB_HEIGHT` away) so it never pokes through it. **/
	static inline final SAND_MOUND_MAX_HEIGHT:Float = 3.2 * SCALE;

	static inline final SAND_MOUND_MAX_RADIUS:Float = 2.1 * SCALE;

	static inline final CONE_SEGMENTS:Int = 14;

	/** Below this fraction, a sand cone/mound isn't built at all — nothing left (or nothing yet) to draw, rather than a degenerate zero-size mesh. **/
	static inline final MIN_VISIBLE_FRACTION:Float = 0.01;

	/**
		How much the sand's own additive glow overlay (`addGlowOverlay`)
		brightens whatever's behind/around it — "the same kind" of soft
		white light-emission `graphics.shaders.TileRingGlow` gives the
		tower's floor seams, applied here as a plain additive second draw of
		the exact same geometry rather than that shader's own UV/ring-boundary
		math, which has no equivalent on a solid mesh like this one.
	**/
	static inline final SAND_GLOW_ALPHA:Float = 0.4;

	/** How many small "grains" mark the stream between the two bulbs while actively flowing. **/
	static inline final GRAIN_COUNT:Int = 6;

	/** Half-width of one grain's own octahedron — `0.08`, not the original `0.16`: reported directly as too big to read as dots even after `addGrain` stopped being flat crossed quads. **/
	static inline final GRAIN_SIZE:Float = 0.08 * SCALE;

	/** How many times the grain pattern cycles over a full drain — cosmetic pacing only, not tied to any real quantity. **/
	static inline final GRAIN_ANIM_SCALE:Float = 3;

	/** How far beyond `PEDESTAL_RADIUS` collision blocks the player — the pedestal is solid all the way through, same flat-boundary treatment as `biomes.hub.TowerReplica.OUTER_RADIUS`'s own collision. **/
	static inline final COLLISION_CLEARANCE:Float = 1.5;

	/**
		Builds the hourglass's own static pedestal under `parent`, anchored
		at `basis`. Never rebuilt again — unlike the caps/glass/spiral/sand
		above it (or the two signs mounted on the pedestal itself, see
		`buildSigns` — those rebuild every tick too, despite never tilting,
		since their own glow now depends on `model.tiltSteps`), the pedestal
		itself is genuinely static, appearance included.
		@param parent the scene object to attach the pedestal under.
		@param basis the hourglass's own local frame (see `HubStructure.anchorAt`).
	**/
	public static function build(parent:h3d.scene.Object, basis:StructureBasis):Void {
		var points:Array<h3d.Vector> = [];
		var idx = new hxd.IndexBuffer();
		var uvs:Array<h3d.prim.UV> = [];
		addFrustumBand(basis, PEDESTAL_RADIUS, 0, PEDESTAL_RADIUS, PEDESTAL_HEIGHT, PEDESTAL_SEGMENTS, points, idx, uvs);
		addCap(basis, PEDESTAL_RADIUS, PEDESTAL_HEIGHT, PEDESTAL_SEGMENTS, points, idx, uvs);

		var prim = new h3d.prim.Polygon(points, idx);
		prim.uvs = uvs;
		var texture = hxd.Res.textures.tower_stone_wall.toTexture();
		texture.wrap = Repeat;
		var mesh = new h3d.scene.Mesh(prim, parent);
		mesh.material.mainPass.addShader(new UnlitTexture(texture));
		mesh.material.mainPass.culling = None;
	}

	/**
		The `+`/`-` signs themselves — one relief plaque each, mounted flush
		against the pedestal's own curved face (never tilting — built
		against the untilted `basis`, not `tiltedBasis`'s output) at angle
		`0` (`+`, the direction that speeds the game up) and `Math.PI` (`-`,
		the direction that slows it down), matching `triggerSide`'s own
		angle convention exactly. Each sign gets its own mesh pair (not one
		shared, like `buildSand`'s single fill) since each one's own
		intensity (`signIntensity`) now differs from the other's, reading
		tilt back to the player: both start equal (the midpoint between
		`SIGN_MIN_INTENSITY` and `1`) at neutral tilt, then whichever side
		the hourglass is currently tilted toward reads brighter and the
		other dimmer, all the way to fully bright/close to (never quite at)
		`SIGN_MIN_INTENSITY` at max tilt, per the ask.
	**/
	static function buildSigns(container:h3d.scene.Object, basis:StructureBasis, model:HourglassModel):Void {
		buildSign(container, basis, 0, true, signIntensity(model, true));
		buildSign(container, basis, Math.PI, false, signIntensity(model, false));
	}

	/**
		One sign's own base fill plus glow overlay, at `intensity` — see
		`buildSigns`'s own doc for what drives that value.

		Both the fill *and* the glow scale with `intensity`, not just the
		glow: an always-opaque, always-bright fill (`Colours.HOURGLASS_SAND`,
		matching the sand it shares that color with) plus only the additive
		glow varying was tried first and looked identical at every tilt —
		additive white on top of a fill already that bright clips every
		color channel to full well before the glow's own alpha reaches
		anywhere near `1`, so anything past a low threshold was invisible.
		Alpha-blending the fill itself by `intensity` instead (`Colours.HOURGLASS_SAND`
		at `intensity` as its own alpha, `h3d.mat.BlendMode.Alpha`) gives a
		dim sign real headroom to actually read as dim — near `0`, it's
		mostly transparent, blending into the pedestal stone behind it
		("nearly imperceptible," per the ask) rather than a saturated block
		of color with the glow just turned off.
	**/
	static function buildSign(container:h3d.scene.Object, basis:StructureBasis, angle:Float, isPlus:Bool, intensity:Float):Void {
		var points:Array<h3d.Vector> = [];
		var idx = new hxd.IndexBuffer();
		addSign(basis, angle, isPlus, points, idx);

		var prim = new h3d.prim.Polygon(points, idx);
		var mesh = new h3d.scene.Mesh(prim, container);
		mesh.material.mainPass.addShader(new h3d.shader.FixedColor(Colours.HOURGLASS_SAND, intensity));
		mesh.material.mainPass.culling = None;
		mesh.material.mainPass.depthWrite = false;
		mesh.material.blendMode = h3d.mat.BlendMode.Alpha;

		addGlowOverlay(container, prim, Colours.HOURGLASS_SAND_GLOW, intensity * SAND_GLOW_ALPHA);
	}

	/**
		A sign's own intensity this tick, `SIGN_MIN_INTENSITY` to `1` — the
		midpoint of that range at neutral tilt, scaling all the way up to
		`1` as `model.tiltSteps` reaches `HourglassModel.MAX_TILT_STEPS`
		*toward* `isPlus`'s own side, or down to `SIGN_MIN_INTENSITY` at
		the same max reached the other way — "equal on both sides at
		first... [changing] up to being real bright on one side and nearly
		imperceptible on the other," per the ask, spanning the whole tilt
		range rather than saturating early, and never quite reaching fully
		invisible (see `SIGN_MIN_INTENSITY`'s own doc). `model.tiltSteps` is
		already signed toward `Plus` (positive) or `Minus` (negative) — see
		`HourglassModel.tiltSteps`'s own doc — so the `Plus` sign just reads
		that sign directly and `Minus` reads its negation; `t` (`tiltSteps`
		normalized to `[-1, 1]`) is guaranteed within that range already
		(`tick` itself clamps `tiltSteps`), so `hxd.Math.lerp`'s own output
		needs no further clamping to land in `[SIGN_MIN_INTENSITY, 1]`.
	**/
	public static function signIntensity(model:HourglassModel, isPlus:Bool):Float {
		var direction = isPlus ? 1 : -1;
		var t = model.tiltSteps / HourglassModel.MAX_TILT_STEPS;
		return hxd.Math.lerp(SIGN_MIN_INTENSITY, 1, (1 + direction * t) / 2);
	}

	/**
		One sign, at `angle` around the pedestal's own circle (`0` matches
		`triggerSide`'s own `Plus`, `Math.PI` its `Minus`) — a single
		horizontal bar for `-`, that same bar plus a vertical one crossing it
		for `+`.
	**/
	static function addSign(basis:StructureBasis, angle:Float, isPlus:Bool, points:Array<h3d.Vector>, idx:hxd.IndexBuffer):Void {
		addHorizontalBar(basis, angle, points, idx);
		if (isPlus) {
			addVerticalBar(basis, angle, points, idx);
		}
	}

	/**
		The sign's own horizontal bar, centered on `centerAngle` — swept
		across `SIGN_ARC_SEGMENTS` facets around the pedestal's own true
		curve (each vertex a real `ringPoint` at its own angle, radius
		`PEDESTAL_RADIUS + SIGN_INSET`) rather than one flat chord cut
		across it, per the ask, "bend along the pedestal." `SIGN_BAR_LENGTH`
		is a physical (arc) length, converted to the matching angular span
		via `/ PEDESTAL_RADIUS` (arc length = radius × angle) so the bar's
		own real-world size doesn't change with this — same reasoning
		`entities.painting.PaintingModel.buildArcQuad`'s own angular span
		conversion uses.
	**/
	static function addHorizontalBar(basis:StructureBasis, centerAngle:Float, points:Array<h3d.Vector>, idx:hxd.IndexBuffer):Void {
		var halfAngularSpan = (SIGN_BAR_LENGTH / 2) / PEDESTAL_RADIUS;
		var halfThickness = SIGN_BAR_THICKNESS / 2;
		var radius = PEDESTAL_RADIUS + SIGN_INSET;
		for (i in 0...SIGN_ARC_SEGMENTS) {
			var t0 = i / SIGN_ARC_SEGMENTS;
			var t1 = (i + 1) / SIGN_ARC_SEGMENTS;
			var angle0 = centerAngle - halfAngularSpan + t0 * 2 * halfAngularSpan;
			var angle1 = centerAngle - halfAngularSpan + t1 * 2 * halfAngularSpan;
			var bottomA = ringPoint(basis, radius, angle0, SIGN_HEIGHT - halfThickness);
			var bottomB = ringPoint(basis, radius, angle1, SIGN_HEIGHT - halfThickness);
			var topB = ringPoint(basis, radius, angle1, SIGN_HEIGHT + halfThickness);
			var topA = ringPoint(basis, radius, angle0, SIGN_HEIGHT + halfThickness);
			MeshBuilder.addQuad(points, idx, bottomA, bottomB, topB, topA);
		}
	}

	/**
		The `+`'s own vertical bar, crossing `addHorizontalBar`'s at
		`centerAngle` — two flat quads (above and below the horizontal bar,
		not one crossing straight through it) so the two bars' own alpha-blended
		fills never overlap. Overlapping them was tried first and looked
		"poorly adjusted," reported directly — two translucent quads stacked
		on the same patch of pedestal blend to a visibly denser, differently-shaded
		square right at the crossing, breaking the plus sign's own otherwise
		uniform look. Leaving a matching gap here (`SIGN_BAR_THICKNESS`
		wide, exactly the horizontal bar's own thickness) hands that whole
		center square to the horizontal bar alone instead.

		Each segment is a single flat quad, unlike `addHorizontalBar`: it
		runs along `up`, which a cylinder has zero curvature in at all, so
		every point along its own length sits exactly on the true surface
		already, no sweeping needed. Its own thickness spans a small
		angular range around `centerAngle` (`ringPoint` again, so it still
		sits on the true surface at each of its two edges) — small enough,
		at this object's own scale, that the sliver of curvature across
		that thickness alone is well under a millimeter-equivalent, not
		worth a second sweep.
	**/
	static function addVerticalBar(basis:StructureBasis, centerAngle:Float, points:Array<h3d.Vector>, idx:hxd.IndexBuffer):Void {
		var halfLength = SIGN_BAR_LENGTH / 2;
		var halfThickness = SIGN_BAR_THICKNESS / 2;
		var halfAngularThickness = halfThickness / PEDESTAL_RADIUS;
		var radius = PEDESTAL_RADIUS + SIGN_INSET;
		var angleA = centerAngle - halfAngularThickness;
		var angleB = centerAngle + halfAngularThickness;
		addVerticalBarSegment(basis, radius, angleA, angleB, SIGN_HEIGHT + halfThickness, SIGN_HEIGHT + halfLength, points, idx);
		addVerticalBarSegment(basis, radius, angleA, angleB, SIGN_HEIGHT - halfLength, SIGN_HEIGHT - halfThickness, points, idx);
	}

	/** One of `addVerticalBar`'s own two segments, spanning `heightA` to `heightB`. **/
	static function addVerticalBarSegment(basis:StructureBasis, radius:Float, angleA:Float, angleB:Float, heightA:Float, heightB:Float,
			points:Array<h3d.Vector>, idx:hxd.IndexBuffer):Void {
		var bottomA = ringPoint(basis, radius, angleA, heightA);
		var bottomB = ringPoint(basis, radius, angleB, heightA);
		var topB = ringPoint(basis, radius, angleB, heightB);
		var topA = ringPoint(basis, radius, angleA, heightB);
		MeshBuilder.addQuad(points, idx, bottomA, bottomB, topB, topA);
	}

	/**
		(Re)builds everything above the pedestal — wood caps, glass bulbs,
		metal spiral, and sand — under `container`, plus the two signs
		mounted on the (untilted) pedestal itself, since their own glow
		depends on `model.tiltSteps` too (see `buildSigns`'s own doc).
		Called once at initial build time and again every tick thereafter
		with the current `model`'s state, after the caller has cleared
		`container`'s previous children (see class doc). Opaque pieces
		(caps, spiral, sand, signs) build before the glass so its alpha
		blending composites over them rather than the other way around.
		@param container the (already-cleared) scene object to build into.
		@param basis the hourglass's own local frame, untilted — `tiltedBasis` derives the actual tilted one this builds against; the signs mount straight on this one, never tilted.
		@param model the current tilt/sand state to render.
	**/
	public static function buildDynamic(container:h3d.scene.Object, basis:StructureBasis, model:HourglassModel):Void {
		var tilted = tiltedBasis(basis, model);
		buildSigns(container, basis, model);
		buildCaps(container, tilted);
		buildSpiral(container, tilted);
		buildSand(container, tilted, model);
		buildGlass(container, tilted);
		buildGlassHighlights(container, tilted);
	}

	/**
		The frame's own local basis after rotating `basis` by `model.tiltAngle()`
		around its own `uAxis`, plus (while `model.flipped`) an extra 180°
		around that same axis — a flip is a full flip in place, not a
		different mechanic, so it reuses the exact same axis/plumbing the
		small stepped tilt already does, just a much bigger angle. `up`/`vAxis`
		rotate together so they stay perpendicular to each other and to
		`uAxis` at any angle.

		Around `uAxis`, not `vAxis` — reported directly as hard to actually
		see: the two signs sit along `uAxis` (`buildSigns`, angle `0`/`Math.PI`),
		so tilting around that same axis swings the assembly mostly *toward
		and away from* whoever's standing at either sign, foreshortened
		almost to nothing from their own vantage point. Tilting around
		`uAxis` instead swings it side to side (in the `vAxis`/`up` plane)
		as seen from either sign — squarely across the viewer's own line of
		sight rather than along it.

		Rotates around the assembly's own vertical *center* (`BULB_HEIGHT`
		above local height `0`, `LEVITATION_HEIGHT` above the pedestal — see
		those constants' own docs), not around that base point itself:
		reported directly that flipping around the base left the whole
		object visibly lower afterward than before, since a 180° turn around
		a point well below the object's own middle swings that middle out to
		the *opposite* side of the pivot instead of leaving it in place.
		Fixing a world-space `center` first and deriving `origin` from it
		(rather than the other way around) keeps that center exactly fixed
		at any `angle`, flipped or not — the small stepped tilt swings a
		little around the middle now too, instead of only around the base,
		which reads just as naturally for something already floating clear of
		the pedestal rather than pinned to it.
	**/
	static function tiltedBasis(basis:StructureBasis, model:HourglassModel):StructureBasis {
		var center = HubStructure.worldPoint(basis, 0, 0, PEDESTAL_HEIGHT + LEVITATION_HEIGHT + BULB_HEIGHT);
		var angle = model.tiltAngle() + (model.flipped ? Math.PI : 0);
		var tiltedUp = SphereMath.rotateAroundAxis(basis.up, basis.uAxis, angle);
		var tiltedV = SphereMath.rotateAroundAxis(basis.vAxis, basis.uAxis, angle);
		return {
			origin: center.sub(tiltedUp.scaled(BULB_HEIGHT)),
			up: tiltedUp,
			uAxis: basis.uAxis,
			vAxis: tiltedV
		};
	}

	/**
		The top and bottom wood blocks the glass sits recessed into — each a
		short solid cylinder (`CAP_THICKNESS` tall, not a bare disc) standing
		proud of the glass's own rim plane (`0` and `BULB_HEIGHT * 2`) rather
		than eating into it, so this never has to touch `buildGlass`/`buildSand`/
		`buildSpiral`'s own geometry. Flat `Colours.HOURGLASS_WOOD` fill, same
		placeholder discipline as `entities.painting.PaintingModel.buildFrame`'s
		own moulding.
	**/
	static function buildCaps(container:h3d.scene.Object, tilted:StructureBasis):Void {
		var points:Array<h3d.Vector> = [];
		var idx = new hxd.IndexBuffer();
		addCapBlock(tilted, -CAP_THICKNESS, 0, points, idx);
		addCapBlock(tilted, BULB_HEIGHT * 2, BULB_HEIGHT * 2 + CAP_THICKNESS, points, idx);

		var mesh = new h3d.scene.Mesh(new h3d.prim.Polygon(points, idx), container);
		mesh.material.mainPass.addShader(new h3d.shader.FixedColor(Colours.HOURGLASS_WOOD));
		mesh.material.mainPass.culling = None;
	}

	/** One wood cap's own solid block, from `heightA` to `heightB` — a cylindrical side wall (`addFrustumBand` with equal radii) capped flat top and bottom. **/
	static function addCapBlock(tilted:StructureBasis, heightA:Float, heightB:Float, points:Array<h3d.Vector>, idx:hxd.IndexBuffer):Void {
		addFrustumBand(tilted, CAP_RADIUS, heightA, CAP_RADIUS, heightB, CAP_SEGMENTS, points, idx);
		addCap(tilted, CAP_RADIUS, heightA, CAP_SEGMENTS, points, idx);
		addCap(tilted, CAP_RADIUS, heightB, CAP_SEGMENTS, points, idx);
	}

	/**
		The glass's own radius at `height` (`0` to `BULB_HEIGHT * 2`, bottom
		cap to top cap) — `GLASS_RIM_RADIUS` at either cap, narrowing linearly
		to `GLASS_NECK_RADIUS` at the neck (`BULB_HEIGHT`). Shared by
		`buildGlass` itself and `buildSpiral`, so the spiral's own wire
		actually hugs the bulb's real profile (pinching at the waist) rather
		than winding around a fixed cylinder.
		@param height how far up from the bottom cap, `0` to `BULB_HEIGHT * 2`.
		@return the glass's own radius at that height.
	**/
	static function glassRadiusAt(height:Float):Float {
		var t = hxd.Math.clamp(Math.abs(height - BULB_HEIGHT) / BULB_HEIGHT, 0, 1);
		return hxd.Math.lerp(GLASS_NECK_RADIUS, GLASS_RIM_RADIUS, t);
	}

	/** The two glass bulbs — a semi-transparent shell following `glassRadiusAt`'s own profile, alpha-blended so the sand/spiral behind it stay visible. **/
	static function buildGlass(container:h3d.scene.Object, tilted:StructureBasis):Void {
		var points:Array<h3d.Vector> = [];
		var idx = new hxd.IndexBuffer();
		addFrustumBand(tilted, GLASS_RIM_RADIUS, 0, GLASS_NECK_RADIUS, BULB_HEIGHT, GLASS_SEGMENTS, points, idx);
		addFrustumBand(tilted, GLASS_NECK_RADIUS, BULB_HEIGHT, GLASS_RIM_RADIUS, BULB_HEIGHT * 2, GLASS_SEGMENTS, points, idx);

		var mesh = new h3d.scene.Mesh(new h3d.prim.Polygon(points, idx), container);
		mesh.material.mainPass.addShader(new h3d.shader.FixedColor(Colours.HOURGLASS_GLASS, GLASS_ALPHA));
		mesh.material.mainPass.culling = None;
		mesh.material.mainPass.depthWrite = false;
		mesh.material.blendMode = h3d.mat.BlendMode.Alpha;
	}

	/** Three thin, brighter bands (the two rims plus the neck) standing in for a specular glint — see `GLASS_HIGHLIGHT_ALPHA`'s own doc for why brightness rather than real reflection. **/
	static function buildGlassHighlights(container:h3d.scene.Object, tilted:StructureBasis):Void {
		var points:Array<h3d.Vector> = [];
		var idx = new hxd.IndexBuffer();
		addFrustumBand(tilted, GLASS_RIM_RADIUS, 0, GLASS_RIM_RADIUS, GLASS_HIGHLIGHT_BAND, GLASS_SEGMENTS, points, idx);
		addFrustumBand(tilted, GLASS_RIM_RADIUS, BULB_HEIGHT * 2 - GLASS_HIGHLIGHT_BAND, GLASS_RIM_RADIUS, BULB_HEIGHT * 2, GLASS_SEGMENTS, points, idx);
		addFrustumBand(tilted, GLASS_NECK_RADIUS, BULB_HEIGHT - GLASS_HIGHLIGHT_BAND / 2, GLASS_NECK_RADIUS, BULB_HEIGHT + GLASS_HIGHLIGHT_BAND / 2,
			GLASS_SEGMENTS, points, idx);

		var mesh = new h3d.scene.Mesh(new h3d.prim.Polygon(points, idx), container);
		mesh.material.mainPass.addShader(new h3d.shader.FixedColor(Colours.HOURGLASS_GLASS_HIGHLIGHT, GLASS_HIGHLIGHT_ALPHA));
		mesh.material.mainPass.culling = None;
		mesh.material.mainPass.depthWrite = false;
		mesh.material.blendMode = h3d.mat.BlendMode.Alpha;
	}

	/**
		The metal reinforcement: a single ribbon winding `SPIRAL_TURNS` times
		from the bottom cap to the top, hugging `glassRadiusAt`'s own profile
		plus `SPIRAL_GAP` — per "optionally reinforced with metal filaments
		spiraling around," standing in for the corner posts a plainer frame
		would use.
	**/
	static function buildSpiral(container:h3d.scene.Object, tilted:StructureBasis):Void {
		var points:Array<h3d.Vector> = [];
		var idx = new hxd.IndexBuffer();
		var totalHeight = BULB_HEIGHT * 2;
		var segments = Math.round(SPIRAL_TURNS * SPIRAL_SEGMENTS_PER_TURN);
		for (i in 0...segments) {
			var t0 = i / segments;
			var t1 = (i + 1) / segments;
			addSpiralSegment(tilted, t0, t1, totalHeight, points, idx);
		}

		var mesh = new h3d.scene.Mesh(new h3d.prim.Polygon(points, idx), container);
		mesh.material.mainPass.addShader(new h3d.shader.FixedColor(Colours.HOURGLASS_METAL));
		mesh.material.mainPass.culling = None;
	}

	/** One short ribbon segment of the spiral, from fractional position `t0` to `t1` along its own full winding path. **/
	static function addSpiralSegment(tilted:StructureBasis, t0:Float, t1:Float, totalHeight:Float, points:Array<h3d.Vector>, idx:hxd.IndexBuffer):Void {
		var height0 = t0 * totalHeight;
		var height1 = t1 * totalHeight;
		var angle0 = t0 * SPIRAL_TURNS * 2 * Math.PI;
		var angle1 = t1 * SPIRAL_TURNS * 2 * Math.PI;
		var radius0 = glassRadiusAt(height0) + SPIRAL_GAP;
		var radius1 = glassRadiusAt(height1) + SPIRAL_GAP;

		var innerA = ringPoint(tilted, radius0 - SPIRAL_THICKNESS / 2, angle0, height0);
		var innerB = ringPoint(tilted, radius1 - SPIRAL_THICKNESS / 2, angle1, height1);
		var outerB = ringPoint(tilted, radius1 + SPIRAL_THICKNESS / 2, angle1, height1);
		var outerA = ringPoint(tilted, radius0 + SPIRAL_THICKNESS / 2, angle0, height0);
		MeshBuilder.addQuad(points, idx, innerA, innerB, outerB, outerA);
	}

	/**
		The sand itself: a pile hanging from the neck in whichever bulb is
		currently physically upper (its own surface dropping as `model.sandPhase`
		drains it), a mound resting on its own cap in whichever bulb is
		currently physically lower (growing as sand piles into it), and a
		handful of small "grains" marking the stream between them while
		actively flowing — all one flat fill (`Colours.HOURGLASS_SAND`, or
		`_SAND_GOLD` once `model.unlocked` — see class doc's own hidden
		mechanic), one mesh, plus a second additive `addGlowOverlay` pass
		over the same geometry.

		*Physically* upper/lower, not *locally* top/bottom: `tiltedBasis`
		only rotates the frame this is drawn in, so which local region
		(`0` to `BULB_HEIGHT`, or `BULB_HEIGHT` to `BULB_HEIGHT * 2`) is
		physically upper flips right along with `model.flipped` — it's the
		local-top region normally, but the local-bottom one every other
		cycle. Reported directly as the filling side visibly growing *down*
		from the neck instead of mounding *up* from its own floor once
		flipped — exactly what happens if the hanging-pile/mound shapes stay
		pinned to local top/bottom instead of swapping with whichever one is
		genuinely upper this cycle. `localTopIsUpper` below picks which
		local region gets which shape/fraction each tick instead.
	**/
	static function buildSand(container:h3d.scene.Object, tilted:StructureBasis, model:HourglassModel):Void {
		var points:Array<h3d.Vector> = [];
		var idx = new hxd.IndexBuffer();

		var neckHeight = BULB_HEIGHT;
		var topFraction = 1 - model.sandPhase;
		var bottomFraction = model.sandPhase;

		var localTopIsUpper = !model.flipped;
		var upperFraction = localTopIsUpper ? topFraction : bottomFraction;
		var lowerFraction = localTopIsUpper ? bottomFraction : topFraction;
		var upperDirection = localTopIsUpper ? 1 : -1;
		var lowerCapHeight = localTopIsUpper ? 0.0 : BULB_HEIGHT * 2;
		var lowerDirection = localTopIsUpper ? 1 : -1;

		var fillApexHeight = lowerCapHeight + lowerDirection * SAND_MOUND_BASE_OFFSET;
		if (upperFraction > MIN_VISIBLE_FRACTION) {
			addHangingPile(tilted, neckHeight, upperDirection, upperFraction, points, idx);
		}
		if (lowerFraction > MIN_VISIBLE_FRACTION) {
			fillApexHeight = addMound(tilted, lowerCapHeight, lowerDirection, lowerFraction, points, idx);
		}

		if (model.sandPhase > MIN_VISIBLE_FRACTION && model.sandPhase < 1 - MIN_VISIBLE_FRACTION) {
			addStreamGrains(tilted, neckHeight, fillApexHeight, model.sandPhase, points, idx);
		}

		var sandColor = model.unlocked ? Colours.HOURGLASS_SAND_GOLD : Colours.HOURGLASS_SAND;
		var glowColor = model.unlocked ? Colours.HOURGLASS_SAND_GOLD_GLOW : Colours.HOURGLASS_SAND_GLOW;

		var prim = new h3d.prim.Polygon(points, idx);
		var mesh = new h3d.scene.Mesh(prim, container);
		mesh.material.mainPass.addShader(new h3d.shader.FixedColor(sandColor));
		mesh.material.mainPass.culling = None;

		addGlowOverlay(container, prim, glowColor, SAND_GLOW_ALPHA);
	}

	/**
		The physically-upper bulb's own remaining sand: an open point fixed
		at the neck (where it drains out) widening `direction` away from it
		to a flat surface — `fraction` `1` = full (surface as far from the
		neck as `SAND_HANGING_MAX_HEIGHT`/`_MAX_RADIUS` allow), `0` = empty
		(surface collapsed onto the neck itself). `direction` is `+1` for
		the local-top region (surface moves toward `BULB_HEIGHT * 2`) or
		`-1` for local-bottom (toward `0`) — whichever one `buildSand` has
		determined is currently physically upper.
	**/
	static function addHangingPile(tilted:StructureBasis, neckHeight:Float, direction:Int, fraction:Float, points:Array<h3d.Vector>, idx:hxd.IndexBuffer):Void {
		var surfaceHeight = neckHeight + direction * fraction * SAND_HANGING_MAX_HEIGHT;
		var surfaceRadius = fraction * SAND_HANGING_MAX_RADIUS;
		addFrustumBand(tilted, 0, neckHeight, surfaceRadius, surfaceHeight, CONE_SEGMENTS, points, idx);
		addCap(tilted, surfaceRadius, surfaceHeight, CONE_SEGMENTS, points, idx);
	}

	/**
		The physically-lower bulb's own mound: a flat base fixed `direction`
		off `capHeight` (that bulb's own outer cap — its floor), narrowing to
		an apex that reaches further `direction`, toward the neck, as
		`fraction` grows — `0` = a bare film right on the floor, `1` = a full
		peak reaching almost to the neck. `direction`/`capHeight` mirror
		`addHangingPile`'s own — whichever local region `buildSand` has
		determined is currently physically lower.
		@return the apex height reached, for `addStreamGrains` to aim its own grains at.
	**/
	static function addMound(tilted:StructureBasis, capHeight:Float, direction:Int, fraction:Float, points:Array<h3d.Vector>, idx:hxd.IndexBuffer):Float {
		var baseHeight = capHeight + direction * SAND_MOUND_BASE_OFFSET;
		var apexHeight = baseHeight + direction * fraction * SAND_MOUND_MAX_HEIGHT;
		addFrustumBand(tilted, SAND_MOUND_MAX_RADIUS, baseHeight, 0, apexHeight, CONE_SEGMENTS, points, idx);
		addCap(tilted, SAND_MOUND_MAX_RADIUS, baseHeight, CONE_SEGMENTS, points, idx);
		return apexHeight;
	}

	/**
		A second draw of `prim` — the exact same triangles `buildSand`/`buildSigns`
		just built, no rebuild needed — additive-blended (`h3d.mat.BlendMode.Add`)
		at `color`, so that geometry reads as emitting soft light rather than
		just sitting there flat-colored. Per the ask, "the same kind" of glow
		`graphics.shaders.TileRingGlow` gives the tower floor's seams; that
		shader's own math is all UV/ring-boundary geometry specific to a
		textured floor decal, nothing a solid mesh like this one has an
		equivalent of, so this reaches for the same *visual* result (soft
		additive light) via a plain double-draw instead of porting that
		shader's own geometry-specific code. Not used by `buildGlass`/
		`buildGlassHighlights` — those stay `Alpha`-blended, since glass
		tints what's behind it rather than emitting its own light.
	**/
	static function addGlowOverlay(container:h3d.scene.Object, prim:h3d.prim.Polygon, color:Int, alpha:Float):Void {
		var mesh = new h3d.scene.Mesh(prim, container);
		mesh.material.mainPass.addShader(new h3d.shader.FixedColor(color, alpha));
		mesh.material.mainPass.culling = None;
		mesh.material.mainPass.depthWrite = false;
		mesh.material.blendMode = h3d.mat.BlendMode.Add;
	}

	/**
		`GRAIN_COUNT` small dot "grains" between the neck and the physically-
		lower mound's own current peak (`fillApexHeight`), cycling along that
		span as `sandPhase` advances — and, since nothing here is
		one-directional, cycling the other way for free whenever `sandPhase`
		itself decreases instead (mid-drain after a flip, see
		`HourglassModel.tick`'s own doc), with no separate flag or
		special-cased code path needed for either. Works unmodified regardless
		of which local region `fillApexHeight` actually came from this tick
		(see `buildSand`'s own doc) — `hxd.Math.lerp` doesn't care which end
		is numerically bigger.
	**/
	static function addStreamGrains(tilted:StructureBasis, neckHeight:Float, fillApexHeight:Float, sandPhase:Float, points:Array<h3d.Vector>,
			idx:hxd.IndexBuffer):Void {
		for (i in 0...GRAIN_COUNT) {
			var baseT = i / GRAIN_COUNT;
			var t = baseT + sandPhase * GRAIN_ANIM_SCALE;
			t -= Math.floor(t);
			var height = hxd.Math.lerp(neckHeight, fillApexHeight, t);
			addGrain(tilted, height, points, idx);
		}
	}

	/**
		One stream grain: a tiny octahedron (6 points, 8 faces) centered on
		`tilted`'s own axis at `height` — not the earlier two crossed flat
		quads, reported directly as reading like small jagged blades rather
		than dots. A real (if faceted) small solid reads as a dot from any
		angle by construction, the actual goal that "reads from more than one
		viewing angle" doc line was reaching for with a cheaper flat trick.
	**/
	static function addGrain(tilted:StructureBasis, height:Float, points:Array<h3d.Vector>, idx:hxd.IndexBuffer):Void {
		var top = HubStructure.worldPoint(tilted, 0, 0, height + GRAIN_SIZE);
		var bottom = HubStructure.worldPoint(tilted, 0, 0, height - GRAIN_SIZE);
		var posU = HubStructure.worldPoint(tilted, GRAIN_SIZE, 0, height);
		var negU = HubStructure.worldPoint(tilted, -GRAIN_SIZE, 0, height);
		var posV = HubStructure.worldPoint(tilted, 0, GRAIN_SIZE, height);
		var negV = HubStructure.worldPoint(tilted, 0, -GRAIN_SIZE, height);

		MeshBuilder.addTriangle(points, idx, top, posU, posV);
		MeshBuilder.addTriangle(points, idx, top, posV, negU);
		MeshBuilder.addTriangle(points, idx, top, negU, negV);
		MeshBuilder.addTriangle(points, idx, top, negV, posU);
		MeshBuilder.addTriangle(points, idx, bottom, posV, posU);
		MeshBuilder.addTriangle(points, idx, bottom, negU, posV);
		MeshBuilder.addTriangle(points, idx, bottom, negV, negU);
		MeshBuilder.addTriangle(points, idx, bottom, posU, negV);
	}

	/** A world point on `basis`'s own circle at `radius`/`angle`, raised `height` above its own ground level (or pivot, for a tilted basis). **/
	static function ringPoint(basis:StructureBasis, radius:Float, angle:Float, height:Float):h3d.Vector {
		return HubStructure.worldPoint(basis, radius * Math.cos(angle), radius * Math.sin(angle), height);
	}

	/**
		A ring/frustum band between two (radius, height) circles — a
		cylinder wall (`radiusA == radiusB`), or a cone (`radiusA == 0` or
		`radiusB == 0`), all the same shape. `uvs`, when non-null, gets a
		plain tiled mapping (for the pedestal's own textured wall); left
		null for the flat-shaded glass/sand, which doesn't need one.
	**/
	static function addFrustumBand(basis:StructureBasis, radiusA:Float, heightA:Float, radiusB:Float, heightB:Float, segments:Int, points:Array<h3d.Vector>,
			idx:hxd.IndexBuffer, ?uvs:Array<h3d.prim.UV>):Void {
		for (i in 0...segments) {
			var angleA = i * (2 * Math.PI / segments);
			var angleB = (i + 1) * (2 * Math.PI / segments);
			var a = ringPoint(basis, radiusA, angleA, heightA);
			var b = ringPoint(basis, radiusA, angleB, heightA);
			var c = ringPoint(basis, radiusB, angleB, heightB);
			var d = ringPoint(basis, radiusB, angleA, heightB);
			MeshBuilder.addQuad(points, idx, a, b, c, d);

			if (uvs != null) {
				var uRepeat = a.sub(b).length() / MeshBuilder.WALL_TEXTURE_TILE_SIZE;
				var vRepeat = a.sub(d).length() / MeshBuilder.WALL_TEXTURE_TILE_SIZE;
				uvs.push(new h3d.prim.UV(0, vRepeat));
				uvs.push(new h3d.prim.UV(uRepeat, vRepeat));
				uvs.push(new h3d.prim.UV(uRepeat, 0));
				uvs.push(new h3d.prim.UV(0, 0));
			}
		}
	}

	/** A flat disc cap at `height`/`radius` — a triangle fan from `basis`'s own center, sealing a cylinder/cone so it doesn't read as hollow. Textured (radial UV) only when `uvs` is non-null. **/
	static function addCap(basis:StructureBasis, radius:Float, height:Float, segments:Int, points:Array<h3d.Vector>, idx:hxd.IndexBuffer,
			?uvs:Array<h3d.prim.UV>):Void {
		var center = HubStructure.worldPoint(basis, 0, 0, height);
		for (i in 0...segments) {
			var angleA = i * (2 * Math.PI / segments);
			var angleB = (i + 1) * (2 * Math.PI / segments);
			var a = ringPoint(basis, radius, angleA, height);
			var b = ringPoint(basis, radius, angleB, height);
			MeshBuilder.addTriangle(points, idx, center, a, b);

			if (uvs != null) {
				uvs.push(new h3d.prim.UV(0.5, 0.5));
				uvs.push(new h3d.prim.UV(0.5 + Math.cos(angleA) * 0.5, 0.5 + Math.sin(angleA) * 0.5));
				uvs.push(new h3d.prim.UV(0.5 + Math.cos(angleB) * 0.5, 0.5 + Math.sin(angleB) * 0.5));
			}
		}
	}

	/**
		How far a world point's own `HubStructure.localUV`-reported `height`
		can be from this structure's local ground before a query treats it as
		nowhere near the hourglass at all, regardless of what its `(u, v)`
		happens to read — see `localUV`'s own class doc for the
		antipodal-collapse bug this guards against, and
		`biomes.hub.MazeShrine.HEIGHT_SANITY_BOUND`'s own doc for why this
		needs no more precision than "obviously one, not the other."
	**/
	static inline final HEIGHT_SANITY_BOUND:Float = 30;

	/**
		Whether `worldPos` is too close to the pedestal to be walked into —
		a single circular boundary against the untitled `basis` (the
		pedestal itself never tilts, only everything above it does).
		@param basis the hourglass's own local frame.
		@param worldPos the position to check — typically the player's own tentative new position.
		@return true if `worldPos` is blocked by the pedestal.
	**/
	public static function blocksMovement(basis:StructureBasis, worldPos:h3d.Vector):Bool {
		var local = HubStructure.localUV(basis, worldPos);
		if (Math.abs(local.height) > HEIGHT_SANITY_BOUND) {
			return false; // nowhere near the hourglass at all - see HEIGHT_SANITY_BOUND's own doc for why (u, v) alone can't tell
		}
		return Math.sqrt(local.u * local.u + local.v * local.v) < PEDESTAL_RADIUS + COLLISION_CLEARANCE;
	}

	/**
		Which sign (if any) `playerPos` currently stands close enough to the
		pedestal, and lined up closely enough with, to trigger — "as close as
		collisions permit" (within `PEDESTAL_RADIUS + COLLISION_CLEARANCE +
		SIGN_TRIGGER_DISTANCE_MARGIN` of the pedestal's own center) and
		within `SIGN_ANGLE_TOLERANCE` of that sign's own exact bearing
		(`0` for `Plus`, `Math.PI` for `Minus` — `basis`'s own fixed `uAxis`/
		`vAxis`, not the player's own momentary facing, same fixed-frame
		convention every other hub structure query already uses). Fed
		straight into `HourglassModel.tick`, which does its own
		edge-detection against this — see that method's own doc for why a
		plain, stateless "which side is the player at right now" query
		(this one) is exactly what that edge-detection needs to work
		against.
		@param basis the hourglass's own local frame.
		@param playerPos the position to check — typically the player's own current position.
		@return the sign the player is currently positioned to trigger, or `None`.
	**/
	public static function triggerSide(basis:StructureBasis, playerPos:h3d.Vector):TriggerSide {
		var local = HubStructure.localUV(basis, playerPos);
		if (Math.abs(local.height) > HEIGHT_SANITY_BOUND) {
			return None; // nowhere near the hourglass at all - see HEIGHT_SANITY_BOUND's own doc for why (u, v) alone can't tell
		}
		var distance = Math.sqrt(local.u * local.u + local.v * local.v);
		if (distance > PEDESTAL_RADIUS + COLLISION_CLEARANCE + SIGN_TRIGGER_DISTANCE_MARGIN) {
			return None;
		}
		var angle = Math.atan2(local.v, local.u);
		if (Math.abs(angle) <= SIGN_ANGLE_TOLERANCE) {
			return Plus;
		}
		if (Math.abs(angle) >= Math.PI - SIGN_ANGLE_TOLERANCE) {
			return Minus;
		}
		return None;
	}
}
