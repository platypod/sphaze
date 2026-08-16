package biomes.weft;

import biomes.common.grid.GridModel;
import biomes.common.grid.GridModel.GridData;
import biomes.common.grid.GridModel.GridNode;
import biomes.maze.MazeGenerator;
import utest.Assert;
import utest.Test;

/**
	Covers the pairing itself — the one authored thing in this space — and
	the invariant it exists to hold.

	None of it is visible. A pairing that quietly failed to be an
	involution would still toggle walls and still look like a working
	mechanic; it would simply mean the wall you opened at your antipode is
	not the one that answers to the wall you closed, and the player's
	model of the space would be wrong with nothing to correct it. The odd-
	column rows are the concrete case, and `testTheUnpairableRowsAreExactly
	TheOddColumnOnes` pins which rows those are rather than leaving it as
	an argument in a doc comment.
**/
class WeftModelTest extends Test {
	function key(node:GridNode):String {
		return GridModel.nodeKey(node);
	}

	function freshMaze():GridData {
		var seed = 12345;
		var maze = MazeGenerator.generate(() -> {
			seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
			return seed / 2147483648.0;
		});
		WeftModel.enforceOpposite(maze);
		return maze;
	}

	/** The poles answer to each other, which is the one pairing that needs no column arithmetic at all. **/
	function testThePolesArePaired():Void {
		Assert.equals(key(PoleNode(South)), key(WeftModel.antipodeOf(PoleNode(North))));
		Assert.equals(key(PoleNode(North)), key(WeftModel.antipodeOf(PoleNode(South))));
		Assert.isTrue(WeftModel.isPairable(PoleNode(North)));
		Assert.isTrue(WeftModel.isPairable(PoleNode(South)));
	}

	/** Where the pairing applies at all it is a genuine fixed-point-free involution: apply it twice and you are back, never where you started after one. **/
	function testPairingIsAnInvolutionWhereverItApplies():Void {
		var pairable = 0;
		for (node in GridModel.allNodes()) {
			if (!WeftModel.isPairable(node)) {
				continue;
			}
			pairable++;
			var partner = WeftModel.antipodeOf(node);
			Assert.notEquals(key(node), key(partner), 'node ${key(node)} is its own antipode');
			Assert.equals(key(node), key(WeftModel.antipodeOf(partner)), 'node ${key(node)} did not survive a round trip');
		}
		Assert.isTrue(pairable > 0, "nothing is pairable at all");
	}

	/**
		**Exactly the odd-column rows are unpairable**, and for the reason
		`WeftModel`'s doc gives: the antipodal map shifts a row by half its
		columns, which on an odd count lands on a cell boundary, and no
		fixed-point-free pairing of an odd number of cells exists anyway.
		Pinned here so that a future change to `GridModel.colsForRow` shows
		up as a failing test rather than as a silently larger dead zone.
	**/
	function testTheUnpairableRowsAreExactlyTheOddColumnOnes():Void {
		for (node in GridModel.allNodes()) {
			switch node {
				case PoleNode(_):
					Assert.isTrue(WeftModel.isPairable(node), "a pole should always pair");
				case RingNode(row, _):
					var oddRow = GridModel.colsForRow(row) % 2 != 0;
					Assert.equals(!oddRow, WeftModel.isPairable(node), 'row $row has ${GridModel.colsForRow(row)} columns; pairability disagrees');
			}
		}
	}

	/** A wall's partner is a real wall — the antipodal cells are genuinely adjacent, so the rule always names something that exists. **/
	function testEveryPartnerIsItselfARealWall():Void {
		var checked = 0;
		for (node in GridModel.allNodes()) {
			for (neighbor in GridModel.neighborsOf(node)) {
				var partner = WeftModel.partnerOf(node, neighbor);
				if (partner == null) {
					continue;
				}
				checked++;
				var adjacent = false;
				for (candidate in GridModel.neighborsOf(partner.a)) {
					if (key(candidate) == key(partner.b)) {
						adjacent = true;
					}
				}
				Assert.isTrue(adjacent, 'the partner of ${key(node)}-${key(neighbor)} is not an adjacent pair');
			}
		}
		Assert.isTrue(checked > 0, "no wall has a partner");
	}

	/** Pairing is symmetric: if this wall answers to that one, that one answers back. **/
	function testPartnershipIsMutual():Void {
		for (node in GridModel.allNodes()) {
			for (neighbor in GridModel.neighborsOf(node)) {
				var partner = WeftModel.partnerOf(node, neighbor);
				if (partner == null) {
					continue;
				}
				var back = WeftModel.partnerOf(partner.a, partner.b);
				Assert.notNull(back, 'the partner of ${key(node)}-${key(neighbor)} has no partner of its own');
				Assert.equals(GridModel.edgeKey(node, neighbor), GridModel.edgeKey(back.a, back.b), "partnership is not mutual");
			}
		}
	}

	/**
		**The invariant**: after `enforceOpposite`, no paired wall is ever
		in the same state as its partner. This is the rule the player will
		reason with, and it is the thing that would break silently.
	**/
	function testEnforceMakesEveryPairOpposite():Void {
		var maze = freshMaze();

		for (node in GridModel.allNodes()) {
			for (neighbor in GridModel.neighborsOf(node)) {
				var partner = WeftModel.partnerOf(node, neighbor);
				if (partner == null) {
					continue;
				}
				Assert.notEquals(GridModel.isOpen(maze, node, neighbor), GridModel.isOpen(maze, partner.a, partner.b),
					'${key(node)}-${key(neighbor)} matches its partner instead of opposing it');
			}
		}
	}

	/** **Closing a wall opens its partner**, which is the verb the whole space is built on. **/
	function testTogglingAWallFlipsItsPartnerTheOtherWay():Void {
		var maze = freshMaze();

		var acted = 0;
		for (node in GridModel.allNodes()) {
			for (neighbor in GridModel.neighborsOf(node)) {
				var partner = WeftModel.partnerOf(node, neighbor);
				if (partner == null || acted >= 40) {
					continue;
				}
				acted++;

				var wasOpen = GridModel.isOpen(maze, node, neighbor);
				Assert.isTrue(WeftModel.toggle(maze, node, neighbor), "a paired wall refused to toggle");

				Assert.equals(!wasOpen, GridModel.isOpen(maze, node, neighbor), "the wall itself did not flip");
				Assert.equals(wasOpen, GridModel.isOpen(maze, partner.a, partner.b), "the partner did not take the opposite state");
			}
		}
		Assert.isTrue(acted > 0, "no paired wall was found to toggle");
	}

	/** Toggling twice returns the whole sphere to where it started, so the player can always undo. **/
	function testTogglingTwiceRestoresBothWalls():Void {
		var maze = freshMaze();

		for (node in GridModel.allNodes()) {
			for (neighbor in GridModel.neighborsOf(node)) {
				var partner = WeftModel.partnerOf(node, neighbor);
				if (partner == null) {
					continue;
				}
				var before = GridModel.isOpen(maze, node, neighbor);
				var partnerBefore = GridModel.isOpen(maze, partner.a, partner.b);

				WeftModel.toggle(maze, node, neighbor);
				WeftModel.toggle(maze, node, neighbor);

				Assert.equals(before, GridModel.isOpen(maze, node, neighbor), "the wall did not come back");
				Assert.equals(partnerBefore, GridModel.isOpen(maze, partner.a, partner.b), "the partner did not come back");
				return;
			}
		}
		Assert.fail("no paired wall was found");
	}

	/** An unpaired wall is scenery: the rule declines to move it rather than moving it alone and breaking the invariant. **/
	function testAnUnpairedWallDoesNotToggle():Void {
		var maze = freshMaze();

		for (node in GridModel.allNodes()) {
			for (neighbor in GridModel.neighborsOf(node)) {
				if (WeftModel.isPaired(node, neighbor)) {
					continue;
				}
				var before = GridModel.isOpen(maze, node, neighbor);
				Assert.isFalse(WeftModel.toggle(maze, node, neighbor), "an unpaired wall reported a change");
				Assert.equals(before, GridModel.isOpen(maze, node, neighbor), "an unpaired wall moved anyway");
				return;
			}
		}
		Assert.pass(); // a grid with no unpaired walls at all would be fine too
	}
}
