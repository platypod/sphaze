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
| [Walls that behave by a rule](#walls-that-behave-by-a-rule) | wall state | idea (4 variants) | high |
| [Two-sided maze](#two-sided-maze-the-open-half) | topology, gravity | **prototype landed**, crossing open | — |
| [Perception rules](#perception-rules-as-the-biomes-own-variable) | what you may know | **one of ten built** | low each |
| [Antipode pairs](#antipode-pairs) | geometry | idea | medium |
| [Great-circle corridors](#great-circle-corridors) | geometry | idea | high |
| [Junction drafting](#junction-drafting) | who builds the maze | idea | medium |
| [Verticality](#verticality-a-maze-that-isnt-flat) | traversal | idea (3 ways in) | low→high |
| [Paintings mechanics](#paintings-mechanics) | traversal | partly covered by the hub | low |
| [Various levels](#various-levels) | biome identity | idea | — |
| [Per-biome maze recipes](#per-biome-maze-recipes) | biome identity | styles built, assignment open | low |
| [Biome links / rosetta maze](#biome-links-and-the-rosetta-maze) | progression | idea | high |
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
| **Life-driven** | walls follow a cellular automaton | has a real objection against it, below |

- *Unproven:* all four; and Life-driven has a known problem.
- *Cost:* high — see [the engineering
  note](notes/rule-driven-walls-engineering.md) for what the codebase needs
  (short version: one chokepoint already exists; the gaps are rebuild cadence, a
  wall closing on a stationary player, and serializing the rule's phase).

<details><summary>Why raw Conway is a bad wall generator — and four ways it could still work</summary>

Raised directly (2026-07-29): wouldn't a Life board mostly die back, leaving the
maze open? Yes. Random soup at `biomes.conway.ConwayState.INITIAL_DENSITY`
evaporates within a few dozen generations into scattered still lifes and
blinkers — a *mostly open* board. So raw B3/S23 on the walls doesn't work, and
the existing `biomes.conway.ConwayBiome` should be read as what it is (a live
simulation the player walks *on*, with a static maze of its own) rather than a
step toward this.

1. **Invert the mapping** (walls = dead cells) so the sparse stable end-state is
   a sparse *maze* — but then the opening generations are a near-solid block.
2. **Seed deliberate patterns** instead of soup and treat each as level
   furniture: a blinker is a door, a still life is a permanent wall, a glider is
   a moving hazard. This is the version that's actually a *mechanic* (pattern
   literacy) rather than a texture.
3. **Run Life on a subset of edges** layered over a static spanning tree, so
   connectivity is guaranteed by construction and Life can only add or remove
   shortcuts.
4. **Use a rule with a labyrinthine attractor** — B3/S12345 is literally known
   as "Maze" and grows exactly that kind of structure.

Recommendation if it gets built: 3 plus 4, on the cheapest possible board first.
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

---

## Narrative & characters

### Story and lore

We need a main story to knead everything together — the live exploration is in
[story-line.md](story-line.md).

### Cute characters

Cats, ghosts, ravens: something with a coherent theme, rather noir.

---

## Controls

### Mobile controls

Deliberately undesigned until there's a playable desktop version to adapt from —
see [`../GUIDELINES.md`](../GUIDELINES.md) §1.8.
