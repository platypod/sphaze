package tools.geodesic;

import tools.geodesic.GeodesicSphere.GeodesicSphereData;
import tools.geodesic.Vec3.Vec3Math;
import utest.Assert;
import utest.Test;

class GeodesicValidatorTest extends Test {
	function testASoundSphereHasNoProblems():Void {
		var frequency = 3;
		var sphere = GeodesicSphere.generate(frequency);

		Assert.equals(0, GeodesicValidator.validate(sphere, frequency).length);
	}

	function testFlagsAMismatchedFrequency():Void {
		var sphere = GeodesicSphere.generate(3);

		var problems = GeodesicValidator.validate(sphere, 4);

		Assert.isTrue(problems.length > 0);
	}

	/** Hand-built: two degree-5 ("pentagon") nodes that neighbor each other — a real geodesic sphere never produces this, so the validator has to catch it from a fixture, not just confirm it never fires on real data. **/
	function testFlagsAdjacentPentagons():Void {
		var neighbors = [[1, 2, 3, 4, 5], [0, 6, 7, 8, 9], [0], [0], [0], [0], [1], [1], [1], [1],];
		var sphere:GeodesicSphereData = {positions: [for (_ in 0...10) Vec3Math.make(0, 0, 0)], neighbors: neighbors};

		var problems = GeodesicValidator.validate(sphere, 1);

		Assert.isTrue(problems.filter((p) -> p.indexOf("adjacent to pentagon") != -1).length > 0);
	}

	function testFlagsADisconnectedSphere():Void {
		var sphere:GeodesicSphereData = {
			positions: [for (_ in 0...4) Vec3Math.make(0, 0, 0)],
			neighbors: [[1], [0], [3], [2]], // two separate pairs, never joined
		};

		var problems = GeodesicValidator.validate(sphere, 1);

		Assert.isTrue(problems.filter((p) -> p.indexOf("not fully connected") != -1).length > 0);
	}
}
