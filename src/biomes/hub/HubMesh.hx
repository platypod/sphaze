package biomes.hub;

import biomes.common.grass.GrassMesh;
import biomes.common.grass.GrassModel;
import graphics.shaders.GrassWind;
import graphics.shaders.UnlitTexture;

/**
	Builds the hub's own outer shell (an `h3d.prim.Sphere`, textured with a
	tiled grass image so the floor the `GrassMesh` blades stand on reads as
	ground rather than an abstract surface) and its grass. The hub used to
	also build a central column here (`buildColumn`/`addCap`) — gone now
	that paintings mount on the two freestanding landmark structures
	(`MazeShrine`, `TowerReplica`) instead, which build and texture
	themselves; this class no longer needs to know paintings exist at all.
**/
class HubMesh {
	/** Segment counts for the outer shell's `h3d.prim.Sphere`. **/
	static inline final SHELL_SEGS_W = 32;

	static inline final SHELL_SEGS_H = 24;

	/** Grass texture repeat density: tiles around the equator, and pole to pole — chosen so tiles read roughly square (the equator's circumference is about twice the pole-to-pole distance), same ratio the previous checkerboard used. **/
	static inline final FLOOR_TILE_U = 40;

	static inline final FLOOR_TILE_V = 20;

	/**
		@param parent the scene object to attach the meshes under.
		@param isWalkable whether a candidate world position is clear of both landmark structures — see `HubBiome`, which is what actually knows where they stand.
	**/
	public static function build(parent:h3d.scene.Object, isWalkable:h3d.Vector->Bool):Void {
		// h3d.prim.Sphere's own poles sit on the Z axis (built from
		// cos/sin(t) into x/y, cos(t) into z) — rotated here to match this
		// project's Y-axis pole convention (SphereMath.sphericalToCartesian)
		// instead. Keeps the tiled texture's own grain aligned with this
		// project's pole-to-pole axis instead of running crosswise to it.
		var shellPrim = new h3d.prim.Sphere(HubModel.RADIUS, SHELL_SEGS_W, SHELL_SEGS_H);
		shellPrim.addUVs();
		var shellMesh = new h3d.scene.Mesh(shellPrim, parent);
		shellMesh.setRotation(-Math.PI / 2, 0, 0);
		var grassTexture = hxd.Res.textures.grass.toTexture();
		grassTexture.wrap = Repeat;
		shellMesh.material.mainPass.addShader(new UnlitTexture(grassTexture, FLOOR_TILE_U, FLOOR_TILE_V));
		shellMesh.material.mainPass.culling = None;

		// Denser and calmer than the baseline: the hub is a small, mostly-empty
		// room the player lingers in rather than passes through, so a thicker
		// floor reads better, and a busier sway would compete with the room's
		// own stillness.
		GrassMesh.build(parent, HubModel.RADIUS, isWalkable, GrassModel.DEFAULT_TUFT_COUNT * 4, GrassWind.DEFAULT_SWAY_AMPLITUDE * 2 / 3);
	}
}
