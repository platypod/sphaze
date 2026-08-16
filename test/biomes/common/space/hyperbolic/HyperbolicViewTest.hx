package biomes.common.space.hyperbolic;

import geometry.Isometry;
import utest.Assert;
import utest.Test;

/**
	Checks the `pos`/`forward` ↔ isometry bridge in both directions.

	The load-bearing test here is `testRoundTripsThroughAnArbitraryFrame`:
	it asserts that reading a frame's position and facing and rebuilding a
	frame from them returns the *same matrix*, for frames built by walking
	and turning arbitrarily far from the origin. That single property
	catches every sign convention, every column ordering and every
	normalisation mistake this class could make at once — which matters,
	because a wrong sign here would not crash, it would render a world
	that is mirrored or rotated and otherwise entirely plausible. The
	mirrored-controls bug in the Phase 0 harness was exactly this class of
	error, and every test that existed at the time passed straight through
	it.
**/
class HyperbolicViewTest extends Test {
	static inline final EPSILON:Float = 1e-9;
	static inline final RADIUS:Float = 1.0;

	/** A spread of frames reached by different combinations of walking and turning, including far enough out that a boost's entries are large. **/
	function sampleFrames():Array<Isometry> {
		return [
			Isometry.identity(),
			Isometry.translation(Hyperbolic, 0.8),
			Isometry.rotation(0.7),
			Isometry.compose(Isometry.translation(Hyperbolic, 1.3), Isometry.rotation(-2.1)),
			Isometry.compose(Isometry.compose(Isometry.rotation(0.4), Isometry.translation(Hyperbolic, 2.5)), Isometry.rotation(1.9)),
			Isometry.compose(Isometry.translation(Hyperbolic, 4.0), Isometry.compose(Isometry.rotation(2.8), Isometry.translation(Hyperbolic, 3.0))),
		];
	}

	function positionOf(frame:Isometry):h3d.Vector {
		var p = Isometry.positionOf(frame);
		return new h3d.Vector(p.x, p.y, p.z);
	}

	/** A frame's facing is the image of the `+x` tangent — its own first column. **/
	function forwardOf(frame:Isometry):h3d.Vector {
		return new h3d.Vector(frame.m[0], frame.m[3], frame.m[6]);
	}

	function assertSameMatrix(expected:Isometry, actual:Isometry, tolerance:Float, message:String):Void {
		for (i in 0...9) {
			Assert.floatEquals(expected.m[i], actual.m[i], tolerance, '$message (entry $i)');
		}
	}

	/** Standing at the origin facing `+x` is, by definition, the frame that changes nothing. **/
	function testTheOriginFacingForwardIsTheIdentity():Void {
		var frame = HyperbolicView.frameOf(new h3d.Vector(0, 0, 1), new h3d.Vector(1, 0, 0), RADIUS);
		assertSameMatrix(Isometry.identity(), frame, EPSILON, "the origin facing +x should be the identity");
	}

	/**
		**Reading a frame and rebuilding it returns the same frame** — the
		property that pins down every convention in the class at once. See
		the class doc for why this one carries the weight.
	**/
	function testRoundTripsThroughAnArbitraryFrame():Void {
		for (i => frame in sampleFrames()) {
			var rebuilt = HyperbolicView.frameOf(positionOf(frame), forwardOf(frame), RADIUS);
			assertSameMatrix(frame, rebuilt, 1e-7, 'frame $i did not survive the round trip');
		}
	}

	/** The Minkowski adjoint really is the inverse, however far out the frame sits. **/
	function testInvertUndoesAFrame():Void {
		for (i => frame in sampleFrames()) {
			assertSameMatrix(Isometry.identity(), Isometry.compose(frame, HyperbolicView.invert(frame)), 1e-7,
				'frame $i times its inverse is not the identity');
			assertSameMatrix(Isometry.identity(), Isometry.compose(HyperbolicView.invert(frame), frame), 1e-7, 'inverse times frame $i is not the identity');
		}
	}

	/** The view puts the camera at the model origin — the invariant the whole rendering approach rests on. **/
	function testTheViewMapsThePlayerToTheOrigin():Void {
		for (i => frame in sampleFrames()) {
			var view = HyperbolicView.viewOf(positionOf(frame), forwardOf(frame), RADIUS);
			var seen = Isometry.apply(view, {x: frame.m[2], y: frame.m[5], z: frame.m[8]});

			Assert.floatEquals(0, seen.x, 1e-7, 'frame $i is not at the camera origin');
			Assert.floatEquals(0, seen.y, 1e-7, 'frame $i is not at the camera origin');
			Assert.floatEquals(1, seen.z, 1e-7, 'frame $i is not at the camera origin');
		}
	}

	/**
		**Agrees with `geometry.HyperbolicWalker`**, which is independently
		tested and is what the validated Phase 0 room actually walks with.
		Two representations of the same motion — one tracking the view and
		never inverting, one tracking `pos`/`forward` and inverting here —
		must produce the same view matrix, or the Sprawl will not look like
		the room you already played.
	**/
	function testAgreesWithTheWalkerOnAStraightWalk():Void {
		var space = new HyperbolicSpace(RADIUS);
		var pos = new h3d.Vector(0, 0, 1);
		var forward = new h3d.Vector(1, 0, 0);
		var walker = new geometry.HyperbolicWalker();

		for (step in 0...6) {
			var moved = space.moveAlong(pos, forward, forward, 0.7, RADIUS);
			pos = moved.pos;
			forward = moved.forward;
			walker.moveForward(0.7);

			assertSameMatrix(walker.view, HyperbolicView.viewOf(pos, forward, RADIUS), 1e-7, 'views disagree after step $step');
		}
	}

	/** `radius` is honoured, so a biome can pick its own scale the way `HyperbolicSpace` already lets it. **/
	function testScalesWithTheRadius():Void {
		var scaled = HyperbolicView.frameOf(new h3d.Vector(0, 0, 40), new h3d.Vector(1, 0, 0), 40.0);
		assertSameMatrix(Isometry.identity(), scaled, EPSILON, "a scaled origin should still be the identity");
	}
}
