package biomes.common;

import entities.player.PlayerModel;
import entities.player.Camera.CameraOverride;
import entities.painting.PaintingModel;

/**
	Contract every biome instance implements — the hub included. `GameLoop`
	talks to whichever biome is current only through this interface, never
	by biome type name: the hub used to be a special-cased second scene kind
	alongside "the maze," even though it already had everything a biome has
	(its own build, its own collision, its own spawn point, its own
	painting) — see docs/PROJECT_LOG.md's restructuring entry. It's a
	particular biome (the always-present navigation hub), not a different
	kind of thing.
**/
interface Biome {
	/** This biome's own registry id (e.g. `"hub"`, `"maze"`) — how paintings and the biome registry refer to it. **/
	function id():String;

	/**
		This biome's own gravity strength, in world units/s² — how fast a
		falling or jumping player accelerates here (see `applyGravity`). A
		property of the biome, not a shared global, so e.g. the tower can
		feel lighter than the hub/maze.
	**/
	function gravity():Float;

	/**
		This biome's own clear color, used by `GameLoop` when entering it.
		Most biomes keep the default neutral gray; the Möbius strip uses a
		darker space backdrop instead.
		@return this biome's background color as `0xRRGGBB`.
	**/
	function backgroundColor():Int;

	/** (Re)builds this biome's meshes under `parent`. Called each time the biome is entered. **/
	function build(parent:h3d.scene.Object):Void;

	/**
		A PlayerModel standing at this biome's own entry point.
		@param returning true if the player is coming back into a biome they
		already visited (e.g. from the hub) rather than a fresh visit — a
		biome may resume near wherever they left, or ignore this and always
		use a fixed spawn (see `biomes.HubBiome`).
		@param fromBiomeId the `id()` of the biome the player is arriving
		from — null exactly when `returning` is false (there's no meaningful
		"from" for a fresh arrival); a biome that cares (e.g. the hub, to
		pick which of its own several column faces to spawn in front of)
		can rely on it being non-null whenever `returning` is true.
		@return the spawned player.
	**/
	function spawnPlayer(returning:Bool, fromBiomeId:Null<String>):PlayerModel;

	/**
		This biome's own exit paintings, checked each tick against the
		player's position (see `GameLoop.checkPaintingTrigger`) — re-read
		fresh every tick rather than cached at entry, since a biome's own set
		can change mid-visit (e.g. the tower's own return painting, absent
		until enough levels are dropped). Empty if this biome has nothing to
		warp out to right now.
		@return this biome's currently active exit paintings.
	**/
	function exitPaintings():Array<PaintingModel>;

	/**
		Attempts to move `player` by `distance` along `direction` through this biome's own collision rule.
		@param player the player to move.
		@param direction unit tangent at `player.pos` to move along.
		@param distance arc length to move; negative moves the opposite way.
	**/
	function tryMove(player:PlayerModel, direction:h3d.Vector, distance:Float):Void;

	/**
		Advances `player`'s vertical physics by one fixed step: gravity
		pulls `player.verticalVelocity` down at this biome's own `gravity()`,
		and landing — where "the ground" actually is directly below
		`player.pos`, and what happens once `player` reaches it — is this
		biome's own collision rule, same reasoning `tryMove` already uses
		for horizontal movement.
		@param player the player to update.
		@param dt fixed timestep duration, in seconds.
	**/
	function applyGravity(player:PlayerModel, dt:Float):Void;

	/**
		Advances any per-tick state this biome owns beyond movement/gravity —
		today, only the hub's own hourglass (`entities.hourglass.HourglassModel`).
		Called unconditionally every fixed step, real (unscaled) `dt`
		regardless of `timeScale()` — see `HourglassModel`'s own class doc
		for why a self-referential scale would be a feedback loop. A biome
		with nothing of the sort is a no-op, same discipline as `serialize`
		for a biome with nothing to save.
		@param player the current player — read-only here (e.g. for proximity to some ambient object); nothing today mutates it.
		@param dt fixed timestep duration, in seconds — real time, not scaled by `timeScale()`.
	**/
	function tick(player:PlayerModel, dt:Float):Void;

	/**
		The player pressed the interact key here. A biome with nothing to
		interact with ignores it — a no-op, same as `tick` for a biome with
		no per-tick state of its own.

		Part of the contract rather than a downcast in `GameLoop`, for the same
		reason everything else here is (see this interface's own class doc):
		`GameLoop` reads the key and hands it to whichever biome is current
		without knowing what, if anything, that biome does with it. Introduced
		for `biomes.twosided.TwoSidedBiome`'s own marks, and deliberately
		named for the *input* rather than for marking — several backlogged
		mechanics (wall-carry, junction drafting, scouting) are all "the player
		acted here," and none of them wants its own key.
		@param player the player interacting; a biome may act on their position, or move them.
	**/
	function interact(player:PlayerModel):Void;

	/**
		An override for where the camera sits and looks this frame, in place
		of the normal first-person placement `entities.player.Camera.applyTo`
		would otherwise compute from the player alone. Non-null exactly while
		this biome is showing something other than the ordinary FPS view —
		today, only `tools.geodesic.GeodesicConwayBiome`'s zoomed-in pentagon
		engraving. `GameLoop` also reads non-null here as "this biome is
		capturing input right now": normal movement/turning is suspended and
		the mouse switches out of pointer-lock, for as long as this keeps
		returning non-null (see `GameLoop.fixedUpdate`'s own doc).

		Part of the contract rather than a downcast in `GameLoop`, for the
		same reason `interact` is (see this interface's own class doc). A
		biome with nothing of the sort returns null, unconditionally — same
		discipline as `interact` for a biome with nothing to act on.
		@param player the current player, in case the override is computed relative to them.
		@return a camera placement to use instead of the normal one, or null to use the normal one.
	**/
	function cameraOverride(player:PlayerModel):Null<CameraOverride>;

	/**
		The player clicked while `cameraOverride` was non-null — `GameLoop`
		only ever calls this then, with the click already unprojected into a
		world-space ray through whichever camera `cameraOverride` had in
		effect. A biome with no click-driven editing (every biome except
		whichever one owns the current `cameraOverride`) is a no-op, same
		discipline as `interact`/`tick` for a biome with nothing of their own
		kind either.
		@param ray the click's own world-space ray, from the overridden camera's eye through the clicked pixel.
	**/
	function onEditClick(ray:h3d.col.Ray):Void;

	/**
		This biome's own contribution to the game's overall game-speed
		multiplier — `1` for every biome except the hub, whose own
		hourglass can push it up or down (see `entities.hourglass.HourglassModel`).
		Part of the contract (like `gravity()`) rather than a downcast in
		`GameLoop`, per this interface's own class doc ("never by biome type
		name"). Combined across *every* registered biome, not just
		whichever is current — see `entities.registries.BiomesRegistry.globalTimeScale`,
		which is what `GameLoop` actually reads — so the hub's own hourglass
		keeps affecting the game's speed even after the player has walked
		out of the hub, per direct ask ("the speed [e]ffect should be
		global"). Only the hourglass's own tilt/trigger detection stays
		scoped to physically standing in the hub (see `HubBiome.tick`); this
		method's own *value*, once set, applies everywhere.
		@return this biome's own contribution to the current game-speed multiplier.
	**/
	function timeScale():Float;

	/**
		This biome's own state as a JSON string — the counterpart `restore`
		reads back for `GameLoop`'s L (import) dev tool. Part of the contract
		rather than something `GameLoop` reaches for via a type-specific
		downcast, so a future stateful biome doesn't need its own special
		case there. A biome with nothing worth saving (e.g. the hub) can just
		return `"{}"`.

		**Currently unreachable from a keybind.** `GameLoop` used to expose
		this via E as a matching export dev tool; E was freed for the
		pentagon-engraving interaction instead (see `docs/PROJECT_LOG.md`'s
		2026-08-10 entry) and nothing rebinds export elsewhere yet. Every
		implementation is left as-is rather than deleted — `restore`/import
		still depends on the same format, and a future export key just needs
		to call this again.
		@return this biome's state as JSON.
	**/
	function serialize():String;

	/**
		Restores this biome's state from JSON produced by `serialize` — the
		inverse, used by `GameLoop`'s L (import) dev tool. A no-op for a biome
		with nothing worth restoring.
		@param json a JSON string produced by `serialize`.
	**/
	function restore(json:String):Void;
}
