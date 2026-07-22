package biomes.hub;

import biomes.hub.HubStructure.StructureBasis;
import entities.painting.PaintingModel;
import entities.player.PlayerModel;
import graphics.Colours;

/**
	The minimal hub-side marker for `biomes.mobius.MobiusBiome` — a single
	framed painting anchored at `basis.origin`, nothing else: no
	surrounding wall or spire the way `MazeShrine`/`TowerReplica` build one
	(see `docs/game-design/philosophy.md`'s "prototype the cheapest version first"
	pillar, confirmed with hooman for this first pass). `wallA`/`wallB` in
	`build` exist purely to give `entities.painting.PaintingModel.buildQuad`
	a width/orientation to mount the frame on — there's no physical wall
	behind them, so nothing here blocks movement (unlike
	`TowerReplica.blocksMovement`): a player can walk straight through this
	marker's own footprint.

	No dedicated art exists for this biome yet — `h3d.mat.Texture.fromColor`
	stands in with a flat placeholder fill (`graphics.Colours.MOBIUS_BAND_A`,
	the same placeholder the ribbon's own mesh already uses), trivially
	swapped for a real `res/sprites/painting--biome-mobius-*.png` later
	(see `entities.painting.PaintingModel.toHubTexture`'s own doc for that
	convention).
**/
class MobiusWaypoint {
	/** Half the painting's own mounting span — purely nominal, since there's no real wall to fit against. **/
	static inline final HALF_SPAN:Float = 3;

	/** Clear height `PaintingModel.fillWall` sizes the painting into — arbitrary, same role `biomes.hub.TowerReplica.FLOOR_HEIGHT` plays for its own painting. **/
	static inline final CLEAR_HEIGHT:Float = 10;

	/** How far past `basis.origin` the player reappears when returning from the ribbon, arc-length in the marker's own local frame — must clear `PaintingModel.TRIGGER_DISTANCE` (4), same as every other biome's own return spawn. **/
	static inline final RETURN_SPAWN_OFFSET:Float = 6;

	/**
		Builds the marker's own framed painting, anchored at `basis`.
		@param parent the scene object to attach the mesh under.
		@param basis the marker's own local frame (see `HubStructure.anchorAt`).
	**/
	public static function build(parent:h3d.scene.Object, basis:StructureBasis):Void {
		var wallA = basis.origin.sub(basis.uAxis.scaled(HALF_SPAN));
		var wallB = basis.origin.add(basis.uAxis.scaled(HALF_SPAN));
		var roomCenter = basis.origin.add(basis.vAxis);
		var size = PaintingModel.fillWall(CLEAR_HEIGHT);
		var texture = h3d.mat.Texture.fromColor(Colours.MOBIUS_BAND_A);
		PaintingModel.buildQuad(parent, wallA, wallB, roomCenter, texture, size.baseHeight, size.height, basis.up);
	}

	/**
		The marker's own painting as a trigger — right at `basis.origin`
		itself, since there's no wall segment to take a midpoint of.
		@param basis the marker's own local frame.
		@param destinationBiomeId `biomes.mobius.MobiusBiome.ID`.
		@return the marker's own exit painting.
	**/
	public static function exitPainting(basis:StructureBasis, destinationBiomeId:String):PaintingModel {
		return new PaintingModel(basis.origin, destinationBiomeId);
	}

	/**
		A `PlayerModel` standing `RETURN_SPAWN_OFFSET` past `basis.origin`,
		facing away from it — where the player reappears coming back out of
		the ribbon. Re-projected onto the hub's true sphere, same
		correction `TowerReplica.returnSpawn`/`MazeShrine.returnSpawn`
		already make for the same reason.
		@param basis the marker's own local frame.
		@param radius the hub's own sphere radius.
		@return the spawned player.
	**/
	public static function returnSpawn(basis:StructureBasis, radius:Float):PlayerModel {
		var tentativePos = basis.origin.add(basis.vAxis.scaled(RETURN_SPAWN_OFFSET));
		var pos = tentativePos.normalized().scaled(radius);

		var posDir = pos.normalized();
		var forward = basis.vAxis.sub(posDir.scaled(basis.vAxis.dot(posDir))).normalized();
		return new PlayerModel(pos, forward);
	}
}
