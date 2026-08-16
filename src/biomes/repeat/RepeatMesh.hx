package biomes.repeat;

import game.BoxBatch;
import game.MeshBuilder;

/**
	The cell city: flat ground, blocky buildings, and a pale marker
	standing wherever a tile diverges from the reference.

	**The visual dialect is doing mechanical work, not decorating.**
	`docs/game-design/direction/art-and-audio.md` assigns this space
	Manifold Garden's register — blocky, low-poly, almost no texture,
	silhouette carrying everything — and argues it from the mechanic
	rather than from taste: spot-the-difference needs hard edges and
	repeated units, because a city gives divergence somewhere obvious to
	hide in a way organic terrain never does. A missing block in a
	skyline is a shape you can *remember*; a missing rock on a hillside
	is not.

	Colour is value only. κ = 0 is bone, slate and ash, and hue belongs to
	curvature alone — so buildings, ground and marker are separated by
	lightness, exactly as in `biomes.ribbon.RibbonMesh`.
**/
class RepeatMesh {
	static inline final GROUND_COLOR:Int = 0x2E3238;
	static inline final BUILDING_COLOR:Int = 0x8A929C;

	/** The marker standing in a diverged plot — the brightest thing in the biome, and the only one. **/
	static inline final FRAGMENT_COLOR:Int = 0xEFEAE0;

	static inline final FRAGMENT_HEIGHT:Float = 16;
	static inline final FRAGMENT_HALF_WIDTH:Float = 2.2;

	/**
		Builds every tile within `radius` tiles of the one the player is
		standing in.
		@param parent the scene object to build under.
		@param centre the tile at the centre of the built region.
		@param radius how many tiles out to build, each way.
		@param collected which tiles have had their fragment taken, keyed by `RepeatBiome.tileKey`.
	**/
	public static function build(parent:h3d.scene.Object, centre:{i:Int, j:Int}, radius:Int, collected:Map<String, Bool>):Void {
		addGround(parent, centre, radius);

		var buildings = new BoxBatch(parent, BUILDING_COLOR);
		var fragments = new BoxBatch(parent, FRAGMENT_COLOR);

		for (di in -radius...radius + 1) {
			for (dj in -radius...radius + 1) {
				addTile(buildings, fragments, centre.i + di, centre.j + dj, collected);
			}
		}

		buildings.flush();
		fragments.flush();
	}

	/** One flat quad under the whole built region — the streets, and everything a building is not standing on. **/
	static function addGround(parent:h3d.scene.Object, centre:{i:Int, j:Int}, radius:Int):Void {
		var points:Array<h3d.Vector> = [];
		var idx = new hxd.IndexBuffer();

		var origin = RepeatModel.tileOrigin(centre.i - radius, centre.j - radius);
		var span = (radius * 2 + 1) * RepeatModel.TILE_SIZE;

		MeshBuilder.addQuad(points, idx, new h3d.Vector(origin.x, 0, origin.z), new h3d.Vector(origin.x + span, 0, origin.z),
			new h3d.Vector(origin.x + span, 0, origin.z + span), new h3d.Vector(origin.x, 0, origin.z + span));

		var mesh = new h3d.scene.Mesh(new h3d.prim.Polygon(points, idx), parent);
		mesh.material.mainPass.addShader(new h3d.shader.FixedColor(GROUND_COLOR));
		mesh.material.mainPass.culling = None;
	}

	/** One tile's buildings, plus its fragment marker if it diverges and has not been collected. **/
	static function addTile(buildings:BoxBatch, fragments:BoxBatch, i:Int, j:Int, collected:Map<String, Bool>):Void {
		var half = RepeatModel.buildingHalfExtent();

		for (plotX in 0...RepeatModel.PLOTS_PER_TILE) {
			for (plotZ in 0...RepeatModel.PLOTS_PER_TILE) {
				if (!RepeatModel.hasBuilding(i, j, plotX, plotZ)) {
					continue;
				}
				var centre = RepeatModel.plotCentre(i, j, plotX, plotZ);
				buildings.add(centre.x, centre.z, half, half, 0, RepeatModel.buildingHeight(plotX, plotZ));
			}
		}

		var divergence = RepeatModel.divergenceOf(i, j);
		if (divergence == null || collected.exists(RepeatBiome.tileKey(i, j))) {
			return;
		}
		var at = RepeatModel.plotCentre(i, j, divergence.plotX, divergence.plotZ);
		fragments.add(at.x, at.z, FRAGMENT_HALF_WIDTH, FRAGMENT_HALF_WIDTH, 0, FRAGMENT_HEIGHT);
	}
}
