package entities;

import game.Process;

/**
	Base class for anything that exists in the game world (player, enemies,
	items, projectiles, ...) — see docs/GUIDELINES.md §1.2. Behavior/state is
	composed from small data pieces attached to an Entity rather than deep
	subclassing (a `Health`, `Movement`, `Inventory`, ...); Entity itself
	stays minimal, a `Process` with nothing else added, until a component
	actually needs one.
**/
class Entity extends Process {
	public function new() {
		super();
	}
}
