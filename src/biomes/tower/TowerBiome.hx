package biomes.tower;

import biomes.common.Biome;
import biomes.common.space.flat.FlatSpace;
import biomes.hub.HubBiome;
import biomes.tower.TowerModel.TowerData;
import entities.painting.PaintingModel;
import entities.player.PlayerModel;

/**
	The vertical tower: a shaft of stacked circular layers (see `TowerModel`'s
	own class doc for the cross-section shape) the player free-falls down
	through gaps in, walls all around, gravity lighter than the hub/maze's.
	The descent's own goal is reaching the bottom (`TowerModel.GOAL_LEVELS`),
	tracked here as `deepestLayerReached` — a running max, not just the
	latest tick's own layer, so jumping back upward mid-fall never un-gates
	the return painting once it's actually been earned. Only one biome ever
	leads here (the hub), so `spawnPlayer`'s `returning`/`fromBiomeId` don't
	need to distinguish anything — every arrival starts the same way, at the
	top layer's own always-solid center disk.
**/
class TowerBiome implements Biome {
	public static inline final ID:String = "tower";

	/**
		Lighter than the hub/maze's own (`biomes.hub.HubBiome.GRAVITY`) —
		"slightly decreased," per the ask. First-pass value, tune by feel.
	**/
	static inline final GRAVITY:Float = 42;

	var layout:TowerData;

	/** The deepest layer reached so far this visit — see class doc for why this is a running max, not the latest tick's own layer. **/
	var deepestLayerReached:Int = 0;

	public function new(layout:TowerData) {
		this.layout = layout;
	}

	public function id():String {
		return ID;
	}

	public function gravity():Float {
		return GRAVITY;
	}

	public function build(parent:h3d.scene.Object):Void {
		TowerMesh.build(layout, parent);
	}

	/**
		Always the top layer's own center disk — always solid regardless of
		the generated layout (see `TowerModel`'s own class doc), so this
		never needs to check the layout at all. Resets
		`deepestLayerReached`, since every arrival starts the descent over.
	**/
	public function spawnPlayer(returning:Bool, fromBiomeId:Null<String>):PlayerModel {
		deepestLayerReached = 0;
		return new PlayerModel(new h3d.Vector(0, TowerModel.layerY(0), 0), new h3d.Vector(0, 0, 1), 0, FlatSpace.INSTANCE);
	}

	/**
		An always-available entrance painting at the top (an escape hatch
		near spawn — giving up partway down shouldn't strand the player
		until they reach the bottom), plus the goal painting once the
		player has actually reached it — a running max
		(`deepestLayerReached`), not the latest tick's own layer, so
		jumping back upward mid-fall never un-gates it once it's been
		earned. Both lead back to the hub; see `TowerMesh` for where
		they're actually mounted.
	**/
	public function exitPaintings():Array<PaintingModel> {
		var paintings = [wallPainting(0)];
		if (deepestLayerReached >= TowerModel.GOAL_LEVELS - 1) {
			paintings.push(wallPainting(TowerModel.GOAL_LEVELS - 1));
		}
		return paintings;
	}

	/** The hub-bound painting mounted on the outer wall at `layer`'s own height — see `TowerModel.paintingWallEdge`. **/
	static function wallPainting(layer:Int):PaintingModel {
		var left = TowerModel.paintingWallEdge(layer, true);
		var right = TowerModel.paintingWallEdge(layer, false);
		var size = PaintingModel.fillWall(TowerModel.LAYER_HEIGHT - TowerModel.TILE_THICKNESS);
		return new PaintingModel(PaintingModel.centerOf(left, right, size.baseHeight, size.height, new h3d.Vector(0, 1, 0)), HubBiome.ID);
	}

	public function tryMove(player:PlayerModel, direction:h3d.Vector, distance:Float):Void {
		TowerCollision.tryMove(player, direction, distance);
	}

	public function applyGravity(player:PlayerModel, dt:Float):Void {
		var layer = TowerCollision.applyGravity(player, GRAVITY, layout, dt);
		if (layer > deepestLayerReached) {
			deepestLayerReached = layer;
		}
	}

	public function serialize():String {
		return TowerGenerator.serialize(layout);
	}

	public function restore(json:String):Void {
		layout = TowerGenerator.deserialize(json);
	}
}
