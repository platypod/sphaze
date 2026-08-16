# Ideas backlog

Not implemented yet — parked here until we get to them.

**How to use this file.** Skim the table, open the entry you care about, expand
its details only if you're about to build it. Every entry keeps the same shape:
a one-line pitch, then *Fits* (which pillar it serves), *Unproven* (what a
prototype has to answer), *Cost*, and a collapsed block for the reasoning.

**House rules.** Check a new entry against [philosophy.md](philosophy.md) before
adding it, and against the geometry-corollary rule in
[inspirations.md](inspirations.md) — *a biome's mechanic should be a corollary of
the sphere, not a decoration on it.* When an idea ships, delete it from here (the
code plus [`../PROJECT_LOG.md`](../PROJECT_LOG.md) is the record from then on) —
keeping only whatever part is still open. If an entry outgrows ~25 lines outside
its details block, it's a design note: give it its own file under
[notes/](notes/) and link it, the way
[the rule-driven walls one](notes/rule-driven-walls-engineering.md) does.

## At a glance

| Idea | Changes | State | Cost |
|---|---|---|---|
| [Mark now, see later](#mark-now-see-later) | wayfinding | idea (built cross-face only, in two-sided) | low |
| [Someone messes with the marks](#someone-messes-with-the-marks) | wayfinding, tone | idea, blocked on marks | low |
| [Scouting](#scouting) | wayfinding | idea | medium |
| [Cross-biome displacement](#cross-biome-displacement) | world cohesion | idea | medium |
| [Reverse time](#reverse-time-off-the-hourglass) | time | trigger built, effect open | medium |
| [Falls-counter unlocks](#falls-counter-unlocks) | precision | counter built, unlocks open | low |
| [Tree growth](#real-tree-growth-möbius-forest) | time | deferred by choice | medium |
| [One side affects the other](#one-side-affects-the-other-möbius) | topology | idea | medium |
| [Walls that behave by a rule](#walls-that-behave-by-a-rule) | wall state | Life-driven built, 3 idea | high |
| [Two-sided maze](#two-sided-maze-the-open-half) | topology, gravity | **prototype landed**, crossing open | — |
| [Perception rules](#perception-rules-as-the-biomes-own-variable) | what you may know | **one of ten built** | low each |
| [Retroactive rediscovery via a gained sense](#retroactive-rediscovery-via-a-gained-sense) | what you may know, persistent | idea | medium |
| [Antipode pairs](#antipode-pairs) | geometry | idea | medium |
| [Great-circle corridors](#great-circle-corridors) | geometry | idea | high |
| [Junction drafting](#junction-drafting) | who builds the maze | idea | medium |
| [Verticality](#verticality-a-maze-that-isnt-flat) | traversal | idea (3 ways in) | low→high |
| [Paintings mechanics](#paintings-mechanics) | traversal | partly covered by the hub | low |
| [Various levels](#various-levels) | biome identity | idea | — |
| [Per-biome maze recipes](#per-biome-maze-recipes) | biome identity | styles built, assignment open | low |
| [Geodesic sphere for Conway](#geodesic-sphere-for-conway-hexagons--12-pentagon-beacons) | biome identity, geometry | idea, engineering scoped | high |
| [Maze-compatible life rule](#a-maze-compatible-life-rule) | biome identity, simulation | open question, measured | medium |
| [Hex-native structure library](#a-hex-native-structure-library) | biome identity, simulation | **superseded (2026-08-09): live rule is now Ventrella, not B2/S34 — see below** | low |
| [True glider guns](#true-glider-guns) | biome identity, simulation | idea, half-unblocked (a much better traveler exists now) | high |
| [Deliberate pentagon activation](#deliberate-pentagon-activation-not-random-soup) | biome identity, progression | **shared prerequisite (soup off) built**; composing interface **built**; 4 narrative variants still idea | low→high |
| [Biome links / rosetta maze](#biome-links-and-the-rosetta-maze) | progression | idea | high |
| [Broken cells that need fixing](#broken-cells-that-need-fixing) | progression, interconnection | idea | medium |
| [Zoom in/out to move between biomes](#zoom-inout-to-move-between-biomes) | traversal, scale | idea | high |
| [Secret painting swap](#secret-one-time-painting-swap-tower) | secret | idea | low |

---

## Mechanics

### Mark now, see later

**Let the player leave marks on the ground — an arrow at a junction, say — that
are illegible up close and only readable from across the sphere.**

- *Fits:* "see far, not near" directly; it's wayfinding that works *with* the
  asymmetry instead of handing over a map.
- *Unproven:* whether a mark you can only read from the far side is useful or
  merely fiddly.
- *Cost:* low. Cross-face marks already exist in
  `biomes.twosided.MarkModel`; what's missing is the same-face version and any
  notion of a mark *saying* something.

<details><summary>Detail</summary>

The original shape: a mark isn't legible up close — it only becomes readable
once the player is far enough away to see it *and its surroundings* from the
opposite side, letting them retrace their route (or deduce a better one). The
two-sided prototype covers a narrower case (a post visible from either face,
saying only "here"), so the open questions are what a mark should say, and
whether reading one at distance is genuinely worth the walk.
</details>

### Someone messes with the marks

**Marks the player left don't always still say what they said.**

- *Fits:* the noir tone, and it makes wayfinding social rather than mechanical.
- *Unproven:* the dosage. Explicit ask: **subtle but noticeable.**
- *Cost:* low, but blocked on the base mark mechanic.

<details><summary>Detail</summary>

An arrow rotated a few degrees, a mark moved one junction over, one added that
the player never left. The player should be able to *catch* it — and, ideally,
start distrusting a still-correct mark, which is the better half of the effect —
never be silently griefed by an invisible RNG. So: tamper rarely, tamper
visibly-in-hindsight (a tampered mark should look slightly wrong when
re-examined up close — a hand not the player's), and never tamper with the mark
the player is currently looking at.

Pairs naturally with whoever is doing it being a real character: the
raven/watchdog in the Garden of Eden candidate, or the goblin steering visitors
in the salvaged Minotaur material (see
[design-decisions-records.md](design-decisions-records.md)). Don't build the
antagonist before the thing it vandalises.
</details>

### Scouting

**Send something off in a direction — a rolling ball, a burst of coloured gas —
to reveal a bit of the path ahead before committing to walk it.**

- *Fits:* wayfinding that costs something, rather than free information.
- *Unproven:* what the scout *is*, diegetically and mechanically.
- *Cost:* medium — needs a moving thing with its own collision.

### Cross-biome displacement

**Things turn up in the wrong biome — a creature or object escaped into a world
it doesn't belong to — and the player's job is to spot it and take it home.**

- *Fits:* "interconnected, not a level select" (traffic between biomes makes them
  one world) and "see far, not near" (an out-of-place thing is exactly what reads
  from across the sphere — a wrong glint in the wrong biome).
- *Unproven:* the carry/lure/chase interaction, which doesn't exist in any form.
- *Cost:* medium.

<details><summary>Detail</summary>

Salvaged from the rejected "Night Shift" story alternative (see
[design-decisions-records.md](design-decisions-records.md)): the storyline died,
this mechanic was explicitly kept (hooman: "a great idea"). The existing spawn
scaffolding (`entities.CreatureSpawnTable`,
`entities.registries.CreaturesRegistry`/`NpcsRegistry`) is already shaped for
"what escapes where". Prototype the cheapest version first.
</details>

### Reverse time, off the hourglass

**Hang a real rewind mechanic off the hub hourglass's hidden unlock.**

- *Fits:* diegetic-over-chrome — the control is an object in the world.
- *Unproven:* what the mechanic *is* (undo a hazard, rewind an obstacle, replay
  the player's own last few seconds).
- *Cost:* medium; the trigger exists, the effect doesn't.

<details><summary>Detail</summary>

The tiltable hourglass (`entities.hourglass.HourglassModel`/`Hourglass`) already
has a real trigger, not just the safety valve this entry used to describe: walk
it to its minus floor and keep pushing past it
(`HourglassModel.overdraftCount`/`OVERDRAFT_UNLOCK_COUNT`) and it snaps back to
neutral and sets `unlocked` permanently, shown today by the sand turning gold.
Nothing else in the game reacts to `unlocked` yet. Prototype the cheapest
version of whatever the mechanic is before wiring level design around it.
</details>

### Falls-counter unlocks

**Hang objectives off the tower's fall counter.**

- *Fits:* rewards precision over speed.
- *Unproven:* what each unlock actually is — undecided.
- *Cost:* low.

<details><summary>Detail</summary>

The counter and its floor ring-glow cue are built
(`biomes.tower.TowerBiome.fallCount`, `graphics.shaders.TileRingGlow`). Three
scenarios, each meant to unlock something different, none built: touching only
the top and bottom floors (the minimum possible), touching every single floor,
and anything in between (no unlock).
</details>

### Real tree growth (Möbius forest)

**Saplings that visibly grow into full trees over time, instead of a one-time
scatter placed fully grown.**

- *Fits:* gives the hourglass's time-scale something else to bite on.
- *Unproven:* rebuild-on-tick vs interpolated scale.
- *Cost:* medium. **Deliberately deferred** in favour of the cheap static version.

<details><summary>Detail</summary>

If built, it should hang off the existing global time-scale
(`HourglassModel.timeScale` / `BiomesRegistry.globalTimeScale`) rather than
inventing a second clock: growth would speed up, slow down, or stop dead along
with everything else — "a mechanism with the time stop", per the ask. Needs
persistent per-tree state (a growth stage or planted-at timestamp in
`MobiusForestGenerator.PlacedTree`, serialized with the rest of the layout).
</details>

### One side affects the other (Möbius)

**Change something on one lift of the strip and its counterpart on the other
changes too.**

- *Fits:* a consequence of the strip's topology, not a switch puzzle pasted onto
  it. Shares its shape with [antipode pairs](#antipode-pairs) — build the second
  on whatever mechanism the first establishes.
- *Unproven:* whether the player ever *notices* the pairing.
- *Cost:* medium. Prototype the cheapest reversible interaction first.

### Walls that behave by a rule

**A biome whose maze isn't a fixed layout but one governed by a rule the player
learns to read.** Each variant is its own biome, not a stack of twists in one.

| Variant | What it does | Notes |
|---|---|---|
| **Metronome** | sections rise and fall on the world tick | the hourglass is already a global time-scale dial, so the player's difficulty control is diegetic at no new cost |
| **Close behind you** | crossing an edge shuts it | strongest "see far, not near" fit in this file: the whole route must be planned before entry. Precedent: Ravensburger's Labyrinth ([inspirations](inspirations.md)) |
| **Growth** | hedges close over time | shares its clock with [tree growth](#real-tree-growth-möbius-forest) — build both on one mechanism or neither |
| **Life-driven** | walls follow a cellular automaton | **built**, option 3 below — see [2026-08-03 record](design-decisions-records.md) |

- *Unproven:* Metronome, Close behind you, Growth — Life-driven shipped its first cut.
- *Cost:* high — see [the engineering
  note](notes/rule-driven-walls-engineering.md) for what the codebase needs
  (short version: one chokepoint already exists; the gaps are rebuild cadence, a
  wall closing on a stationary player, and serializing the rule's phase).

<details><summary>Why raw Conway is a bad wall generator — and four ways it could still work</summary>

Raised directly (2026-07-29): wouldn't a Life board mostly die back, leaving the
maze open? Yes. Random soup at `biomes.conway.ConwayState.INITIAL_DENSITY`
evaporates within a few dozen generations into scattered still lifes and
blinkers — a *mostly open* board. So raw B3/S23 on the walls doesn't work
directly — see below for the shape that shipped instead.

1. **Invert the mapping** (walls = dead cells) so the sparse stable end-state is
   a sparse *maze* — but then the opening generations are a near-solid block.
2. **Seed deliberate patterns** instead of soup and treat each as level
   furniture: a blinker is a door, a still life is a permanent wall, a glider is
   a moving hazard. This is the version that's actually a *mechanic* (pattern
   literacy) rather than a texture.
3. **Run Life on a subset of edges** layered over a static spanning tree, so
   connectivity is guaranteed by construction and Life can only add or remove
   shortcuts. **Built 2026-08-03**, gated on rolling per-cell activity rather
   than raw density (`biomes.conway.ConwayMazeReactivity`): a field of frozen
   still lifes has population but no activity, so its walls settle back to
   closed instead of staying open forever on stale density.
4. **Use a rule with a labyrinthine attractor** — B3/S12345 is literally known
   as "Maze" and grows exactly that kind of structure. Still open — the board
   underneath `ConwayBiome` stays plain B3/S23 for now.

Recommendation if it gets built: 3 plus 4, on the cheapest possible board first.
3 landed; 4 (or seeded patterns from option 2) remain open follow-ups if 3
alone doesn't hold up in play.
</details>

### Two-sided maze: the open half

**Built** — `biomes.twosided.TwoSidedBiome`: one layout, both faces of the
shell, ordinary gravity inside, weak enough outside to jump three walls high,
marks that pierce the shell and read from either side. What's left is the
interesting part.

![Cross-section of the shell: inside the sphere a walker under gravity 60 between plain walls with a long sightline; outside, an inverted walker under gravity 4.5 arcing over three hatched walls; a pink post pierces the shell and reads from both faces.](../assets/game-design/two-sided-shell.svg)

- **How you actually cross.** The poles are simply open today, chosen because
  they're the grid's own degenerate merged cells and need no new geometry —
  hooman's framing was "warp, opening, whatever flip mechanism… we'll figure out
  later." Candidates: a painting as a doorway (consistent with every other
  transition, but paintings currently mean *leave the biome*); a physical hole
  that makes the shell read as real thickness; or **a flip triggered by
  something the player does** — jumping hard enough from the outside to leave
  the surface and land on the inside, which makes the two-gravity contrast
  itself the door. That last is the most elegant and the one to prototype first.
- **What makes marks load-bearing.** A mark is currently a tool with no lock:
  nothing requires one. It becomes a *mechanic* only when something on the
  outside can't be found without a mark placed from the inside — a wall that
  only reveals its door from a distance, a region where the outside face gives
  no landmarks, a target only distinguishable from across the sphere.
- **What a mark says.** Just "here", for now. Cross-face marking adds a
  question: should a mark record which *side* it was placed from?
- **Standing on wall tops.** A jump on the outside passes over walls because
  collision is skipped above wall height; there's no landing on one. Wants the
  same thing [verticality](#verticality-a-maze-that-isnt-flat) wants.

### Perception rules as the biome's own variable

**The maze is ordinary; what the player is *allowed to know* is what changes.**
The most pillar-aligned axis available — it works directly on the
see-far-not-near asymmetry instead of alongside it. One per biome, never stacked.

| Rule | What changes | Corollary of the sphere? |
|---|---|---|
| **Candlelight** | see near, not far — the asymmetry inverted | yes (felt by absence) |
| **Inverse-legibility walls** | walls grow taller nearer the goal, so visibility drops as you approach | yes |
| **Centre-lit shadows** | one lamp at the centre draws the far hemisphere's walls as shadows | **strongest** — only a sphere's interior can do it |
| **Near-fade** | near geometry faint, far geometry crisp | yes (the pillar, literally) |
| **Mirror band** | a polished ring reflects the far side, so you read around your own horizon | yes |
| **Echo** | a pulse whose reply rhythm encodes distance | partly (non-visual channel) |
| **Posture trade** | crouch to see near, raise your head to see far — never both | yes |
| **One snapshot** | keep exactly one remembered view of the far side at a time | partly |
| **Compass** | always know the goal's bearing, never the walls | no |
| **Drifting fog** | occlusion moves, so surveying is opportunistic | weakest — works in any maze |

![Cross-section of a corridor where wall heights grow toward the goal; a sightline from far out clears the low walls and dies against the tall ones.](../assets/game-design/inverse-legibility.svg)

![A sphere with a single lamp at its centre; walls on the near interior cast wedge-shaped shadows onto the far side.](../assets/game-design/centre-lit-shadows.svg)

<details><summary>What the first built one (the wind biome) settled — read this before building another</summary>

`biomes.wind.WindBiome` (2026-07-29) makes a draft flow out of the exit along
the corridors, so the grass is a flow field converging on the way out. Three
findings, in the order learned — the last two only after hooman looked at it and
said it was showing nothing, which it was:

1. **Size.** A cue meant to be read at distance has to be physically big enough
   to survive there. At normal grass height a blade covers under a pixel from
   across the sphere and its shape carries nothing.
2. **A constant offset, not an oscillation.** The sway was a zero-mean sine, so
   blades wobbled about upright and never bent anywhere. Anything meant to be
   *read* needs a steady state, not just motion about a neutral one.
3. **Motion carries direction; a static cue carries only an axis.** A lean looks
   much the same bent either way from a distance. What distinguishes "the exit is
   that way" from "it's behind me" is a gust travelling downwind — each blade's
   phase taken from its place along the flow, not a random per-blade value.
   **Generalised: any entry here that means to point somewhere must say how it
   resolves the 180° ambiguity, and motion is the cheapest answer.**

Still open, and probably shared by all ten: whether a distance cue is genuinely
*navigable* rather than merely visible (needs walking, not screenshots), and that
nothing stops a player reading the cue one tuft at a time at their feet, which
defeats the point — the fix is making the *local* reading ambiguous while the
aggregate stays honest.
</details>

### Retroactive rediscovery via a gained sense

**Start missing a sense — colourblind is the seed example — and gain it
partway through, so biomes already solved turn out to have had an obvious
path invisible to the player's own eye the whole time.**

Raised directly (2026-08-10), alongside the
[Garden of Eden candidate](storylines/garden-of-eden.md)'s own
"each stage a gameplay unlock" driver — colour vision reads there as an
evolution stage aimed at *reading* rather than *moving*, the way `gun`
is aimed at scouting and `spaceship` at speed. This entry is the
story-agnostic mechanic underneath that framing.

- *Fits:* "interconnected, not a level select" harder than any single
  [perception rule](#perception-rules-as-the-biomes-own-variable) can on
  its own — those are a fixed rule *of a biome*, gated on which biome
  you're in; this is gated on which *stage the player is*, so unlocking
  it changes how every biome already visited reads, not just the one
  you're standing in. Also composes with "see far, not near": a path
  legible only in colour, at distance, is a second axis of the same
  asymmetry.
- *Unproven:* whether "solved once, differently legible on a second
  visit" reads as a reward or as "I should have seen that", and whether
  the game can cheaply flag which already-visited biomes are worth a
  revisit rather than making the player recheck all of them blind.
- *Cost:* medium — the biome geometry doesn't change, only what's
  rendered/legible; needs a persistent player-state flag (parallel to
  the taxonomy-stage unlocks the driver already wants) and at least one
  biome authored with a colour-only path from day one, not retrofitted.

<details><summary>Detail</summary>

The concrete first cut: render the game desaturated by default (a real
rendering constraint, not just a fictional frame — see the open question
in the candidate file about which of the two this should be); one wall,
mark, or route in an early, already-solvable biome is distinguishable
only by hue, invisible in greyscale; gaining colour vision (whichever
evolution stage it's tied to) flips a global shader/render-state and
that route is retroactively there. Generalises past colour: any sense
the player starts without (hearing a hum through walls, feeling a draft
without the wind biome's grass) is the same shape — gain it, then reread
what's already behind you. Colour is the cheapest to prototype, since
`graphics.shaders` already carries per-biome shader state to hook a
global desaturation pass into.

</details>

### Antipode pairs

**Every point on a sphere has exactly one antipode — and from the interior it's
the point you see *best*. So pair the maze: what you do to a wall here happens
to its counterpart there, identically or inverted.**

![A sphere with two cells at opposite ends of a line through the centre; a change at one appears at the other, or its opposite.](../assets/game-design/antipode-pairs.svg)

- *Fits:* the geometry-corollary rule, hardest of any entry here. hooman: "I like
  the antipod pairs idea."
- *Unproven:* whether a player can *find* the paired wall by looking, and whether
  it reads as a connection rather than a coincidence.
- *Cost:* medium.

<details><summary>Three verbs, cheapest first — and the implementation note</summary>

- **Tag** a wall (no structural change) and its antipode is tagged too. The safest
  first prototype: it can't make a maze unsolvable, and it answers the real
  question immediately.
- **Remove/add** a wall and its antipode opens/closes with it (same), or against
  it (opposite). "Opposite" is the more interesting puzzle and the more
  dangerous one — it can wall off a region, so a solvability check (or a rule
  that a pair may never close the last route to a cell) is part of the design.
- **Carry** a wall: pick one up here and it can only be set down at an antipode
  — Void Stranger's tile-rod verb ([inspirations](inspirations.md)) with the
  sphere supplying the constraint, since choosing what to move means reading the
  far side and then walking half a world with the shape held in memory.

Implementation: the antipode of a `GridNode` is a pure key transform (`theta →
pi - theta`, `phi → phi + pi`, then re-resolve the column against
`GridModel.colsForRow` — the two rows involved have the same column count by
symmetry, so pairs are exact), and edges pair by their endpoints' antipodes.
Check early that the poles pair cleanly (they should: north's antipode is
south), since they're the grid's usual special case.
</details>

### Great-circle corridors

**A maze whose corridors are arcs of great circles, so every corridor followed
far enough returns to where it started. Walking "straight" is a loop; the puzzle
is working out which circle you're on.**

![A sphere with three great circles at different inclinations, dots at their crossings, and a path that returns to its own start.](../assets/game-design/great-circle-corridors.svg)

- *Fits:* up close every corridor looks identically straight, so only distance
  tells them apart — the asymmetry doing load-bearing work.
- *Unproven:* whether "which circle am I on" is a puzzle or just disorienting.
- *Cost:* **high** — wants its own layout generator (circles at assorted
  inclinations, intersections as junctions) and its own collision approach.
  Worth a cheap unwalkable mock-up (just the circles, drawn) before committing to
  walkable geometry.

### Junction drafting

**Don't generate the maze up front: at each junction the player picks what to
build from a small offered hand, under constraints, with incomplete information
about what's beyond.**

- *Fits:* choosing the layout becomes the gameplay rather than a menu — the Blue
  Prince lesson ([inspirations](inspirations.md)). In the sphere it also
  satisfies the story-line's "actions visibly accumulate", by geometry instead of
  props: the half-built maze is visible from across it.
- *Unproven:* whether the hand is drawn *at* the junction (immediate, tense) or
  planned before entering (deliberate, more like drafting a route). Those are
  different games.
- *Cost:* medium. hooman wants both placements on the table: in the sphere, and
  in another biome where drafting is the whole identity rather than a layer.

### Verticality: a maze that isn't flat

**Today every walkable surface is a 2D sheet embedded in 3D, so every maze is a
2D maze. Make the third axis carry route information.**

| Way in | What it buys | Cost |
|---|---|---|
| **Jump as a verb** | per-edge wall heights turn the maze into a topographic map — and height is exactly what reads at distance, so it composes with inverse-legibility | low: `Biome.gravity()` is already per-biome |
| **Concentric shells** | "up" moves between whole mazes; the far side you see isn't the one you stand on | medium: fits the grid code, fights the collision code's one-radius assumption |
| **Zero-G / free flight** | a lattice maze with no floor at all | high: removes the local "up" that `PlayerModel`/`Camera` assume |

- *Unproven:* whether verticality is fun here at all. hooman: "I don't know on
  which space it will fit best yet."
- *Cost:* start with the jump variant on the existing sphere grid — nearly free,
  and it answers the question before anything gets rebuilt.
- **Jump variant, first cut, built 2026-08-04** — on `biomes.conway`, not a new
  grid: live cells got a real hitbox (`ConwayGrid.groundHeightAt`), standable
  on top, and `ConwayCollision` lets a player airborne above `ConwayGrid.WALL_HEIGHT`
  cross a closed edge — jump onto a live cell, jump again from there, clear a
  wall. `ConwayBiome.GRAVITY` came down from `60` to `28` to make the first
  jump actually reach a cell's own top (see that constant's own doc for the
  arithmetic). Answers the "is this fun" question for the maze grid itself
  next, if wanted — this only proves it on Conway's own denser grid.

---

## Levels & biomes

### Paintings mechanics

**New mechanics based on what's *drawn* on a painting: a warp between two
paintings of the same scenery, two sides of one scene, a wall you can cross
through.**

*Note:* the hub/menu navigation (decided 2026-07-17) already uses paintings as
doorways. Revisit whether an in-maze warp is still separately wanted.

### Various levels

**Levels with their own game design: a mansion by candlelight with shorter
sight; another with a compass; levels entered *through* real paintings, with a
challenge to solve to get back out.**

The wind-led level this entry used to name is built (`biomes.wind.WindBiome`) —
see [perception rules](#perception-rules-as-the-biomes-own-variable).

### Per-biome maze recipes

**The generation styles exist; which biome carves with what is undecided — and
that's the design question, since a biome's corridors are the first thing a
player reads about it.**

- *Built:* `biomes.common.maze.MazeStyle` — randomized DFS, Prim, Kruskal,
  axis-biased, recursive division, plus braiding as a post-pass, on any topology.
- *Chosen so far:* the wind biome carves axis-biased so its flow field gets long
  sweeping curves; the exterior biome carves Prim for frequent dead-end feedback
  where nothing else is legible. **Four of five styles are unused.**
- *Waiting for an identity:* recursive division makes rooms and halls rather than
  corridors — which is the mansion level above.
- *Cost:* low. Wants playtesting per style, not a decision on paper. One further
  lesson to steal when it happens (Dead Cells, [inspirations](inspirations.md)):
  authored skeleton, generated detail, rather than pure procedure everywhere.

### Geodesic sphere for Conway (hexagons + 12 pentagon beacons)

**Replace `biomes.conway`'s lat/long grid — cells shrink toward the poles by
`sin(theta)`, uneven in a way the ordinary maze grid already fixed for itself
(`GridModel.colsForRow` bands column count near the poles) but Conway's own
grid deliberately didn't — with a hexagon-based geodesic sphere, and lean into
the 12 pentagons a sphere always forces rather than hide them.**

Raised directly (2026-08-04): "I don't quite like the fact that a cell's
dimension near the poles is so different... What if we based each cell on a
hexagon... redesigned our sphere around it?" then, on the unavoidable 12
defect cells an icosahedral hex tiling produces: "I don't mind the N
pentagons — on the opposite, we will build mechanisms around them." Landed on
a pulsing-beacon rule for the pentagons: visually a tall column of light with
no hitbox, technically a cell alive on its own fixed clock rather than by
neighbor count — with the rule itself modeled as swappable per-pentagon data,
anticipating other mechanics later.

- *Fits:* [inspirations.md](inspirations.md)'s own rule directly — *"a
  biome's mechanic should be a corollary of the sphere, not a decoration on
  it."* The 12 pentagons aren't a design choice dressed up after the fact;
  Euler's formula forces them on any sphere tiled this way, and the beacon
  rule is what happens when that forced structure is read as signal rather
  than defect.
- *Was already asked once:* [PROJECT_LOG.md](../PROJECT_LOG.md) records the
  lat/long-vs-cube-sphere/geodesic question being walked through and
  deliberately deferred before the maze was ever built — *"revisit if pole
  distortion... turns out to matter once the maze is actually walkable."*
  This is that revisit.
- *Unproven:* whether a 6-neighbor Life rule (B3/S23 doesn't transfer as-is —
  no diagonals, different neighbor count) actually produces the
  gliders/oscillators/methuselahs the square grid now has, before committing
  to one; whether the position→cell lookup's face-boundary tie-break is
  actually clean in practice, not just on paper.
- *Cost:* high, but scoped — see [the engineering
  note](notes/geodesic-sphere-engineering.md) for the construction method
  (icosahedral subdivision → Goldberg dual, density tunable via one
  frequency parameter, 12 pentagons guaranteed and always mutually
  non-adjacent), the generate → score → bake pipeline (checked-in data
  asset, not computed live), four candidate hex-Life rulesets with a
  recommended starting one, and — the part that could have been a
  showstopper but isn't — a known-good position→cell lookup algorithm (the
  same three-step approach Uber's H3 uses: nearest-icosahedral-face bucket,
  local closed-form projection, table lookup; effectively constant-time, not
  a scan over cell count).
- *Open:* whether this stays Conway-specific or becomes a sibling to
  `biomes.common.grid`'s shared `GridTopology`/`GridModel` for other biomes —
  not decided; the pentagon-beacon mechanic argues for Conway-specific for
  now regardless, since no other biome has a reason to want beacons.

### A maze-compatible life rule

**Find a hex Life rule that stays alive while its neighbour influence is
gated by the maze's own walls — so the walls shape the simulation instead of
merely being reshaped by it.**

Split out of the geodesic-sphere work above (2026-08-05) after the shipped
answer went the other way. `biomes.conway`'s square grid gates Life by walls:
a cell only counts a neighbour it has an open passage to. That was ported to
the hex sphere and had to be taken straight back out, because there it
doesn't change the dynamics, it ends them — measured across all four
candidate rules, a wall-gated board is extinct within ~5 generations, every
time.

The arithmetic is unforgiving. A hex node has 6 neighbours; a carved maze is
a spanning tree, so ~2 of them are open; every candidate rule needs 2-3
*live* neighbours to sustain anything. So a cell needs essentially both of
its two open neighbours alive simultaneously, every generation. The square
grid survives the same rule because it has 8 neighbours *and* because
`ConwayGrid.allowsInfluence` lets diagonal influence route through either
intermediate cell — influence leaks around corners there. A hexagon has no
diagonals; every neighbour is a direct edge, all or nothing.

Also measured and rejected as a way out: opening the maze up. `B2/S23` only
comes alive past ~5 open edges of 6, at which point there is barely a maze
left; and `MazeBraider` at `fraction = 1` reaches only 2.19, nowhere near.

- *Fits:* the same [inspirations.md](inspirations.md) rule the geodesic
  sphere is built on — a biome's mechanic should be a corollary of the
  sphere. Walls that genuinely constrain the life growing between them is a
  stronger version of that than walls the life merely pushes around.
- *Unproven:* whether such a rule exists at all. The four candidates were
  never a search — they were derived by scaling `B3/S23`'s thresholds by the
  neighbour-count ratio, which is a reasonable first guess and nothing more.
  Nobody has swept the space for a rule suited to a *sparse* graph (survival
  at 1-2 live neighbours, asymmetric birth/survive, or a generation rule that
  reads wall state as something other than a hard gate).
- *Cost:* medium, and cheaply bounded — `GeodesicLifeReport` already
  compares rules across conditions headlessly, and reintroducing the gate is
  a change to a single method (`GeodesicLifeState.liveNeighborCount`). The
  work is the search and its scoring criteria, not the plumbing.

### A hex-native structure library

**Find small Life patterns (oscillators, "gliders," methuselahs) that
actually work on this sphere's 6-neighbour hex/pentagon grid —
`biomes.conway.ConwaySeedLibrary`'s own patterns don't transfer, they're
defined for the square grid's 8-neighbour rule.** Build-order Phase 8 from
[the engineering note](notes/geodesic-sphere-engineering.md).

**Search actually run, 2026-08-06** (`GeodesicGliderSearch`,
`GeodesicGliderTrajectory`) — see `GeodesicGliderTracker`'s own doc for the
full story. Local exhaustive 1-ring search found 24 confirmed translating
patterns across 4 candidate rules, but the long-run follow-up (5000
generations) showed every `B2/S34` candidate — the rule the real board
actually plays under — is a *bounded shuttle*, drifting about one hex-cell
out and back forever rather than genuinely traveling.

**Resolved the same day, from outside the local search space.** Web
research on hexagonal Life-like automata turned up `xq14_0ig5l3z102`: a
real, confirmed period-14 spaceship in `B2/S34H` (Golly/Catagolue's own
name for this exact rule), found by Catagolue's own distributed soup
search across ~100 billion random soups — a working example already
existed, just never reachable by a single node's own 1-ring. Ported onto
this mesh (`GeodesicGliderPatterns.placeKnownSpaceship`, walking real 3D
tangent directions rather than any coordinate system) and verified by
`GeodesicGliderPort`'s own headless probe: 8 clean periods (112
generations) of genuinely growing centroid drift — real net travel, not
the shuttles' oscillation — before it reaches a pentagon and dissolves
into a small residual structure. This is what `GeodesicGliderTracker`
spawns now, replacing the shuttle patterns entirely.

- *Fits:* the geometry-corollary rule, same as everything else in this
  package — even though the *pattern itself* came from outside the project,
  placing it required this mesh's own real geometry (no shortcut via a
  coordinate system that doesn't exist here).
- *Resolved:* whether a genuinely traveling pattern exists on this grid —
  yes, confirmed. *Still unproven:* how far it travels before a pentagon
  interrupts it varies by anchor and direction (8 periods / ~112
  generations from one measured anchor) — not yet characterized across
  many anchors, and no attempt made yet to find a *second* known hex
  spaceship for comparison.
- *Cost:* the port itself was cheap once the right object was found — the
  real cost was in the coordinate-convention debugging (an initial wrong
  guess at which diagonal pair of hex neighbors the pattern's axes use
  quietly produced a broken port that looked like just another shuttle
  until checked against a plain flat-grid simulation).

**"Can we find others?" — a second search, also come up empty
(2026-08-07).** `xq14_0ig5l3z102` is the *only* spaceship Catagolue has
ever catalogued for `b2s34h`, checked directly across all 16 symmetry
categories it tracks (not just the default one) — nothing smaller has
ever turned up there either, across ~100 billion soups. `GeodesicGliderSearch2`
then widened past the 1-ring: every population-3-to-5 subset of a 2-ring
patch (19 cells, 16,473 candidates), screened short then confirmed
long-run the same way `xq14_0ig5l3z102` itself was. `2166` looked like
they translated in a short window; **`0` were confirmed travelers over a
long run** — every one was another shuttle. Ran ~8 hours headless,
`neko`.

- *Unproven, still:* population 6-7 in the same 2-ring patch, and any
  population past that 2-ring footprint entirely, are both untried —
  this result narrows the search space, it doesn't close it. Given the
  cost curve so far (1-ring: minutes; 2-ring pop 3-5: ~8 hours), a wider
  pass is a real time investment, not a quick follow-up.
- *Open:* whether it's worth searching further at all, given the known
  spaceship already works and reads fine in play — this is now squarely
  a "nice to have variety" question, not a "does this even work" one.

### True glider guns

**A structure that emits gliders on its own, forever — the way Conway's
Gosper gun does — rather than a scripted re-seed-on-a-timer stand-in.**
Raised explicitly (2026-08-06) so the difference between "spawn point"
(built) and "glider gun" (not attempted) stays visible rather than getting
quietly conflated later.

**Updated (2026-08-09):** the live rule changed from B2/S34 to Jeffrey
Ventrella's own 4-state hex-CA (`docs/game-design/design-decisions-records.md`'s
own entry has the full story), and the confirmed traveler changed with it
— `xq14_0ig5l3z102` (B2/S34, ~8 periods before dissolving at a pentagon) is
superseded by a Ventrella period-2 glider that traveled a chord distance of
`1.812` on a unit sphere (most of the way to antipodal) over ~100
generations before looping back around and colliding with its own launch
site. `GeodesicLifeState`/`xq14_0ig5l3z102` are untouched and still compile
as a fallback, but the *current* ingredient for a gun is the Ventrella
glider, spawned by `GeodesicVentrellaGliderSpawner`, not the old spaceship.

- *Fits:* an emergent gun would be the strongest possible answer to
  "gliders gliding forevermore" — a source, not a scripted timer.
- *Unproven:* whether a gun is even possible here — still half-blocked, not
  fully. One ingredient exists: a real long-range traveler, and a
  considerably better one than before (whole-sphere range vs. ~8 periods).
  Still missing: a second oscillator whose own period lines up to eject
  one cleanly. The old "dissolves at a pentagon" ceiling on how far
  downstream a gun's output could travel is largely gone — this glider's
  own death cause was self-collision with its own launch site after a full
  lap, not a pentagon encounter, so a gun built around it could plausibly
  send gliders most of the way around the sphere before anything catches
  up with them.
- *Cost:* still high, but the blocking half of the prerequisite (any
  confirmed traveler at all) is done, and done better than before — what's
  left is finding or constructing the ejector oscillator, a real but
  bounded search rather than an open one.

### Deliberate pentagon activation, not random soup

**Raised directly (2026-08-06):** the geodesic sphere's ambient soup (Phase
5/6's `B2_S23` default, ~55% population, always churning) reads as too
chaotic — "too many activated cells right from the start... I'd like the
game to be less chaotic, so that the player has ground to think and have a
meaningful impact." The proposed redirect: stop simulating a random board at
all, and let the player *choose* which structure to spawn at which pentagon
— the order/timing of activation becomes the actual puzzle, and a specific
sequence unlocks the route to the maze's goal.

**Shared prerequisite for all four variants below — built (2026-08-06),
carried over under a different rule (2026-08-09).** Turn the ambient soup
off so a spawned structure's own propagation is the only thing happening
and stays legible. Originally built for B2/S34 (`GeodesicGliderTracker`'s
own scripted spawn points); after the live rule switched to Ventrella's
4-state hex-CA (`docs/game-design/design-decisions-records.md`'s own
2026-08-09 entry), the exact same philosophy carried over onto the new
engine — `GeodesicConwayBiome` still doesn't seed the board at all, and
steps `GeodesicVentrellaState` with a `noRandomBirths` source so
`MUTATION_RATE` can't sprout stray life either. The only cells ever alive
now are `GeodesicVentrellaGliderSpawner`'s own 12 pentagon-anchored launch
sites and whatever their own subrule math grows from those — same
requested outcome ("I want only the spawned gliders"), same mechanism in
spirit, new class names. What's still *not* built: any of the four
variants themselves — this only satisfies their shared precondition, not
player choice, unlockable structures, or a later reversion beat. This also
reopens ["a maze-compatible life rule"](#a-maze-compatible-life-rule) from
a different angle: with no ambient soup to sustain, the rule only has to
keep *one deliberately-placed structure* alive/legible near a pentagon,
not the whole sphere — a much smaller design space than what that entry
scoped.

Four variants raised together, not mutually exclusive:

1. **Learn structures elsewhere, unlock them here.** Other biomes teach
   specific Life patterns (gliders and the like); the sphere is one of the
   later stages, only fully playable once some are unlocked. Directly the
   pillar's own worked example — "a key or piece of information gating
   another biome, à la *Outer Wilds*" — not a stretch to fit.
2. **Travel first, mastery later.** The sphere carries both the
   pentagon-activation mechanic *and* an ordinary travel/maze layer from the
   start, so the player sees and walks it early, but only *works* the
   pentagon puzzle once enough has been unlocked elsewhere (per idea 1).
   Softens the sequencing risk of "you can't touch the sphere's real mechanic
   until you've been to N other biomes first."
3. **A later reversion to real soup.** At some story beat, the sphere goes
   back to chaotic, ungoverned Life — genuinely alive again rather than a
   player-conducted instrument. Raised with its own caveat attached ("we'd
   have to see how that fits the narrative") — deliberately not resolved
   here; needs a beat in [storylines/](storylines/README.md) to hang on, not
   invented to fit after the fact.
4. **Two-sided revisit, Conway-specific.** Exterior cells keep the
   jump-over-wall mechanic; interior cells "just paint the floor" and only
   pentagons (recoloured for legibility) actually matter underfoot. This
   is the same shell already built for [the two-sided
   maze](#two-sided-maze-the-open-half) (`biomes.twosided.TwoSidedBiome`) —
   not a new gravity/crossing mechanic, an application of that one here. It
   also inherits that entry's own answer to the obvious objection: the
   exterior doesn't threaten "see far, not near," because
   `biomes.exterior.ExteriorBiome`'s own finding is that the outside curves
   away below the horizon — no global survey is possible from out there
   either way, so the interior keeps its monopoly on seeing far. Also
   inherits that entry's two open questions (how crossing actually works,
   what makes a mark load-bearing) rather than answering them independently.

- *Fits:* [inspirations.md](inspirations.md)'s own geometry-corollary rule
  stays satisfied either way (the pentagons are still the forced topological
  feature the mechanic hangs on); variants 1-2 are the *strongest* fit yet
  for "interconnected, not a level select," since they make the sphere
  literally unfinishable without having been elsewhere first.
- *Unproven:* whether a spawned structure actually stays self-limiting
  under any rule tried so far (see the shared prerequisite above) — nothing
  has been measured yet, this is still at the "idea" stage per the user's
  own framing ("that's a random idea"). Variant 4 additionally inherits
  every open question [the two-sided maze entry](#two-sided-maze-the-open-half)
  already has unresolved.
- *Cost:* varies sharply by variant — turning the soup off is cheap (a
  config change plus, likely, a real rule/propagation-containment pass);
  variant 1's cross-biome unlock system and variant 4's Conway-specific
  two-sided port are both real builds on top of that.
- *Open:* which variant(s) to actually pursue, and in what order — nothing
  committed yet. A reasonable cheap-first path floated in discussion: soup
  off, one fixed structure per pentagon (sidesteps needing a hex-native
  structure *library* at all — see [that backlog
  entry](#a-hex-native-structure-library) — since the puzzle is sequencing,
  not pattern choice), see if the core activate → propagate → wall-opens
  loop feels good before investing in variant 1's unlock system.
- *Open:* whether "wall-gated" has to mean a hard gate at all. A softer
  coupling — walls halving a neighbour's contribution rather than zeroing it,
  or gating only *birth* and not survival — might get the design intent
  without the extinction, and was never tried.

**Story reading added (2026-08-10, hooman).** The same activate →
propagate → wall-opens loop this entry already scopes, reread as the
[Garden of Eden candidate](storylines/garden-of-eden.md)'s
glider evolution stage made literal: the reward for solving the maze this
way is framed as **new information plus a new gameplay mechanism** —
i.e. whatever the taxonomy's next stage (spaceship/gun) unlocks, not a
generic reward. Doesn't resolve any of the open questions above; only
gives the eventual solved-state a narrative payoff to hang variant 1's
cross-biome unlock on, if that candidate wins.

**The composing interface, spec'd (2026-08-10, hooman).** How the player
actually builds the pattern they spawn at a pentagon, worked through
across several rounds:

- **Trigger:** walk up to a pentagon, prompted to press `E`. The
  interface itself is an engraving on the pentagon's own floor — a real
  object in the world, not a screen-space overlay — so it stays inside
  the diegetic-over-chrome pillar without needing an exception.
- **Entry:** `E` starts a continuous camera dolly-in toward the
  engraving (closer, tilted down) — still the sphere-interior POV the
  whole game uses, never a hard cut to an orthographic top-down. `E`
  again reverses it and returns control.
- **Editing:** mouse click/raycast onto the engraved cells toggles them
  on/off. The one mouse-driven interaction in a game that's otherwise
  walk-and-`E` for everything — a deliberate exception, made because
  composing a pattern cell-by-cell via the walk+`E` verb was judged too
  slow.
- **Time while composing:** the rest of the simulation **freezes**
  while zoomed in — plausibly free, since a global time-scale dial
  already exists for the hourglass mechanic
  (`HourglassModel.timeScale`/`BiomesRegistry.globalTimeScale`); setting
  it to `0` for the duration may be all this needs, rather than a new
  pause mechanism.
- **Persistence:** the composed pattern **persists** at that pentagon
  across visits — returning re-opens the same engraving with the same
  cells still toggled, so revisiting to patch a dead branch or extend a
  growing structure is a real, expected use case, not just "compose
  once and leave."
- **Activation:** every ~20 ticks (tunable), the composed pattern is
  **re-stamped onto the live board regardless of what's alive there** —
  a sustaining source that keeps reasserting itself, not a one-shot seed
  left to evolve freely between stamps.
- **Resolved (2026-08-10): overwrite the footprint exactly.** The stamp
  force-sets every footprint cell to exactly what the composed pattern
  says (on or off), not an OR — an evolved neighbour inside the
  footprint gets overwritten every restamp, same as a cell the player
  never touched. The pentagon is a metronome the board can never
  permanently diverge from, not a guaranteed-seed-plus-emergent-growth
  hybrid. **Built** — `tools.geodesic.GeodesicPentagonEngraving.tickAll`
  calls `GeodesicVentrellaState.seedSingle` for every footprint node on
  each restamp, unconditionally.

**Built (2026-08-10)**, full composing interface above included:
`tools.geodesic.GeodesicPentagonEngraving` (per-pentagon pattern
storage, footprint, restamp clock) plus the wiring through
`GeodesicConwayBiome.interact`/`cameraOverride`/`onEditClick` and two
new `biomes.common.Biome` interface methods (`cameraOverride`,
`onEditClick`) every biome now implements. `Keybinds.INTERACT` moved
from `F` to `E` for this (freed by retiring the debug export-maze tool
— see `docs/PROJECT_LOG.md`'s own 2026-08-10 entries). Not yet
persisted across `serialize`/`restore` — an open gap, not a considered
omission.

### Biome links, and the rosetta maze

**Progression gated on knowledge rather than items: you need a key, or a piece of
information, from one biome to get further in another (à la *Outer Wilds*).**

The specific form worth naming — **the rosetta maze**: a maze's walls can carry a
*message*, not just a route, because this game already makes things illegible up
close and legible from afar.

![Two spheres: a dark maze whose eleven blind turns are a string of lefts and rights, and an ordinary maze whose wall pattern draws that same string.](../assets/game-design/rosetta-maze.svg)

- *Fits:* the knowledge *is* the key — no unlock, no item, no UI.
- *Unproven:* whether a constrained layout can stay a solvable maze, and whether
  the pattern can be noticeable without looking like a bug.
- *Cost:* high. Cheapest first step: hand-author one small pattern into one small
  maze, look at it from the far side, and see whether it reads at all.

<details><summary>Worked example</summary>

Say biome A is the candlelight maze where the player can't see and has to turn
correctly at eleven junctions in the dark. Those eleven turns are a string of
lefts and rights. Biome B is an ordinary, solvable sphere maze whose walls, read
as light and dark from the antipode, draw exactly that string — a row of marks, a
shape, a picture of A's route. A player who walks B head-down just solves a maze
and leaves; one who stops and looks across notices the pattern is too regular to
be generated, and now holds A's solution.

The two hard parts: the generator has to satisfy a *constraint* (draw this
pattern) while staying solvable, which is a real generative problem rather than a
parameter; and the pattern has to be findable without being so obvious it reads
as a bug.
</details>

### Secret one-time painting swap (tower)

**Go back up through the tower's *entrance* painting instead of descending to the
goal, and something secret triggers.**

For example: the hub's to-tower painting is swapped for a special one-time-use
variant, available only that one time the player is back in the hub, and reset
the moment they leave through any other biome's painting.

### Broken cells that need fixing

**A cellular automaton biome contains cells that are corrupted or broken — walls
that shouldn't be there, dead patterns that won't propagate — and the only way to
fix them is by visiting another biome, solving a puzzle there, and that solution
retroactively fixes the broken cells in the first biome.**

- *Fits:* "interconnected, not a level select" — the two biomes become a system,
  neither complete without the other. Forces the player to move between spaces,
  carrying knowledge and intent across boundaries.
- *Unproven:* the visual/mechanical clarity of "this broken pattern is waiting for
  a fix from elsewhere" and whether the fix reads as causation or coincidence.
- *Cost:* medium — needs state synchronization across biomes (a puzzle solved in
  biome A affects biome B's simulation) and diegetic communication of the link
  (how does the player understand one is waiting for the other?).

<details><summary>Detail</summary>

The shape: a Life biome (or another rule-based biome) where certain cells or walls
are deliberately "broken" or dormant — a pattern that won't stabilize, oscillate,
or propagate without external intervention. Elsewhere, another biome holds a
puzzle (spatial, puzzle-box, timing-based) whose solution is *the seed pattern or
rule modification* that wakes the broken cells.

Example: a Life board has a region where cells keep dying before forming a glider,
always dying one generation too early. Solving a puzzle in the wind biome (or tower,
or any other) yields the knowledge/pattern/modification that feeds the broken cells
the extra generation they need. Return to the Life biome and the glider is now alive
and travels.

The dangerous part is clarity: the player needs to *know* a cell is broken and
*waiting* for a fix, not just assume it's the way the board is supposed to be. This
is where the "see far, not near" pillar helps — a broken region should look visibly
*wrong* from across the sphere (a pattern that's obviously incomplete, a wall
sequence that's obviously unfinished) while being illegible up close.

Pairs naturally with [cross-biome displacement](#cross-biome-displacement) if both
are built — one moves objects between worlds, the other solves problems in one
world to fix another.
</details>

### Zoom in/out to move between biomes

**Instead of paintings or portals, zoom the camera in and out to transition
between biomes. Zooming into a cell (or a point in space) takes you into a
smaller, nested world; zooming out takes you back to the scale you came from.**

- *Fits:* the geometry-corollary rule — zooming leverages the scale of the sphere
  itself as a navigation mechanism. Also works with fractal/recursive concepts
  ("you're simultaneously inside and outside the sphere").
- *Unproven:* whether the transition feels diegetic and intentional, and whether
  scale-based nesting can stay cognitively legible (how deep is too deep?).
- *Cost:* high — requires significant camera/viewport work, per-biome scale
  relationship definition, and collision/camera-clipping handling at boundaries.
  Alternatively: much cheaper if limited to one or two specific transition points
  per biome rather than global zoom navigation.

<details><summary>Detail</summary>

Two implementations, cheapest first:

1. **Focal-point zoom (limited, cheaper).** Each biome has one or more "zoom
   points" — a specific cell, a junction, a landmark — where the player can
   hold a button to zoom in, smoothly transitioning into the next biome at full
   scale. Zooming out from that biome returns to the same zoom point in the
   previous biome. Think of it like opening a door and stepping through, except
   the door is a focus-and-zoom. Cost: medium — smoother than paintings, needs
   camera interpolation and scale-transition logic, but not a wholesale camera
   redesign.

2. **Full freecam zoom (expensive, ambitious).** The camera can zoom continuously
   from any location; at certain scale thresholds or targets, biomes load/unload.
   The player can zoom into the interior of a cell to find a maze inside, or zoom
   out from the maze to see the cell as part of a larger pattern. Demands per-biome
   scale definitions, nested collision/rendering, and careful camera constraints
   (don't let the player zoom to an impossible scale/position). Cost: high.

The first keeps the spirit — moving between worlds by changing scale — while being
manageable. Start there, and only attempt the second if the first feels too
constrained in play.

Pairs well with fractal/recursive story ideas: if the game's philosophy includes
"you're a pattern that escaped, now discovering larger and smaller patterns," then
zoom-based navigation makes that philosophy *tangible*. Each biome you enter is a
smaller scale, each exit zooms you back up.
</details>

---

## Narrative & characters

### Story and lore

We need a main story to knead everything together — the live exploration is in
[storylines/](storylines/README.md).

### Cute characters

Cats, ghosts, ravens: something with a coherent theme, rather noir.

---

## Controls

### Mobile controls

Deliberately undesigned until there's a playable desktop version to adapt from —
see [`../GUIDELINES.md`](../GUIDELINES.md) §1.8.
