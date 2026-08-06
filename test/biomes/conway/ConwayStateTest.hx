package biomes.conway;

import biomes.conway.ConwayMaze.ConwayMazeData;
import biomes.conway.ConwayMaze.ConwayNode;
import utest.Assert;
import utest.Test;

class ConwayStateTest extends Test {
	/**
		An isolated ring cell (no maze edges open anywhere) has zero live
		neighbors every generation, so a cell alive at the start dies on the
		first step and then stays dead — one flip, then quiet. `noMutation`
		pins out `ConwayState.MUTATION_RATE`'s randomness so this stays a pure
		B3/S23 check.
	**/
	function testActivityRisesOnAFlipAndDecaysOnceTheCellSettles():Void {
		var state = ConwayState.deserialize(haxe.Json.stringify({live: [ConwayGrid.keyOf(5, 10)], activity: []}));
		var maze:ConwayMazeData = {openEdges: new haxe.ds.StringMap(), coreEdges: new haxe.ds.StringMap()};

		state.step(maze, noMutation);
		var afterFlip = state.activityOf(5, 10);
		state.step(maze, noMutation);
		var afterSettling = state.activityOf(5, 10);

		Assert.isTrue(afterFlip > 0, 'expected the flip to raise activity above zero, got $afterFlip');
		Assert.isTrue(afterSettling < afterFlip, 'expected activity to decay once the cell stops flipping (got $afterSettling after $afterFlip)');
	}

	function testMutationCanFlipACellAgainstWhatTheRuleAloneWouldDo():Void {
		// An isolated dead cell has zero live neighbors, so plain B3/S23 keeps it dead forever.
		var state = ConwayState.deserialize(haxe.Json.stringify({live: [], activity: []}));
		var maze:ConwayMazeData = {openEdges: new haxe.ds.StringMap(), coreEdges: new haxe.ds.StringMap()};

		state.step(maze, alwaysMutate);

		Assert.isTrue(state.isAlive(5, 10), "a random() always under MUTATION_RATE should flip every cell's ruled state");
	}

	static function noMutation():Float {
		return 1; // never below ConwayState.MUTATION_RATE
	}

	static function alwaysMutate():Float {
		return 0; // always below ConwayState.MUTATION_RATE
	}

	/**
		`step` draws one `rng()` per ring cell and per pole (mutation) before
		ever reaching the structure-spawn roll — this stub returns `1`
		(never triggers mutation or the spawn roll) for those leading calls,
		then hands out `sequence` in order, so a test can pin exactly what
		the spawn roll/pattern/rotation/position draw without caring about
		the grid's own cell count.
	**/
	static function sequencedRandom(sequence:Array<Float>):Void->Float {
		var suppressCount = ConwayGrid.RING_ROWS * ConwayGrid.COLS + 2;
		var calls = 0;
		return () -> {
			var index = calls - suppressCount;
			calls++;
			return index >= 0 && index < sequence.length ? sequence[index] : 1;
		}
	}

	function testStructureSpawnStampsAKnownPatternWhenTriggered():Void {
		var maze:ConwayMazeData = {openEdges: new haxe.ds.StringMap(), coreEdges: new haxe.ds.StringMap()};
		var state = ConwayState.deserialize(haxe.Json.stringify({live: [], activity: []}));
		// Spawn trigger, pattern index 0 (GLIDER), rotation 0, anchor row 0, anchor col 0.
		var rng = sequencedRandom([0, 0, 0, 0, 0]);

		state.step(maze, rng);

		Assert.isTrue(state.isAlive(0, 1));
		Assert.isTrue(state.isAlive(1, 2));
		Assert.isTrue(state.isAlive(2, 0));
		Assert.isTrue(state.isAlive(2, 1));
		Assert.isTrue(state.isAlive(2, 2));
		Assert.floatEquals(1, state.activityOf(0, 1));
	}

	function testStructureSpawnNeverTriggersWhenRandomStaysAboveTheRate():Void {
		var maze:ConwayMazeData = {openEdges: new haxe.ds.StringMap(), coreEdges: new haxe.ds.StringMap()};
		var state = ConwayState.deserialize(haxe.Json.stringify({live: [], activity: []}));

		state.step(maze, noMutation); // 1 forever: no mutation, no spawn roll either

		Assert.isFalse(state.isAlive(0, 1));
	}

	function testSerializeRoundTripsActivity():Void {
		var state = ConwayState.deserialize(haxe.Json.stringify({
			live: [ConwayGrid.keyOf(1, 1)],
			activity: [{k: ConwayGrid.keyOf(2, 2), v: 0.42}]
		}));

		var restored = ConwayState.deserialize(state.serialize());

		Assert.isTrue(restored.isAlive(1, 1));
		Assert.floatEquals(0.42, restored.activityOf(2, 2));
	}

	/**
		A 2x2 "block" still life — the only maze edges open are the block's
		own four internal ones, so `ConwayGrid.liveNeighborCount`'s
		wall-gated influence gives each cell exactly 3 live neighbors
		(the other three cells in the block) every generation: a stable
		survivor, isolated from anything outside the block by the closed
		maze around it.
	**/
	static function blockMaze():ConwayMazeData {
		var openEdges = new haxe.ds.StringMap<Bool>();
		openEdges.set(ConwayMaze.edgeKey(RingNode(5, 10), RingNode(5, 11)), true);
		openEdges.set(ConwayMaze.edgeKey(RingNode(6, 10), RingNode(6, 11)), true);
		openEdges.set(ConwayMaze.edgeKey(RingNode(5, 10), RingNode(6, 10)), true);
		openEdges.set(ConwayMaze.edgeKey(RingNode(5, 11), RingNode(6, 11)), true);
		return {openEdges: openEdges, coreEdges: new haxe.ds.StringMap()};
	}

	function testAgeIncrementsEachGenerationACellSurvives():Void {
		var maze = blockMaze();
		var state = ConwayState.deserialize(haxe.Json.stringify({
			live: [
				ConwayGrid.keyOf(5, 10),
				ConwayGrid.keyOf(5, 11),
				ConwayGrid.keyOf(6, 10),
				ConwayGrid.keyOf(6, 11)
			],
			activity: []
		}));

		state.step(maze, noMutation);
		Assert.equals(1, state.ageOf(5, 10));
		state.step(maze, noMutation);
		Assert.equals(2, state.ageOf(5, 10));
		state.step(maze, noMutation);
		Assert.equals(3, state.ageOf(5, 10));
	}

	function testAgeIsZeroForACellThatIsNotAlive():Void {
		var state = ConwayState.deserialize(haxe.Json.stringify({live: [], activity: []}));

		Assert.equals(0, state.ageOf(5, 10));
	}

	/**
		An isolated cell (no maze edges open anywhere) has zero live
		neighbors, so it dies on the first step and stays dead — `justDied`
		should read true for exactly that one generation, not the one after.
	**/
	function testJustDiedIsTrueOnlyForTheGenerationACellActuallyDiesIn():Void {
		var maze:ConwayMazeData = {openEdges: new haxe.ds.StringMap(), coreEdges: new haxe.ds.StringMap()};
		var state = ConwayState.deserialize(haxe.Json.stringify({live: [ConwayGrid.keyOf(5, 10)], activity: []}));

		state.step(maze, noMutation);
		Assert.isTrue(state.justDiedAt(5, 10));
		state.step(maze, noMutation);
		Assert.isFalse(state.justDiedAt(5, 10));
	}

	function testStructureSpawnSetsAgeToOneForEveryStampedCell():Void {
		var maze:ConwayMazeData = {openEdges: new haxe.ds.StringMap(), coreEdges: new haxe.ds.StringMap()};
		var state = ConwayState.deserialize(haxe.Json.stringify({live: [], activity: []}));
		// Spawn trigger, pattern index 0 (GLIDER), rotation 0, anchor row 0, anchor col 0.
		var rng = sequencedRandom([0, 0, 0, 0, 0]);

		state.step(maze, rng);

		Assert.equals(1, state.ageOf(0, 1));
		Assert.equals(1, state.ageOf(2, 2));
	}

	function testSerializeRoundTripsAge():Void {
		var maze = blockMaze();
		var state = ConwayState.deserialize(haxe.Json.stringify({
			live: [
				ConwayGrid.keyOf(5, 10),
				ConwayGrid.keyOf(5, 11),
				ConwayGrid.keyOf(6, 10),
				ConwayGrid.keyOf(6, 11)
			],
			activity: []
		}));
		state.step(maze, noMutation);
		state.step(maze, noMutation);

		var restored = ConwayState.deserialize(state.serialize());

		Assert.equals(2, restored.ageOf(5, 10));
	}
}
