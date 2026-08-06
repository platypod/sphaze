package biomes.conway;

import biomes.conway.ConwayMaze.ConwayMazeData;
import biomes.conway.ConwayMaze.ConwayNode;

/**
	Lets population activity erode and regrow the biome's non-core walls each
	generation: the DFS spanning tree carved at generation time
	(`ConwayMaze`'s `coreEdges`) always stays open, so the maze can never be
	split into unreachable pieces no matter how the reactive edges move; every
	other edge opens where nearby cells have recently been flipping and
	closes back where they've gone quiet — a dead board settles back into a
	static maze, a live one keeps reshaping its own corridors.
**/
class ConwayMazeReactivity {
	/** A non-core edge opens once either endpoint's rolling activity reaches this. **/
	static inline final OPEN_THRESHOLD:Float = 0.5;

	/**
		A non-core edge closes back once both endpoints' activity falls to
		this or below — kept well under `OPEN_THRESHOLD` so an edge doesn't
		flicker every generation.
	**/
	static inline final CLOSE_THRESHOLD:Float = 0.15;

	/**
		Reacts one generation's worth of Life activity into the maze's
		non-core edges. Call once per `ConwayState.step`, same cadence as the
		Life layer itself.
		@param maze the maze to mutate — only edges outside `coreEdges` are ever touched.
		@param state the Life layer just stepped, queried for per-cell activity.
		@param playerNode the node the player currently occupies — its edges are never closed, so a wall can't arrive on a stationary player.
	**/
	public static function step(maze:ConwayMazeData, state:ConwayState, playerNode:ConwayNode):Void {
		for (edge in ConwayMaze.allEdges()) {
			if (ConwayMaze.isCore(maze, edge.a, edge.b)) {
				continue;
			}

			var key = ConwayMaze.edgeKey(edge.a, edge.b);
			var activity = edgeActivity(state, edge.a, edge.b);
			var isOpen = maze.openEdges.exists(key);
			if (!isOpen && activity >= OPEN_THRESHOLD) {
				maze.openEdges.set(key, true);
			} else if (isOpen && activity <= CLOSE_THRESHOLD && !touches(edge, playerNode)) {
				maze.openEdges.remove(key);
			}
		}
	}

	/**
		An edge's own activity — the hotter of its two endpoints. Public so
		`ConwayMesh` can drive `ConwayWallGlow` off the same "how hot is this
		edge" reading `step` uses to decide whether to open or close it.
	**/
	public static function edgeActivity(state:ConwayState, a:ConwayNode, b:ConwayNode):Float {
		return Math.max(activityOf(state, a), activityOf(state, b));
	}

	static function activityOf(state:ConwayState, node:ConwayNode):Float {
		return switch node {
			case PoleNode(pole): state.poleActivityOf(pole);
			case RingNode(row, col): state.activityOf(row, col);
		}
	}

	static function touches(edge:{a:ConwayNode, b:ConwayNode}, node:ConwayNode):Bool {
		var key = ConwayMaze.nodeKey(node);
		return ConwayMaze.nodeKey(edge.a) == key || ConwayMaze.nodeKey(edge.b) == key;
	}
}
