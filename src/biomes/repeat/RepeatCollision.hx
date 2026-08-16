package biomes.repeat;

import entities.player.PlayerModel;

/**
	Buildings block; streets do not.

	Axis-separated: the move is attempted on each axis independently and
	each is kept only if it lands somewhere standable. That is what makes
	walking into a wall slide along it instead of stopping dead, which
	matters more in a city than anywhere else in the game — the whole
	space is right angles, and every approach to a building is a graze.
**/
class RepeatCollision {
	/** How far the player's own body keeps clear of a wall. Without it the camera can sit exactly in a face and see through it. **/
	static inline final PLAYER_RADIUS:Float = 3.0;

	/**
		Moves `player` by `distance` along `direction`, sliding along any
		building it meets.
		@param player the player to move.
		@param direction unit tangent to move along.
		@param distance how far to move; negative moves the opposite way.
	**/
	public static function tryMove(player:PlayerModel, direction:h3d.Vector, distance:Float):Void {
		var from = player.pos;
		var step = direction.scaled(distance);

		var x = from.x;
		var z = from.z;

		if (isOpen(from.x + step.x, z)) {
			x = from.x + step.x;
		}
		if (isOpen(x, from.z + step.z)) {
			z = from.z + step.z;
		}

		player.pos = new h3d.Vector(x, from.y, z);
	}

	/**
		Whether a world position is standable — outside every building's
		own footprint, by at least `PLAYER_RADIUS`.

		Only the plot containing the position and its immediate neighbours
		are checked, since a building cannot reach further than one plot;
		the neighbours matter because `PLAYER_RADIUS` lets a position just
		inside one plot still be too close to the building in the next.
		@param x world x.
		@param z world z.
		@return true if the player may stand there.
	**/
	public static function isOpen(x:Float, z:Float):Bool {
		var half = RepeatModel.buildingHalfExtent() + PLAYER_RADIUS;

		for (dx in -1...2) {
			for (dz in -1...2) {
				var probeX = x + dx * RepeatModel.PLOT_SIZE;
				var probeZ = z + dz * RepeatModel.PLOT_SIZE;
				var tile = RepeatModel.tileIndexAt(probeX, probeZ);
				var origin = RepeatModel.tileOrigin(tile.i, tile.j);
				var plotX = Math.floor((probeX - origin.x) / RepeatModel.PLOT_SIZE);
				var plotZ = Math.floor((probeZ - origin.z) / RepeatModel.PLOT_SIZE);

				if (!RepeatModel.hasBuilding(tile.i, tile.j, plotX, plotZ)) {
					continue;
				}
				var centre = RepeatModel.plotCentre(tile.i, tile.j, plotX, plotZ);
				if (Math.abs(x - centre.x) < half && Math.abs(z - centre.z) < half) {
					return false;
				}
			}
		}
		return true;
	}
}
