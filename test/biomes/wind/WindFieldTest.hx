package biomes.wind;

import biomes.common.grid.GridModel;
import biomes.common.grid.GridModel.GridData;
import biomes.common.grid.GridModel.GridNode;
import biomes.common.space.sphere.SphereMath;
import utest.Assert;
import utest.Test;

/**
	The wind field's two load-bearing properties: it points *away* from the
	exit (so walking into the wind leads out), and it flows along corridors
	rather than through walls — which is the only reason it's a usable cue
	rather than a compass.
**/
class WindFieldTest extends Test {
	/** Two cells side by side in one row, connected: the draft at the far cell should blow away from the exit cell. **/
	function testWindBlowsAwayFromTheExit():Void {
		var exit = RingNode(7, 0);
		var neighbor = RingNode(7, 1);
		var field = new WindField(mazeWith([{a: exit, b: neighbor}]), exit);

		var direction = field.sampleAt(positionOf(neighbor)).dir;
		var awayFromExit = towardFrom(exit, neighbor);

		Assert.isTrue(direction.dot(awayFromExit) > 0,
			'wind at the neighbouring cell should point away from the exit (dot was ${direction.dot(awayFromExit)})');
	}

	/** The field is a unit tangent — anything else makes the shader's own sway either wrong or NaN. **/
	function testDirectionIsAUnitTangent():Void {
		var exit = RingNode(7, 0);
		var neighbor = RingNode(7, 1);
		var field = new WindField(mazeWith([{a: exit, b: neighbor}]), exit);

		var pos = positionOf(neighbor);
		var direction = field.sampleAt(pos).dir;

		Assert.floatEquals(1, direction.length());
		Assert.floatEquals(0, direction.dot(pos.normalized()));
	}

	/**
		A cell that's adjacent on the grid but *walled off* from the exit must
		get no draft from it — the flood only crosses open edges. Checked by
		walling everything: with no open edges at all, every cell but the exit
		is unreachable, and the field falls back rather than inventing a
		direction.
	**/
	function testWalledOffCellsGetNoDraftFromTheExit():Void {
		var exit = RingNode(7, 0);
		var neighbor = RingNode(7, 1);
		var open = new WindField(mazeWith([{a: exit, b: neighbor}]), exit).sampleAt(positionOf(neighbor)).dir;
		var walled = new WindField(mazeWith([]), exit).sampleAt(positionOf(neighbor)).dir;

		Assert.isFalse(open.x == walled.x && open.y == walled.y && open.z == walled.z, "a walled-off cell should not get the same draft as a connected one");
	}

	/** Down a straight corridor, every cell gets a draft — the flood doesn't stop one step out. **/
	function testDraftReachesDownAWholeCorridor():Void {
		var cells = [for (col in 0...5) RingNode(7, col)];
		var edges = [for (col in 0...4) {a: cells[col], b: cells[col + 1]}];
		var field = new WindField(mazeWith(edges), cells[0]);

		for (col in 1...5) {
			var direction = field.sampleAt(positionOf(cells[col])).dir;
			Assert.floatEquals(1, direction.length(), 'no draft at corridor cell $col');
		}
	}

	/**
		The gust phase has to *increase* step by step away from the exit — that
		monotonic ramp is what makes the sway a wave travelling downwind, and
		without it the field conveys an axis but no direction (which is exactly
		how the first version of this biome ended up showing nothing readable).
	**/
	function testFlowPhaseRisesStepByStepAwayFromTheExit():Void {
		var cells = [for (col in 0...5) RingNode(7, col)];
		var edges = [for (col in 0...4) {a: cells[col], b: cells[col + 1]}];
		var field = new WindField(mazeWith(edges), cells[0]);

		var previous = -1.0;
		for (col in 0...5) {
			var phase = field.sampleAt(positionOf(cells[col])).flowPosition;
			Assert.isTrue(phase > previous, 'phase should rise with distance from the exit; cell $col gave $phase after $previous');
			Assert.floatEquals(col * WindField.PHASE_PER_STEP, phase);
			previous = phase;
		}
	}

	static function mazeWith(edges:Array<{a:GridNode, b:GridNode}>):GridData {
		var openEdges = new haxe.ds.StringMap<Bool>();
		for (edge in edges) {
			openEdges.set(GridModel.edgeKey(edge.a, edge.b), true);
		}
		return {openEdges: openEdges};
	}

	static function positionOf(node:GridNode):h3d.Vector {
		var centre = GridModel.centerOf(node);
		return SphereMath.sphericalToCartesian(1, centre.theta, centre.phi);
	}

	/** A tangent at `to` pointing away from `from` — what "downwind" means one cell out from the exit. **/
	static function towardFrom(from:GridNode, to:GridNode):h3d.Vector {
		var pos = positionOf(to);
		var posDir = pos.normalized();
		var chord = pos.sub(positionOf(from));
		return chord.sub(posDir.scaled(chord.dot(posDir))).normalized();
	}
}
