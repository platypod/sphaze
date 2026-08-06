package tools.geodesic;

import biomes.common.maze.MazeTopology;
import biomes.common.maze.MazeTopology.EdgeAxis;
import tools.geodesic.GeodesicSphere.GeodesicSphereData;

/**
	Presents a `GeodesicSphereData` as a `biomes.common.maze.MazeTopology` —
	proof, not just a claim, that the maze-carving system needs nothing new
	to run on a geodesic sphere: every carver in `biomes.common.maze` only
	ever touches `nodeKeys()`/`neighborsOf()`/`axisOf()`, the same contract
	`biomes.common.grid.GridTopology`/`biomes.conway.ConwayTopology` already
	implement for their own very different grids. `RandomizedDfs`/`Prim`/
	`Kruskal`/`AxisBiased` all work against this immediately;
	`RecursiveDivision` doesn't (it needs `RectangularTopology`, meaningless
	on an arbitrary graph with no rows/columns), same as it already doesn't
	apply to `ConwayTopology`.

	Node keys are the node's own integer id, stringified — there's no
	row/col (or any other structured) identity to preserve the way the
	lat/long biomes' own `nodeKey` formats do.
**/
class GeodesicTopology implements MazeTopology {
	final sphere:GeodesicSphereData;

	public function new(sphere:GeodesicSphereData) {
		this.sphere = sphere;
	}

	public function nodeKeys():Array<String> {
		return [for (id in 0...sphere.neighbors.length) Std.string(id)];
	}

	public function neighborsOf(nodeKey:String):Array<String> {
		var id = idOf(nodeKey);
		return [for (neighbor in sphere.neighbors[id]) Std.string(neighbor)];
	}

	/** No row/col (or any other structured) axis exists on this graph — every edge is `Irregular`, the same reading `GridTopology.axisOf` already gives a pole edge. **/
	public function axisOf(a:String, b:String):EdgeAxis {
		return Irregular;
	}

	static function idOf(nodeKey:String):Int {
		var id = Std.parseInt(nodeKey);
		if (id == null) {
			throw 'not a GeodesicTopology node key: "$nodeKey"';
		}
		return id;
	}
}
