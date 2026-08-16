package biomes.ribbon;

import game.BoxBatch;
import game.MeshBuilder;

/**
	Builds the Ribbon's terrain: one flat slab for the whole diagram, a
	raised box on every live cell, and a pale monolith standing on the
	initial condition.

	Static geometry, built once per entry — unlike `biomes.sprawl.SprawlBiome`,
	which has to rebuild every frame because its world is transformed
	around a pinned camera. A flat space needs none of that.

	**Colour is doing exactly one job here, and it is not this one.**
	`docs/game/art-and-audio.md` reserves hue for
	curvature — κ = 0 means neutral bone, slate and ash, and nothing in a
	flat biome may reach for a hue to make itself noticed. So the live
	cells, the dead ground and the monolith are separated by **value**
	alone: three steps of the same grey. That constraint is why this biome
	looks like a museum rather than a diagram, which is the tone
	`docs/game/world.md` asks for.
**/
class RibbonMesh {
	/** Dead ground: ash, the darkest of the three values. **/
	static inline final GROUND_COLOR:Int = 0x2B2E33;

	/** Live cells: slate, one clear step up. **/
	static inline final LIVE_COLOR:Int = 0x767E88;

	/** The initial condition's own marker: bone, the brightest thing in the biome and the only one. **/
	static inline final MONOLITH_COLOR:Int = 0xE8E4DA;

	/** Tall enough to be visible from most of the strip's length, which is the whole purpose of putting it there. **/
	static inline final MONOLITH_HEIGHT:Float = 40;

	static inline final MONOLITH_HALF_WIDTH:Float = 1.6;

	/**
		Fraction of a cell each live slab actually fills.

		Without it, adjacent live cells merge into one unbroken expanse of
		slate and the diagram reads as a few large blobs rather than as
		cells — which defeats the point of standing on a *cellular*
		automaton. Leaving a gap lets the darker ground show through as a
		grid, so the structure stays legible at any distance.
		`biomes.sprawl.SprawlBiome` does the same thing to its own floor
		tiles for the same reason.
	**/
	static inline final CELL_INSET:Float = 0.82;

	/**
		Builds the whole biome's geometry under `parent`.
		@param automaton the history to lay out as terrain.
		@param parent the scene object to build under.
	**/
	public static function build(automaton:RibbonAutomaton, parent:h3d.scene.Object):Void {
		addGround(parent);
		addLiveCells(automaton, parent);
		addMonolith(parent);
	}

	/** The dead floor, as a single quad under everything — a live cell's own box sits on top of it rather than replacing it. **/
	/** The dead floor, as a single sloped quad under everything — a live cell's own box sits on top of it rather than replacing it. **/
	static function addGround(parent:h3d.scene.Object):Void {
		var points:Array<h3d.Vector> = [];
		var idx = new hxd.IndexBuffer();
		var half = RibbonModel.HALF_WIDTH;

		// One quad, not a strip per generation: the base is linear in z, so
		// a single sloped quad follows it exactly.
		var low = RibbonModel.baseHeightAt(RibbonModel.PAST_EDGE);
		var high = RibbonModel.baseHeightAt(RibbonModel.PRESENT_EDGE);
		MeshBuilder.addQuad(points, idx, new h3d.Vector(-half, low, RibbonModel.PAST_EDGE), new h3d.Vector(half, low, RibbonModel.PAST_EDGE),
			new h3d.Vector(half, high, RibbonModel.PRESENT_EDGE), new h3d.Vector(-half, high, RibbonModel.PRESENT_EDGE));

		var mesh = new h3d.scene.Mesh(new h3d.prim.Polygon(points, idx), parent);
		mesh.material.mainPass.addShader(new h3d.shader.FixedColor(GROUND_COLOR));
		mesh.material.mainPass.culling = None;
	}

	/**
		A raised box per live cell, through `game.BoxBatch` — which exists
		because of this biome, and now serves two.

		The full Rule 110 diagram is about 7,300 live cells, past what a
		16-bit index buffer can address in one mesh, and overflowing it
		fails **silently**: the terrain rendered as a bare plane,
		indistinguishable from geometry that had never been generated. See
		`BoxBatch`'s own doc, which carries the story.

		One box per cell rather than merging runs of adjacent live cells,
		which would genuinely cut the count — a run-merger can be subtly
		wrong in a way a per-cell loop cannot, and with the vertex ceiling
		gone there is nothing to buy with the risk.
	**/
	static function addLiveCells(automaton:RibbonAutomaton, parent:h3d.scene.Object):Void {
		var batch = new BoxBatch(parent, LIVE_COLOR);
		var half = RibbonModel.CELL_SIZE / 2 * CELL_INSET;

		for (g in 0...automaton.generations()) {
			for (i in 0...automaton.width) {
				if (!automaton.isLive(g, i)) {
					continue;
				}
				var z = RibbonModel.zOf(g);
				batch.add(RibbonModel.xOf(i), z, half, half, RibbonModel.baseHeightAt(z), RibbonModel.RELIEF);
			}
		}
		batch.flush();
	}

	/** The marker on generation `0`'s own live cell — where the history stops, and somebody started it. **/
	static function addMonolith(parent:h3d.scene.Object):Void {
		var batch = new BoxBatch(parent, MONOLITH_COLOR);
		var z = RibbonModel.zOf(0);
		batch.add(RibbonModel.xOf(RibbonModel.SEED_INDEX), z, MONOLITH_HALF_WIDTH, MONOLITH_HALF_WIDTH, RibbonModel.baseHeightAt(z), MONOLITH_HEIGHT);
		batch.flush();
	}
}
