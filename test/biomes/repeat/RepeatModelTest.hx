package biomes.repeat;

import utest.Assert;
import utest.Test;

/**
	Covers the two properties the whole space's mechanic rests on:
	**every tile is identical**, and **the ones that are not differ in
	exactly one place, in the direction that opens ground**.

	Both are the kind of claim that cannot be checked by looking. A city
	where tiles differed subtly everywhere would look exactly like one
	where they were identical, right up until a player tried to use the
	comparison mechanic and found it meaningless — and a divergence that
	*added* a building instead of removing one would be a difference you
	can only look at, which the design specifically rules out because
	noticing and reaching must be the same act.
**/
class RepeatModelTest extends Test {
	/**
		**Every tile carries the same reference layout.** The generator
		takes only the plot's position within a tile — never the tile's own
		coordinates — so sameness is structural rather than something that
		has to be maintained. This checks it across a wide spread of tiles,
		ignoring divergences.
	**/
	function testEveryTileSharesTheSameReferenceLayout():Void {
		for (i in -6...7) {
			for (j in -6...7) {
				for (plotX in 0...RepeatModel.PLOTS_PER_TILE) {
					for (plotZ in 0...RepeatModel.PLOTS_PER_TILE) {
						var here = RepeatModel.hasBuilding(i, j, plotX, plotZ);
						var reference = RepeatModel.referenceHasBuilding(plotX, plotZ);
						var divergence = RepeatModel.divergenceOf(i, j);
						var isDiverged = divergence != null && divergence.plotX == plotX && divergence.plotZ == plotZ;

						Assert.equals(reference && !isDiverged, here, 'tile ($i, $j) plot ($plotX, $plotZ) does not follow the reference');
					}
				}
			}
		}
	}

	/**
		**A divergence only ever removes a building.** The design requires
		that recognising a difference and reaching new ground be the same
		act, which an added building would break — you would see it and
		have nowhere new to go.
	**/
	function testADivergenceAlwaysOpensGround():Void {
		var found = 0;
		for (i in -8...9) {
			for (j in -8...9) {
				var divergence = RepeatModel.divergenceOf(i, j);
				if (divergence == null) {
					continue;
				}
				found++;
				Assert.isTrue(RepeatModel.referenceHasBuilding(divergence.plotX, divergence.plotZ),
					'tile ($i, $j) diverges on a plot the reference leaves empty, so it opens nothing');
				Assert.isFalse(RepeatModel.hasBuilding(i, j, divergence.plotX, divergence.plotZ), 'tile ($i, $j) still has its diverged building standing');
			}
		}
		Assert.isTrue(found > 0, "no tile in a 17x17 block diverged at all");
	}

	/** A tile diverges in at most one place, so a comparison has a single answer rather than a list. **/
	function testATileDivergesInAtMostOnePlace():Void {
		for (i in -6...7) {
			for (j in -6...7) {
				var differences = 0;
				for (plotX in 0...RepeatModel.PLOTS_PER_TILE) {
					for (plotZ in 0...RepeatModel.PLOTS_PER_TILE) {
						if (RepeatModel.hasBuilding(i, j, plotX, plotZ) != RepeatModel.referenceHasBuilding(plotX, plotZ)) {
							differences++;
						}
					}
				}
				Assert.isTrue(differences <= 1, 'tile ($i, $j) diverged in $differences places');
			}
		}
	}

	/**
		Divergences are **common enough to find and rare enough to hunt**.
		A rate near zero makes a playtester conclude the mechanic is not
		implemented; a rate near one makes comparison pointless because
		every tile is special. Bounds rather than an exact figure, since
		the rate is explicitly a prototype value expected to be tuned.
	**/
	function testDivergencesAreNeitherEverywhereNorNowhere():Void {
		var total = 0;
		var diverged = 0;
		for (i in -12...13) {
			for (j in -12...13) {
				total++;
				if (RepeatModel.divergenceOf(i, j) != null) {
					diverged++;
				}
			}
		}
		var rate = diverged / total;
		Assert.isTrue(rate > 0.1, 'only $rate of tiles diverge — too rare to read as a mechanic');
		Assert.isTrue(rate < 0.6, '$rate of tiles diverge — too common for sameness to mean anything');
	}

	/** The layout is stable across calls, which every other guarantee here quietly depends on. **/
	function testTheGeneratorIsDeterministic():Void {
		for (plotX in 0...RepeatModel.PLOTS_PER_TILE) {
			for (plotZ in 0...RepeatModel.PLOTS_PER_TILE) {
				Assert.equals(RepeatModel.referenceHasBuilding(plotX, plotZ), RepeatModel.referenceHasBuilding(plotX, plotZ));
				Assert.floatEquals(RepeatModel.buildingHeight(plotX, plotZ), RepeatModel.buildingHeight(plotX, plotZ));
			}
		}
	}

	/** Not every plot is built on, or there would be no streets to walk down. **/
	function testTheCityHasStreets():Void {
		var empty = 0;
		for (plotX in 0...RepeatModel.PLOTS_PER_TILE) {
			for (plotZ in 0...RepeatModel.PLOTS_PER_TILE) {
				if (!RepeatModel.referenceHasBuilding(plotX, plotZ)) {
					empty++;
				}
			}
		}
		Assert.isTrue(empty > 0, "every plot is built on — the tile is a solid block");
		Assert.isTrue(empty < RepeatModel.PLOTS_PER_TILE * RepeatModel.PLOTS_PER_TILE, "no plot is built on — the tile is empty ground");
	}

	/** World position maps to the tile containing it, negatives included — where a naive integer cast would land a whole tile off. **/
	function testTileIndexingHandlesNegativePositions():Void {
		Assert.equals(0, RepeatModel.tileIndexAt(1, 1).i);
		Assert.equals(-1, RepeatModel.tileIndexAt(-1, -1).i);
		Assert.equals(-1, RepeatModel.tileIndexAt(-1, -1).j);
		Assert.equals(1, RepeatModel.tileIndexAt(RepeatModel.TILE_SIZE + 1, 0).i);
		Assert.equals(-2, RepeatModel.tileIndexAt(-RepeatModel.TILE_SIZE - 1, 0).i);
	}

	/** A plot's own centre falls in the tile it belongs to — the round trip collision and mesh building both rely on. **/
	function testPlotCentresLandInTheirOwnTile():Void {
		for (i in -3...4) {
			for (j in -3...4) {
				for (plotX in 0...RepeatModel.PLOTS_PER_TILE) {
					for (plotZ in 0...RepeatModel.PLOTS_PER_TILE) {
						var centre = RepeatModel.plotCentre(i, j, plotX, plotZ);
						var tile = RepeatModel.tileIndexAt(centre.x, centre.z);
						Assert.equals(i, tile.i, 'plot ($plotX, $plotZ) of tile ($i, $j) landed in tile ${tile.i}');
						Assert.equals(j, tile.j, 'plot ($plotX, $plotZ) of tile ($i, $j) landed in tile ${tile.j}');
					}
				}
			}
		}
	}
}
