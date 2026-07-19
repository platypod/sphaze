package biomes.common;

import entities.player.PlayerModel;

/**
	Shared "fall until you hit the surface you're already standing on"
	gravity rule for any biome whose floor is present everywhere (today: the
	hub and the maze) — a jump is a cosmetic hop that always lands back at
	`groundHeight` the same tick it would cross below it, never touching
	`pos` itself (see `PlayerModel.airborneHeight`'s own doc). The tower
	biome has real multi-level falling instead and implements its own
	`Biome.applyGravity` directly rather than using this.
**/
class Gravity {
	/**
		Integrates `player.verticalVelocity`/`airborneHeight` by one fixed
		step under `gravity`, then clamps back to `groundHeight` the instant
		it would go below it — this biome's floor is always there (at
		`groundHeight`, not necessarily `0`), so there's never a real gap to
		fall through.
		@param player the player to update.
		@param gravity this biome's own gravity strength, in world units/s².
		@param dt fixed timestep duration, in seconds.
		@param groundHeight how high above the biome's own base surface the ground is directly below `player`, right now — `0` (the base surface itself) for a biome with nothing standable above it; a caller with its own standable obstacles (e.g. `biomes.hub.HubBiome`, over one of `biomes.hub.MazeShrine`'s own walls) computes this fresh every call, since it can change tick to tick as the player moves horizontally.
	**/
	public static function fallToSurface(player:PlayerModel, gravity:Float, dt:Float, groundHeight:Float = 0):Void {
		player.verticalVelocity -= gravity * dt;
		player.airborneHeight += player.verticalVelocity * dt;

		if (player.airborneHeight <= groundHeight) {
			player.airborneHeight = groundHeight;
			player.verticalVelocity = 0;
			player.grounded = true;
		} else {
			player.grounded = false;
		}
	}
}
