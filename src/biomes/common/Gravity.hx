package biomes.common;

import entities.player.PlayerModel;

/**
	Shared "fall until you hit the surface you're already standing on"
	gravity rule for any biome whose floor is present everywhere (today: the
	hub and the maze) — a jump is a cosmetic hop that always lands back at
	`PlayerModel.airborneHeight` 0 the same tick it would cross below it,
	never touching `pos` itself (see that field's own doc). The tower biome
	has real multi-level falling instead and implements its own
	`Biome.applyGravity` directly rather than using this.
**/
class Gravity {
	/**
		Integrates `player.verticalVelocity`/`airborneHeight` by one fixed
		step under `gravity`, then clamps back to the surface (0) the
		instant it would go below it — this biome's floor is always there,
		so there's never a real gap to fall through.
		@param player the player to update.
		@param gravity this biome's own gravity strength, in world units/s².
		@param dt fixed timestep duration, in seconds.
	**/
	public static function fallToSurface(player:PlayerModel, gravity:Float, dt:Float):Void {
		player.verticalVelocity -= gravity * dt;
		player.airborneHeight += player.verticalVelocity * dt;

		if (player.airborneHeight <= 0) {
			player.airborneHeight = 0;
			player.verticalVelocity = 0;
			player.grounded = true;
		} else {
			player.grounded = false;
		}
	}
}
