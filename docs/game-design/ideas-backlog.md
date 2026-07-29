# Ideas backlog

Not implemented yet — parked here until we get to them. Check new entries
against [philosophy.md](philosophy.md) before adding; when an idea gets
implemented, delete it from here (the implementation itself, plus
`../PROJECT_LOG.md`, is the record from then on). Where an entry came from
somewhere outside the project, [inspirations.md](inspirations.md) holds the
reference and the specific lesson taken from it — including the
geometry-corollary rule most of the 2026-07-29 entries below were judged
against.

## Mechanics

- **"Mark now, see later"**: let the player leave marks on the ground (e.g.
  an arrow at a path junction pointing back the way they came). A mark isn't
  legible up close — it only becomes readable once the player is far enough
  away to see it and its surroundings from across the sphere, letting them
  retrace their route (or deduce a better one) from the opposite side.
  Unproven idea — worth prototyping before committing to it.
  - **Someone else messes with the marks** (2026-07-29): marks the player
    left don't always still say what they said. An arrow rotated a few
    degrees, a mark moved one junction over, one added that the player
    never left. The explicit ask is **subtle but noticeable** — the player
    should be able to catch it (and, ideally, start distrusting a
    still-correct mark, which is the better half of the effect), never be
    silently griefed by an invisible RNG. So: tamper rarely, tamper
    *visibly-in-hindsight* (a tampered mark should look slightly wrong when
    re-examined up close, e.g. a hand not the player's), and never tamper
    with the mark the player is currently looking at. Pairs naturally with
    whoever is doing it being a real character (the raven/watchdog in the
    Garden of Eden candidate; the goblin steering visitors in the salvaged
    Minotaur material — see
    [design-decisions-records.md](design-decisions-records.md)). Depends on
    the base mark mechanic existing first; don't build the antagonist
    before the thing it vandalises.
- **Scouting mechanic**: send something off in a direction — a rolling
  ball, a burst of colored gas, whatever reads well — to reveal a bit of the
  path ahead before the player commits to walking it themselves.
- **Cross-biome displacement (send it back where it belongs)**: things
  from one biome turn up in another — a creature or object escaped into
  the wrong world — and the player's job is to spot it and return it
  home. Salvaged from the rejected "Night Shift" story alternative (see
  [design-decisions-records.md](design-decisions-records.md)): the
  storyline died, this mechanic was explicitly kept (hooman: "a great
  idea"). Fits "interconnected, not a level select" (traffic between
  biomes makes them one world) and "see far, not near" (an out-of-place
  thing is exactly what reads from across the sphere — a wrong glint in
  the wrong biome). The existing spawn scaffolding
  (`entities.CreatureSpawnTable`,
  `entities.registries.CreaturesRegistry`/`NpcsRegistry`) is already
  shaped for "what escapes where". Needs chase/lure/carry interactions
  that don't exist in any form yet — prototype the cheapest version
  first, same discipline as every other backlog entry here.
- **Reverse-time mechanic, hung off the hub hourglass**: the hub's own
  tiltable hourglass (`entities.hourglass.HourglassModel`/`Hourglass`, implemented)
  now has a real trigger for this, not just the safety valve this entry used
  to describe — walk it all the way to its minus floor and keep trying to
  push past it (`HourglassModel.overdraftCount`/`OVERDRAFT_UNLOCK_COUNT`)
  and it snaps back to neutral and sets `unlocked` permanently, represented
  today by the sand turning gold. Still exactly as open as this entry always
  said: nothing else in the game reacts to `unlocked` yet. The idea remains
  to hang a real mechanic off it somewhere (undo a hazard, rewind an
  obstacle, replay the player's own last few seconds of movement —
  unproven which). Prototype the cheapest version of whatever that
  mechanic is before wiring it into any biome design, same discipline as
  every other backlog entry here.
- **Falls counter: unlock something for a low count**: the counter itself and
  its floor ring-glow cue are implemented (`biomes.tower.TowerBiome.fallCount`,
  `graphics.shaders.TileRingGlow` — see `../PROJECT_LOG.md`), nudging the
  player toward precision over speed. Still open: the actual objectives hung
  off it. Three scenarios, each meant to unlock something different (nothing
  built yet for any of them): touching only the top and bottom floors (the
  minimum possible), touching every single floor, and anything in between
  (no unlock). What each unlock actually is remains undecided/unproven.
- **Real tree growth over time (Möbius forest)**: the Möbius biome's forest
  (`biomes.mobius.MobiusForestGenerator`, implemented) is a one-time
  procedural scatter today — trees are placed fully-grown, once, at
  `game.GameLoop` startup, same as every other biome's own generated layout.
  hooman: we might want real growth later instead — saplings that visibly
  grow into full trees over time — but explicitly deferred for now in favor
  of the cheaper static version. If this gets built, it should hang off the
  hourglass's own time-scale mechanism (`entities.hourglass.HourglassModel.timeScale`/
  `entities.registries.BiomesRegistry.globalTimeScale`, already global —
  see `../PROJECT_LOG.md`'s "hourglass's own speed effect goes global"
  entry) rather than inventing a second, separate clock: growth would speed
  up, slow down, or (at the hourglass's own extreme tilt) stop dead in
  place along with everything else time-scaled already does, "a mechanism
  with the time stop" per the ask. Needs its own persistent per-tree state
  (a growth stage or planted-at timestamp in `MobiusForestGenerator.PlacedTree`,
  serialized/restored same as the rest of the layout) and a rebuild-on-tick
  or interpolated-scale approach for the actual visual growth — unproven
  which, prototype the cheapest version before committing, same discipline
  as every other backlog entry here.
- **One side affects the other (Möbius strip)**: changing something on one
  lift of the Möbius biome could affect its counterpart on the other — e.g.
  cutting, marking, growing, or otherwise altering part of the strip and
  later discovering the "same" place from the mirrored traversal state has
  changed too. Strong fit for the project's "interconnected, not a level
  select" and "prototype unproven mechanics before committing" pillars:
  this should read as a consequence of the strip's topology, not a generic
  switch puzzle pasted onto it. Worth prototyping with the cheapest possible
  reversible interaction first before designing a whole puzzle chain around
  it.
- **Walls that behave by a rule, not just walls** (2026-07-29): a biome
  whose maze isn't a fixed layout but one governed by a rule the player
  learns to read. Several candidates, each its own biome rather than a
  stack of twists in one:
  - **Metronome walls**: sections rise and fall on the world tick, so
    crossing is a timing problem. The hourglass is already a global
    time-scale control (`entities.hourglass.HourglassModel.timeScale` via
    `entities.registries.BiomesRegistry.globalTimeScale`), which makes the
    player's own difficulty dial diegetic — slow time to make a closing gap
    crossable — at no new-mechanism cost.
  - **Corridors that close behind you**: crossing an edge shuts it. Forces
    the whole route to be planned from across the sphere *before* entering,
    which is the strongest fit for the "see far, not near" pillar of
    anything in this file. Precedent for "shifting a passage is itself a
    move" in [inspirations.md](inspirations.md) (Ravensburger's Labyrinth).
  - **Growth**: hedges that close over time, so the maze you solved is not
    the maze you return through. Shares its clock with the deferred
    Möbius tree-growth entry above — build them on the same mechanism or
    neither.
  - **Life-driven walls** — the Conway variant, and the one with a real
    open question against it (raised directly, 2026-07-29): wouldn't a
    Life board mostly die back, leaving the maze open? Yes — random soup at
    `biomes.conway.ConwayState.INITIAL_DENSITY` mostly evaporates within a
    few dozen generations into scattered still lifes and blinkers, i.e. a
    *mostly open* board. So raw B3/S23 on the walls is a bad wall
    generator, and the existing `biomes.conway.ConwayBiome` should be read
    as what it is (a live simulation the player walks *on*, with a static
    maze of its own) rather than as a step toward this. Four ways it could
    still work, if it's wanted: **(a)** invert the mapping (walls = dead
    cells) so the sparse stable end-state is a sparse *maze* — but then the
    opening generations are a near-solid block; **(b)** seed deliberate
    patterns instead of soup and treat each as level furniture — a blinker
    is a door, a still life is a permanent wall, a glider is a moving
    hazard — which is the version that's actually a *mechanic* (pattern
    literacy) rather than a texture; **(c)** run Life only on a subset of
    edges layered over a static spanning tree, so connectivity is
    guaranteed by construction and Life can only add or remove shortcuts;
    **(d)** use a rule with a labyrinthine stable attractor instead of
    B3/S23 — B3/S12345 is literally known as "Maze" and grows exactly that
    kind of structure. Recommendation if it gets built: (c) plus (d),
    prototyped on the cheapest possible board before any level design
    leans on it.

  **What the codebase would need** (asked directly, 2026-07-29 — answer:
  much less than expected, but not nothing):
  - The good news is that wall state already has exactly **one chokepoint**:
    `biomes.common.grid.GridModel.isOpen`. Rendering
    (`GridMesh`'s own `Walls`), collision (`GridModel.wallZoneNeighbor` →
    `GridCollision`) and decoration placement
    (`GridModel.isWellClearOfWalls`) all ask it rather than reading
    `GridData.openEdges` themselves, so "walls that change" is a change
    *behind* one call, not a change to every consumer. **Keep it that
    way**: the rule to preserve is that nothing snapshots `openEdges` into
    a private copy. One thing already does derive state at load time —
    `biomes.maze.MazeExitWall.find`, cached in `MazeBiome.exitWall` — and
    would need re-deriving (or pinning) whenever a rule-driven layout
    mutates.
  - **Rebuild cadence is the real cost.** `GridMesh.build` builds the whole
    sphere's walls as one `h3d.prim.Polygon`, and `Biome.build` only runs on
    entry. `ConwayBiome` already proves per-step rebuilding is viable at its
    own 0.75s cadence; a full grid maze rebuilt at 60Hz is not. So a
    rule-driven biome needs either rebuild-on-change-only (fine for
    close-behind-you, where changes are rare and player-driven) or walls
    split into per-cell meshes so only the changed cells rebuild.
  - **A wall arriving around a stationary player needs a decided rule**,
    and there isn't one: `wallZoneNeighbor`'s test is deliberately "am I
    deeper into this wall's zone than I was last tick", i.e. a *movement*
    test, which by construction can't fire for a player standing still
    while geometry closes on them. Pick one (refuse the close, eject along
    the nearest open tangent, or harm the player) before any biome depends
    on it, rather than discovering it as a stuck-in-a-wall bug.
  - **Serialization needs the rule's phase, not just the edges.**
    `Biome.serialize` currently encodes open edges alone, which is enough
    for a static maze; a rule-driven one has to save its tick/phase too or
    an exported bug report won't reproduce.
- **Perception rules as the biome's own variable** (2026-07-29): the maze
  is ordinary; what the player is *allowed to know* is what changes. The
  most pillar-aligned axis available, since it works directly on the
  see-far-not-near asymmetry instead of alongside it. Candidates, roughly
  cheapest first — one per biome, never stacked:
  - **Candlelight (invert the asymmetry)**: see near, not far. The
    mansion/shorter-sight level already sketched under "Various levels"
    below. Makes the core hook felt by its absence, and turns marks and
    memory into the only tools.
  - **Inverse-legibility walls**: wall height is what reads from across the
    sphere, so make it a gradient — walls grow *taller* the closer the
    player gets to the goal, meaning visibility drops as they approach and
    the endgame must be executed on a plan made from far away.
    `GridMesh.WALL_HEIGHT` is a single constant today; per-edge height is a
    data change, not an architectural one.
  - **Centre-lit shadows**: one light at the sphere's centre casts every
    wall's shadow onto the *far side*, so the structure of the hemisphere
    behind the player is legible as shadow on the hemisphere in front of
    them. Nothing but a sphere's interior can do this, which makes it the
    strongest geometry-corollary candidate in this list.
  - **Near-fade**: near geometry renders translucent/faint, far geometry
    crisp — the pillar taken literally rather than approximated by fog.
    Cheap to try (a distance term in the wall shader) and immediately
    answers whether the asymmetry is fun when pushed to its limit.
  - **Mirror band**: a polished ring (water at the equator, glass, ice)
    reflecting the far side, so the player can read around their own
    horizon by looking at the reflection instead of across the sphere.
  - **Echo**: a pulse the player emits; walls answer, and the reply's
    rhythm encodes distance. A non-visual perception channel, diegetic by
    construction, and it composes with candlelight rather than competing.
  - **Posture trade**: extend the core mechanic into an explicit exchange —
    crouch and you see local detail but nothing far; raise your head and
    you see across but not your own feet. Today raising your head is free;
    making it cost something is the cheapest way to turn the hook into a
    decision.
  - **One snapshot**: the player may keep exactly one remembered view of
    the far side at a time (a still image, diegetically a sketch or a
    photograph), replacing it whenever they take another. Wayfinding
    without ever handing over a map, per the pillar's own warning.
  - **Drifting fog banks**: patches of occlusion moving across the sphere's
    interior, so surveying is opportunistic — wait for a gap rather than
    look whenever you like. The weakest of these against the
    geometry-corollary rule (it would work in any maze) — noted for
    completeness, not recommended first.
  - **Compass**: always know the bearing of the goal, never the walls (also
    sketched under "Various levels" below).
- **Antipode pairs** (2026-07-29, hooman: "I like the antipod pairs idea"):
  every point on a sphere has exactly one antipode, and — on the interior —
  it is the point the player can see *best*, since it's the farthest one and
  sits dead centre of their view when they raise their head. So make the
  maze paired: what the player does to a wall here happens to its antipodal
  counterpart there, either **identically or inverted** (the shape of the
  ask: "the same/opposite to the corresponding one"). Three verbs worth
  prototyping, cheapest first:
  - **Tag** a wall (no structural change) and its antipode is tagged too —
    the safest first prototype, because it can't make a maze unsolvable
    and it immediately answers the real question: can a player actually
    *find* the antipodal wall by looking, and does that read as a
    connection rather than a coincidence?
  - **Remove/add** a wall and its antipode opens/closes with it (same), or
    closes/opens against it (opposite). "Opposite" is the more interesting
    puzzle and the more dangerous one — it can wall off a region, so a
    solvability check (or a rule that a pair may never close the last route
    to a cell) is part of the design, not an afterthought.
  - **Carry** a wall: pick a wall up here and it can only be set down at an
    antipode — Void Stranger's tile-rod verb (see
    [inspirations.md](inspirations.md)) with the sphere supplying the
    constraint that makes it interesting, since choosing what to move means
    reading the far side and then walking half a world with the shape held
    in memory.

  Implementation note: the antipode of a `GridNode` is a pure key transform
  (`theta → pi - theta`, `phi → phi + pi`, then re-resolve the column
  against `GridModel.colsForRow` — the two rows involved have the same
  column count by symmetry, so pairs are exact rather than approximate),
  and edges pair by their two endpoints' antipodes. Worth checking early
  whether the pole nodes pair with each other cleanly (they should: north's
  antipode is south) since they're the grid's usual special case. Shares
  the "changing here changes there" shape with the Möbius entry above —
  build the second one on whatever mechanism the first one establishes.
- **Great-circle corridors** (2026-07-29): a maze whose corridors are arcs
  of great circles, so *every* corridor followed far enough returns to where
  it started — walking "straight" is a loop, and the puzzle becomes working
  out which circle you're on. Up close every corridor looks identically
  straight, so the only way to tell them apart is from a distance: the
  asymmetry doing load-bearing work rather than being decoration. Wants its
  own layout generator rather than the row/column grid (a set of great
  circles at assorted inclinations, with intersections as junctions), which
  also means its own collision approach — the most structurally expensive
  idea in this file, and worth a cheap unwalkable visual mock-up (just the
  circles, drawn) before committing to walkable geometry.
- **Junction drafting** (2026-07-29): don't generate the maze up front. At
  each junction the player picks what to build there from a small offered
  hand, under constraints (limited pieces, a piece that must be used, a
  budget), with incomplete information about what's beyond. Choosing the
  layout becomes the gameplay rather than a menu — the Blue Prince lesson in
  [inspirations.md](inspirations.md). Two placements, and hooman explicitly
  wants both on the table: **in the sphere**, where the half-built maze is
  visible from across it and so becomes a growing monument to the player's
  own choices (which is the story-line requirement that the player's actions
  visibly accumulate, satisfied by geometry instead of props), and **in
  another biome** with a different topology, where drafting is the whole
  identity rather than a layer on a maze. Open question to answer with the
  cheapest prototype: whether the offered hand is drawn at the junction
  (immediate, tense) or planned before entering (deliberate, more like
  drafting a route) — those are different games.
- **Verticality: a maze that isn't flat** (2026-07-29, hooman: "I like the
  idea of a 3D maze as well… I don't know on which space it will fit best
  yet"): today every walkable surface is a 2D sheet embedded in 3D (sphere
  interior, Möbius strip, the tower's stacked floors), and a maze on it is a
  2D maze. A genuinely 3D maze means the third axis carries route
  information: routes that pass over and under each other, walls whose
  height is a gate rather than a barrier, and dead ends that are only dead
  at one altitude. Three ways in, with different costs:
  - **Jump as a verb** (cheapest): `Biome.gravity()` is already per-biome
    and `GameLoop.JUMP_IMPULSE` is shared, so a low-gravity biome jumps
    higher off the same launch with no new mechanism. Give walls per-edge
    heights and the maze becomes a topographic map — one you can read from
    across the sphere, since height is exactly what reads at distance
    (composes with the inverse-legibility entry above).
  - **Concentric shells**: two or more grid spheres at different radii,
    linked by openings, so "up" moves the player between whole mazes and
    the far side you can see is not the one you're standing on. Fits the
    existing grid code (a second `GridGeometry.RADIUS`) far better than it
    fits the collision code, which assumes one radius per biome.
  - **Zero-G / free flight**: no floor at all, a lattice maze the player
    flies through. The tower already proves real free-fall through open
    space with `FlatSpace`, but removing "there is a surface you stand on"
    invalidates most of what `PlayerModel`/`Camera` assume about a local
    up — the most expensive of the three, and the one to prototype in the
    ugliest possible form first.

  No decision on which space it lands in; the honest first step is the jump
  variant on the existing sphere grid, because it's nearly free and it
  answers whether verticality is fun here at all before anything gets
  rebuilt around it.

## Levels & biomes

- **Paintings mechanics**: based on what's drawn on paintings on the wall,
  we could introduce new mechanics. For instance, a warp between two
  paintings of the same scenery, or two sides of the same scenery, or a wall
  the player can cross through, etc. *Note:* the hub/menu navigation
  (decided 2026-07-17, see `../PROJECT_LOG.md`) already uses paintings as
  doorways to the hub — revisit whether an in-maze warp/cross-through
  mechanic is still separately wanted, or whether that's now covered.
- **Various levels** with varying game design: one in a mansion, with a
  candlelight, with a shorter sight. Another with a compass, another led by
  the wind, etc. Maybe the paintings could be the link between
  biomes/levels, or some kind of portal, or something. We could even base
  some levels on real paintings which we'd enter, solve a related challenge
  to get out with some kind of reward.
- **Biomes links**: perhaps you need to get a key, or a piece of information
  from a biome to be able to progress in another (kind of like *Outer
  Wilds*).
  - **Rosetta maze** (2026-07-29 — the specific form of the above worth
    naming, after the first sketch of it didn't land): the point is that a
    maze's own walls can carry a *message* rather than only a route,
    because this game already has a rule that things are illegible up close
    and legible from far away. Concretely: generate biome B's layout so
    that, seen from a distance, its pattern of open and closed walls isn't
    just corridors — it's a **picture of the answer to biome A**. Say A is
    the candlelight biome where the player can't see and has to turn
    correctly at eleven junctions in the dark. Those eleven turns are a
    string of lefts and rights. B is an ordinary, solvable sphere maze whose
    walls, read as light/dark from the antipode, draw exactly that string —
    as a row of marks, a shape, a picture of A's route. A player who walks B
    with their head down just solves a maze and leaves; a player who stops
    and looks across notices the wall pattern is too regular to be
    generated, and now holds A's solution. Nothing is unlocked, no item is
    granted, no UI says anything: the knowledge *is* the key, which is the
    *Outer Wilds* shape this entry has always been about, made out of
    geometry instead of a note. Two hard parts, both worth knowing before
    building it: the layout generator has to satisfy a *constraint* (draw
    this pattern) while staying a solvable maze — a real generative problem,
    not a parameter — and the pattern has to be noticeable enough to be
    found without being so obvious it looks like a bug. Cheapest first
    prototype: hand-author one small pattern into one small maze, look at it
    from the far side, and see whether it reads at all.
- **Secret one-time painting swap (tower)**: if the player goes back up
  through the tower's own *entrance* painting (the one they fell in
  through) instead of descending to the goal and using the return
  painting, that could trigger something secret — e.g. the hub's
  to-tower painting gets swapped for a special one-time-use variant,
  available only that one time the player is back in the hub, and reset
  (back to the normal tower painting) the moment they leave through any
  other biome's painting instead.

## Narrative & characters

- **Story and lore**: we need a main story to knead everything together —
  the live exploration is in [story-line.md](story-line.md).
- **Cute characters**: cats, ghosts, ravens, something with a coherent
  theme, rather noir.

## Controls

- **Mobile controls** (see [`../GUIDELINES.md`](../GUIDELINES.md) §1.8):
  deliberately undesigned until there's a playable desktop version to
  adapt from.
