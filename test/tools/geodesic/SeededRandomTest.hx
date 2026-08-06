package tools.geodesic;

import utest.Assert;
import utest.Test;

/**
	Guards the distribution properties `SeededRandom` exists for, because
	the generator it replaced passed every "does it compile / does it return
	a number" check while being catastrophically non-uniform on one of its
	two targets — and silently invalidated a whole round of measurements
	before anyone looked at its output. These assertions are what "looking
	at its output" turns into once it's a test.
**/
class SeededRandomTest extends Test {
	static inline final SAMPLES:Int = 20000;

	/** A mutation rate this small is exactly the case the old generator got wrong (it fired on ~50% of draws instead of 0.08%), so it's the case worth pinning. **/
	static inline final SMALL_THRESHOLD:Float = 0.0008;

	function testEveryDrawIsInRange():Void {
		var rng = new SeededRandom(1);
		for (_ in 0...SAMPLES) {
			var value = rng.next();
			if (value < 0 || value >= 1) {
				Assert.fail('draw out of [0, 1): $value');
				return;
			}
		}
		Assert.pass();
	}

	function testTheMeanIsAboutAHalf():Void {
		var rng = new SeededRandom(42);
		var total = 0.0;
		for (_ in 0...SAMPLES) {
			total += rng.next();
		}

		Assert.isTrue(Math.abs(total / SAMPLES - 0.5) < 0.02, 'mean was ${total / SAMPLES}');
	}

	/** A uniform generator puts a `p` share of its draws below `p`; the broken one put 74% below `0.24`. **/
	function testDrawsBelowAThresholdMatchThatThreshold():Void {
		var rng = new SeededRandom(3);
		var below = 0;
		for (_ in 0...SAMPLES) {
			if (rng.next() < 0.24) {
				below++;
			}
		}

		Assert.isTrue(Math.abs(below / SAMPLES - 0.24) < 0.02, 'share below 0.24 was ${below / SAMPLES}');
	}

	function testARareThresholdStaysRare():Void {
		var rng = new SeededRandom(7);
		var fired = 0;
		for (_ in 0...SAMPLES) {
			if (rng.next() < SMALL_THRESHOLD) {
				fired++;
			}
		}

		Assert.isTrue(fired < SAMPLES * 0.01, 'a $SMALL_THRESHOLD threshold fired $fired times in $SAMPLES draws');
	}

	function testTheSameSeedReplaysTheSameSequence():Void {
		var first = new SeededRandom(99);
		var second = new SeededRandom(99);
		for (_ in 0...100) {
			Assert.equals(first.next(), second.next());
		}
	}

	function testDifferentSeedsDiverge():Void {
		var first = new SeededRandom(1);
		var second = new SeededRandom(2);

		Assert.notEquals(first.next(), second.next());
	}

	/** A zero seed would freeze a multiplicative generator at zero forever. **/
	function testAZeroSeedStillProducesAVaryingSequence():Void {
		var rng = new SeededRandom(0);
		var first = rng.next();

		Assert.notEquals(first, rng.next());
	}
}
