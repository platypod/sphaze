package game;

/**
	Minimal update/pause/parent-child tree — the foundation CLAUDE.md's
	Architecture section commits to, kept deliberately small (see
	docs/GUIDELINES.md §1.3): fixed-timestep propagation and pausing, and
	nothing else. Not a scene graph (that's `h3d.scene.Object`) and not an
	ECS scheduler — just "this thing ticks on the fixed step, can have
	children that tick with it, and pausing it pauses them too."

	Only `fixedUpdate` exists for now, not a separate variable-rate
	`update`: nothing in the game today has frame-rate-dependent per-entity
	behavior (`Main` drives everything through its own accumulator — see
	CLAUDE.md's "Architecture"), so a second hook would be unused
	scaffolding. Add it if/when something actually needs per-frame (not
	per-tick) behavior.
**/
class Process {
	public var paused:Bool = false;

	final children:Array<Process> = [];

	public function new() {}

	/** Attaches `child` so it fixed-updates/pauses along with this process. **/
	public function addChild(child:Process):Void {
		children.push(child);
	}

	/** Detaches `child` — it stops receiving `fixedUpdate` calls through this tree. **/
	public function removeChild(child:Process):Void {
		children.remove(child);
	}

	/**
		Advances this process by one fixed timestep, then its children —
		unless paused, in which case neither this process's own tick nor any
		child's runs at all (pausing a parent pauses its whole subtree).
		@param dt fixed timestep duration.
	**/
	public function fixedUpdate(dt:Float):Void {
		if (paused) {
			return;
		}
		onFixedUpdate(dt);
		for (child in children) {
			child.fixedUpdate(dt);
		}
	}

	/** Override to add this process's own per-tick behavior; called before children tick. **/
	public function onFixedUpdate(dt:Float):Void {}
}
