import utest.Test;
import utest.Assert;
import game.Process;

/** Covers Process's update/pause/parent-child propagation — see docs/GUIDELINES.md §1.3. **/
class ProcessTest extends Test {
	function testFixedUpdateTicksChildren():Void {
		var parent = new CountingProcess();
		var child = new CountingProcess();
		parent.addChild(child);

		parent.fixedUpdate(1.0 / 60);

		Assert.equals(1, parent.ticks);
		Assert.equals(1, child.ticks);
	}

	function testPausingAParentAlsoPausesItsChildren():Void {
		var parent = new CountingProcess();
		var child = new CountingProcess();
		parent.addChild(child);
		parent.paused = true;

		parent.fixedUpdate(1.0 / 60);

		Assert.equals(0, parent.ticks);
		Assert.equals(0, child.ticks);
	}

	function testRemoveChildStopsItFromTicking():Void {
		var parent = new CountingProcess();
		var child = new CountingProcess();
		parent.addChild(child);
		parent.removeChild(child);

		parent.fixedUpdate(1.0 / 60);

		Assert.equals(1, parent.ticks);
		Assert.equals(0, child.ticks);
	}
}

/** Test-only Process that counts its own ticks. **/
private class CountingProcess extends Process {
	public var ticks:Int = 0;

	override function onFixedUpdate(dt:Float):Void {
		ticks++;
	}
}
