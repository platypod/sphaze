package game;

/**
	Every keyboard binding `GameLoop` reads, named for what it does rather
	than which physical key it is — so the update loop reads as intent
	(`isDown(TURN_LEFT)`) instead of a wall of `hxd.Key.*` codes, and a
	rebind is a one-line change here instead of a hunt through `GameLoop`.
**/
class Keybinds {
	public static inline final TURN_LEFT:Int = hxd.Key.LEFT;
	public static inline final TURN_RIGHT:Int = hxd.Key.RIGHT;
	public static inline final SPRINT:Int = hxd.Key.SHIFT;

	/** Forward/backward each have two physical keys (arrows + ZS) — `GameLoop` checks both for each. **/
	public static inline final MOVE_FORWARD:Int = hxd.Key.UP;

	public static inline final MOVE_FORWARD_ALT:Int = hxd.Key.Z;
	public static inline final MOVE_BACKWARD:Int = hxd.Key.DOWN;
	public static inline final MOVE_BACKWARD_ALT:Int = hxd.Key.S;

	/** Named for their on-screen direction, not the physical key — see `GameLoop.fixedUpdate`'s own comment on why Q/D map this way under Heaps' left-handed camera. **/
	public static inline final STRAFE_LEFT:Int = hxd.Key.Q;

	public static inline final STRAFE_RIGHT:Int = hxd.Key.D;

	public static inline final TILT_UP:Int = hxd.Key.SPACE;
	public static inline final TOGGLE_DEBUG_OVERLAY:Int = hxd.Key.F3;
	public static inline final EXPORT_MAZE:Int = hxd.Key.E;
	public static inline final IMPORT_MAZE:Int = hxd.Key.L;
}
