package tools.geodesic;

import biomes.common.maze.MazeTopology.EdgeAxis;
import utest.Assert;
import utest.Test;

/** Proves a `GeodesicSphereData` genuinely satisfies `biomes.common.maze.MazeTopology`'s own contract — not just that it compiles against the interface. **/
class GeodesicTopologyTest extends Test {
	function testNodeKeysCoverEveryNode():Void {
		var sphere = GeodesicSphere.generate(2);
		var topology = new GeodesicTopology(sphere);

		Assert.equals(sphere.neighbors.length, topology.nodeKeys().length);
	}

	function testNeighborsOfMatchesTheUnderlyingAdjacency():Void {
		var sphere = GeodesicSphere.generate(2);
		var topology = new GeodesicTopology(sphere);

		var neighborIds = [for (key in topology.neighborsOf("0")) Std.parseInt(key)];

		Assert.same(sphere.neighbors[0], neighborIds);
	}

	function testAxisOfIsAlwaysIrregular():Void {
		var sphere = GeodesicSphere.generate(2);
		var topology = new GeodesicTopology(sphere);

		Assert.equals(EdgeAxis.Irregular, topology.axisOf("0", "1"));
	}
}
