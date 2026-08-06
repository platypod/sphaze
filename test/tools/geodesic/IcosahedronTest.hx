package tools.geodesic;

import tools.geodesic.Vec3.Vec3Math;
import utest.Assert;
import utest.Test;

class IcosahedronTest extends Test {
	function testHasTwelveUnitVertices():Void {
		Assert.equals(12, Icosahedron.VERTICES.length);
		for (v in Icosahedron.VERTICES) {
			Assert.floatEquals(1, Vec3Math.length(v));
		}
	}

	function testHasTwentyFaces():Void {
		Assert.equals(20, Icosahedron.FACES.length);
	}

	/** Every vertex of a regular icosahedron touches exactly 5 faces — the property `GeodesicSphere`'s own "always exactly 12 pentagons" guarantee depends on. Checked here rather than trusted, since `FACES` is hand-transcribed. **/
	function testEveryVertexTouchesExactlyFiveFaces():Void {
		var faceCount = [for (_ in 0...12) 0];
		for (face in Icosahedron.FACES) {
			faceCount[face.a]++;
			faceCount[face.b]++;
			faceCount[face.c]++;
		}
		for (vertexId in 0...12) {
			Assert.equals(5, faceCount[vertexId], 'vertex $vertexId touches ${faceCount[vertexId]} faces');
		}
	}
}
