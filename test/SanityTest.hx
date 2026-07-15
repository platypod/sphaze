import utest.Test;
import utest.Assert;

/**
	Proves the utest harness compiles and runs end to end. Delete once real
	gameplay logic (and its tests) lands.
**/
class SanityTest extends Test {
	function testArithmetic():Void {
		var expected = 4;
		Assert.equals(expected, 2 + 2);
	}
}
