package biomes.hub;

import biomes.hub.HubStructure.StructureBasis;
import entities.painting.PaintingModel;
import entities.player.PlayerModel;
import graphics.Colours;

/**
	Minimal hub marker for `biomes.conway.ConwayBiome`: a single framed
	painting, no blocking geometry.
**/
class ConwayWaypoint {
	static inline final HALF_SPAN:Float = 3;
	static inline final CLEAR_HEIGHT:Float = 10;
	static inline final RETURN_SPAWN_OFFSET:Float = 6;

	public static function build(parent:h3d.scene.Object, basis:StructureBasis):Void {
		var wallA = basis.origin.sub(basis.uAxis.scaled(HALF_SPAN));
		var wallB = basis.origin.add(basis.uAxis.scaled(HALF_SPAN));
		var roomCenter = basis.origin.add(basis.vAxis);
		var size = PaintingModel.fillWall(CLEAR_HEIGHT);
		var texture = h3d.mat.Texture.fromColor(Colours.CONWAY_TILE_LIVE);
		PaintingModel.buildQuad(parent, wallA, wallB, roomCenter, texture, size.baseHeight, size.height, basis.up);
	}

	public static function exitPainting(basis:StructureBasis, destinationBiomeId:String):PaintingModel {
		return new PaintingModel(basis.origin, destinationBiomeId);
	}

	public static function returnSpawn(basis:StructureBasis, radius:Float):PlayerModel {
		var tentativePos = basis.origin.add(basis.vAxis.scaled(RETURN_SPAWN_OFFSET));
		var pos = tentativePos.normalized().scaled(radius);

		var posDir = pos.normalized();
		var forward = basis.vAxis.sub(posDir.scaled(basis.vAxis.dot(posDir))).normalized();
		return new PlayerModel(pos, forward);
	}
}
