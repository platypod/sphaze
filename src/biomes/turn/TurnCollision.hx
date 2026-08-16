package biomes.turn;

import entities.player.PlayerModel;
import geometry.Isometry;

/**
	Keeps the player on the band, slides them past obstacles, and — the
	part that makes this space non-orientable rather than merely long —
	applies the glide reflection when they reach the end of it.
**/
class TurnCollision {
	/** How far the player's own body keeps clear of an obstacle or a rail. **/
	static inline final PLAYER_RADIUS:Float = 4.0;

	/**
		Moves `player`, holding them on the band and sliding them past
		anything in the way.

		Axis-separated, like `biomes.repeat.RepeatCollision`: at this
		biome's speed, stopping dead against an obstacle would end a run
		outright, and grazing one should cost momentum rather than the lap.
		@param player the player to move.
		@param direction unit tangent to move along.
		@param distance how far to move.
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
		wrapIfNeeded(player);
	}

	/**
		**Where the band becomes a Möbius band.** When the player walks off
		one end of the fundamental domain, the glide reflection puts them
		back at the other end — reflected. Both position *and* facing are
		transformed, by the same isometry, or the view would spin at the
		seam.

		Nothing about the transition is visible: the identification is by
		an isometry and the world is drawn on both sides of the seam, so
		the scene is continuous across it. The player's controls are not
		reflected either, which is the design's own point — *your
		handedness is not a property you carry*. The only tell is the room:
		the bright rail is now on the other side (see `TurnMesh`).

		`forward` is transformed as a **direction**, not a point — see
		`TurnModel.directionToModel`, which zeroes the homogeneous
		coordinate so the glide's translation drops out and only its
		reflection applies. Transforming it as a point would fling the
		facing a full period away and leave `forward` no longer a unit
		vector.
		@param player the player to wrap.
	**/
	public static function wrapIfNeeded(player:PlayerModel):Void {
		var direction = TurnModel.wrapDirection(player.pos);
		if (direction == 0) {
			return;
		}
		var identification = direction > 0 ? TurnModel.glideBack() : TurnModel.glide();

		var moved = Isometry.apply(identification, TurnModel.toModel(player.pos));
		var faced = Isometry.apply(identification, TurnModel.directionToModel(player.forward));

		player.pos = TurnModel.toWorld(moved, player.pos.y);
		player.forward = new h3d.Vector(faced.x, player.forward.y, faced.y);
	}

	/**
		Whether a world position is standable: inside the rails, and clear
		of every obstacle.

		Obstacles are checked in the fundamental domain only, and that is
		enough *because* the player is always in it — `wrapIfNeeded` runs
		after every move, so a position outside the domain never persists.
		The one case that needs care is a move that lands just past the
		seam before wrapping; the obstacles nearest either end are half a
		spacing in from it, so nothing straddles the boundary.
		@param x world x.
		@param z world z.
		@return true if the player may stand there.
	**/
	public static function isOpen(x:Float, z:Float):Bool {
		if (Math.abs(z) > TurnModel.HALF_WIDTH - PLAYER_RADIUS) {
			return false;
		}

		for (index in 0...TurnModel.OBSTACLE_COUNT) {
			var along = TurnModel.obstacleAlong(index);
			if (Math.abs(x - along) >= TurnModel.OBSTACLE_HALF_DEPTH + PLAYER_RADIUS) {
				continue;
			}
			if (Math.abs(z - TurnModel.obstacleAcross(index)) < TurnModel.OBSTACLE_HALF_WIDTH + PLAYER_RADIUS) {
				return false;
			}
		}
		return true;
	}
}
