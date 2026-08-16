package biomes.weft;

import biomes.common.grid.GridMesh;
import biomes.common.grid.GridModel.GridData;
import graphics.Colours;

/**
	The Weft's own floor and walls — built from `GridMesh`'s verified
	geometry (`buildFloorPrim`, `buildWallPrim`: the same corner and
	row-boundary-seam construction the maze prototype uses, unmodified),
	with the Weft's own material on top instead of `GridMesh.build`'s
	grass and stone.

	**Why this exists at all**, rather than the Weft continuing to call
	`GridMesh.build` directly. Grass and stone are the maze prototype's own
	materials — `biomes.maze`, unnumbered, predating
	[the direction](../../../docs/game/world.md) entirely — and the Weft
	inherited them by reusing that prototype's grid rather than by any
	deliberate choice. Flagged directly ("no... coherence with our new
	Artistic Direction"): grass is organic, against
	[art-and-audio.md](../../../docs/game/art-and-audio.md)'s "everything
	is cells"; its hue is whatever a grass texture's hue happens to be, not
	a function of curvature, against that document's other universal
	constant. Flat amber/ember/brass fixes both — see `Colours.WEFT_FLOOR`
	and `Colours.WEFT_WALL` for the reasoning behind the specific values.

	Unlit and flat-shaded, same reasoning as every other flat-color mesh in
	the project (`biomes.defect.DefectMesh`, `biomes.conway.ConwayMesh`, …):
	nothing here has real lighting to shade by, so a lit material would
	read as a smooth gradient across faces the sphere's own faceting is
	supposed to keep discrete.
**/
class WeftMesh {
	/**
		@param maze the current layout.
		@param parent the scene object to attach the floor and walls under.
	**/
	public static function build(maze:GridData, parent:h3d.scene.Object):Void {
		var floorMesh = new h3d.scene.Mesh(GridMesh.buildFloorPrim(), parent);
		floorMesh.material.mainPass.addShader(new h3d.shader.FixedColor(Colours.WEFT_FLOOR));
		floorMesh.material.mainPass.culling = None;

		var wallMesh = new h3d.scene.Mesh(GridMesh.buildWallPrim(maze), parent);
		wallMesh.material.mainPass.addShader(new h3d.shader.FixedColor(Colours.WEFT_WALL));
		wallMesh.material.mainPass.culling = None;
	}
}
