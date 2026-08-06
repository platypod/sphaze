# Note — geodesic sphere for Conway: shape, rules, lookup, pentagons

Engineering answer to the design conversation on 2026-08-04 about replacing
`biomes.conway`'s lat/long grid (cells shrink toward the poles, `sin(theta)`
distortion) with a hexagon-based geodesic sphere, embracing rather than hiding
the 12 pentagons a sphere always forces. Lives here rather than in
[ideas-backlog.md](../ideas-backlog.md) for the same reason
[the rule-driven walls note](rule-driven-walls-engineering.md) does — this is
about the code, not the pitch; the backlog entry links here.

## Construction: icosahedral subdivision → Goldberg dual

Start from a regular icosahedron (12 vertices, 20 triangular faces). Subdivide
each face by a frequency `f`, project the new points onto the sphere, then take
the *dual* — each original vertex becomes a cell, each face becomes a vertex of
the dual. The result (a Goldberg polyhedron) has exactly 12 pentagons, always,
regardless of `f` — Euler's formula forces it (V - E + F = 2 has no all-hexagon
solution on a sphere) — plus `10f²` hexagons everywhere else. Total faces
`10f² + 2`.

`f` is the one density knob, independent of the topology choice: `f = 2` gives
42 cells (too coarse to be a maze), `f ≈ 11` gives ~1212 cells, in the same
range as today's ~1234-cell lat/long grid. Pick `f` to match the pacing we
want, not the other way around.

Two things worth confirming empirically once this is built, not assumed: the
12 pentagons from an icosahedral construction are always mutually
non-adjacent for any `f ≥ 2` (they sit at the original icosahedron's own
vertices, which are never neighbors of each other past `f = 1`) — good, that's
free spacing for a "beacon" mechanic without extra work. Higher Goldberg
*classes* (chiral subdivisions, `GP(m, n)` with `n > 0`, "twisted" rather than
straight) trade a small amount of extra construction complexity for
slightly more uniform cell shapes at the same `f` — worth generating a few
class variants and comparing, not assuming class I (`n = 0`, the simple case)
is automatically the roundest option.

## Generate → score → bake, not lazy-on-boot

Raised directly: auto-generate candidate spheres, evaluate them against
criteria we define, and bake the winner into a checked-in data asset at build
time — not computed live on first boot.

- **Generator**: produces one candidate sphere from parameters (`f`, Goldberg
  class/chirality, maybe a maze-carve seed layered on top for a full "ready to
  ship" instance rather than bare topology).
- **Criteria** (a starting list — this is exactly what "we will define" means,
  refine before building): total cell count within a target pacing range; cell
  area / edge-length variance below some threshold (uniformity is the whole
  point of leaving lat/long); the 12 pentagons mutually non-adjacent (should
  be free per above, but verify rather than assume); topology sanity (fully
  connected, matches the expected `10f² + 2` face count exactly — a
  malformed subdivision is a build-breaking bug, not a runtime one to
  discover later).
- **Bake target**: a `make` target in the same family as the existing
  `fmt`/`lint`/`check`/`test`/`build` ones, running generate → score → pick →
  serialize. Output is a JSON asset (node positions, adjacency, per-face
  lookup table — see below), checked in and loaded through `hxd.Res` like
  every other asset this project uses, per `CLAUDE.md`'s own "gameplay data
  lives in external data, not hardcoded in classes" rule. `ConwayGrid`'s
  current closed-form `nodeAt(theta, phi)` formula has no equivalent on an
  irregular graph anyway, so this isn't fighting the architecture to get
  there — the data-driven approach is the only approach.

## Life rule candidates for a 6-neighbor grid

B3/S23 doesn't transfer as-is: it's defined on a Moore (8-neighbor) grid, and
a hexagon has 6 neighbors with no diagonal/orthogonal distinction to begin
with. This needs its own rule, not a straight port — flagged honestly rather
than assumed to "just work" the way the maze-carving side does.

**A principled way to generate starting candidates**: scale B3/S23's own
thresholds by the same neighbor-count ratio (6/8 = 0.75) rather than guessing
blind. B3/S23 births at 3/8 (37.5%) of neighbors and survives at 2-3/8
(25-37.5%). Scaled to 6 neighbors: birth ≈ 2.25 → round to `B2`; survive ≈
1.5-2.25 → round to `S2` or `S23`. That gives a small, defensible candidate
set to actually try, not a definitive answer — whether any of these produces
gliders/oscillators at all is not guaranteed by the math and has to be
watched, the same way every Life-like automaton's actual behavior is
discovered empirically rather than derived:

| Candidate | Reasoning |
|---|---|
| `B2/S23` | The direct proportional scaling above — **best first candidate**, since it's the least arbitrary of the set. |
| `B2/S3` | Tighter survival — likely sparser, more oscillator-heavy. |
| `B2/S34` | Looser survival — likely denser, more stable-structure-heavy. |
| `B3/S34` | Higher birth threshold — a control for "what if birth should scale differently than survival." |

> **Resolved in Phase 5 of the build order below — read that entry before
> this table.** `B2/S23` is confirmed as the pick, but not for the reason
> given here, and the more important finding is that maze *openness*, not
> the rule, is what decides whether this biome lives at all. The first
> comparison run also reached a confident wrong answer off a broken
> randomness source; that story is worth reading before trusting any
> measurement in this note.

**Recommendation** (original, kept for the record): start with `B2/S23`, the proportional-scaling result, and
build a small headless harness (a `utest` case that runs N generations from a
few seed densities and reports population-over-time / whether anything moves)
to actually compare the four before committing — the same "prototype unproven
mechanics before committing" pillar that `ConwayState.MUTATION_RATE` and the
structure-spawner already leaned on for the square grid, and hex Life is
genuinely less charted territory than square Life, so this matters more here,
not less.

## Position → cell lookup: solved, not brute force

Good news: this is not a new problem. It's exactly what Uber's H3 library
does — a hexagonal hierarchical spatial index built on an icosahedron,
production-tested at global scale — so the approach below isn't a novel
invention, it's known-good prior art adapted to our own baked data.

**Three fixed-cost steps, not a scan over cell count:**

1. **Nearest icosahedral face.** Only 20 faces exist, regardless of `f` — so
   this step's cost never grows with grid resolution. Precompute the 20 face
   center unit vectors as part of the baked data; finding the nearest one to
   a query point is ≤20 dot products. Compare that to today's
   `ConwayGrid.nodeAt` doing a handful of trig operations — same order of
   cost, not a scan of ~1200 cells.
2. **Local face coordinates.** Once the face is known, gnomonically project
   the query point onto that face's own plane and read off barycentric-style
   coordinates within it — closed-form linear algebra, the direct analog of
   how `nodeAt` today turns `(theta, phi)` into `(row, col)` via a formula,
   just done per-face instead of globally.
3. **`(face, local coords) → node id`.** A lookup table, part of the same
   baked data — O(1) array/hash access.

Total: effectively constant-time per query, independent of `f`. The one
real implementation detail to work out carefully (not blocking, but not
hand-waved either) is face-boundary handling — a query point exactly on a
seam between two icosahedral faces needs a consistent tie-break so it never
reads as "no face," the same class of edge case `ConwayGrid.nodeAt`'s own
`row`/`col` clamping already handles today for the lat/long grid's own
boundaries.

## Pentagon rule: a pluggable per-node behavior, not a special case bolted on

Raised directly: "a pulsing beacon — visually a tall column of light with no
hitbox, technically a cell that comes to life every few ticks," with the rule
itself modeled as something swappable per-pentagon later ("we will see later
if we also include another mechanic on top, or instead of that one for some
pentagons").

That "anticipate it" ask is the actual design requirement, more than the
beacon itself: **a cell's simulation rule needs to be data, addressed
per-node, not one universal function every node shares.** Concretely, a
`CellRule` a node is assigned (baked into the same per-instance data as
positions/adjacency, so picking a pentagon's rule is a data change, not a
code change):

- **`LifeRule`** (default, hexagons): the neighbor-count B/S rule above.
- **`BeaconRule`** (pentagons, to start): ignores neighbors entirely, alive
  for one generation every `N` generations on its own fixed clock — a
  landmark, not a participant in the surrounding automaton. `N` and phase are
  themselves per-node data, so 12 beacons could desync from each other for
  free if that reads better than a synchronized pulse.

Visually, a `BeaconRule` cell needs its own mesh treatment distinct from an
ordinary live block — a vertical light column rather than a raised standable
block, and explicitly *no* collision height (`groundHeightAt`-equivalent
returns `0` for it always) — a beacon is seen, not stood on.

This also happens to fit
[inspirations.md](../inspirations.md)'s own rule directly: *"a biome's
mechanic should be a corollary of the sphere, not a decoration on it."* The
12 pentagons aren't a design choice being dressed up with a mechanic after
the fact — they're forced by the sphere's own topology (Euler's formula), and
the beacon rule is what happens when that forced structure is read as
signal instead of defect.

## Refinement pass (2026-08-04) — what got sharper, nothing disqualifying

Traced every current Conway file for `(row, col)` coupling before scoping a
build order, rather than assuming `ConwayGrid.nodeAt` was the only thing that
changes:

- **The blast radius is real but concentrated.** 7 of the 8 files
  (`ConwayGrid`, `ConwayMaze`, `ConwayTopology`, `ConwayMazeReactivity`,
  `ConwayMesh`, `ConwaySeedLibrary`, `ConwayState`) touch row/col somewhere.
  But `ConwayCollision` and `ConwayBiome` — the two that talk to the player
  and the rest of the game — only ever go through `ConwayGrid.nodeAt`/
  `groundHeightAt`/`cornerAt`/`RADIUS` and never see a row or column
  directly. Same "one chokepoint" shape the wall-reactivity work already
  leaned on: the rewrite is concentrated in the grid/mesh/state layer, not
  scattered through everything that layer feeds.
- **`ConwaySeedLibrary`'s four patterns don't port.** Glider/LWSS/R-pentomino/
  acorn are literal row/col offsets tuned for a square Moore-8 lattice and
  B3/S23 specifically — not "a hex version of the same shape." Finding
  hex-native equivalents (if any exist) is its own research task, gated on
  the Life-rule prototype below, not bundled into the grid switch.
- **Nothing else changed the verdict.** Movement itself
  (`PlayerModel.moveAlong`/`SphereSpace`) is already topology-independent —
  cells only gate collision/gravity/wall queries, never how the player
  actually moves across the sphere — so switching grids touches none of
  that. And "see far, not near" gets *better*, not worse: hexagons stay
  roughly the same apparent size at any distance, where lat/long wedges
  currently pinch toward a point at the poles.

## Build order

Dependency-ordered — each phase either has no gameplay logic riding on it yet
(so it can be checked visually/numerically in isolation) or explicitly says
what it's waiting on.

1. **Topology + data model — built 2026-08-04.** `tools.geodesic`
   (`Icosahedron`, `GeodesicSphere`, `GeodesicValidator`, `GeodesicBake`):
   plain integer node ids and an adjacency list, not `ConwayNode`'s
   row/col-coupled enum. The subdivision-and-weld construction turned out
   not to need an explicit "take the dual" step at all — see
   `GeodesicSphere`'s own class doc for why cell *adjacency* is already
   identical to the triangulated mesh's own vertex-adjacency graph, which
   simplified this phase considerably. `GeodesicTopology` implements
   `biomes.common.maze.MazeTopology` directly against baked data — proof,
   not just a claim, that the maze carvers need nothing new. Baked once via
   `make bake-geodesic` (a new `bake.hxml`/neko target, since writing a
   file needs `sys.io.File` and the usual `-js` target doesn't have it) to
   `res/geodesic/conway-sphere.json` — 1212 nodes at the chosen frequency
   `11`, matching the exit check exactly (`10 × 11² + 2 = 1212`), 12
   pentagons of degree 5, 1200 hexagons of degree 6, all mutually
   non-adjacent. `GeodesicValidator` runs these checks (plus full
   connectivity) both in `GeodesicBake` itself and in `GeodesicValidatorTest`;
   `IcosahedronTest` separately confirms the hand-transcribed base
   icosahedron is topologically sound (every vertex touches exactly 5
   faces) rather than trusting the transcription on faith.
2. **Position → cell lookup — built 2026-08-04.** `GeodesicLookup`. Two
   real corrections found while actually building it, past what this note
   originally scoped:
   - Checking only the single nearest-by-face-center face has a genuine
     correctness gap at seams; this checks all 20 faces' own candidate
     and keeps whichever is truly closest in 3D. Still bounded cost (`20`
     faces), never `O(node count)` — the complexity property holds, the
     "check one face" optimism just didn't.
   - Rounding gnomonic-projected barycentric weights to the nearest grid
     index isn't the same as finding the true nearest node — barycentric
     space and the sphere's curved surface aren't linearly related after
     `GeodesicSphere.barycentricPoint`'s own normalize step. Caught by
     `GeodesicLookupTest`: a shared edge's own midpoint resolved to a
     third, objectively farther node, because neither real endpoint was
     ever generated as a candidate. Fixed by also checking the rounded
     point's own immediate 6-neighbor ring, not just the single rounded
     point — still `O(20 × 7)`, a fixed constant, not a search.

   Exit checks, both passing: every node's own stored position resolves
   back to itself (`testEveryNodesOwnPositionResolvesToItself`), and a
   dense sweep (37×53 points) across arbitrary directions never throws —
   the still-open "face-boundary tie-break" this note flagged is now
   resolved for real, not just planned for.
3. **Static rendering — built 2026-08-04, exit check confirmed visually.**
   Two pieces, not one:
   - `GeodesicDual`: the actual hexagon/pentagon boundary polygons
     `GeodesicSphere` deliberately deferred in Phase 1 — one node's own
     ring of neighbors walked in cyclic order (`cyclicNeighbors`), each
     consecutive pair's *circumcenter* (not the simpler centroid — see
     `cellBoundary`'s own doc) one polygon vertex. Found and fixed while
     testing: the centroid version failed a real invariant
     (`GeodesicDualTest`) — a boundary point could sit measurably closer
     to a *neighboring* cell's own center than to the cell it was
     supposed to be a corner of, worst right around pentagons, which
     matter most here. Circumcenter fixed it outright (equidistant from
     the two ring-neighbors forming each corner, by definition).
   - `GeodesicPreview`: a genuinely standalone visual harness (its own
     `preview.hxml`/`geodesic-preview.html`/`make preview-geodesic`,
     never referenced from `Main`/`GameLoop`) — no Life, no walls, no
     maze, no player, just every cell as a flat inset polygon, hexagons
     and pentagons in two colors. Screenshotted directly (this doesn't
     need a running game or keyboard input, just a fixed camera): reads
     unambiguously as a sphere of hexagons with 12 evenly-scattered
     pentagon defects. One rendering artifact chased down before trusting
     the result — cells right at the sphere's own silhouette (viewed
     nearly edge-on) rendered as self-intersecting slivers at first;
     confirmed via `GeodesicDualTest`'s own boundary-angle math that this
     was never a data bug (every pentagon's own boundary is a perfectly
     regular, monotonically-wound polygon) before writing it off as an
     expected flat-facet-at-a-grazing-angle artifact — one that's also
     irrelevant to the real game regardless, since the sphere gets walked
     from *inside* at close range, never viewed as a distant silhouette
     from outside.
4. **Collision + movement — built 2026-08-04.** `GeodesicCollision`, the
   `ConwayCollision` counterpart the phase-1-4 sequencing anticipated —
   and it was small, confirming the chokepoint finding: `PlayerModel`
   position → `GeodesicLookup.nodeAt` → same-node-or-`MazeEdges.isOpen`,
   revert if neither. Deliberately no wall-height/jump gate yet — that's
   tied to a live cell's own standable height, which doesn't exist until
   Phase 5. No `groundHeightAt`-equivalent needed either: nothing stands
   above the floor yet, so `biomes.common.Gravity.fallToSurface` at
   `groundHeight = 0` is already everything Phase 4 needs — genuinely
   nothing to port there until Phase 5 adds standable cells.

   Exit check honestly can't be *walked* the literal way it's worded —
   this project's own `CLAUDE.md` already documents that Claude can't
   reliably drive keyboard input in its own browser preview, and
   `GeodesicPreview` has no player or input handling to begin with. Two
   things stand in for that: `GeodesicCollisionTest` calls
   `GeodesicCollision.tryMove` directly against a real carved maze
   (`GeodesicTopology` + `MazeCarver`) and asserts blocked-on-closed/
   allowed-on-open/allowed-within-node — the exact same way
   `biomes.conway.ConwayCollisionTest` already verifies the *existing*
   grid's own collision, without live walking either. And
   `GeodesicPreview` now renders that same carved maze's own closed edges
   as raised ticks alongside Phase 3's hex/pentagon tiles — visual
   confirmation a real maze (not noise) came out the other end, screenshotted
   directly. Roughly two-thirds of all edges close in a perfect maze over
   this graph (average degree `~6`, only `nodes - 1` of `~3 * nodes` total
   edges survive the carve) — expected density, not a bug; the tick
   styling needed tuning down once (`WALL_HALF_WIDTH`/`WALL_HEIGHT_FRACTION`)
   so that density didn't visually swamp the hexagon pattern underneath.
5. **Life simulation — built 2026-08-05.** `GeodesicLifeRule`
   (`GeodesicLifeRules`, the four candidates from this note's own table
   above as plain data) and `GeodesicLifeState` — `ConwayState` generalized
   to key by node id, neighbor-counting against baked adjacency +
   `MazeEdges.isOpen` wall-gating instead of the square grid's Moore
   formula. Activity decay, age tracking, `justDied`, and mutation rate all
   ported unchanged in spirit — only the address type (`Int` node id vs.
   `"cell:row:col"`) and neighbor source actually differ.

   The headless comparison harness this phase called for
   (`GeodesicLifeReport`, a one-off tool run by hand — not part of
   `test.hxml`/the bake pipeline, the same way a throwaway analysis script
   wouldn't be) was **built, run, believed, and then found to be measuring
   nothing.** Its first version concluded all four rules were
   statistically indistinguishable, all settling into a noisy ~50%
   equilibrium. That conclusion was an artifact of its own randomness
   source: it runs on neko, and the xorshift32 it borrowed from
   `test.biomes.maze.MazeGeneratorTest` returns *negative, non-uniform*
   values there (neko's `Int` is 31-bit, so `>>> 0` never yields an
   unsigned 32-bit value). Measured: mean `0` instead of `0.5`, 50% of
   draws negative, 74% below `0.24`. So `rng() < MUTATION_RATE` fired on
   about half of all nodes every generation instead of `0.08%`, and all
   four rules were being measured as the same coin flip. The tell was
   visible in the output the whole time and went unread — a seed density
   of `0.24` was producing 50% of nodes alive.

   Fixed with `tools.geodesic.SeededRandom` (Park-Miller LCG evaluated in
   `Float`, so no target's integer width can change the sequence;
   `SeededRandomTest` now pins its distribution). Re-run over five board
   seeds, the honest picture is very different, and *two* things came out
   of it:

   **The rules are not close.** Mean live share once settled, on a fully
   open board: `B2/S23` `54.9%`, `B2/S34` `2.1%`, `B2/S3` `1.5%`,
   `B3/S34` `0.5%`. `B2/S23` is the only candidate that sustains a
   population at all. It stays the pick, but now on evidence rather than
   for being the least arbitrary.

   **The rule was never the binding constraint — maze openness is.** The
   original scoping treated "which rule" and "what the maze looks like" as
   independent questions. They aren't. Mean live share, by rule and by
   what share of non-core edges are open on top of the carve:

   | openness | open edges/node | `B2/S23` | `B2/S3` | `B2/S34` | `B3/S34` |
   |---|---|---|---|---|---|
   | `0` (bare carve) | `2.0` | `0.1%` | `0.1%` | `0.1%` | `0.1%` |
   | `0.25` | `3.0` | `1.1%` | `0.2%` | `0.2%` | `0.1%` |
   | `0.5` | `4.1` | `2.1%` | `0.2%` | `0.1%` | `0.1%` |
   | `0.75` | `5.0` | `44.7%` | `0.4%` | `0.4%` | `0.1%` |
   | `1` (open field) | `6.0` | `54.9%` | `1.5%` | `2.1%` | `0.5%` |

   A carved maze is a spanning tree, so a node has ~2 open edges *total*,
   while every candidate needs 2-3 live *open* neighbors — a bare carve is
   uninhabitable for reasons that have nothing to do with the rule. The
   biome only comes alive past ~5 open edges per node. Two consequences
   worth carrying into Phase 7+:

   - **`MazeBraider` cannot close this gap.** Measured directly: braiding
     every dead end (`fraction = 1`) moves openness from `2.0` to `2.19`
     edges per node, and the board still dies at generation 4. Dead ends
     are a rounding error at this degree; this biome needs a genuinely
     different wall density, not a braid post-pass.
   - **Openness and liveliness aren't the same axis.** At openness `1` the
     population is highest (`54.9%`) but mean activity collapses to
     `0.056` — a board of still lifes, visually static. At `0.75`,
     population is `44.7%` with activity `0.289`, five times as much
     churn. If the biome wants *movement* (which is the whole reason
     `GeodesicReactivity` exists), ~`0.75` is the target, not "as open as
     possible".

   **Resolution (2026-08-05): the wall-gate was removed.** Given the
   choice between a maze with almost no walls and a simulation that dies,
   the coupling itself was the thing to drop.
   `GeodesicLifeState.liveNeighborCount` now counts every neighbour on the
   sphere's own adjacency and ignores the layout entirely; `step` no
   longer takes one. The division of labour is now **walls are what the
   player navigates, Life is what the biome does**, with the coupling
   running one way only — `GeodesicReactivity` still reads activity to
   move walls around.

   Re-measured after the change (frequency `6`, five board seeds, three
   seed densities): `B2/S23` holds `54.6%`-`55.0%` and never goes extinct
   at any density, confirming the pick is robust rather than an artifact
   of one soup. The other three stay marginal (`B2/S34` ~`2%`, `B2/S3`
   ~`1.3%`, `B3/S34` ~`0.2%`, mostly extinct).

   And the worry this raised — that a low-activity board (~`0.06` mean,
   against `GeodesicReactivity`'s own `0.5` open threshold) would leave
   the walls inert — measured as unfounded, and in fact lands somewhere
   better than intended. At frequency `10` over 200 generations: a
   turbulent opening (749 of 1999 reactive edges open by generation 25)
   settling into a steady state of 67-149 open, fluctuating by ~80 between
   samples. So the maze stays a maze — the spanning tree plus 3-7% extra
   passages — with localised pockets of churn opening and closing
   shortcuts, rather than either freezing solid or dissolving into an open
   field.

   Recorded as an open question rather than a closed one: whether a rule
   exists that stays alive *while* wall-gated was never actually
   searched — the four candidates were derived by scaling `B3/S23`, not by
   sweeping the space for something suited to a sparse graph. See
   `docs/game-design/ideas-backlog.md`'s "A maze-compatible life rule"
   entry, which also notes that a *soft* coupling (walls halving a
   neighbour's contribution, or gating birth but not survival) was never
   tried and might get the design intent without the extinction.

   Exit check: `GeodesicLifeStateTest` mirrors `ConwayStateTest`'s own
   shape — isolated node with no open edges dies, mutation can override
   the rule, age is `0` when dead, seed density `0`/`1` edge cases — plus
   one hand-verified prediction on a programmatically-found mesh triangle
   (two seeded alive with one shared neighbor dead: under `B2/S23` the two
   die from under-population, the third is born from exactly 2 live
   neighbors). All passing.
6. **Reactivity + wall visuals — built 2026-08-05.** `GeodesicReactivity`
   and `GeodesicLifecycle`, and it was as mechanical as predicted — the
   interesting part was what it exposed, not what it took to write.
   - `GeodesicReactivity` is an *instance*, not a static class like
     `ConwayMazeReactivity`. It resolves the core/reactive split once in
     its constructor (core = a snapshot of the carve's own open edges,
     since a carver returns exactly a spanning tree) and then only walks
     the reactive edges. The square-grid version re-enumerates every edge
     and re-tests `isCore` every generation; at frequency `11` that's
     `~3630` edges of which `1211` can never change, so this drops a third
     of the per-generation work and all of the `edgeKey` string building
     that went with it. No `coreEdges` field is needed on the baked data
     the way `ConwayMazeData` carries one — the information is already in
     the layout at the moment of carving.
   - `GeodesicLifecycle` deliberately merges what the square grid split
     across `ConwayGrid` (heights, `groundHeightAt`) and `ConwayMesh`
     (brightnesses, bucket sorting). Those two independently re-derive the
     same age → stage rule from the same readings; here `stageOf` is
     computed once and both consumers read off it. The one place render
     and collision *must* disagree is pinned by a test: a `Dying` node
     still draws its farewell flash but returns `0` standable height, so a
     player standing on a cell that just died falls.

   Exit checks: 14 new tests, including the guarantee that actually
   matters on a sphere with no outer boundary — connectivity re-verified
   by flood fill after *every single generation* of sustained churn, since
   the core set exists precisely so reactive edges can never partition the
   maze. `GeodesicPreview` now runs the simulation live, with cells raised
   and shaded per lifecycle stage and walls moving underneath them.

   Two things worth recording about verifying this:
   - **The preview can't be observed animating in an automated browser
     pane.** Its document stays `hidden`, and a hidden document never
     fires `requestAnimationFrame`, so Heaps' loop simply doesn't run and
     every screenshot comes back byte-identical to generation `0`. That
     looks exactly like a frozen simulation and isn't one. `?generations=N`
     fast-forwards before the first frame so any single generation is
     reachable as a still, which is all a screenshot can honestly show.
   - **This phase is what surfaced the Phase 5 RNG problem.** Running the
     preview for real showed the sphere going dead within a few
     generations, which contradicted Phase 5's "never extinct" claim and
     led straight to the broken generator. Worth noting the shape of it:
     the bad result was found by *rendering* the thing, not by any of the
     tests, all of which passed throughout (they run on JS, where the
     xorshift is fine).
7. **Pentagon beacon.** The one genuinely new mechanic, not a port: the
   `CellRule` dispatch (`LifeRule`/`BeaconRule`), the light-column visual
   with no collision height, and per-node rule assignment read from the
   baked data.
8. **Hex-native structure library.** Deliberately last and separate:
   rebuild what `ConwaySeedLibrary` did, but only once Phase 5 has actually
   settled on a ruleset — searching for hex gliders/methuselahs under a
   rule that might still change is wasted work.
9. **Save/load.** Serialization keys switch from `"cell:row:col"`/
   `"pole:north"` strings to node ids. Old saves aren't migrated — same
   precedent as every other format change this session, consistent with
   this project's own stance against compatibility shims for a solo/hobby
   save format.

Phases 1-4 are pure infrastructure with their own exit checks and no
Life-rule dependency — worth landing and confirming solid before Phase 5
commits to which of the four candidate rules to build the rest on top of.

## Wiring into the real game

Phases 1-6 above proved the sphere out entirely inside `tools.geodesic`,
reachable only through `GeodesicPreview`'s own standalone `-main` — nothing
under `Main`/`GameLoop`/`biomes.conway` referenced any of it. Turning that
into something a player actually walks is a separate scope, not one of the
original nine phases, tracked here as its own numbered list:

1. **Real mesh rendering — built 2026-08-06.** `GeodesicMesh`, the
   `biomes.conway.ConwayMesh` counterpart: same palette
   (`graphics.Colours.CONWAY_*`) and the same `ConwayWallGlow` shader,
   unchanged, over the new cell shape. Three differences, all forced by
   the geometry:
   - A cell is an N-gon (5 or 6 sides), not always-four corners —
     `addBlock` loops over however many the boundary has instead of
     `ConwayMesh.addBlock`'s fixed four.
   - A wall's own two endpoints come from a new
     `GeodesicDual.sharedEdge(sphere, boundaries, nodeId, neighborId)`,
     the real shared boundary segment between two cells' own polygons —
     not an approximation. Derived from a property of `cellBoundary`
     that wasn't obvious going in and was checked with a standalone
     script before trusting it: `boundary[k]` is the circumcenter of
     triangle `(nodeId, ring[k], ring[k+1])`, so the polygon edge between
     `boundary[k-1]` and `boundary[k]` is exactly the edge shared with
     `ring[k]`. Verified both algebraically (`GeodesicDualTest`: querying
     from either endpoint returns the same two points) and visually — the
     preview's own wall lines now trace the actual hex/pentagon
     tessellation instead of the fixed-width ticks Phase 4's version used
     as a placeholder.
   - Open/core/ghost classification needed a new
     `GeodesicReactivity.isCore(a, b)` — that class previously only
     exposed a count of reactive edges, not a per-edge query, since
     nothing before this needed to ask about one edge in isolation.

   `GeodesicPreview` was rewired to call `GeodesicMesh.build` directly
   instead of its own bespoke stand-in geometry (flat inset fans, raised
   ticks) — deliberately, so what the preview shows *is* what the real
   biome will render, not an approximation of it, and so there's only one
   rendering implementation to keep correct rather than two that could
   silently drift apart. The preview's own pentagon/hexagon color
   distinction (Phase 3's diagnostic aid) is gone with it: the real biome
   has no pentagon-specific rendering yet (that's step 5 below), so
   coloring them differently now would suggest a distinction the code
   doesn't actually make.

   Exit checks: `GeodesicMeshTest` (build never throws across many
   generations, handles an entirely dead board and an entirely open
   layout — the two edge cases where some vertex buffer legitimately ends
   up empty), plus new `GeodesicDualTest`/`GeodesicReactivityTest` cases
   for `sharedEdge`/`isCore`. All passing. Not exercised by an `hxd.App`
   run (this project's own `utest` suite doesn't cover rendering/scene
   code, per `CLAUDE.md`) — visual confirmation is the
   `GeodesicPreview` screenshot: a real hex/pentagon tessellation, wall
   lines following actual cell edges, alpha-blended live blocks, no
   console errors.
2. **`GeodesicConwayBiome` — built 2026-08-06.** Implements
   `biomes.common.Biome` the same way `ConwayBiome` does, assembling
   pieces that already existed. Two real gaps found while assembling
   them, not anticipated by the scoping that named this step "mostly
   assembly":
   - **The combo-jump gate didn't exist yet.** `GeodesicCollision`
     (Phase 4) predates `GeodesicLifecycle` (step 1's live blocks) and so
     had no wall-height check at all — every closed edge blocked,
     unconditionally. Ported `ConwayCollision.allowsStep`'s own
     `playerHeight >= WALL_HEIGHT` clause over
     `GeodesicLifecycle.WALL_HEIGHT`, with a new
     `GeodesicCollisionTest` case pinning it (airborne above that height
     crosses a closed edge that would otherwise block).
   - **Loading the baked sphere at runtime needed a JSON parser that
     didn't exist.** `GeodesicBake` only ever *wrote* `GeodesicSphereData`
     to disk; nothing read it back. Added
     `GeodesicSphere.fromJson(json):{sphere, frequency}` (the `frequency`
     is `GeodesicLookup`'s own second constructor argument, not part of
     `GeodesicSphereData` itself, so it has to travel alongside), tested
     by round-tripping through the *exact* shape `GeodesicBake` writes
     rather than a shape the test invents — so a future bake-format
     change that this parser doesn't also follow fails in
     `GeodesicSphereTest`, not silently at runtime. Loaded through
     `hxd.Res.load("geodesic/conway-sphere.json").toText()`, this
     project's own "assets only through `hxd.Res`" rule.

   `ConwayBiome.GRAVITY` and a new `ConwayBiome.BACKGROUND_COLOR` (pulled
   out of an inline literal) were made `public` so `GeodesicConwayBiome`
   could reuse the exact tuned values — `GRAVITY` specifically, since its
   own doc comment carries real jump-clearance derivation math that a
   duplicated literal would have silently detached from.

   `serialize`/`restore` are the `Biome` interface's own sanctioned
   `"{}"`/no-op pair (the same one `HubBiome` uses for "nothing worth
   saving") — deliberately, since there *is* something worth saving here
   and it isn't built yet; that's step 3 below, not a half-format
   improvised in this step to be thrown away once step 3 lands.

   Not yet exercised: this project has no biome-level integration test
   for any biome (`ConwayBiome` included — only its constituent pieces
   are tested, matching `GeodesicConwayBiome`'s own `GeodesicCollision`/
   `GeodesicMesh`/`GeodesicLifeState` coverage), and it isn't wired into
   `GameLoop` yet (step 4), so whether `hxd.Res.load` actually resolves
   the baked asset at runtime is unverified until then.
3. **Save/load — built 2026-08-06.** Node-id-keyed serialization for
   `GeodesicLifeState` + the maze layout — the original build order's own
   Phase 9. Same four-part shape `ConwayBiome.serialize` already uses over
   `ConwayMaze`/`ConwayState` (open edges, core edges, Life state, tick
   accumulator), just node-id-keyed instead of string-keyed:
   `GeodesicLifeState.serialize`/`deserialize` (mirrors
   `ConwayState`'s own — `live` as a plain id list, `activity`/`age` as
   `{k, v}` pairs since `haxe.Json` can't serialize an `IntMap` directly,
   `justDied` deliberately dropped as a one-generation visual cue).

   One real gap, not anticipated by "mirror `ConwayMaze`'s split": a save
   has no "freshly carved" layout lying around to hand
   `GeodesicReactivity`'s own constructor — only whatever
   `layout.openEdges` happens to be after however many generations of
   reactive churn, which is *not* the core set (core is core forever;
   `layout.openEdges` is core ∪ whatever reactive edges are open right
   now). So the core set has to be persisted on its own, separately from
   the current open edges — added `GeodesicReactivity.coreEdgeKeys`/
   `fromCoreKeys` for exactly that (the reconstruction trick: a synthetic
   layout with *only* the core edges open, handed to the same constructor
   a fresh carve would use, reconstructs identically — no new code path
   inside the constructor itself). `GeodesicSphereData` itself (positions,
   adjacency) is never part of the save at all: every session loads the
   same checked-in baked asset fresh, so persisting a copy would be pure
   redundancy — a difference from `ConwayMaze`, which has no equivalent
   external asset to fall back on.

   Exit checks: round-trip tests for both new pieces
   (`GeodesicLifeStateTest`, `GeodesicReactivityTest`) — alive/activity/
   age preserved and `justDied` correctly dropped; `fromCoreKeys`
   reconstructs an instance that agrees with the original on `isCore` for
   *every* edge, not just a matching count. No biome-level round-trip
   test for `GeodesicConwayBiome.serialize`/`restore` itself, consistent
   with this project having no biome-level integration test for any
   biome — the pieces it composes are what's tested.
4. **The swap — built 2026-08-06.** `game/GameLoop.hx`'s
   `biomeRegistry.register(new ConwayBiome())` is now `new
   GeodesicConwayBiome()`. Genuinely one line plus an import swap —
   `biomes.conway.ConwayBiome` turned out to have exactly one external
   reference outside its own package/tests (this line); every other
   mention project-wide (`biomes.hub.HubBiome`, `ConwayWaypoint`,
   `ConwayGrid`'s own doc comments) is either `ConwayBiome.ID` (a string
   constant, indifferent to which class is actually registered under it)
   or prose. `biomes.conway.*` itself is untouched and still compiles —
   deliberately not deleted; see this entry's own "what's still around"
   note below.

   Verified: `haxe build.hxml` clean, then the actual built game
   (`make serve`) loaded in a real browser tab. `GeodesicConwayBiome`'s
   constructor runs synchronously during `biomeRegistry.register`, before
   the dev room's first frame ever draws — so the dev room actually
   rendering (portrait signs for `hub`/`maze`/`twosided` visible, no
   console errors) is real confirmation that `hxd.Res.load` resolved the
   baked JSON and the constructor completed without throwing, closing the
   "unverified until the swap happens" gap step 2 flagged.

   **Not verified, and said plainly rather than assumed**: walking to the
   `conway`-labelled portal, entering, and confirming spawn/mesh/
   collision/the jump-over-wall gate in the actually-running game. Mouse
   drag (the input this browser pane's own camera-look depends on)
   produced no rotation — the same "keyboard/mouse input doesn't reliably
   reach the canvas in this automated environment" limitation
   `CLAUDE.md`'s own "Manual/interactive verification" section already
   documents, not a new finding. This needs hooman to drive and confirm.

   **What's still around:** `biomes.conway.*` (`ConwayBiome`, `ConwayMesh`,
   `ConwayGrid`, `ConwayState`, `ConwayMaze`, `ConwayCollision`,
   `ConwayMazeReactivity`, `ConwaySeedLibrary`) and their tests are
   untouched, unregistered, and unreferenced from `GameLoop` — a complete,
   still-passing, trivially-revertible fallback, not dead code pruned
   away. Deleting it is a separate decision this step didn't make
   unilaterally.
5. **Pentagon beacon and hex structure library** — the original build
   order's Phases 7 and 8, still not built. Could ship the swap without
   them (pentagons render as inert hexagon-shaped cells) or block on
   them; not yet decided.

## Wall straightening (2026-08-06)

Raised directly: "I'm not fond of the hex-shaped walls... when two walls
are adjacent on two hexes, what if we made them straight?" The plan going
in was to bridge a kink only where the turn is shallow, leaving real
corners alone — killed by measurement before any of it got written.
Over a real carved maze (frequency `10`), every pass-through kink measures
`54°-72°` (median `60°`), with no gap separating "shallow" from "sharp."
That's the tessellation itself, not noise: two dual-polygon edges from
different hexagons meet at close to a hexagon's own exterior angle
regardless of which way the corridor is actually heading, so there's no
per-vertex angle that tells a real turn apart from an artifact of the
grid.

What does distinguish a real corner is topological: a vertex where exactly
two closed walls meet is provably a pass-through (nothing else touches it,
so removing it changes nothing about what connects to what); a vertex
where one or three-or-more meet is a genuine dead end or branch, and has
to stay put. `GeodesicWallSimplifier.simplify` collapses every maximal run
of pass-through vertices between two such anchors into a single straight
chord — no angle math, no tunable threshold. Applied separately to the
solid-wall and ghost-wall buckets in `GeodesicMesh.build` (a segment never
bridges across the two), before either becomes quads.

Measured on the real bake (frequency `11`, a `RandomizedDfs` carve): `43%`
of runs are already anchored on both ends and pass through unchanged; the
rest merge a median of `2` original segments, up to `11` in the longest
observed case; the straight chord is usually close to the original
zigzag's own path length (median `88%` of it) but can be considerably
shorter for a rare long run (`24%` in the worst case observed) — an
accepted cost of a hard chord rather than a curve-preserving
simplification (Douglas-Peucker per chain, the fuller "option 2" this was
scoped against but not what was built).

Purely cosmetic, confirmed rather than assumed: `GeodesicCollision` only
ever reads the node graph (`MazeEdges.isOpen`), never wall geometry, so
this cannot change where a player can actually walk — the same property
that made trying it cheap in the first place.

Exit check: `GeodesicWallSimplifierTest` (isolated segment unchanged,
dead-end-to-dead-end chain collapses to one chord, a junction stops every
arm that meets it, a closed loop with no anchor at all survives
untouched) plus a `GeodesicPreview` screenshot — visibly fewer, longer,
straighter strokes in place of the tight hex zigzag, no console errors.

**Retracted 2026-08-06, played in the real biome rather than judged from
a screenshot.** Two problems the screenshot alone never showed: a merged
chord's own endpoints don't correspond to any *one* edge collision
actually blocks on, so the player gets stopped somewhere the drawn wall
doesn't visibly explain; and because virtually every wall on this grid is
already on the reactive edge set, a chain recomputed fresh every
generation reshaped visibly whenever *any* single edge inside it flipped
— not a flaw in the simplifier itself (it does exactly what it's
documented to do), but a mismatch between "merge geometry across several
edges" and "collision and reactivity are both strictly per-edge."
`GeodesicMesh` no longer calls it; the class and its own tests stay as a
correct building block, in case a future approach needs one. See
`docs/game-design/design-decisions-records.md`'s own retraction entry.

## Wall straightening, attempt 2: a coarse maze (prototype, 2026-08-06)

Rather than merging wall geometry after the fact — attempt 1's mistake —
this changes what the maze graph *is*. Two spheres instead of one:
the fine sphere (current density, `FINE_FREQUENCY`) still carries the
floor tessellation and the Life simulation, unchanged; a coarser sphere
(`COARSE_FREQUENCY`) carries the maze itself — carving, reactivity, and
(once/if this moves past prototype) collision. `GeodesicCoarseMaze.fineToCoarse`
assigns every fine cell to whichever coarse region it falls inside
(`GeodesicLookup` over the coarse sphere, reused rather than reinvented —
"map an arbitrary point to its nearest node in a baked sphere" is exactly
this assignment). A wall gets drawn for a fine edge only where that
assignment actually crosses a coarse boundary; its geometry is still the
real fine-cell edge (`GeodesicDual.sharedEdge`, no chord, no
approximation), but its open/closed/ghost *state* comes from the single
coarse edge the whole boundary shares. Wall and collision boundary are
the same object again — coarser, not approximated.

One geometric assumption this leans on, checked rather than assumed
before writing anything: two fine cells straddling a coarse boundary are
always assigned to *adjacent* coarse regions, never regions two hops
apart (which would make a boundary edge correspond to no coarse edge at
all). Measured with a standalone script across three fine/coarse
frequency pairings (`11`/`4`, `11`/`5`, `10`/`3`) — zero violations out of
`1100`-`2000` boundary edges each. `FINE_FREQUENCY = 10`/`COARSE_FREQUENCY = 5`
(the pairing the preview actually uses) averages `4.8` fine cells per
coarse region, range `4`-`6` — matching the density asked for directly.
Free bonus, not engineered: both spheres subdivide the same 12
`Icosahedron.VERTICES`, so the coarse sphere's own 12 pentagons and the
fine sphere's own 12 pentagons are the literal same 12 points in space,
at any frequency pairing.

`GeodesicReactivity.step`/`edgeActivity` were generalized from taking a
concrete `GeodesicLifeState` to taking a plain `Int->Float` — a small,
behavior-preserving refactor (every existing caller now passes
`state.activityOf`) that turned out necessary rather than optional: with
maze and Life keyed by different node spaces, reactivity needs *some*
node's own activity reading without caring which space that node id is
in. `GeodesicCoarseMaze.coarseActivity` supplies the coarse-space version
— the *hottest* fine cell anywhere in a region, not an average, for the
same reason a single hot neighbor already opens an edge rather than
needing every neighbor hot at once.

`GeodesicMesh.build` itself is untouched — the prototype calls it with a
synthetic all-open, all-core `(layout, reactivity)` pair (every fine edge
trivially "core" to it) so it draws floor and blocks only, and reuses the
newly-public `GeodesicMesh.buildWallMesh` for its own coarse-derived wall
meshes rather than re-deriving the UV/shader bookkeeping.

**Moved into the real biome and played (2026-08-06).** Same lesson from
attempt 1 applied deliberately this time: don't call it decided off a
screenshot. `GeodesicConwayBiome` now holds both spheres, `GeodesicCollision.tryMove`
gained an optional `fineToCoarse` parameter to remap a fine position
before checking the coarse layout, and the wall/floor split moved out of
`GeodesicPreview` into a shared `GeodesicCoarseMaze.wallSegments` both
classes call. Played result: the collision/visual mismatch and the
whole-chain reshaping that killed attempt 1 are gone — but "too many
walls disappear," reported directly. Root-caused, not guessed at:
`B2/S23` itself is untouched (still runs purely on the fine sphere,
walls never gated it — see the earlier "wall-gated Life" decision above);
what actually changed is how easily a coarse *wall* reads as active.

The original `coarseActivity` aggregated per coarse *node* — the hottest
fine cell anywhere in the whole region (~5 cells), and a coarse edge then
took the max of *two* such regions. Measured: a single fine cell crosses
`OPEN_THRESHOLD` `7`-`10%` of the time; a whole region's own hottest-of-5
reads hot `24`-`38%` of the time purely from that widening, and the
resulting coarse-edge open rate hit `89%` within 10 generations, settling
near `49%` — against the original fine-level system's own settled
`3`-`7%`. A cheaper fix (2nd-highest in the region instead of the single
max) only partly helped (`31%`), because the real problem wasn't *which*
order statistic each region reports, it was that an edge's own decision
was compounding *two* independent region-wide aggregates — effectively
sampling ~10 fine cells for one edge, not the ~2 the original per-edge
system watched.

Replaced `coarseActivity` (per coarse node) with `boundaryActivity` (per
coarse *edge*): only the fine cells that are actual endpoints of a
boundary crossing between exactly that edge's own two regions get a
vote — a cell elsewhere in either region, nowhere near this particular
wall, no longer counts. `GeodesicReactivity.step` was generalized a
second time to match — from `Int->Float` (a node's own activity) to
`(Int, Int) -> Float` (an edge's own activity directly) — since a
boundary-local reading is inherently a per-edge quantity, not something
derived from two independent per-node values anymore. Every existing
caller (the original fine-space tests included) now supplies
`(a, b) -> GeodesicReactivity.edgeActivity(state.activityOf, a, b)`,
preserving the old "max of two node readings" behavior exactly where
that's still what's wanted.

Measured after the fix: settled coarse-edge open rate dropped from `49%`
to `30%` (generation `60`, same seed) — real, and structurally more
honest (no more far-region cells voting on a wall they're nowhere near),
but not all the way back to the original `3`-`7%`. Reported plainly
rather than smoothed over: a coarse edge genuinely borders more fine
cells (`4`-`5`) than the original per-fine-edge system ever watched
(`2`), so some elevation above the old baseline is structural to working
at coarse granularity at all, not a leftover bug. Whether `30%` reads as
"enough" is for actual play to judge — building and headless-measuring it
doesn't answer that, only playing it does, which is why this note stops
short of calling the tuning finished.

Exit check: `GeodesicCoarseMazeTest`'s `boundaryActivity` cases (result
matches an independently-filtered maximum over only the correct
boundary's own fine cells; zero for a pair with no boundary crossing at
all) plus `GeodesicCollisionTest`'s two new coarse-mapped cases (blocks
across a closed coarse edge, always allowed within one coarse region
regardless of the coarse layout). Full suite green throughout both
iterations. `GeodesicPreview` and `GeodesicConwayBiome` share one
`GeodesicCoarseMaze.wallSegments`/`boundaryActivity` implementation, not
two copies that could drift apart.

**The rest of the gap was never the wall formula — it was the rule
(2026-08-06, same session).** Played again after the `boundaryActivity`
fix, `30%` open still read as "way too much," alongside a separate but
related observation: "we still have way too many cells activated." Both
point at the same thing, and it's upstream of anything `GeodesicReactivity`
can fix: `B2/S23`'s own settled *population* is ~56% of the fine sphere —
over half the board alive and flickering at any moment, which floods
every boundary's own `boundaryActivity` regardless of how tightly that
aggregation is scoped.

Measured directly (300 generations, 8 seeds, the real
`boundaryActivity`-driven reactivity): `B2/S23` settles at `~9%` open,
`~56%` population. Switching `GeodesicLifeRules.DEFAULT` to `B2/S34`
(one of the four original candidates, never previously the pick) lands
almost exactly on the actual ask: `4.8%` mean settled open against a
`5%` target, `~1.1%` population. Its own risk — flagged honestly rather
than assumed away — is real but small: `1` of `8` seeds hit zero
population at some point over 300 generations, and that one seed's board
self-healed via `MUTATION_RATE` within `2` generations (expected: at
~1200 fine cells and a `0.0008` mutation rate, a bare board still gets
~1 random birth per generation). `B2/S3` was also tried and rejected on
the same evidence: `6` of `8` seeds went extinct, too fragile to trust.
This also corrects Phase 5's own "near extinction" characterization of
`B2/S34` — that was a real reading under the conditions measured *then*
(a fully open board, no mutation-recovery framing), not a stable verdict
that holds under every condition; measured fresh here rather than
carried forward on faith.

The Life rule and the maze-openness problem Phase 5 already found remain
two separate, still-true facts, not in tension: every candidate,
`B2/S34` included, still dies within ~5 generations on a *bare* carved
maze with zero open edges (Phase 5's own finding, unaffected by any of
this). Wall-gating Life is still removed, for the same reason as always.
This round only ever concerned which rule drives the *unrestricted* fine
simulation `GeodesicMesh`/`GeodesicCoarseMaze` build on top of.

See `GeodesicLifeRules.DEFAULT`'s own doc comment for the full three-round
history of this pick — worth reading in full once, since each round was
right about the question it was actually answering, and wrong only in
assuming that question was the last one that would need asking.

## Pentagon coloring, and a glider search (2026-08-06, same session)

Two smaller, separate threads after the rule switch above.

**Pentagons now render distinctly** — `GeodesicMesh.build` splits the floor
into two meshes by degree (`neighbors[id].length == 5`) instead of one
shared one, shaded with a new `Colours.CONWAY_TILE_PENTAGON`. Deliberately
architected as a single-constant switch (set it back equal to
`CONWAY_TILE_DEAD` to blend pentagons back in) since it was requested as a
reversible experiment, not a final call.

**"I'd rather have gliders gliding... forevermore" than soup** prompted an
actual search rather than a guess: `GeodesicGliderSearch` exhaustively
tries every non-empty subset of one node's own 1-ring (127 patterns) under
all 4 candidate rules, matching shapes across generations by a
coordinate-free signature (`GeodesicShapeSignature` — sorted pairwise
graph-BFS distances between live cells, invariant under any isometry of
the mesh). Found 24 confirmed-translating patterns: 12 fast `B2/S23`
3-cell period-1 ones, and a 6-pattern family shared by `B2/S3`/`B2/S34`
(4-cell, period-2).

The important correction came from running longer.
`GeodesicGliderTrajectory` ran the 6 `B2/S34` patterns (the rule that
actually matters — `GeodesicLifeRules.DEFAULT`) for 5000 generations
instead of the search's own 8-16-generation confirmation window, and found
every one is a **bounded shuttle**: it drifts about one hex-cell from its
own spawn point, then drifts back, forever — never trending outward, never
reaching a pentagon. "Translates between two consecutive periods" and
"travels indefinitely" turned out not to be the same claim. (The first
version of this probe missed this entirely — it logged "population
changed" events and got 2500 near-identical lines per candidate, which was
never a pentagon interaction, just this period-2 family's own normal
locomotion breathing between 4 and 3 live cells every single generation.
Rewritten to track centroid drift from spawn instead, which is what
actually caught the shuttle.)

Built anyway, honestly labeled: `GeodesicGliderTracker` seeds one shuttle
each at 3 spread pentagons, tracks it forward with the same signature
technique run live, colors it `Colours.CONWAY_TILE_GLIDER` (amber), and —
since a shuttle never leaves to make room for a new copy — spawns once per
site rather than on a repeating clock, only retrying after tracking is
actually lost. Explicitly scoped as *spawn points*, not glider guns
("only go for a spawn-point right now, but flag and document the need to
go for glider guns later on") — see `docs/game-design/ideas-backlog.md`'s
"True glider guns" entry, blocked on ever finding a pattern that actually
travels. Widening the search (larger seed radius, more rule combinations)
is real unstarted work, not a closed question — a shuttle existing doesn't
mean a traveler can't.

## A real traveler, found outside the local search (2026-08-06, same session)

Playing the shuttle-based spawn points made it obvious nothing was
actually going anywhere. Redirected the search from "widen the local 1-ring
sweep" to "find out whether this problem has known answers" — it does.
Catagolue's own distributed soup search (`~100` billion random soups)
already found `xq14_0ig5l3z102`, a confirmed period-14 spaceship in
`B2/S34H` — Golly/Catagolue's own name for exactly `GeodesicLifeRules
.B2_S34` on a hexagonal neighborhood. A working object existed the whole
time, just outside a single node's own 127-pattern 1-ring.

Decoding its apgcode (Catagolue's `decodeCanon`, reimplemented in Node
from their own `rle_tools.js`) gave 12 cells in `(x,y)` hex-on-square
coordinates — but which of the square grid's two diagonal corners the hex
neighborhood keeps is a real ambiguity, and the first guess (the pair most
web sources describe) was wrong: checked on a plain flat-grid Python
simulation *before* trusting a sphere port, it collapsed to a 3-cell
fragment within 15 generations instead of reproducing itself. The other
diagonal pair reproduces it exactly — generation 14 is generation 0
shifted by `(-1,-1)`. Under that pair, the pattern's own `(1,0)`/`(0,1)`
axes are 120° apart, not 60° (they're both neighbors of a shared origin
cell but not of each other) — the detail that would have silently broken
a naive "pick two adjacent neighbors" placement.

Placed onto the real mesh — no coordinate system to lean on, so
`GeodesicGliderPatterns.placeKnownSpaceship` picks two of an anchor's own
6 neighbors 120° apart by tangent-plane angle as the axial basis, then
walks real 3D positions outward, re-deriving "which neighbor continues in
this direction" at every hop from position data rather than trusting
neighbor-array order (`GeodesicTopology.axisOf` is `Irregular`
everywhere). `GeodesicGliderPort`'s own headless probe confirmed it: 8
clean periods (112 generations) of centroid drift growing steadily
(`0.116` → `0.913`, linear — real travel, not the shuttles' oscillation)
before reaching a pentagon and dissolving into a small stable residual
structure, gracefully rather than dying or exploding.

`GeodesicGliderTracker` now spawns this instead of the old shuttle
patterns — generator sites need real pentagon clearance
(`MIN_PENTAGON_CLEARANCE = 4`) rather than adjacency to one, since the
pattern's own walk reaches up to 6 hex-steps out. Not "forevermore" in the
absolute sense (a finite sphere with 12 pinch-points was never going to
allow that), but genuinely gliding for a real distance before a graceful,
visible end — which is what was actually asked for.

The still-open half: `docs/game-design/ideas-backlog.md`'s "true glider
guns" entry — a real payload glider exists now, an ejector oscillator
whose period lines up to eject one cleanly does not.
