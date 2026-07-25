package biomes.conway;

import biomes.conway.ConwayGrid.Pole;

enum ConwayNode {
	PoleNode(pole:Pole);
	RingNode(row:Int, col:Int);
}

typedef ConwayMazeData = {
	var openEdges:haxe.ds.StringMap<Bool>;
}

/**
	Conway biome's own maze layout over ConwayGrid's topology.
**/
class ConwayMaze {
	public static function generate(?random:Void->Float):ConwayMazeData {
		var rng = random != null ? random : Math.random;
		var visited = new haxe.ds.StringMap<Bool>();
		var openEdges = new haxe.ds.StringMap<Bool>();

		var start = allNodes()[0];
		if (start == null) {
			return {openEdges: openEdges};
		}

		var stack:Array<ConwayNode> = [start];
		visited.set(nodeKey(start), true);

		while (stack.length > 0) {
			var current = stack[stack.length - 1];
			if (current == null) {
				break;
			}

			var unvisited = neighborsOf(current).filter((neighbor) -> !visited.exists(nodeKey(neighbor)));
			if (unvisited.length == 0) {
				stack.pop();
				continue;
			}

			var next = unvisited[Math.floor(rng() * unvisited.length)];
			if (next == null) {
				continue;
			}
			openEdges.set(edgeKey(current, next), true);
			visited.set(nodeKey(next), true);
			stack.push(next);
		}

		return {openEdges: openEdges};
	}

	public static function serialize(maze:ConwayMazeData):String {
		var edges = [for (key in maze.openEdges.keys()) key];
		return haxe.Json.stringify({openEdges: edges});
	}

	public static function deserialize(json:String):ConwayMazeData {
		var parsed:{openEdges:Array<String>} = haxe.Json.parse(json);
		var openEdges = new haxe.ds.StringMap<Bool>();
		if (parsed.openEdges != null) {
			for (key in parsed.openEdges) {
				openEdges.set(key, true);
			}
		}
		return {openEdges: openEdges};
	}

	public static function isOpen(maze:ConwayMazeData, a:ConwayNode, b:ConwayNode):Bool {
		return maze.openEdges.exists(edgeKey(a, b));
	}

	public static function nodeKey(node:ConwayNode):String {
		return switch node {
			case PoleNode(North): "pole:north";
			case PoleNode(South): "pole:south";
			case RingNode(row, col): 'ring:$row:$col';
		}
	}

	public static function edgeKey(a:ConwayNode, b:ConwayNode):String {
		var keyA = nodeKey(a);
		var keyB = nodeKey(b);
		return keyA < keyB ? '$keyA|$keyB' : '$keyB|$keyA';
	}

	public static function allNodes():Array<ConwayNode> {
		var nodes:Array<ConwayNode> = [PoleNode(North), PoleNode(South)];
		ConwayGrid.eachRingCell((row, col) -> nodes.push(RingNode(row, col)));
		return nodes;
	}

	public static function neighborsOf(node:ConwayNode):Array<ConwayNode> {
		return switch node {
			case PoleNode(North):
				[for (col in 0...ConwayGrid.COLS) RingNode(0, col)];
			case PoleNode(South):
				[for (col in 0...ConwayGrid.COLS) RingNode(ConwayGrid.RING_ROWS - 1, col)];
			case RingNode(row, col):
				var neighbors:Array<ConwayNode> = [RingNode(row, wrapCol(col - 1)), RingNode(row, wrapCol(col + 1))];
				if (row == 0) {
					neighbors.push(PoleNode(North));
				} else {
					neighbors.push(RingNode(row - 1, col));
				}
				if (row == ConwayGrid.RING_ROWS - 1) {
					neighbors.push(PoleNode(South));
				} else {
					neighbors.push(RingNode(row + 1, col));
				}
				neighbors;
		}
	}

	static function wrapCol(col:Int):Int {
		var wrapped = col % ConwayGrid.COLS;
		return wrapped < 0 ? wrapped + ConwayGrid.COLS : wrapped;
	}
}
