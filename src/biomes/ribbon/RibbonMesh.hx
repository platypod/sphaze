package biomes.ribbon;

import game.MeshBuilder;

/**
	Builds the Ribbon's terrain: one flat slab for the whole diagram, a
	raised box on every live cell, and a pale monolith standing on the
	initial condition.

	Static geometry, built once per entry — unlike `biomes.sprawl.SprawlBiome`,
	which has to rebuild every frame because its world is transformed
	around a pinned camera. A flat space needs none of that.

	**Colour is doing exactly one job here, and it is not this one.**
	`docs/game-design/direction/art-and-audio.md` reserves hue for
	curvature — κ = 0 means neutral bone, slate and ash, and nothing in a
	flat biome may reach for a hue to make itself noticed. So the live
	cells, the dead ground and the monolith are separated by **value**
	alone: three steps of the same grey. That constraint is why this biome
	looks like a museum rather than a diagram, which is the tone
	`docs/game-design/direction/world-and-threads.md` asks for.
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

	/** Four sides and a cap, four vertices each — see `addBox`. **/
	static inline final VERTICES_PER_BOX:Int = 20;

	/**
		The most vertices one `h3d.prim.Polygon` may hold here: `65535`,
		the largest index a 16-bit index buffer can address, rounded down
		to a whole number of boxes. Exceeding it fails **silently** — see
		`addLiveCells`, where that cost a debugging session.
	**/
	static inline final MAX_VERTICES_PER_MESH:Int = 65520;

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
		addMesh(parent, points, idx, GROUND_COLOR);
	}

	/**
		A raised box per live cell, split across as many meshes as it takes
		to stay under `MAX_VERTICES_PER_MESH`.

		**The splitting is not an optimisation, it is the fix for a bug
		this biome hit on its first run.** The full Rule 110 diagram is
		about 7,300 live cells, which at twenty vertices each is roughly
		146,000 — well past the 65,535 a 16-bit index buffer can address.
		Heaps raised no error and WebGL reported nothing: the indices
		simply wrapped, and the terrain rendered as a flat, empty plane
		with no live cell anywhere on it. It looked exactly like geometry
		that had never been generated.

		Worth knowing beyond this file, because nothing in the codebase
		guards against it: `biomes.sprawl.SprawlBiome` builds far more
		geometry than this and stays clear only because it culls to a draw
		distance first. Any static mesh over a few thousand boxes needs
		this treatment.

		One box per cell rather than merging runs of adjacent live cells,
		which would genuinely cut the count — a run-merger can be subtly
		wrong in a way a per-cell loop cannot, and now that splitting has
		removed the ceiling there is nothing to buy with the risk.
	**/
	static function addLiveCells(automaton:RibbonAutomaton, parent:h3d.scene.Object):Void {
		var points:Array<h3d.Vector> = [];
		var idx = new hxd.IndexBuffer();
		var half = RibbonModel.CELL_SIZE / 2 * CELL_INSET;

		for (g in 0...automaton.generations()) {
			for (i in 0...automaton.width) {
				if (!automaton.isLive(g, i)) {
					continue;
				}
				if (points.length + VERTICES_PER_BOX > MAX_VERTICES_PER_MESH) {
					addMesh(parent, points, idx, LIVE_COLOR);
					points = [];
					idx = new hxd.IndexBuffer();
				}
				var z = RibbonModel.zOf(g);
				addBox(points, idx, RibbonModel.xOf(i), z, half, half, RibbonModel.baseHeightAt(z), RibbonModel.RELIEF);
			}
		}
		addMesh(parent, points, idx, LIVE_COLOR);
	}

	/** The marker on generation `0`'s own live cell — where the history stops, and somebody started it. **/
	static function addMonolith(parent:h3d.scene.Object):Void {
		var points:Array<h3d.Vector> = [];
		var idx = new hxd.IndexBuffer();

		var z = RibbonModel.zOf(0);
		addBox(points, idx, RibbonModel.xOf(RibbonModel.SEED_INDEX), z, MONOLITH_HALF_WIDTH, MONOLITH_HALF_WIDTH, RibbonModel.baseHeightAt(z), MONOLITH_HEIGHT);
		addMesh(parent, points, idx, MONOLITH_COLOR);
	}

	/**
		An axis-aligned box standing on the tilted base: four sides and a
		cap, no underside (nothing ever sees it).

		The box is *not* tilted with the base — its own faces stay
		axis-aligned and it simply starts at `baseY`. A cell of the diagram
		is a discrete thing sitting on the ground, not a shear of it, and
		keeping the boxes upright is what stops the slope reading as a
		rendering error.
	**/
	static function addBox(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, x:Float, z:Float, halfX:Float, halfZ:Float, baseY:Float, height:Float):Void {
		var x0 = x - halfX;
		var x1 = x + halfX;
		var z0 = z - halfZ;
		var z1 = z + halfZ;

		var corners = [
			new h3d.Vector(x0, baseY, z0),
			new h3d.Vector(x1, baseY, z0),
			new h3d.Vector(x1, baseY, z1),
			new h3d.Vector(x0, baseY, z1)
		];
		var tops = [for (c in corners) new h3d.Vector(c.x, baseY + height, c.z)];

		for (k in 0...4) {
			var next = (k + 1) % 4;
			MeshBuilder.addQuad(points, idx, corners[k], corners[next], tops[next], tops[k]);
		}
		MeshBuilder.addQuad(points, idx, tops[0], tops[1], tops[2], tops[3]);
	}

	static function addMesh(parent:h3d.scene.Object, points:Array<h3d.Vector>, idx:hxd.IndexBuffer, color:Int):Void {
		if (points.length == 0) {
			return; // Polygon rejects an empty vertex list
		}
		var mesh = new h3d.scene.Mesh(new h3d.prim.Polygon(points, idx), parent);
		mesh.material.mainPass.addShader(new h3d.shader.FixedColor(color));
		mesh.material.mainPass.culling = None;
	}
}
