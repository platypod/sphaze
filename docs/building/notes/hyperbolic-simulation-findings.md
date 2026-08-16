# Simulating a cellular automaton in hyperbolic space — first findings

Measured 2026-08-11, in the same session that produced
[../direction/](../../game/README.md). Written as a note rather than a
backlog entry because it carries two results that will otherwise be
rediscovered expensively: one encouraging, one that changes how the
Sprawl has to be built.

Method: generated a `{7,3}` patch with `geometry.HyperbolicTiling`, ran
outer-totalistic two-state rules over it with a fixed dead boundary,
seeded from a soup in the inner rings, 120 generations, scoring only
cells far enough from the edge to be unaffected by it. Exploratory probe,
not an exhaustive search — `|B| ≤ 2`, `|S| ≤ 3`, no `B0`.

## Finding 1 — the heptagrid sustains life easily *(encouraging)*

**972 of the sampled rules survived 120 generations without either dying
out or saturating**, and dozens changed population *every single
generation* across the whole measured window rather than settling into
still lifes.

That is a markedly better starting position than this project's history
on the hex sphere, where the recorded experience was that random soup
*"evaporates within a few dozen generations into scattered still lifes
and blinkers"* ([../ideas-backlog.md](../../open/ideas-backlog.md), 2026-07-29)
and where a multi-rule search found **zero** confirmed travellers across
2166 candidates.

The intuition for why is the same fact the whole direction rests on: with
seven neighbours and exponential neighbourhood growth, a cell has far
more ways to be supported, so the knife-edge between extinction and
explosion is much wider. Rules on `{7,3}` are, loosely, *easier to keep
alive*.

Sample of the highest-churn survivors, for whoever picks this up:

```
B23/S26   B12/S26   B12/S257   B27/S234   B13/S27   B12/S13
B13/S267  B1/S137   B1/S13     B12/S256   B23/S123  B14/S467
```

**What this does not show — and the confidence should be lower than the
headline suggests.** Three caveats, all real:

1. **Sustained churn is not a travelling structure.** No glider hunt has
   been run, and the harder question — *do compact, persistent,
   translating patterns exist in negative curvature?* — remains exactly as
   open as [../direction/roadmap.md](../roadmap.md) says.
2. **The scored region was tiny: 85 cells.** With a fixed dead boundary
   only two rings away, activity near the edge can leak inward and
   masquerade as sustained interior dynamics. A patch this small cannot
   distinguish "the rule is alive" from "the boundary is stirring it".
3. **The rule sample was restricted** (`|B| ≤ 2`, `|S| ≤ 3`, no `B0`) and
   the seed was a single soup at one density with one RNG seed. This is a
   probe, not a survey.

Treat finding 1 as *"promising enough to justify the real experiment"*,
not as *"{7,3} sustains life"*. The real experiment is the one finding 2
argues for: a compact surface, no boundary, several seeds, the full rule
space.

## Finding 2 — a finite hyperbolic patch is *mostly boundary* **(the one that bites)**

The patch used had **617 faces, of which only 85 were far enough from the
edge to score** — about 14%. Adding rings makes this *worse*, not better,
because ring populations grow by a factor of φ² ≈ 2.618 each step: the
outermost two rings always hold the large majority of the tiling.

This is not a tuning problem. It is the isoperimetric character of
hyperbolic space showing up as an engineering constraint, and it is the
same fact the design keeps calling **"everywhere is edge"**:

> In hyperbolic space you cannot simulate "a region and ignore its
> boundary", because there is no scale at which the boundary becomes
> negligible. Every finite patch is dominated by its own edge, forever.

Three ways out, in the order they should be considered:

1. **Use a compact hyperbolic surface instead of a patch — recommended.**
   A genus-2 surface is *finite, has no boundary at all, and is still
   negatively curved everywhere*. The boundary problem disappears by
   construction rather than being mitigated.

   The design already contains this: **The Knot**
   ([../direction/world-and-threads.md](../../game/world.md))
   is a genus-2 surface, filed there as a late-game exotic space. This
   finding promotes it — it is not only a good biome, it is *the*
   technically correct way to run a hyperbolic simulation. Strong
   candidate for building it **before** the Sprawl, contrary to the
   roadmap's current ordering.

   **The honest caveat**, which the design should own rather than gloss:
   the amenability argument in
   [../direction/README.md](../../game/README.md) is a statement about
   *infinite* groups. A compact surface has finitely many cells, so the
   strict theorem applies to its infinite universal cover, not to the
   finite thing being simulated. What survives on a compact surface is
   the *felt* geometry — exponential growth, no useful notion of
   "surrounded", up to the injectivity radius. For a game that is
   sufficient and arguably better; but the fiction should not claim more
   rigour than the object has, and higher genus buys more room before the
   wrap becomes noticeable.

2. **Absorb the boundary into the fiction.** A patch with a real edge, and
   the edge means something. Cheapest, and it wastes the geometry.

3. **Simply use bigger patches.** Fails: the cost is exponential and the
   *ratio* never improves. Recorded so nobody tries it twice.

## What to do next

- Run an actual travelling-structure search on the surviving rules,
  reusing the `GeodesicLifeReport`-style harnesses. Use a compact
  genus-2 surface, not a patch, so results are not boundary artefacts.
- Re-examine the roadmap's biome ordering in light of finding 2.
- Re-run finding 1 without the `|B| ≤ 2, |S| ≤ 3` restriction once there
  is a boundary-free substrate worth spending the compute on.
