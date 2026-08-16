package biomes.defect;

import entities.player.PlayerModel;

/**
	The identification: crossing the seam rotates the player about the
	apex by the cone angle.

	**This is the entire non-flat content of the space.** Everywhere else
	the player walks ordinary straight lines through ordinary flat
	coordinates. The concentrated curvature lives in exactly this
	function, applied at exactly one ray.
**/
class DefectCollision {
	/**
		Applies the cone's own identification if the player has stepped off
		the wedge, rotating **both position and facing** by the same amount
		— facing along with position, or the view would spin at the seam
		and the holonomy would be hidden rather than carried.

		Nothing about the crossing is visible: the two edges of the wedge
		are glued by a rotation, which is an isometry, and the plain looks
		the same either side. That invisibility is the design's own
		legibility law for this space — *the lie is only detectable by
		returning somewhere and finding yourself turned*.
		@param player the player to wrap.
	**/
	public static function wrapIfNeeded(player:PlayerModel):Void {
		var crossing = DefectModel.seamCrossing(player.pos.x, player.pos.z);
		if (crossing == 0) {
			return;
		}
		var angle = crossing * DefectModel.CONE_ANGLE;

		var moved = DefectModel.rotate(player.pos.x, player.pos.z, angle);
		var faced = DefectModel.rotate(player.forward.x, player.forward.z, angle);

		player.pos = new h3d.Vector(moved.x, player.pos.y, moved.z);
		player.forward = new h3d.Vector(faced.x, player.forward.y, faced.z);
	}
}
