# Multi-Rule Glider Exploration (Option 2)

## Motivation

After exhaustively searching B2/S34h (hexagonal CA with birth at 2 neighbors, survival at 3-4), the 1-ring search found only shuttles, and the 2-ring search (`GeodesicGliderSearch2`) found one confirmed spaceship (`xq14_0ig5l3z102`, 12 cells) plus no other travelers in the 3-5 cell range.

This exploration tests whether **alternative hexagonal rulesets produce richer spaceship fauna** — that is, whether we gain meaningful structures by switching rules entirely, or whether B2/S34h's sparsity is fundamental to the hexagonal substrate.

## Candidates

### B24/S46 (Birth at 2,4; Survive at 4,6)

- **Source**: Research literature documents this rule producing **period-8 gliders with multi-unit-per-period movement** on hexagonal grids.
- **Structure expectation**: Richer than B2/S34h because birth conditions are looser (two separate thresholds instead of one), potentially supporting more diverse metastability.
- **Tradeoff**: May be noisier/denser; less well-studied in the sphaze context.

### B35/S2 (Birth at 3,5; Survive at 2)

- **Source**: Well-documented in standalone hexagonal CA research (GitHub hex-conway, hexlife implementations).
- **Structure expectation**: Known to support stable structures and moving patterns.
- **Tradeoff**: Different survival logic (only 2 neighbors) is a significant departure from B2/S34h's looser-survival philosophy.

## Methodology

`GeodesicGliderSearchMultiRule` runs the same exhaustive search across all three rules:

1. **Patch**: 2-ring neighborhood (center + neighbors' neighbors, up to 19 cells) on a frequency-10 geodesic sphere.
2. **Population range**: 3–5 cells per seed (smaller than `xq14_0ig5l3z102`'s 12-cell range, focusing on compact structures).
3. **Screening** (per rule): 40 generations, flag anything that shows periodic motion with drift ≥ 0.01 units.
4. **Confirmation** (per rule): 2000 generations, measure whether the centroid keeps trending away from spawn (vs. bounded shuttle behavior).

### Output format

```
--- Testing rule B24/S46 ---
Rule B24/S46: 1234 candidates → 45 screened → 12 confirmed travelers
  [B24/S46] pop=3 drift=0.042/step cells=[45,67,89]
  [B24/S46] pop=4 drift=0.031/step cells=[45,67,89,92]
  ...
```

Per-rule summary allows side-by-side comparison: how many candidates screen positive? How many confirm? What size/drift patterns do travelers show?

## Expected outcomes

### Scenario A: B24/S46 or B35/S2 are richer
- **Finding**: These rules produce more diverse/efficient spaceships than B2/S34h.
- **Action**: Consider adopting the richer rule for maze generation, re-run full ecosystem tests (wall openness, population stability) with the new rule.

### Scenario B: B24/S46 and B35/S2 have comparable or fewer travelers
- **Finding**: B2/S34h's sparsity is intrinsic to hexagonal geometry, not a limitation of the rule choice.
- **Action**: Embrace B2/S34h as the canonical rule; multi-biome option (different rules in different regions) becomes more interesting than rule-switching.

### Scenario C: No clear winner; different patterns emerge
- **Finding**: Each rule supports distinct structure types (e.g., B24/S46 gliders, B35/S2 oscillators) but none strictly dominates.
- **Action**: Multi-biome design becomes compelling — spawn different rule variants by region.

## Running the search

```bash
make search-gliders
```

The neko runtime will print results to stdout. Expect 1–2 minutes per rule (3 rules = ~5 min total) depending on machine and the number of candidates that screen positive.

## Implementation details

- **Multi-rule abstraction**: Each candidate is tested under all three rules in sequence; same `screen()` and `confirmTravels()` methods, parametrized on rule.
- **Drift rate calculation**: `confirmTravels()` now returns the averaged drift per checkpoint (distance / number of checkpoints) for finer-grained comparison of traveler speed.
- **No rule mutability assumptions**: Ensures both GeodesicGliderSearch2 (single-rule baseline) and this multi-rule variant can coexist.

## Next steps

1. Run `make search-gliders` and log the output.
2. Compare screened/confirmed counts and traveler drift profiles across rules.
3. If a richer rule emerges, decide: adopt it, or explore multi-biome?
