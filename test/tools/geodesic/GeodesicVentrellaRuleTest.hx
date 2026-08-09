package tools.geodesic;

import tools.geodesic.GeodesicVentrellaRule.GeodesicVentrellaRules;
import utest.Assert;
import utest.Test;

/**
	`SPHERE_CA`'s own subrule table is hand-transcribed from a published
	figure (`GeodesicVentrellaRules`'s own doc), the one place in this port
	a single mistyped digit would silently change the automaton rather than
	fail to compile — this pins the shape invariants a transcription error
	is most likely to break, not the emergent behavior itself (that's
	`GeodesicVentrellaStateTest`'s job).
**/
class GeodesicVentrellaRuleTest extends Test {
	function testThereAreExactlyTwentySubrules():Void {
		Assert.equals(20, GeodesicVentrellaRules.SPHERE_CA.subrules.length);
	}

	function testEveryDigitIsWithinTheFourStateRange():Void {
		var states = GeodesicVentrellaRules.SPHERE_CA.states;
		for (i in 0...GeodesicVentrellaRules.SPHERE_CA.subrules.length) {
			var subrule = GeodesicVentrellaRules.SPHERE_CA.subrules[i];
			Assert.isTrue(subrule.referenceState >= 0 && subrule.referenceState < states,
				'subrule ${i + 1}: referenceState ${subrule.referenceState} out of range');
			Assert.isTrue(subrule.neighborState >= 0 && subrule.neighborState < states,
				'subrule ${i + 1}: neighborState ${subrule.neighborState} out of range');
			Assert.isTrue(subrule.resultState >= 0 && subrule.resultState < states, 'subrule ${i + 1}: resultState ${subrule.resultState} out of range');
			Assert.isTrue(subrule.neighborCount >= 0 && subrule.neighborCount <= GeodesicVentrellaRules.MAX_NEIGHBOR_COUNT,
				'subrule ${i + 1}: neighborCount ${subrule.neighborCount} out of range');
		}
	}

	/** The paper calls these two out by name as identical (both `1223`) — a transcription check as much as a rule-table one. **/
	function testSubrulesOneAndThreeAreIdenticalAsThePaperClaims():Void {
		var first = GeodesicVentrellaRules.SPHERE_CA.subrules[0];
		var third = GeodesicVentrellaRules.SPHERE_CA.subrules[2];
		Assert.equals(first.referenceState, third.referenceState);
		Assert.equals(first.neighborState, third.neighborState);
		Assert.equals(first.neighborCount, third.neighborCount);
		Assert.equals(first.resultState, third.resultState);
	}

	/** The paper's other named example: subrule 2's own result is always overwritten by subrule 8's, because both share the same `(referenceState, neighborState, neighborCount)` match condition and 8 is checked later. **/
	function testSubruleEightSharesSubruleTwosOwnMatchConditionAndComesLater():Void {
		var second = GeodesicVentrellaRules.SPHERE_CA.subrules[1];
		var eighth = GeodesicVentrellaRules.SPHERE_CA.subrules[7];
		Assert.equals(second.referenceState, eighth.referenceState);
		Assert.equals(second.neighborState, eighth.neighborState);
		Assert.equals(second.neighborCount, eighth.neighborCount);
		Assert.notEquals(second.resultState, eighth.resultState, "if these matched too, the paper's own example would be pointless");
	}
}
