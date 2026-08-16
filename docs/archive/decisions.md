# Design decision records

Append-only records of design decisions: what was decided or rejected,
against which alternatives, and why. This is the decision-shaped complement
to `project-log.md`'s chronology — when a file in
[storylines/](../game/README.md) or [philosophy.md](../rules/philosophy.md)
changes state, the reasoning lands here so
the current-state files stay clean. Entries follow this shape:

> **YYYY-MM-DD — Title — STATUS.** What it was; why it got this status;
> what was salvaged, if anything.

## Story-spine exploration (2026-07-22)

Records from the story exploration session; the surviving candidates live
in [storylines/](../game/README.md).

- **2026-07-22 — Story alternative 3, "The Late Resident" (noir /
  self-investigation) — REJECTED.** Recorded because the idea was judged
  genuinely good; rejected because hooman isn't keen on *walking* it —
  playing the ghost of the house's own death is not a fiction they want
  to inhabit, however clean the design. The pitch, for the record: the
  player is the ghost, waking nameless and weightless in the
  sphere-house, seen only by the cat (cats see ghosts); the hourglass
  stopped at the exact moment they died, and the paintings are places
  from their life preserved the way memory preserves places — slightly
  wrong. Driver: the oldest noir hook, detective and case at once — find
  out who you were and how you died. Becoming spine at zero art cost:
  each recovered memory returns an ability the player had in life (you
  don't learn to jump, you *remember* you could — "re-membering" in the
  literal sense), and the world recovers the player in return (portraits
  regain your face, ghosts learn your name back one fragment at a time,
  the raven — corvids really do recognize individual faces for years —
  returns your belongings to an accumulating shelf). Progression
  knowledge-gated in the most literal way possible: you advance by
  finding out. Rereads: the tower is where you fell (fall counter =
  making peace with falling; minimal-falls unlock = the perfect descent
  you didn't get the first time — with an explicit tone guardrail: the
  death stays an ambiguous, investigable case, never a self-harm
  reading); gold sand = recovered moments of your life; the backlogged
  reverse-time mechanic becomes the ending — flip the finished hourglass
  to undo the death at the price of un-knowing everything the player
  became, or let it run out and walk into the last painting whole.
  Salvageable even though rejected: the "world remembers you back"
  impact channel, the ability-as-memory unlock justification, and the
  observation that this and alternative 1 are nearly the same story from
  two protagonists (a house, a painter, a cat, a death) — a possible
  synthesis or sequel door left deliberately unexplored.
- **2026-07-22 — Story alternative 4, "The Night Shift" (whimsy /
  caretaking) — REJECTED.** The player as a cat night guard in a
  museum-sphere whose exhibits wake at night and climb out of their
  paintings; put everything back before dawn, earn promotions into
  deeper wings, uncover why the museum's night runs on bottled time.
  Rejected on the storyline itself (didn't appeal — and it sits in
  Night-at-the-Museum's shadow), not on the register. Salvaged: the
  cross-biome "things escape where they don't belong, send them back"
  mechanic, explicitly kept (hooman: "a great idea") — now a
  story-agnostic entry in [ideas-backlog.md](../open/ideas-backlog.md). One more
  fragment noted before dropping the rest: rehanging paintings as
  player-driven re-curation of which doorway leads where — unclaimed by
  any surviving candidate, worth grabbing if a winner can hold it.
- **2026-07-22 — Story alternative 5, "The Minotaur" (inverted noir /
  becoming) — ABSORBED into alternative 6.** The player as the creature
  that lives in the maze: no mirrors in a labyrinth, so it knows its own
  face only through the paintings that appear in the hub after each
  incursion, painted up on the surface from the testimony of people who
  fled. Driver: reputation as identity — terrify intruders and the
  depictions darken and the heroes come harder; shepherd them out unseen
  and the monster in the paintings slowly gains eyes, hands, a face.
  Rereads: "see far, not near" flips to the warden's view (intruders'
  torchlight crawling the far side of the sphere); the backlogged mark
  mechanic turns adversarial (erase/forge/redraw the intruders' own
  chalk); the hourglass is the prison's sentence, gold sand time served;
  ending = the last hero arrives carrying a mirror, and looking is the
  choice. Never separately accepted or rejected — superseded when hooman
  pivoted from one twisted myth to a whole game of them; survives as
  alternative 6's Labyrinth material, upgraded there by hooman's goblin
  twist.
- **2026-07-22 — Alternative 6, first implementation pass — REJECTED.**
  Hooman liked the twisted-mythologies engine but rejected its first
  concrete dressing wholesale: a Muninn's-errand player role (working
  for Odin's raven Memory, recovering drifted tellings) and a
  pre-assigned myth-to-biome wing list. Kept: the engine (as-told /
  as-found, odd-world topology mapping). Rule going forward: re-derive
  all implementations from whichever motive thread wins — don't
  resurrect the errand framing.
- **2026-07-22 — Story thread B, "The Vacant Throne" (ambition) — SET
  ASIDE.** One of three motive candidates for alternative 6 (with A "The
  Nameless Extra" and C "The Hospice", both still in play). Pantheons
  have empty seats; the hub is a hall of vacant thrones and the player a
  claimant. A throne belongs to whoever the stories say it belongs to,
  so twisting myths *is* the mechanism of power — and the twist that
  would win the throne and the twist that's true keep diverging, with
  the game quietly counting which the player chose; the tally is the
  ending (learn why the seats are empty, then sit, install someone
  fitter, or break the chair). Recorded because the diverging-truth
  device and the empty-seats worldbuilding are strong; set aside because
  ambition as sole driver goes cold without heavy relationship
  counterweight, and gods-and-thrones drifts toward generic epic against
  this game's small noir register.

## Conway maze reactivity (2026-08-03)

- **2026-08-03 — Life-driven walls, option 3 (spanning tree + reactive
  shortcuts) — BUILT.** `biomes.conway.ConwayBiome`'s maze was static
  furniture under a live Life simulation; raised directly as "not
  interesting" and pointed at [ideas-backlog.md](../open/ideas-backlog.md)'s
  "Walls that behave by a rule" entry, which had already flagged the
  raw approach (walls = live cells) as broken — random soup dies back
  into a *mostly open* board within a few dozen generations, so a naive
  density-driven wall rule converges to boring and stays there. Built
  option 3 instead: the DFS spanning tree carved at generation time is
  captured as `ConwayMaze.coreEdges` and never touched, guaranteeing the
  maze stays connected by construction; every other edge
  (`biomes.conway.ConwayMazeReactivity`) opens once either endpoint's
  rolling activity score crosses a high threshold and closes once both
  fall under a lower one (hysteresis, so an edge doesn't flip every
  0.75s tick). Activity is tracked per cell as an EMA of "did this cell
  flip this generation" (`ConwayState.activity`), not raw density —
  deliberately, since a field of frozen still lifes has population but
  no activity, and should read as dead the same way the visible board
  does, rather than holding shortcuts open forever on stale density.
  Per the [engineering note](../building/notes/rule-driven-walls-engineering.md),
  also decided: an edge never closes if it touches the player's current
  cell (refuse-the-close, the simplest of the three offered rules), and
  the rule's phase serializes as part of the existing save (coreEdges
  alongside openEdges, activity alongside the live set) rather than
  needing a new save format. Option 4 (a rule with a labyrinthine
  attractor, e.g. B3/S12345) and option 2 (seeded patterns as level
  furniture) remain open if option 3 alone doesn't hold up in play.

## Conway wall panel + board longevity (2026-08-04)

- **2026-08-04 — Tron-style wall panel — BUILT.** Raised directly: the
  walls were "pretty ugly... lacking depth or texture." Replaced
  `biomes.conway.ConwayMesh`'s flat `h3d.shader.FixedColor` fill with
  `graphics.shaders.ConwayWallGlow` — a dark panel with a Gaussian-falloff
  emissive rim (top/bottom) and vertical seam lines, same falloff
  technique `TileRingGlow` already uses for the tower. Brightness is tied
  to each wall's own `ConwayMazeReactivity.edgeActivity` (carried per-vertex
  in the normal attribute, `GrassWindField`'s established trick for a
  cheap non-lighting per-vertex channel): a wall close to opening pulses
  hot, a quiet one stays dim, so the reactive maze rule from the entry
  above reads visually instead of only through collision.
- **2026-08-04 — Perpetual board mutation — BUILT.** Follow-up ask: the
  visible Life board itself "ends in a very low number of iterations" —
  wants "a bit more life." This is exactly the decay this file's own
  earlier entry already named ("random soup dies back... within a few
  dozen generations"), just felt on the floor board rather than the
  walls it gates. Density alone can't fix it — a frozen block has no live
  neighbors to birth into no matter how the board started. Added
  `ConwayState.MUTATION_RATE` (0.0008/cell/generation, ~1 mutated cell
  per generation across the board): each cell's ruled B3/S23 outcome has
  a small independent chance of flipping anyway, a standard "cosmic ray"
  technique that both seeds fresh births in dead regions and cracks
  existing still lifes back into motion. `ConwayState.step` takes an
  optional `random` source (defaulting to `Math.random`, same DI
  convention `MazeCarver.carve` already uses) so tests can pin it
  deterministic rather than depending on real randomness.

## Conway live-cell hitbox + jump-over-wall (2026-08-04)

- **2026-08-04 — Standable live cells, jump-clears-wall collision —
  BUILT.** Raised directly: "add a hitbox to the cells, so the player can
  jump on a cell, and from there, jump over a wall." Ports
  `biomes.hub.MazeShrine`'s own "airborne above the wall's own height
  clears it" pattern (`blocksMovement`'s `playerHeight` gate,
  `wallTopHeightAt`'s standable top) onto `biomes.conway`, the exact
  jump-variant verticality the backlog's own entry named as "nearly free"
  to try first. `ConwayGrid.groundHeightAt` returns `LIVE_BLOCK_HEIGHT`
  over a currently-alive cell/pole (`0` elsewhere), read fresh every tick
  by `ConwayBiome.applyGravity` the same way `MazeShrine.wallTopHeightAt`
  already is by the hub's — so a cell dying under a standing player drops
  them, free behavior from the existing "recompute every tick" gravity
  contract, no special-casing needed. `ConwayCollision.tryMove` gained a
  `playerHeight >= ConwayGrid.WALL_HEIGHT` OR to its existing open-edge
  check. `LIVE_BLOCK_HEIGHT`/`WALL_HEIGHT` moved from private `ConwayMesh`
  constants to public ones on `ConwayGrid`, so the visual block/wall and
  the real collision heights can't drift apart.

  The one real decision: the numbers didn't work at the existing
  `ConwayBiome.GRAVITY` (`60`, shared with the hub/maze) — a jump's own
  apex there is only `~2.7` units, short of even `LIVE_BLOCK_HEIGHT`
  (`5`), let alone reaching a live cell's top *and* clearing `WALL_HEIGHT`
  (`7.5`) from a second jump off it. Lowered to `28` (apex `~5.8`): clears
  a cell from flat ground with a little margin, and `5 (block) + 5.8
  (second jump) ≈ 10.8` clears the wall with room to spare. Rejected
  alternatives: shrinking `LIVE_BLOCK_HEIGHT`/`WALL_HEIGHT` to fit the
  existing gravity instead — would have undone the just-tuned `ConwayWallGlow`
  wall proportions and made cells barely-there bumps rather than real
  platforms; a per-biome jump impulse — no such hook exists (`GameLoop.JUMP_IMPULSE`
  is one shared constant), while gravity is already `Biome`-scoped, the
  same knob `biomes.twosided.TwoSidedBiome` already tunes for its own
  "jump three walls high" mechanic.

## Conway seed-pattern spawner (2026-08-04)

- **2026-08-04 — Periodic structured spawns (`ConwaySeedLibrary`) —
  BUILT.** Raised directly: `MUTATION_RATE`'s per-cell noise "is fine, but
  the generation is still too dead... more generators and such, some
  movement in the whole biome, structures that live longer, come across
  other structures and mutate and react." Noise alone flickers cells in
  place; it doesn't travel or churn the way a real pattern does. Added
  `ConwayState.STRUCTURE_SPAWN_RATE` (`0.15`/generation, ~1 spawn every
  5 generations): stamps one random pattern from `ConwaySeedLibrary`
  (`GLIDER`, `LWSS` for actual travel; `R_PENTOMINO`, `ACORN` — the two
  best-known methuselahs, 1103 and 5206 generations to settle in
  unrestricted Life — for "live longer") at a random position and 0/90/180/270
  rotation, run *after* the ordinary per-cell rule so the spawn always
  lands rather than being overwritten by that generation's own decision.
  Every stamped cell reads as maximally active (`activityOf = 1`), so a
  fresh structure landing near a wall reacts through
  `ConwayMazeReactivity` immediately, the same as one arriving by
  ordinary play.

  Considered and rejected: a literal Game-of-Life glider *gun* (the more
  literal reading of "more generators"). `ConwayGrid.liveNeighborCount`
  gates every influence, orthogonal included, through the maze's own open
  edges — a gun's ~36x9 footprint needs every internal cell's neighbor
  count exactly right, every generation, and the maze under any given
  spawn is random, so a closed edge somewhere inside is all but certain;
  the gun would fizzle within a handful of generations instead of ever
  firing. The four chosen patterns are far more robust to a stray closed
  edge nearby, and a glider deflecting off a wall it wasn't "supposed" to
  hit is more in character for this biome than a gun silently failing to
  gun would be — see `ConwaySeedLibrary`'s own doc for the full
  reasoning.

## Conway wall transparency + cell lifecycle colors (2026-08-04)

- **2026-08-04 — Live-cell/wall transparency (25%/15%), red wall walked
  back to the original panel — BUILT.** Three quick visual iterations in
  one sitting: live cells alpha-blended to 25% opacity
  (`ConwayMesh.LIVE_BLOCK_OPACITY`); an opened reactive wall first got a
  flat red "ghost" at 25%, then — "actually keep them their original
  color, but make them transparent" — swapped to reusing `ConwayWallGlow`
  itself with a new `opacity` constructor parameter, at 15%
  (`ConwayMesh.GHOST_WALL_OPACITY`), so an opened wall is the same Tron
  panel just faded rather than a distinct color. All three follow the
  same recipe already established by `entities.hourglass.Hourglass`'s own
  dim glass/sand fills: `h3d.mat.BlendMode.Alpha` plus `depthWrite =
  false`.
- **2026-08-04 — Per-cell lifecycle colors — BUILT.** Raised directly: "a
  freshly born cell should be green, a stale one blue, a dead one red
  before disappearing." Added two new pieces of `ConwayState` — `age`
  (consecutive generations a cell has stayed alive, birth is `1`) and
  `justDied` (cells that were alive last generation and aren't now,
  rebuilt fresh every `step`, *not* serialized: a one-generation visual
  cue, not state worth persisting). `ConwayMesh` buckets every live cell
  into one of three separate alpha-blended meshes by `ageOf` against
  `YOUNG_AGE_THRESHOLD` (`4` generations, ~3s) —
  `Colours.CONWAY_TILE_LIVE` (green, reused: the color a freshly-born
  cell already was) below it, `Colours.CONWAY_TILE_STALE` (blue) above
  it — plus a fourth bucket, `Colours.CONWAY_TILE_DYING` (red), for any
  cell `justDiedAt` this generation: it renders once, at the same spot,
  then simply isn't drawn again once `justDied` clears next generation.
  `ConwaySeedLibrary` spawns also set age `1` on every stamped cell, so a
  freshly landed structure reads as a birth rather than inheriting
  whatever "stale" would otherwise show for a cell that only just started
  existing this tick.
- **2026-08-04 — Lifecycle colors walked back to one hue, brightness
  instead — BUILT.** Immediate follow-up: "too much colours... keep
  unicolor-cells, but make them brighter when they birth, dimmer when
  they age, dimmer again when they die." Dropped `Colours.CONWAY_TILE_STALE`/`CONWAY_TILE_DYING`
  entirely; kept the three-bucket mesh structure from the entry above
  (young/stale/dying are still separate draws, since a flat-color mesh
  can't vary per-vertex without `ConwayWallGlow`-style shader work this
  didn't call for) but each bucket now gets the *same* `Colours.CONWAY_TILE_LIVE`
  hue through a new `ConwayMesh.scaledColor` (multiplies RGB by a
  brightness factor, clamped to a valid byte, alpha untouched) —
  `BIRTH_BRIGHTNESS` (`1.3`, deliberately above `1` so birth reads
  brighter than the base hue rather than merely "not dimmed yet"),
  `AGED_BRIGHTNESS` (`0.55`), `DYING_BRIGHTNESS` (`0.28`). Computed from
  one base color programmatically rather than three more hand-picked hex
  constants, so "same hue, different brightness" is structural, not just
  three values that happen to look related.
- **2026-08-04 — Only a young cell's own block clears the wall-jump —
  BUILT.** Raised directly: "only newly-born cells are big enough for the
  player to jump over a wall. The others are slightly shorter, which is
  not enough." `ConwayGrid.LIVE_BLOCK_HEIGHT` split into
  `YOUNG_BLOCK_HEIGHT` (`5`, unchanged) and `AGED_BLOCK_HEIGHT` (`1`,
  new); `ConwayGrid.groundHeightAt` now picks between them via
  `ConwayState.ageOf`/`YOUNG_AGE_THRESHOLD` (moved here from `ConwayMesh`
  so the visual bucket and the real standing height read the same age the
  same way — the constant that used to live only in the rendering code
  now has to be shared, since it gates real physics too). The arithmetic
  that actually matters: a second jump's own apex is `~5.8`
  (`ConwayBiome.GRAVITY`'s own doc), so clearing `WALL_HEIGHT` (`7.5`)
  needs a block at least `~1.7` tall — `AGED_BLOCK_HEIGHT` at `1` isn't
  "slightly shorter" in absolute terms (it can't be and still fail the
  clearance, given how much margin the young case has), but it reads as
  a small, ordinary-looking step down rather than a token nub, which is
  what "slightly shorter" asks for visually even though the actual
  height had to drop by 80% to guarantee the mechanical outcome.
  `ConwayMesh`'s own block geometry (`addBlock`/`addPoleBlock`) now takes
  the height as a parameter instead of assuming one constant, so the
  visual step-down matches the collision step-down exactly — an aged
  cell that looks short *is* short.
- **2026-08-04 — All three block heights dropped, margins now thin —
  BUILT.** Immediate follow-up: "reduce the newly-born cell as well,
  say 2 units high, and we reduce the aged height to 1.5 and the dying
  one to 1." `ConwayGrid.YOUNG_BLOCK_HEIGHT` `5→2`, `AGED_BLOCK_HEIGHT`
  `1→1.5`; new `ConwayMesh.DYING_BLOCK_HEIGHT` (`1`) for the
  one-generation death flash — kept on `ConwayMesh` rather than
  `ConwayGrid` since a dead cell is never `isAlive`, so `groundHeightAt`
  never returns it and nothing is ever standable at that height, unlike
  the other two.

  Flagged directly before building: dropping `YOUNG_BLOCK_HEIGHT` to `2`
  cuts the wall-clearing margin from `3.3` (`5 + ~5.8 jump apex - 7.5
  WALL_HEIGHT`) down to `0.3` (`2 + ~5.8 - 7.5`) — thin enough that the
  fixed-step physics' own discretization could plausibly eat into it.
  Built as asked rather than padding it unasked; `testYoungBlockHeightPlusAJumpsApexClearsWallHeight`
  (`test/biomes/conway/ConwayGridTest.hx`) is the regression check that
  would catch this margin going negative if `GRAVITY` or this constant
  ever drifts. If the in-game jump turns out to miss in practice, the
  real fix is softening the jump apex itself (lower `GRAVITY` further, or
  a smaller `game.GameLoop.JUMP_IMPULSE`) — that changes movement feel
  biome-wide rather than just this one interaction, so it wasn't done
  preemptively.

## Geodesic sphere for Conway (2026-08-04)

- **2026-08-04 — Reversing the lat/long-vs-geodesic call, scoped, not yet
  built — DECIDED.** `docs/archive/project-log.md` records this exact question
  (lat/long + merged poles vs. a pole-safe cube-sphere/geodesic grid)
  already walked through and deliberately deferred before the maze was
  first built, with an explicit "revisit if pole distortion... turns out
  to matter" condition. Raised directly now that it does: "I don't quite
  like the fact that a cell's dimension near the poles is so different...
  What if we based each cell on a hexagon... redesigned our sphere around
  it?" — and, on the 12 unavoidable pentagons an icosahedral hex tiling
  forces (Euler's formula): "I don't mind the N pentagons — on the
  opposite, we will build mechanisms around them" (landed on a pulsing
  beacon rule, modeled as swappable per-node data for future variation).
  Scoped, not started: full design + engineering plan in
  [notes/geodesic-sphere-engineering.md](../building/notes/geodesic-sphere-engineering.md)
  (construction method, generate→score→bake pipeline, four candidate hex
  Life rules, a known-good non-brute-force position→cell lookup borrowed
  from Uber H3's own approach, the pentagon `CellRule` model, and a
  9-phase dependency-ordered build plan). A refinement pass before
  committing to the build order found the rewrite's blast radius
  concentrated in `ConwayGrid`/`ConwayMesh`/`ConwayMaze`/`ConwayState`/
  `ConwayMazeReactivity` (7 of 8 Conway files touch row/col somewhere) but
  `ConwayCollision`/`ConwayBiome` stay nearly untouched (same one-chokepoint
  shape the wall-reactivity work already relied on); also surfaced that
  `ConwaySeedLibrary`'s four patterns are square-grid/B3-S23-specific and
  don't port — a hex-native structure library is its own later phase (8),
  gated on which hex ruleset Phase 5 actually settles on. Nothing found in
  the pass argued against proceeding.
- **2026-08-04 — Phase 1 (topology + data model) — BUILT.** `tools.geodesic`:
  icosahedron data, the subdivide-and-weld generator, a `MazeTopology`
  adapter, a validator, and a bake tool writing
  `res/geodesic/conway-sphere.json` (checked in, not computed live — a new
  `make bake-geodesic` / `bake.hxml` target on `neko`, since file I/O needs
  `sys.io.File` and this project's usual `-js` target doesn't carry it).
  Baked at frequency `11`: 1212 nodes, 12 pentagons (degree 5), 1200
  hexagons (degree 6), matching the `10f² + 2` exit check exactly. One
  simplification found while building, not anticipated in the original
  scoping: computing the Goldberg *dual* explicitly turned out to be
  unnecessary for adjacency — see `GeodesicSphere`'s own class doc. Not yet
  wired into `biomes.conway` or anything the game loads; this is
  infrastructure only, per the build order's own phase 1-4 sequencing.
- **2026-08-04 — Phase 2 (position → cell lookup) — BUILT.**
  `GeodesicLookup`, against Phase 1's baked data. Two real bugs found and
  fixed while building, both past what the engineering note originally
  scoped: (1) the note's "pick the single nearest face, then work only
  within it" plan has a genuine correctness gap at face seams — replaced
  with checking all 20 faces' own candidate and keeping the true closest,
  same `O(20)` complexity bound, just not the more optimistic "usually
  just one face" version; (2) rounding gnomonic-projected barycentric
  weights to the nearest grid index turned out not to reliably find the
  true nearest node (caught by a test: a shared edge's own midpoint
  resolved to a third, objectively farther node) — fixed by also checking
  that point's own immediate 6-neighbor ring, still a fixed `O(20 × 7)`
  bound, not a search that grows with grid resolution. Both exit checks
  from the engineering note now pass for real: every node's own stored
  position resolves to itself, and a dense directional sweep never
  throws. Still infrastructure only — not wired into `biomes.conway` yet.
- **2026-08-04 — Phase 3 (static rendering) — BUILT, exit check confirmed
  by screenshot.** `GeodesicDual` (the boundary-polygon step Phase 1
  deliberately deferred) plus `GeodesicPreview`, a standalone visual
  harness with its own `preview.hxml`/`make preview-geodesic` — not part
  of the actual game. One real bug found and fixed while testing:
  `GeodesicDual.cellBoundary` first used each surrounding triangle's
  *centroid* as a polygon vertex; a test caught it landing measurably
  closer to a neighboring cell's own center than to its own, worst
  around pentagons specifically. Switched to the triangle's
  *circumcenter* (equidistant from all three vertices by definition),
  which fixed it outright. Separately chased down a rendering artifact
  (cells at the preview sphere's own silhouette rendering as
  self-intersecting slivers) before trusting the screenshot — confirmed
  via the same test suite's boundary-angle math that the underlying data
  was always a perfectly regular, correctly-wound polygon, so the
  artifact was a flat-facet/grazing-viewing-angle rendering limitation
  of the preview camera itself, not a bug, and doubly irrelevant since
  the real game never views the sphere as a distant silhouette from
  outside. Final screenshot reads unambiguously as a sphere of hexagons
  with 12 evenly-scattered pentagons. Still not wired into
  `biomes.conway` — phases 1-3 remain pure infrastructure, per the build
  order's own sequencing.
- **2026-08-04 — Phase 4 (collision + movement) — BUILT.**
  `GeodesicCollision`, small as the phase 1-4 sequencing anticipated
  (`PlayerModel` position → `GeodesicLookup.nodeAt` →
  same-node-or-`MazeEdges.isOpen`). No wall-height/jump gate and no
  `groundHeightAt`-equivalent yet — both are tied to a live cell's own
  standable height, which doesn't exist until Phase 5, so there's nothing
  to port there. The exit check's own wording ("walking... behaves like
  the current maze") can't be honored literally — `CLAUDE.md` already
  documents that keyboard input isn't reliable in this project's own
  browser preview, and `GeodesicPreview` has no player. Substituted the
  same thing `biomes.conway.ConwayCollisionTest` already does for the
  *existing* grid: `GeodesicCollisionTest` calls `tryMove` directly
  against a maze actually carved via `GeodesicTopology`/`MazeCarver`, and
  `GeodesicPreview` now renders that carved maze's own closed edges
  alongside Phase 3's tiles — confirmed by screenshot that a real maze,
  not noise, comes out (needed a styling pass once the render showed
  nearly the whole sphere covered in wall ticks: turns out expected — a
  perfect maze over this graph's own average degree (`~6`) closes roughly
  two-thirds of all edges — not a bug, just too dense at the original
  tick size to read against the hexagon pattern underneath).
- **2026-08-05 — Phase 5 (Life simulation) — BUILT.** `GeodesicLifeRule`/
  `GeodesicLifeRules` (the engineering note's own four candidates, as
  data) and `GeodesicLifeState` (`ConwayState` generalized to node-id
  keys, same activity/age/mutation mechanics, neighbor-counting against
  baked adjacency + `MazeEdges.isOpen` instead of a Moore formula). Built
  the headless comparison harness the note called for
  (`GeodesicLifeReport`, a one-off tool, not part of the permanent
  suite/pipeline) and ran all four candidates from the same seed under
  three conditions (unrestricted at two densities, maze-gated), and
  concluded all four rules were statistically indistinguishable. **That
  conclusion was wrong and has been retracted — see the 2026-08-05 entry
  below.** Picked `B2/S23` on that (invalid) basis. Exit check: `GeodesicLifeStateTest`, mirroring
  `ConwayStateTest`'s own shape (isolated-node death, mutation override,
  age-zero-when-dead, seed-density edge cases) plus one hand-verified
  birth/death prediction on an actual mesh triangle — all passing. Still
  not wired into `biomes.conway` — Phase 6 (reactivity + wall visuals) is
  next.
- **2026-08-05 — Phase 5's rule comparison RETRACTED and re-run; Phase 6
  (reactivity + wall visuals) BUILT.**

  *The retraction.* Phase 5's headless comparison was measuring its own
  randomness source, not the rules. `GeodesicLifeReport` runs on neko, and
  the xorshift32 it borrowed from `test.biomes.maze.MazeGeneratorTest` is
  only correct on JS: neko's `Int` is 31-bit, so `>>> 0` never produces an
  unsigned 32-bit value. Measured on neko it returns mean `0`, 50% negative
  draws, 74% below `0.24`. The `MUTATION_RATE` check therefore fired on
  ~half of all nodes per generation instead of `0.08%`, making every rule
  behave as the same coin flip — which is exactly the "all four are
  indistinguishable, all settle at ~50%" result that got written up as a
  finding. The evidence was in the output all along: a seed density of
  `0.24` was reported as 50% of nodes alive. Chosen fix: a new
  `tools.geodesic.SeededRandom` (Park-Miller LCG in `Float`, identical on
  every target) with `SeededRandomTest` pinning its distribution, rather
  than patching the xorshift for neko — a generator whose correctness
  depends on the target's integer width is a trap regardless of which
  targets are in use today. The existing `MazeGeneratorTest.SeededRandom`
  was deliberately left alone: it is correct where it runs (JS only), and
  changing tested code mid-investigation is how one bug becomes two.

  *What the re-run actually says.* Averaged over five board seeds, the
  rules are far apart, not interchangeable — mean settled live share on an
  open board: `B2/S23` `54.9%`, `B2/S34` `2.1%`, `B2/S3` `1.5%`, `B3/S34`
  `0.5%`. `B2/S23` survives as the pick, now on evidence. The more
  consequential finding is that the rule was never the binding constraint:
  **maze openness is.** Every rule dies within ~5 generations on a bare
  carve, because a carve is a spanning tree (~2 open edges per node) while
  every candidate needs 2-3 live *open* neighbors; `B2/S23` only comes
  alive past ~5 open edges per node. Measured and rejected as the fix:
  `MazeBraider` at `fraction = 1` only reaches `2.19` edges per node and
  the board still dies at generation 4 — this biome needs a different wall
  density, not a braid post-pass. Also noted for later tuning: openness `1`
  gives the highest population but collapses activity to `0.056` (still
  lifes, visually static), while `0.75` gives `44.7%` population at `0.289`
  activity — if the biome wants movement, "as open as possible" is the
  wrong target.

  *Phase 6 itself.* `GeodesicReactivity` + `GeodesicLifecycle`, 14 tests,
  full suite green. Two deliberate departures from the square-grid
  originals: reactivity is an instance that resolves the core/reactive edge
  split once in its constructor instead of re-deriving it every generation
  (a third less per-generation work, and no per-edge string building), and
  the lifecycle stage rule lives in one place instead of being
  independently re-derived by `ConwayGrid` and `ConwayMesh` from the same
  readings. `GeodesicPreview` now runs the simulation live. Recorded
  because it cost real time: the preview cannot be seen animating in an
  automated browser pane — a hidden document never fires
  `requestAnimationFrame`, so Heaps' loop doesn't run and every screenshot
  is identical to generation `0`, which is indistinguishable from a frozen
  simulation. `?generations=N` fast-forwards before the first frame so a
  chosen generation is reachable as a still. Worth remembering that this
  RNG bug was caught by *rendering* the biome, not by the test suite —
  every test passed throughout, because they run on JS where the xorshift
  is fine.
- **2026-08-05 — Wall-gated Life on the geodesic sphere — REMOVED; walls
  and Life decoupled.** `biomes.conway`'s square grid only counts a
  neighbour whose edge the maze leaves open. That rule was ported to the
  hex sphere and is now taken back out, because on this topology it doesn't
  shape the dynamics, it ends them: a hex node has 6 neighbours, a carve is
  a spanning tree leaving ~2 open, and every candidate rule needs 2-3 *live*
  neighbours — so a gated board is extinct within ~5 generations, for every
  rule and every seed. `GeodesicReactivity` cannot rescue it, since opening
  a wall needs activity, activity needs life, and life needs open walls; a
  dead board stays dead permanently. The square grid survives the identical
  rule because it has 8 neighbours *and* because `ConwayGrid.allowsInfluence`
  routes diagonal influence through either intermediate cell, so influence
  leaks around corners; a hexagon has no diagonals and every neighbour is
  all-or-nothing.

  Alternatives weighed and rejected: **open the maze up** — `B2/S23` only
  lives past ~5 open edges of 6, at which point there is barely a maze left,
  and `MazeBraider` at `fraction = 1` reaches only `2.19` edges per node
  (measured; board still dies at generation 4). **Bootstrap reactivity from
  a seeded live pocket** — preserves the coupling but leaves the board
  permanently sensitive to seeding and still able to collapse into
  irreversible death. **Search for a rule that works at degree ~2** — the
  right idea, but the candidate set was only ever four rules derived by
  scaling `B3/S23`, so this is a research task, not a fix; parked as a
  backlog entry rather than done under time pressure.

  Chosen: **walls are what the player navigates, Life is what the biome
  does**, coupling one-way (life moves walls, walls don't gate life).
  `GeodesicLifeState.step` no longer takes a `MazeLayout` at all. Two
  measurements taken after the change rather than assumed: `B2/S23` holds
  ~`55%` population and never goes extinct across three seed densities and
  five seeds; and the resulting board, despite low mean activity (~`0.06`
  against a `0.5` open threshold), still moves the walls — settling at 3-7%
  of reactive edges open with continuous local churn, so the maze stays a
  maze with shifting shortcuts rather than freezing or dissolving. Reversal
  is cheap and deliberately kept so: the gate would come back as a change to
  one method. The open question — whether a genuinely maze-compatible rule
  exists, including softer couplings like halving a walled neighbour's
  contribution or gating birth but not survival — is recorded in
  [ideas-backlog.md](../open/ideas-backlog.md).
- **2026-08-06 — Wiring the geodesic sphere into the real game, step 1
  (real mesh rendering) — BUILT.** `GeodesicMesh`, reusing
  `biomes.conway.ConwayMesh`'s own palette and `ConwayWallGlow` shader
  unchanged over the new N-sided cell shape. Needed two small additions to
  existing classes rather than anything in `GeodesicMesh` itself being
  novel: `GeodesicDual.sharedEdge` (the real two-point wall segment shared
  between two adjacent cells' own polygons, derived from a property of
  `cellBoundary` — its `boundary[k]` is the circumcenter of triangle
  `(nodeId, ring[k], ring[k+1])`, so the edge between `boundary[k-1]` and
  `boundary[k]` is exactly the segment shared with `ring[k]` — checked with
  a standalone script before trusting it, then locked down in
  `GeodesicDualTest`) and `GeodesicReactivity.isCore` (a per-edge query;
  the class previously only exposed a count).

  `GeodesicPreview` was rewired to call `GeodesicMesh.build` directly
  instead of keeping its own separate stand-in geometry — one rendering
  implementation instead of two that could quietly diverge, and what the
  preview shows is now literally what the real biome will render. That
  cost the preview's own pentagon/hexagon color distinction (a Phase 3
  diagnostic, not a game mechanic): coloring them apart now would imply a
  rendering distinction that doesn't exist yet, since the pentagon-beacon
  mechanic (build-order Phase 7) is still unbuilt.

  Verified two ways: `GeodesicMeshTest` (new — `build` never throws across
  many generations, and handles the two edge cases where some vertex
  buffer legitimately ends up empty: an entirely dead board, an entirely
  open layout), and a `GeodesicPreview` screenshot showing a real
  hex/pentagon tessellation with wall lines tracing actual cell boundaries
  instead of the fixed-width ticks the Phase 4 placeholder used. Full
  suite green throughout.
- **2026-08-06 — Wiring the geodesic sphere into the real game, step 2
  (`GeodesicConwayBiome`) — BUILT.** Implements `biomes.common.Biome`,
  assembling `GeodesicCollision`/`GeodesicReactivity`/`GeodesicMesh`/
  `GeodesicLookup` — scoped as "mostly assembly," and mostly was, but two
  real gaps surfaced while actually doing it. First: `GeodesicCollision`
  had no wall-height/jump gate at all (it predates `GeodesicLifecycle`,
  the piece that made one possible), so every closed edge blocked
  unconditionally — fixed by porting `ConwayCollision.allowsStep`'s own
  `playerHeight >= WALL_HEIGHT` clause, pinned by a new
  `GeodesicCollisionTest` case. Second: nothing could load the baked
  sphere at runtime — `GeodesicBake` only ever wrote it. Added
  `GeodesicSphere.fromJson`, tested by round-tripping through the exact
  JSON shape `GeodesicBake` produces rather than an invented one, so a
  future bake-format drift fails in the test instead of at runtime;
  loaded via `hxd.Res.load(...).toText()` per this project's own
  asset-loading rule.

  Made `ConwayBiome.GRAVITY`/`BACKGROUND_COLOR` public rather than
  duplicating their values — `GRAVITY` specifically carries real
  jump-clearance derivation in its own doc comment that a copied literal
  would silently detach from.

  `serialize`/`restore` deliberately left as the `Biome` interface's own
  sanctioned `"{}"`/no-op pair (same as `HubBiome`'s) rather than an
  improvised partial save format — real save/load is step 3, not yet
  built, and a half-format here would just be thrown away once it lands.

  Not yet wired into `GameLoop` (step 4) and not runtime-verified: this
  project has no biome-level integration test for *any* biome, so whether
  `hxd.Res.load` actually resolves the baked asset is unconfirmed until
  the swap actually happens.
- **2026-08-06 — Wiring the geodesic sphere into the real game, step 3
  (save/load) — BUILT.** `GeodesicLifeState.serialize`/`deserialize`
  (mirrors `ConwayState`'s own shape, node-id-keyed) and
  `GeodesicConwayBiome.serialize`/`restore` (mirrors `ConwayBiome`'s own
  four-part shape: open edges, core edges, Life state, tick accumulator).

  One real gap: a save has no "freshly carved" layout to hand
  `GeodesicReactivity`'s constructor, only the current `layout.openEdges`
  — which is core ∪ whatever's reactively open right now, not the core set
  itself. Added `GeodesicReactivity.coreEdgeKeys`/`fromCoreKeys` to persist
  and reconstruct the core set on its own; the reconstruction is a
  synthetic core-only layout handed to the existing constructor, not a new
  code path. `GeodesicSphereData` (positions/adjacency) is deliberately
  never part of the save — every session loads the same checked-in baked
  asset fresh, so persisting a copy would be redundant, unlike
  `ConwayMaze` which has no equivalent external asset.

  Verified via round-trip tests for both new pieces (alive/activity/age
  preserved, `justDied` dropped; `fromCoreKeys` agrees with the original
  on `isCore` for every edge, not just a matching count). No biome-level
  test for `GeodesicConwayBiome` itself — this project has none for any
  biome. Full suite green throughout.
- **2026-08-06 — Wiring the geodesic sphere into the real game, step 4
  (the swap) — BUILT.** `game/GameLoop.hx` now registers `new
  GeodesicConwayBiome()` instead of `new ConwayBiome()` — one line plus an
  import, since `ConwayBiome` had exactly one external reference outside
  its own package/tests project-wide; everything else touching it
  (`HubBiome`, `ConwayWaypoint`) only ever used `ConwayBiome.ID`, a string
  constant indifferent to which class backs it.

  Verified two ways: `haxe build.hxml` clean, and the actual built game
  loaded in a real browser. Since `GeodesicConwayBiome`'s constructor runs
  synchronously during registration, before the dev room's first frame,
  the dev room rendering correctly (no console errors, portal signs
  visible) is real confirmation `hxd.Res.load` resolved the baked JSON and
  the constructor didn't throw — closing the gap step 2 had flagged as
  unverified. Explicitly *not* verified: walking into the `conway` portal
  and confirming spawn/mesh/collision/the jump gate in the running game —
  mouse-drag camera look produced no rotation in this environment, the
  same automated-browser input limitation `CLAUDE.md`'s own
  "Manual/interactive verification" section already documents. Needs
  hooman to drive and confirm.

  `biomes.conway.*` and its tests are deliberately untouched — unregistered
  and unreferenced from `GameLoop`, but a complete, still-passing,
  trivially-revertible fallback, not something this step decided to delete.
- **2026-08-06 — Hex-wall straightening — BUILT.** Raised directly ("I'm
  not fond of the hex-shaped walls... when two walls are adjacent on two
  hexes, what if we made them straight?"). The planned approach (bridge
  shallow kinks, leave sharp ones as real corners) was killed by
  measurement before being written: every pass-through kink on a real
  carved maze measures `54°-72°` (median `60°`) with no gap between
  "shallow" and "sharp" — an artifact of the tessellation itself (two
  different hexagons' edges meeting at close to a hexagon's own exterior
  angle), not a signal of whether the corridor is actually turning. No
  per-vertex angle threshold can tell those apart, because there is no
  such distinction to find at a single vertex.

  Built `GeodesicWallSimplifier` instead, using the distinction that
  actually is real: topology, not angle. A vertex where exactly two closed
  walls meet is provably a pass-through; one or three-or-more is a genuine
  anchor (dead end or branch) that must stay put. Collapses every maximal
  pass-through run into one straight chord, no threshold needed. Confirmed
  cosmetic-only: `GeodesicCollision` never reads wall geometry, only the
  node graph, so this can't affect where a player can walk — verified
  before building, not assumed, since it's what made trying this cheap in
  the first place.

  Measured on the real bake (frequency `11`): `43%` of runs already
  anchored on both ends, unchanged; the rest merge a median of `2`
  segments (max `11`); chord length is usually close to the original path
  (median `88%`) but can cut noticeably for a rare long run (`24%` worst
  case) — an accepted cost of a hard chord over full curve-preserving
  simplification (Douglas-Peucker per chain), which wasn't what was asked
  for. Verified via `GeodesicWallSimplifierTest` and a `GeodesicPreview`
  screenshot (visibly fewer, longer, straighter strokes; no console
  errors). Full suite green throughout.
- **2026-08-06 — Hex-wall straightening (`GeodesicWallSimplifier`) — RETRACTED.**
  Built, verified via tests and a screenshot, then played in the real
  biome — which is where it actually broke, not in anything a screenshot
  or a unit test could catch. Two problems: a merged chord's own
  endpoints stop corresponding to any *one* edge collision actually
  blocks on, so the player got stopped somewhere the drawn wall didn't
  visibly explain; and because virtually every wall on this grid is
  already on the reactive edge set (the core spanning tree is never drawn
  as a wall at all), a chain recomputed fresh every generation reshaped
  visibly whenever any single edge inside it flipped — walls appeared to
  "adjust" as edges opened/closed, not just fade. Both are structural to
  merging geometry across several independently-collision-relevant,
  independently-reactive edges, not bugs in the merge logic itself (which
  does exactly what it was built to do). `GeodesicMesh` no longer calls
  it; the class and its own tests are kept rather than deleted, as a
  correct building block for whatever comes next. Direct lesson for this
  project's own "prototype unproven mechanics" pillar: a geometry-only
  screenshot check didn't actually prove this mechanic — playing it did,
  and that gap should be assumed again for anything else that touches
  the relationship between rendered walls and collision.
- **2026-08-06 — Wall straightening, attempt 2: a coarse maze — PROTOTYPE,
  not yet decided.** Raised directly, in response to attempt 1's
  retraction: instead of merging wall geometry, change what the maze
  graph *is* — carve, react to, and (eventually) collide against a
  *coarser* `GeodesicSphere`, while the fine sphere keeps the floor and
  the Life simulation exactly as they are. `GeodesicCoarseMaze.fineToCoarse`
  assigns every fine cell to its owning coarse region via `GeodesicLookup`
  (reused, not reinvented); a wall is drawn only where that assignment
  crosses a coarse boundary, with the fine edge's own real geometry but
  the *coarse* edge's own open/closed state — wall and collision boundary
  are the same object again, at coarse granularity, not approximated
  toward each other the way attempt 1's chords were.

  One assumption checked before building rather than trusted: a boundary
  never skips a region (the two coarse owners of any crossing fine edge
  are always themselves adjacent) — verified with zero violations across
  three frequency pairings before writing `GeodesicCoarseMaze` itself.
  `GeodesicReactivity.step`/`edgeActivity` were generalized from a
  concrete `GeodesicLifeState` parameter to a plain `Int->Float` (every
  existing caller updated to pass `state.activityOf`, behavior
  unchanged) — needed, not optional, once maze and Life stopped sharing
  one node space.

  Still only a prototype: lives entirely in `GeodesicPreview`, not wired
  into `GeodesicConwayBiome`/`GeodesicCollision`. Given attempt 1's own
  lesson above, deliberately not calling this decided until it's been
  played, not just screenshotted.
- **2026-08-06 — Coarse maze moved into the real biome; wall-open rate
  root-caused and reduced — ONGOING, not yet called finished.**
  `GeodesicConwayBiome` now holds both spheres, `GeodesicCollision.tryMove`
  gained an optional `fineToCoarse` remap, and `GeodesicPreview`/
  `GeodesicConwayBiome` share one `GeodesicCoarseMaze.wallSegments`
  implementation rather than two copies. Played result: the mismatch and
  chain-reshaping that killed attempt 1 are gone, but "too many walls
  disappear," reported directly and taken as a real finding, not dismissed.

  Root-caused before touching anything: the Life rule itself (`B2/S23`)
  is untouched — walls never gated it, and nothing here changed that. The
  actual cause was `coarseActivity`'s own per-*node* aggregation (hottest
  fine cell anywhere in a ~5-cell region), compounded twice per edge (max
  of two such regions) — effectively an edge's own open/close decision was
  sampling ~10 fine cells, not the ~2 the original per-fine-edge system
  watched. Measured: fine-cell hot rate `7`-`10%`; region-hot rate (old
  aggregation) `24`-`38%`; resulting coarse-edge open rate `89%` within 10
  generations, settling `49%`, against the original system's own `3`-`7%`.

  Replaced with `boundaryActivity`: per coarse *edge*, from only the fine
  cells actually on that specific boundary — not the whole region either
  side belongs to. Needed a second generalization of
  `GeodesicReactivity.step` (from a node's own activity, `Int->Float`, to
  an edge's own activity directly, `(Int, Int) -> Float`) since a
  boundary-local reading is inherently per-edge, not derivable from two
  independent node values anymore; every existing caller updated to supply
  the old "max of two nodes" behavior explicitly where that's still wanted.

  Result: settled open rate `49% → 30%` — real improvement, more honest
  (no far-region cell votes on a wall it's nowhere near), but not back to
  the original `3`-`7%`, and said plainly rather than smoothed over: a
  coarse edge genuinely touches more fine cells (`4`-`5`) than the
  original design ever did (`2`), so some elevation is structural to
  coarse granularity itself. Whether `30%` is good enough is for actual
  play to decide, not a headless measurement — deliberately left open
  rather than declared fixed.
- **2026-08-06 — Default Life rule switched `B2/S23` → `B2/S34`, same
  session as the coarse-maze open-rate fix — BUILT.** After
  `boundaryActivity` cut settled open rate `49% → 30%`, played again and
  still reported as too much, alongside "we still have way too many cells
  activated." Root-caused past the wall formula this time: `B2/S23`'s own
  settled *population* is `~56%` of the fine sphere, which floods every
  boundary's own activity regardless of how tightly the aggregation
  around it is scoped — the wall-reactivity math was never going to fix
  an upstream population problem by itself.

  Measured properly (300 generations, 8 seeds, real `boundaryActivity`):
  `B2/S23` settles `~9%` open / `~56%` population. `B2/S34` lands almost
  exactly on the actual ask — `4.8%` open (against a stated `5%` target),
  `~1.1%` population — with a real but small risk: `1`/`8` seeds hit zero
  population over 300 generations, self-healing via `MUTATION_RATE`
  within `2` generations (expected at ~1200 cells × `0.0008` ≈ 1 random
  birth/generation even from empty). `B2/S3` was also tried: `6`/`8`
  seeds went extinct, rejected as too fragile.

  Explicitly corrects Phase 5's own "near extinction" characterization of
  `B2/S34` — that was a real reading under the conditions measured then
  (open board, no mutation-recovery framing), not evidence trusted
  forward without re-checking under the actual current conditions.
  Phase 5's separate finding (every rule dies on a bare carved maze with
  zero open edges) is untouched by any of this and remains why walls
  don't gate Life at all.

  Verified: no test broke (the one test whose own doc comment named
  `B2/S23`'s exact `survive = [2, 3]` was checked by hand — the identical
  outcome holds under `B2/S34`'s own `survive = [3, 4]`, since neither
  set includes `1`, the actual number the test's own triangle produces —
  and its doc comment corrected rather than left stale). Full suite green.
  `GeodesicLifeRules.DEFAULT`'s own doc comment carries the full
  three-round history of this pick, since each round was a correct answer
  to the question it was actually asking, not a mistake being repeated.
- **2026-08-06 — Pentagon floor tiles given their own color — BUILT.**
  `GeodesicMesh.build` now routes each cell's floor fan into a separate
  `pentagonFloorPoints`/`pentagonFloorIdx` buffer by degree
  (`neighbors[id].length == 5`) instead of one shared floor mesh, shaded
  with a new `Colours.CONWAY_TILE_PENTAGON` constant. Requested explicitly
  as a reversible experiment ("we might switch opinion a few times") — the
  split into two meshes is the actual mechanism, the color constant is the
  single switch: setting `CONWAY_TILE_PENTAGON` back equal to
  `CONWAY_TILE_DEAD` blends pentagons back in with no other code change.
  Played and confirmed good.
- **2026-08-06 — Glider search run; found shuttles, not travelers;
  pentagon-side spawn points built anyway, explicitly labeled — BUILT.**
  Prompted by "I'd rather have gliders gliding... forevermore" against
  `B2/S34`'s undifferentiated soup. `GeodesicGliderSearch` (exhaustive
  1-ring seed search × `GeodesicLifeRules.ALL`, coordinate-free shape
  matching via `GeodesicShapeSignature`'s sorted pairwise-BFS-distance
  signature) found 24 confirmed-translating patterns out of 508 trials —
  12 fast `B2/S23` 3-cell period-1 patterns, and a shared 6-pattern
  `B2/S3`/`B2/S34` family of 4-cell period-2 patterns.

  `GeodesicGliderTrajectory`'s long-run follow-up (5000 generations, the
  6 `B2/S34` patterns specifically — the rule the real board actually
  plays under) corrected the first reading: every one is a *bounded
  shuttle*, drifting about one hex-cell from its own spawn point and back
  on a long cycle, never trending outward, never reaching a pentagon.
  Robust (no death/explosion/pentagon interaction in any of the 6 over
  5000 generations) but not what "forevermore" asked for — the first
  probe's own "population changed" logging had actually been mistaking
  this family's normal per-generation population breathing (4 cells even
  steps, 3 odd) for pentagon-crossing events; rewritten to track centroid
  drift from spawn instead, which is what actually caught the shuttle
  behavior.

  Built anyway: `GeodesicGliderTracker` seeds one `B2/S34` shuttle each at
  3 spread-out pentagons (`Colours.CONWAY_TILE_GLIDER`, a new amber),
  tracks it forward with the same shape-signature technique run live
  instead of searched historically, and — since a shuttle never leaves to
  make room for a fresh copy — spawns once per site rather than on a
  fixed timer, only retrying after tracking is actually lost and a
  cooldown passes. Scoped explicitly as spawn points, not glider guns, per
  direct instruction ("only go for a spawn-point right now, but flag and
  document the need to go for glider guns later on") — see
  `docs/open/ideas-backlog.md`'s own "True glider guns" entry for
  that follow-up, blocked on a genuine traveler ever being found.

  `GeodesicGliderSearch`'s own `flattestNode`/`localPatterns` helpers were
  split into a new dependency-free `GeodesicGliderPatterns` class once
  `GeodesicGliderTracker` needed them: the search/trajectory classes'
  `Sys.println`-based `main()`s only run on `neko`, and referencing them
  from `GeodesicGliderTracker` (real game code, `-js` target) pulled that
  `Sys` dependency into `build.hxml` and broke compilation.
- **2026-08-06 — Ambient soup removed entirely, same session — BUILT.**
  Requested directly after playing the glider-spawn-point version: "I want
  only the spawned gliders." `GeodesicConwayBiome`'s constructor no longer
  calls `state.seed(...)` at all (previously `SEED_DENSITY = 0.24`, now
  deleted), and `tick` steps `GeodesicLifeState` with a new
  `noRandomBirths` source (`() -> 1`, always above `MUTATION_RATE`)
  instead of the implicit `Math.random` default — otherwise mutation alone
  would keep sprouting stray life across the whole board even with no
  initial seed. The only cells ever alive now are `GeodesicGliderTracker`'s
  own scripted spawns and whatever their own birth/survival math grows
  from those.

  This satisfies the shared prerequisite `docs/ideas-
  backlog.md`'s "deliberate pentagon activation" entry had already named
  (turn the soup off so a spawned structure's own propagation stays
  legible) — noted there, without claiming any of that entry's four actual
  variants (player choice, cross-biome unlocks, etc.) are built.

  Side effect, not separately tuned: `GeodesicCoarseMaze.boundaryActivity`
  now only ever sees activity near the 3 generator sites, so reactive
  coarse walls elsewhere on the maze should stay closed indefinitely —
  expected given no ambient soup exists to open them anymore, not
  independently verified in play yet.
- **2026-08-06 — Real traveling spaceship found and ported, replacing the
  shuttle patterns — BUILT.** After playing the shuttle-based spawn points,
  fed back that nothing was actually gliding, and asked directly for
  research into known hex-CA gliders and search technique rather than
  another local search attempt. Web research found `xq14_0ig5l3z102`: a
  confirmed period-14 spaceship in `B2/S34H` (Golly/Catagolue's own name
  for exactly `GeodesicLifeRules.B2_S34` on a hexagonal neighborhood),
  discovered by Catagolue's own distributed soup search across ~100
  billion random soups — a working example already existed outside this
  project's own 127-pattern 1-ring search space.

  Decoding its apgcode (`decodeCanon`, reimplemented in Node from
  Catagolue's own `rle_tools.js`) gave 12 cells in `(x,y)` hex-on-square
  coordinates. First placement attempt used the diagonal-pair convention
  most web sources describe (`(x+1,y-1)`/`(x-1,y+1)`) and collapsed to a
  3-cell fragment within 15 generations — caught by checking against a
  plain flat-grid Python simulation *before* trusting the sphere port,
  which is what surfaced the actual bug: the *other* diagonal pair
  (`(x+1,y+1)`/`(x-1,y-1)`) reproduces the pattern exactly, generation 14
  matching generation 0 shifted by `(-1,-1)`. Under that pair, `(1,0)` and
  `(0,1)` are 120° apart (not 60°) since they're both neighbors of a
  shared origin cell but not of each other — the detail
  `GeodesicGliderPatterns.hexBasis` gets right by picking two
  angle-sorted neighbors apart, not adjacent.

  Placed onto the real mesh with no coordinate system to lean on: pick two
  of an anchor's own 6 neighbors 120° apart by tangent-plane angle as the
  axial basis, then walk real 3D positions outward, re-deriving "which
  neighbor continues in this direction" at every hop rather than trusting
  neighbor-array order (`GeodesicTopology.axisOf` is `Irregular`
  everywhere). Verified by `GeodesicGliderPort`'s own headless probe: 8
  clean periods (112 generations) of centroid drift growing steadily
  (`0.116` → `0.913`, linear, not the shuttles' oscillation) — real net
  travel — before it reaches a pentagon (`nearest pentagon=0 hops` at the
  exact generation it breaks) and dissolves into a small stable residual
  structure rather than dying or exploding.

  `GeodesicGliderTracker` rewritten around this: `GeodesicGliderPatterns
  .placeKnownSpaceship` replaces the old mask-based 1-ring shuttle
  placement; generator-site anchors now require real pentagon clearance
  (`MIN_PENTAGON_CLEARANCE = 4`, since the pattern's own walk can reach 6
  hex-steps out and a shuttle-era anchor sitting right next to a pentagon
  would regularly fail to place); `spawn` returns `Bool` so a placement
  failure schedules a cooldown retry instead of retrying every tick.
  Tracking/relocation logic (`GeodesicShapeSignature`-based, population +
  shape-signature matching within `TRACK_RADIUS`) needed no changes — it
  was already written generically, not specific to the old 4-cell pattern.

  `docs/open/ideas-backlog.md`'s "hex-native structure library"
  entry marked resolved for the core question (a genuine traveler exists);
  "true glider guns" marked half-unblocked (a real payload glider exists
  now, an ejector oscillator still doesn't).
- **2026-08-06 — Glider tracking bug fixed: exact population/shape match
  broke on the real spaceship's own breathing — BUILT.** Reported directly
  from a screenshot after play: "nothing's gliding... are we using two
  pentagons too close to one another? They seem to be fighting." Root-
  caused with `GeodesicBiomeReplay`, a headless replica of
  `GeodesicConwayBiome`'s own exact construction (real baked fine sphere,
  real `GeodesicGliderTracker`, real `noRandomBirths`-gated
  `GeodesicLifeState.step`): `tracked` fell to `0` within a handful of
  generations of every single spawn and never recovered, confirming
  nothing was ever actually being drawn in `Colours.CONWAY_TILE_GLIDER`.

  Cause: `relocateActive` required the tracked cell set's population *and*
  shape signature to match the value captured at spawn, every generation.
  `xq14_0ig5l3z102` itself breathes between `10` and `12` live cells across
  its own 14-generation period (measured: `12, 10, 12, 11, 12, 12, 12, 12,
  10, ...`) — the very first off-`12` generation broke tracking for good.
  Worse than a cosmetic miss: a tracker that believes its glider is lost
  marks the site due for a fresh spawn, so the *same* site kept reseeding a
  second copy of the pattern directly on top of the first one, which was
  still alive and traveling, just untracked. That collision between two
  copies of one site's own glider — not two different pentagons actually
  fighting — is what the reported screenshot's blob was.

  Fixed by loosening the match: `relocateActive` now accepts whatever's
  alive within `TRACK_RADIUS` of the glider's last known cells as its new
  position, as long as *something* is there and it hasn't grown past a new
  `MAX_TRACKED_POPULATION` (`30`, well above this pattern's own 10-12
  range — high enough to only catch real soup/collision growth, not normal
  breathing). `ActiveGlider`'s now-unused `population`/`signature` fields
  removed along with the check that read them.

  Verified: `GeodesicBiomeReplay` re-run for 1500 generations,
  `population == tracked` at every logged checkpoint, no untracked growth,
  no collision blob recurring. Full suite green, dev server rebuilt clean,
  no console errors — the real test (does a glider actually render amber
  and visibly travel) is still for play to confirm, same as every other
  change this session.
- **2026-08-06 — Wall reactivity switched from decaying activity to binary
  both-cells-alive — BUILT.** Requested directly ("I'd like the wall to
  close faster... a wall only lives if it is surrounded by two live
  cells — a wall only has two adjacent cells, right?") after confirming
  the glider fix worked. `GeodesicCoarseMaze.boundaryActivity` previously
  returned the decaying `activityOf` max across a boundary's own fine
  crossings, so a coarse edge could stay open on lingering recency well
  after the cells that opened it had died — `GeodesicReactivity`'s own
  `CLOSE_THRESHOLD` hysteresis was built to prevent flicker, but it also
  meant "closes eventually," not "closes as soon as it should."

  Rewritten to return `1.0` the instant *any* of a coarse edge's own fine
  crossings has *both* its two adjacent cells alive (`isAlive`, not
  `activityOf`), `0.0` otherwise — no decay. `GeodesicReactivity.step`
  itself needed no changes: its existing `OPEN_THRESHOLD`/`CLOSE_THRESHOLD`
  comparison already behaves as pure immediate open/close for a strictly
  binary `0.0`/`1.0` input. `GeodesicCoarseMazeTest`'s own activity test
  replaced with two deterministic ones (both-alive → `1.0`, only-one-alive
  → `0.0`) instead of the old random-seed-and-compare-against-a-max version,
  since there's no longer a continuous value to approximately match.

  Known trade-off, not separately addressed: closed walls' own glow
  (`WallSegment.activity`, feeding `ConwayWallGlow`) now only ever reads
  `0.0` or `1.0` rather than a smooth buildup — a wall that's about to open
  no longer visibly "warms up" first. Left as-is since it wasn't part of
  what was asked for; revisit only if the binary snap itself reads oddly
  in play.
- **2026-08-07 — Second glider search, also negative — recorded, not
  acted on.** After seeing `xq14_0ig5l3z102` glide, asked directly "can
  we find others?" Checked Catagolue's own record first: that spaceship
  is the *only* one ever catalogued for `b2s34h`, across all 16 symmetry
  categories it tracks. Then ran `GeodesicGliderSearch2`: every
  population-3-to-5 subset of a 2-ring patch (16,473 candidates), same
  screen-then-long-run-confirm rigor as everything else this session.
  `2166` looked promising on a short window; `0` survived long-run
  confirmation — all shuttles. ~8 hours headless, `neko`.

  Not a dead end, just unstarted further work: population 6-7 in the same
  patch, and anything past a 2-ring footprint, remain untried. No code
  changed — `docs/open/ideas-backlog.md`'s own entry carries the
  result and the open question of whether it's worth the compute to keep
  looking, given the known spaceship already works in play.
- **2026-08-07 — Shuttles reinstated as their own generator sites, one
  color per site — BUILT, explicitly "for now."** The six confirmed
  `B2/S34` 1-ring shuttles (bounded, never travel) had been fully retired
  once the real spaceship was ported — reframed directly: not useless for
  never going anywhere, potentially interesting *because* they sit still
  and a traveling glider might run into one. `GeodesicGliderTracker` now
  builds two kinds of site — 3 traveler sites (unchanged) plus 6 shuttle
  sites, one per known 1-ring pattern, anchored directly next to their own
  spread-out pentagon (no `MIN_PENTAGON_CLEARANCE` needed — a 1-ring
  pattern doesn't need walking room the way the spaceship's placement
  walk does).

  Also requested: distinguishable colors per pentagon rather than one
  shared amber, both so a moving structure's origin is legible and so a
  real meeting between two tracked structures reads as two colors
  overlapping rather than one growing. `Colours.CONWAY_TILE_SITE_PALETTE`
  added (9 hues, `CONWAY_TILE_GLIDER` kept as its own first entry);
  `GeodesicMesh.build` reworked from a single glider bucket to one mesh
  per distinct tracked color actually present that generation.
  `GeodesicGliderTracker.trackedCells()` replaces `trackedCellIds()`,
  returning `{id, color}` pairs instead of a flat id list.

  `relocateActive`'s own proximity-based tracking (already population/
  shape-agnostic, from the earlier tracking-bug fix) needed no changes to
  support this — it already keeps following whatever's alive near a
  structure's last position regardless of what that turns into, which is
  exactly what watching an interaction requires.
- **2026-08-09 — Live biome switched from `GeodesicLifeState`'s 2-state
  B2/S34 to a published 4-state hex-CA (Jeffrey Ventrella,
  `https://www.ventrella.com/SphereCA/`) — BUILT.** Third search for
  richer structure, this time widening the *rule* rather than the search
  window: `GeodesicGliderSearchMultiRule` ran the same exhaustive 2-ring,
  population-3-to-5 search across three 2-state candidates (`B2/S34`
  baseline, `B24/S46`, `B35/S2`) — `2166`/`864`/`0` screened positive,
  `0`/`0`/`0` confirmed as long-run travelers under any of them.
  Independently, Ventrella's own published rule demonstrates period-2
  gliders that survive collisions (annihilate, reproduce, or reflect) on
  this exact hex-sphere topology — evolved by genetic search rather than
  hand-derived, and evidenced by the paper's own figures, not just
  claimed. Given three hand-picked 2-state rules all measured empty in
  the small-population range and a fourth, differently-structured rule is
  already demonstrated to work here, switched rather than kept widening
  the same 2-state search.

  **Rejected: keep searching 2-state rules at larger populations/patches
  first.** `GeodesicGliderSearch2`'s own note already flagged population
  6-7 and beyond-2-ring as untried; not chosen because the 2166/864/0
  split across three different birth/survival thresholds reads as this
  rule *family* being thin on this topology, not as one unlucky parameter
  choice — and a working alternative was already in hand, cheaper to try
  than more multi-hour headless search.

  **`GeodesicVentrellaRule`/`GeodesicVentrellaState`** (new): a
  `(referenceState, neighborState, neighborCount, resultState)` subrule
  table (20 subrules, hand-transcribed from the paper's own figure,
  pinned by `GeodesicVentrellaRuleTest`'s shape/transcription checks),
  applied in order each generation with later subrules free to overwrite
  earlier ones — the paper's own "genes expressed under certain
  circumstances" framing. One real adaptation, flagged rather than
  silently assumed: the rule's own neighbor-count digit tops out at `3`
  regardless of a hex node's 6 (or a pentagon's 5) actual neighbors, read
  here as "3 or more" since the source is silent on what a higher raw
  count should mean — untested against the source, worth watching once
  gliders are actually observed in play.

  **Ambient seeding, not scripted spawn sites — asked and answered
  directly.** `GeodesicGliderTracker`'s scripted generator sites (spawning
  the confirmed `B2/S34` spaceship and shuttle patterns at fixed
  locations, one color per site) don't carry over: Ventrella's rule is
  built to produce gliders from generic seed noise, not hand-placed
  patterns, so `GeodesicConwayBiome` now seeds a flat `SEED_DENSITY`
  ambient soup once at construction (and again on a save with no
  persisted state) and steps with real randomness (`MUTATION_RATE`
  included) every tick, instead of tracking generator sites.
  `GeodesicGliderTracker` itself is untouched and unused by the live
  biome — not deleted, since nothing about it was specific to the old
  rule's own math beyond what it happened to spawn.

  **No age-based visual tier — asked and answered directly.**
  `GeodesicLifecycle`'s Young/Aged split read a single species getting
  visually older; Ventrella's states are different species appearing as
  gliders collide, not age classes of one thing, so `LifecycleStage`
  simplified to `Alive`/`Dying`/`Absent`, one flat height/brightness for
  every live cell regardless of which of the three non-zero states it's
  in. Per-state coloring was raised as the natural next step but
  deliberately deferred rather than guessed at ahead of seeing what the
  rule actually produces in play. Real, stated side effect: `ALIVE_BLOCK_HEIGHT`
  reuses the old `YOUNG_BLOCK_HEIGHT` value (not `AGED_BLOCK_HEIGHT`), so
  every live cell is now tall enough for the combo-jump mechanic, not just
  freshly-born ones under the old split — a gameplay-feel change, not an
  unstated side effect of the merge.

  **`GeodesicLifeState`/`GeodesicLifeRule` and every tool built on them**
  (`GeodesicGliderSearch*`, `GeodesicGliderTracker`, `GeodesicGliderTrajectory`,
  `GeodesicLifeReport`, `GeodesicBiomeReplay`, `GeodesicGliderPort`) are
  untouched and still compile — a complete, trivially-revertible
  fallback, the same precedent this project set when `GeodesicConwayBiome`
  itself replaced `biomes.conway.ConwayBiome`.

  **Not yet verified**: whether the rule actually produces visible
  gliders on the real baked sphere, under real wall/reactivity coupling,
  in the running game — this project's own "Claude can't reliably drive
  the game in its browser preview" limitation applies (`CLAUDE.md`'s own
  "Manual/interactive verification" section). What *is* verified: `make
  fmt`/`lint`/`check`/`test` all clean (38,302 assertions, 0 failures),
  including a hand-derived regression pin
  (`GeodesicVentrellaStateTest.testAnIsolatedCellCyclesThroughStatesBeforeDying`)
  confirming the engine's own subrule evaluation matches a by-hand trace
  of the table for an isolated cell (state `1` → `2` → `3` → dies over
  three generations — notably *not* an instant kill the way an isolated
  `GeodesicLifeState` cell is, a real behavioral difference worth knowing
  before reading the biome as "broken" if population doesn't crash
  immediately). Needs hooman to walk the `conway`-labelled portal and
  confirm gliders are actually visible.
- **2026-08-09 — Ambient seeding replaced by scripted glider spawns from
  every pentagon, after a headless diagnosis chain that ruled out three
  wrong explanations before landing on the real one — BUILT.** Played the
  ambient-soup version above; reported directly: "very much 'not much'
  happening... everything dies in a few generations. Then, random
  isolated cells birth, then die." Rather than keep eyeballing that
  through the 3D renderer, moved to pure headless computation —
  `GeodesicVentrellaReport` (population/activity, mirroring
  `GeodesicLifeReport`'s own shape) confirmed it precisely: every seed
  density from `0.1` to `1.0` collapsed to the same `~0.1%` near-total
  extinction, density-independent, which itself explained the "random
  cells birth then die" complaint — an isolated mutated cell cycles state
  `1`→`2`→`3`→dies over exactly 3 generations regardless of density
  (`GeodesicVentrellaStateTest.testAnIsolatedCellCyclesThroughStatesBeforeDying`
  had already proven this by hand).

  **Three wrong turns, each closed off by measurement, not assumption,
  before the real fix:**
  1. *Neighbor-count bucketing.* `GeodesicVentrellaRules.MAX_NEIGHBOR_COUNT`
     caps a subrule's own `neighborCount` digit at `3` despite hex/pentagon
     nodes having `5`-`6` real neighbors — an interpretive gap the source
     paper never resolves. Tried `Clamp` (raw count ≥3 reads as `3`) and
     `Proportional` (raw count scaled by degree) as `NeighborCountMode`;
     neither changed the ambient-soup outcome. Tried a third, more literal
     reading (`Literal` — no bucket at all, raw counts above `3` simply
     match nothing) after re-reading the paper's own wording with
     hooman directly. Also made no difference — and inspecting the actual
     transcribed table digit-by-digit showed why: **every one of the 20
     subrules' own `neighborCount` digit is `0`, `1`, or `2` — none is
     ever `3`.** The three modes only disagree on a comparison against
     `3`, which this specific evolved rule never makes. The whole
     bucketing question was provably moot for this table, discoverable by
     inspection alone, not simulation — a real lesson in checking the data
     before building machinery around a hypothesis.
  2. *Small hand-placed patterns instead of ambient noise.*
     `GeodesicVentrellaGliderSearch` (mirroring `GeodesicGliderSearchMultiRule`'s
     own screen-then-confirm rigor, seeded states restricted to `{1, 3}`
     per the paper's own "collisions evoke state 2" note) found plenty of
     surviving, oscillating small patterns — a real, measured difference
     from ambient soup — but every single one confirmed as a bounded
     shuttle, same as the old B2/S34 search's own outcome. Killed partway
     through (some individual confirms take ~2000 generations; the
     positive-screen rate here was far higher than the B2/S34 search's own
     13%, making a full run impractically slow) once a "denser
     configurations" redesign, requested to specifically stress-test the
     neighbor-count hypothesis, turned out moot by finding #1 above before
     it was even built.
  3. *Re-verifying the transcription.* Re-examined the subrule table
     against a second look at the source image; all four highlighted
     cells (not just the two the paper's own prose explains) checked out
     as internally consistent — `1≡3`, `2` overwritten by `8`, and two
     newly-checked pairs, `7≡15` and `10` overwritten by `13`, matching the
     image's own gray/boxed highlighting convention exactly. Strengthened
     confidence in the table rather than finding a bug.

  **The actual fix: reproduce the paper's own documented glider directly,
  rather than search for one.** All of the above were indirect — hoping a
  search would *stumble onto* a traveler. Never tried *placing* the one
  shape the source paper actually shows (Figure 2: two state-`1` cells two
  hexes apart with one empty hex between them, plus one state-`3` cell
  adjacent to the second black cell). Hand-reconstructed cell-by-cell from
  a description of the figure's own 4 frames, self-verified before
  trusting it (both "the gray cell lands exactly where the previous
  frame's black cell was" checks held exactly, twice, under plain
  axial-hex arithmetic; frame 3 came out exactly frame 1 shifted one hex,
  confirming real period-2 drift by construction). `GeodesicVentrellaFigure2`
  seeded it on the real baked sphere (mapping the description's compass
  directions onto the mesh via a greedy per-hop direction match, since the
  rule only counts neighbor *states*, never neighbor *direction*, so exact
  compass alignment doesn't matter) and it **worked**: chord drift from
  origin climbed to `1.812` (out of a max `2.0` on a unit sphere — most of
  the way to antipodal) over about 60 generations, population locked at a
  stable `6` cells the whole time, then the glider looped back around its
  own great-circle path and died colliding with its own launch site at
  generation `101` — node `24` (part of the original seed) reappeared in
  the final surviving frame, and two state-`2` cells appeared right before
  death, exactly the "collisions evoke state 2" signature the paper
  describes. A real, working, long-range traveler — the first one this
  project has ever confirmed on this rule family, after two failed
  exhaustive searches (B2/S34-family and Ventrella-family alike) turned up
  nothing but shuttles.

  **Shipped as `GeodesicVentrellaGliderPattern` (placement logic) +
  `GeodesicVentrellaGliderSpawner` (12 launch sites, one per pentagon).**
  Each site anchors at its own pentagon's first neighbor (guaranteed a
  hexagon — pentagons are never adjacent to each other) and launches in a
  heading derived from `pentagonIndex % 6`, cycling through every possible
  local direction across the 12 sites rather than all firing the same way.
  Each site respawns every `SPAWN_INTERVAL` (`30`) generations on its own
  staggered clock (`phase = siteIndex * SPAWN_INTERVAL / 12`), so launches
  spread out over time instead of bursting in lockstep — untuned against
  real play, flagged rather than assumed right, the same as `SEED_DENSITY`
  was before it got replaced. `GeodesicConwayBiome.state.step` runs with
  `noRandomBirths` again (reinstated, having been removed when ambient
  seeding was tried) so the board's population is entirely attributable to
  deliberate spawns — the same "I want only the spawned gliders"
  philosophy the original `GeodesicGliderTracker` design had, now paired
  with a rule that actually has a real traveler worth spawning. Anchoring
  this close to pentagons means a glider may cross one within its first
  couple of steps — accepted as an interesting part of watching this rule
  up close, not routed around.

  `generation` (a new `GeodesicConwayBiome` field, incrementing once per
  `state.step`) is now part of `serialize`/`restore` so a restored save's
  spawn sites stay on their own clock rather than resetting to phase `0`;
  `gliderSpawner` itself isn't persisted, since its 12 sites are a pure
  function of the checked-in sphere's own pentagon positions and
  reconstruct identically every session.

  Exit checks: `GeodesicVentrellaGliderPatternTest` (shape contract — 3
  cells, right states, right adjacency, a pentagon origin throws) and
  `GeodesicVentrellaGliderSpawnerTest` (every pentagon's own site
  eventually fires, cadence lands exactly on `phase + SPAWN_INTERVAL`, not
  a generation early). `make fmt`/`lint`/`check`/`test` all clean (38,326
  assertions). **Not yet verified**: whether this reads well in the actual
  running game — `CLAUDE.md`'s own "Claude can't reliably drive the game
  in its browser preview" limitation still applies; needs hooman to walk
  the `conway` portal and watch.
- **2026-08-10 — Two refinements after playing the spawner for real, both
  BUILT.** "It is working" — followed by two concrete notes rather than a
  redesign.
  1. **Spawn density cut to a third.** "We are spawning too much stuff.
     Let's only spawn one glider per 3 pentagons, for now." All-12-pentagons
     read as too busy in play. `GeodesicVentrellaGliderSpawner.PENTAGON_STRIDE`
     (new, `3`) filters which pentagons get a site rather than tuning
     `SPAWN_INTERVAL` down — the complaint was about how much is on screen
     at once, not how often any one site fires, so the fix targets that
     axis specifically. A single constant, deliberately easy to retune
     ("we'll adjust later").
  2. **Live cell blocks now animate instead of popping.** "The whole thing
     feels like it's stuttering, since cells move only at each tick." Root
     cause: live blocks only rebuilt once per `STEP_INTERVAL` (0.75s,
     `GeodesicConwayBiome`'s own generation cadence), so a block appeared
     or vanished in a single frame — inherent to a discrete automaton,
     which has no natural "cell in between two states" the way a moving
     sprite has an in-between position.

     Considered and rejected: true glider-identity tracking with
     interpolated translation (re-introducing something like the old
     `GeodesicGliderTracker`, sliding a tracked shape's visual position
     hex-to-hex) — would look the best specifically for the tracked
     glider, but re-solves a tracking-identity problem this project
     deliberately dropped for simplicity, and does nothing for ambient
     births/deaths elsewhere. Also rejected: shortening `STEP_INTERVAL` —
     doesn't reduce the size of each pop, just how often it happens; trades
     "occasional pop" for "constant flicker," not smoothness.

     **Built: height/opacity crossfade on just the live-cell blocks**,
     cheap enough to rebuild every render frame because it's bounded by
     population size, not `sphere.neighbors.length`. `GeodesicLifecycle.stagesOf`
     snapshots every node's own stage at each generation boundary;
     `GeodesicConwayBiome` keeps two such snapshots (`previousStages`/
     `currentStages`) and calls the new `GeodesicMesh.buildLiveCells` every
     `tick()` — the engine's own fixed 60Hz cadence (`Main.FIXED_DT`), not
     the 0.75s generation step, confirmed by tracing the actual call chain
     (`Main.update` → `GameLoop.fixedUpdate` → `Biome.tick`) before
     building on the assumption — with a lerp factor
     (`accumulator / STEP_INTERVAL`). A node contributes to whichever
     stage it's arriving at (if any height remains at `t`) or the stage
     it's leaving (if fading to nothing); a cell alive in both snapshots,
     the common case, needs no lerp at all. `GeodesicMesh.build` itself
     was split down to just the floor/walls, which don't need any of this
     and still only rebuild once per generation. Collision
     (`applyGravity`'s own `groundHeightOf`) deliberately still reads the
     discrete post-step `state` directly, never interpolated — smoothing
     is visual-only; blending jump timing against a fractional block
     height would make it feel mushy, not smooth.

     `GeodesicMesh.build`'s own unused `trackedCells`/`TrackedCell`-routing
     parameter (dead since the ambient-seeding revision, `GeodesicMesh.TrackedCell`'s
     own doc already flagged it) was dropped from the signature at the same
     time — `GeodesicGliderTracker.trackedCells()` still returns
     `TrackedCell`, kept only because that class stays untouched as a
     fallback, but nothing live routes through it anymore.

     Exit checks: `GeodesicMeshTest` gained coverage specific to the new
     contract (nothing alive in either snapshot → zero children, unlike
     `build`'s own floor/walls which always draw something; a node fading
     out still draws even though its *current* stage alone says nothing's
     alive) plus a never-throws sweep across generations × 5 lerp factors.
     `make fmt`/`lint`/`check`/`test` all clean (38,472 assertions).
     **Not yet verified**: whether the animation actually reads as smooth
     in the running game, same standing limitation as always — needs
     hooman to watch it.
- **2026-08-10 — `LIVE_CELL_BASE_LIFT` (floor Z-fighting) then a
  `depthWrite`-ordering bug (wall bleed-through) — both BUILT, same day,
  in sequence.** Playing the smoothing feature above surfaced two new
  visual complaints at once: "both wall-vs-cells and cells-vs-ground
  (when fade into oblivion) are not too clean-looking." Traced separately
  rather than assumed to share one cause.

  **Floor coincidence.** Before continuous height interpolation existed, a
  live block was always one of three fixed heights (never smaller than
  `1.0`) or entirely absent, so reusing the floor's own `TILE_LIFT` for a
  block's base was harmless — the two were never actually near each
  other. A fading block's height now legitimately approaches `0`, at
  which point a `TILE_LIFT`-based base becomes *exactly* coincident with
  the floor mesh underneath it. `GeodesicMesh.LIVE_CELL_BASE_LIFT` gives
  `buildLiveCells` its own dedicated base, a fixed distance from both the
  floor and a wall's own base at every point during a fade.

  **Wall bleed-through, asked directly** ("How should we address it? Make
  the cell slightly smaller? Or otherwise? I'm not cultured on
  rendering... dare I say mixmapping") **— diagnosed before touching
  anything, not guessed at.** Read Heaps' own render-pipeline source
  first: opaque-vs-alpha draw ordering is architecturally sound
  (`h3d.scene.fwd.Renderer` always draws the opaque "default" pass before
  the "alpha" pass, sorted back-to-front; `depthTest` defaults to `Less`
  regardless of `depthWrite`) — so a solid wall occluding a live cell
  was never actually broken. The real bug:
  `h3d.mat.Material.set_blendMode`'s own `case Alpha` branch sets
  `mainPass.depthWrite = true` as a side effect. Every alpha-blended
  bucket in this renderer (live cells, dying cells, ghost walls) set
  `depthWrite = false` *before* `blendMode = Alpha`, so the explicit
  `false` was silently overwritten back to `true` at runtime — contrary
  to what the code and its own doc comments claimed. With `depthWrite`
  actually `true` on two alpha-blended things sharing the same
  back-to-front alpha pass (a live cell and a ghost wall), whichever one
  draws first in a given frame's distance sort wins the depth buffer
  instead of blending, and that winner flips as the camera moves — "from
  time to time," not a constant failure, matching exactly what was
  reported. Fixed by reordering both statements everywhere the pattern
  occurred (`GeodesicMesh.addLifecycleMesh`, `GeodesicMesh.build`'s own
  ghost-mesh setup, `GeodesicConwayBiome.rebuildMesh`'s own).
  "Make the cell smaller" (the user's own first guess) would not have
  fixed this — the geometry was never overlapping in a way a smaller
  footprint would prevent; the bug was a runtime property flag silently
  reset by an unrelated line, invisible from reading the code alone.

  Exit checks, deliberately not skipped given how easy this exact bug is
  to silently reintroduce: `GeodesicMeshTest` now asserts every
  alpha-blended mesh's own runtime `depthWrite` is `false`, for both the
  live-cell and ghost-wall buckets — and the fix was verified to actually
  matter by temporarily reverting it and confirming the new test fails,
  not just written and trusted. `make fmt`/`lint`/`check`/`test` all
  clean (38,477 assertions). **Not yet visually verified** in the running
  game.
- **2026-08-10 — thick walls (`GeodesicMesh.WALL_THICKNESS`) plus a
  matching collision-clearance check (`GeodesicCollision.WALL_CLEARANCE`)
  — the depthWrite fix above wasn't the whole story.** Reported directly
  after that fix shipped, screenshot attached: "Not fixed, we still see
  some cells through walls." Re-diagnosed rather than assumed fixed —
  the real cause was architecturally different from the first one.
  `GeodesicMesh.addWall` built a single zero-thickness quad; a
  zero-thickness plane has no volume to occlude anything with once the
  viewing angle gets close enough to grazing, whatever the depth/blend
  state — no ordering fix touches that, only giving the wall an actual
  third dimension does.

  **Render fix.** `addWall` now extrudes a real slab: front face, back
  face, and two side caps, `WALL_THICKNESS` (`1.0`) apart, built by a new
  `addWallFace` helper called once per face instead of once for a single
  panel — the original UV/activity convention carries over unchanged,
  just repeated per face.

  **The render fix alone would have been unsafe to ship.** Explicit
  instruction going in: "make sure the player will not be able to stick
  his head IN or THROUGH a wall." `GeodesicCollision.tryMove` was purely
  graph-based — "which cell am I in" — with no distance buffer from a
  wall's own geometry, so it happily let the player walk up to the exact
  line a wall sits on. That line is now *inside* the thickened slab, so
  thickening the render without touching collision would have let the
  camera end up inside solid geometry — arguably worse than the bug being
  fixed. `GeodesicCoarseMaze.boundarySegmentsByFineNode` indexes every
  boundary-crossing wall segment's own world geometry by fine node
  (computed once, in `GeodesicConwayBiome`'s own constructor, since it's
  static — a segment's position never changes, only its openness does);
  `tryMove` now also rejects a move that would land closer than
  `WALL_CLEARANCE` (half the slab's own thickness, plus a small margin)
  to a *closed* segment, via ordinary point-to-segment distance.

  **The safety requirement is a guarantee, not a best-effort mitigation
  — the "never trap the player" clause is why.** A naive clearance check
  ("block if closer than `WALL_CLEARANCE`") would have a failure mode of
  its own: any player who ever ends up too close — a tight spawn point,
  a save from before this landed, a future clearance-radius tweak — could
  find every move blocked and get stuck permanently, unable to even back
  away. `tryMove` only blocks a move when the new clearance is *worse*
  than the old one (`newClearance < WALL_CLEARANCE && newClearance <
  oldClearance`), so retreating out of an already-too-close spot is
  always still possible. Exempt once airborne above
  `GeodesicLifecycle.WALL_HEIGHT`, matching the existing jump-over-the-wall
  combo the graph check already exempts.

  Exit checks: `GeodesicCollisionTest` adds hand-built-segment coverage
  (the same "hand-built edge map" style its own within-one-node test
  already used) for — blocked when a move lands too close to a closed
  segment even though the graph edge itself is open; allowed when a move
  *increases* distance from an already-too-close wall (the safety-net
  case specifically); ignored near an *open* segment; ignored while
  airborne above wall height; and unaffected when `boundarySegments` is
  omitted entirely, covering every pre-existing call site.
  `make fmt`/`lint`/`check`/`test` all clean (38,482 assertions).
  **Not yet visually verified** — same standing limitation as every
  rendering change this session; needs hooman to check both that the
  bleed-through is actually gone and that collision still feels normal
  near walls.
- **2026-08-10 — thick walls also need sealing at the top and at
  junctions, same day, two more rounds after the two entries above.**
  Both caught from a single screenshot of a wall corner shot from a
  raised-head angle (this game's own "look clear across the level"
  mechanic makes both trivial to spot): the slab was open at the top,
  and two segments meeting at a corner left a gap straight through the
  geometry.

  **Open top.** The first "sealed slab" version of `addWall` (the entry
  above) built only the 4 vertical faces — front, back, two side caps —
  and never actually closed the top or bottom, despite its own doc
  comment's claim. `addWall` now adds a top and bottom cap too, using
  the same `addWallFace` helper.

  **Junction gaps.** Each wall segment computes its own thickness offset
  perpendicular to *its own* length — so two segments meeting at a point
  don't share a common thickness direction, and their own front/back
  faces simply don't line up there. Properly mitering each pair is
  angle-dependent, and a junction can have three segments meeting at
  once around a hex/pentagon corner — real work for what's a cosmetic
  seam. `addJunctionPosts` instead drops a small sealed post at every
  point where 2+ segments in a bucket meet, sized (`POST_HALF_WIDTH =
  WALL_THICKNESS / 2`, as a square rather than a circle) to fully cover
  `WALL_THICKNESS` in any tangential direction regardless of the actual
  angle(s) involved, so it doesn't need to know that angle at all.
  "Meets" is by floating-point proximity, not exact equality —
  `GeodesicDual.sharedEdge`'s own two endpoints, queried once per
  neighboring node, come back numerically close but not bit-identical
  (`GeodesicDualTest`'s own `1e-12` distance-squared tolerance is why),
  so this reuses `GeodesicSphere.weldKey`'s existing rounding — already
  trusted for the same "same point, computed twice" problem in
  `GeodesicLookup`'s own weld map — rather than assuming exact matches.
  Wall and ghost buckets get their own posts independently (each
  `buildWallMesh` call runs `addJunctionPosts` over just its own
  segments), so a junction where only one of the meeting edges happens
  to be, say, a wall (the others open) correctly gets no post in the
  wall mesh — nothing there for it to seal, the existing side cap
  already does.

  Exit checks: `GeodesicMeshTest` adds hand-built-segment coverage
  (bypassing real sphere geometry entirely, since what's under test is
  `addJunctionPosts`'s own counting logic, not real wall shapes —
  `testBuildNeverThrowsAcrossManyGenerations` and friends already
  exercise that through a real carved maze) for: two segments with no
  shared endpoint add no extra geometry; a shared endpoint adds a post's
  own geometry beyond the two segments alone; and three segments sharing
  one endpoint still add exactly one post, not one per pair.
  `make fmt`/`lint`/`check`/`test` all clean (38,485 assertions).
  **Not yet visually verified.**
- **2026-08-10 — junction posts became hexagonal pillars, same day, third
  revision.** The square post above worked (closed the gap) but was
  asked directly to be replaced: "rather ugly." Reused as the excuse to
  make the junction actually well-defined rather than merely "big enough
  to cover any angle" — every dual vertex on this mesh is the
  circumcenter of exactly one triangle, so at most 3 wall segments ever
  meet at one, spaced roughly 120° apart by construction (the same
  reason a honeycomb's own vertices are 3-valent). A regular hexagon's
  own faces sit 60° apart, so orienting *one* face toward any one of
  those segments' own departure directions lands roughly every *other*
  face on the remaining ones too — asked directly to confirm this before
  building it ("only orthogonal contacts, should be fine, right?"), and
  it holds: exact at exactly 120° (true away from the 12 pentagons),
  a close approximation near them, where the real angle isn't quite that.
  `POST_RADIUS` (`= WALL_THICKNESS`, a coincidence of the regular-hexagon
  circumradius/apothem ratio at `WALL_THICKNESS`-wide faces, not a second
  independently-chosen number) sizes the pillar so an aligned face lands
  exactly flush with a wall's own edges instead of over- or
  under-covering it. `POST_HEIGHT_MARGIN` (`0.5`, untuned) makes a pillar
  stand a little taller than the walls it joins, also asked directly.
  Orientation is derived from whichever segments are *actually* wall
  right now (the first one found, by iteration order — no need for a
  canonical pick, since a hexagon aligned to any one of 2-3 roughly-120°-
  apart directions serves the others about as well as any other choice
  would), not from the underlying triangle's fixed topology, so a
  pillar's own alignment can shift if the specific subset of surrounding
  edges that are closed changes generation to generation — accepted
  rather than plumbed away, since a shifting-but-still-correctly-sized
  pillar is a non-issue compared to the actual bug (a hole).

  Exit checks: the existing hand-built-segment `GeodesicMeshTest`
  coverage from the entry above needed no changes — it asserts relative
  vertex-count deltas (a shared endpoint adds a post's own geometry; N
  segments sharing one point add exactly one post, not one per pair),
  which hold regardless of the post's own shape. `make fmt`/`lint`/
  `check`/`test` all clean (38,485 assertions, unchanged from the square-
  post version — same coverage, new shape underneath it).
  **Not yet visually verified.**
- **2026-08-10 — the hex pillars above overflowed `hxd.IndexBuffer`'s own
  `UInt16` ceiling, same day, fourth revision.** Reported directly, no
  screenshot needed this time — "texture is stretched from one object to
  a distant one, but a lot of times" is close to a textbook description
  of a wrapped 16-bit index. Not found by reading the code again: found
  by actually building the real pipeline (`GeodesicCoarseMaze.wallSegments`
  → `GeodesicMesh.buildWallMesh`, not the simpler single-sphere path a
  first diagnostic pass mistakenly used) at the real game's own scale
  (fine sphere frequency `11`, coarse frequency `5`, matching
  `res/geodesic/conway-sphere.json` and `GeodesicConwayBiome.COARSE_FREQUENCY`)
  and counting actual vertices: **102,228** in the wall mesh alone — every
  boundary-crossing fine edge turned out to zigzag through the fine
  tessellation at genuine ~120° bends the whole way (measured: 2-segment
  junctions cluster tightly around a `-0.5` dot product between their own
  departure directions, i.e. almost exactly 120°, never near the `-1`
  "basically straight, skip the post" a first hypothesis guessed at), so
  nearly every one of ~1200 wall segments got its own pillar — a real,
  structurally-necessary amount of geometry, not an overcounting bug.
  `hxd.IndexBuffer` is `Array<hxd.impl.UInt16>` underneath (confirmed by
  reading Heaps' own source, not assumed): any index past `65536`
  silently wraps to `index - 65536`, so a huge chunk of that mesh was
  rendering triangles connecting whatever vertex happened to land at the
  wrapped-around index — anywhere else in the mesh, hence "a distant
  one," and since it affects every vertex past the wrap point, "a lot of
  times."

  **Fix: split, not shrink.** `buildWallMesh`'s own signature changes from
  `Null<h3d.scene.Mesh>` to `Array<h3d.scene.Mesh>` — it now starts a
  fresh `Polygon` (`WALL_VERTEX_BUDGET = 60000`, comfortable headroom
  under the hard `65536`) whenever the next `addWall`/`addJunctionPost`
  call would cross it, rather than keeping the pillar density the corner
  gap actually needed and hoping one mesh is always enough. Both call
  sites (`GeodesicMesh.build`'s own internal wall/ghost buckets,
  `GeodesicConwayBiome.rebuildMesh`) now loop over the returned array to
  apply the same per-mesh material settings (`culling`, and for ghosts
  `blendMode`/`depthWrite`) to every chunk instead of a single mesh.
  `addJunctionPosts` split into `collectJunctions` (pure data — every
  junction needing a post) so `buildWallMesh` can check the vertex budget
  *before* committing to a post's own 60 vertices, rather than have the
  old version push straight into a buffer it didn't control the size of.

  Exit checks: a new `GeodesicMeshTest` builds 3000 disjoint synthetic
  segments (no shared endpoints, so junction posts don't complicate the
  arithmetic) — enough to force a split — and asserts every returned
  `Polygon` actually stays at or under the real `65536` ceiling (not just
  the `60000` budget, since the budget is where this method chooses to
  split, not the hard limit itself), and that the total vertex count
  across all chunks matches exactly what ungapped, unchunked geometry
  would produce. `make fmt`/`lint`/`check`/`test` all clean (38,489
  assertions). **Not yet visually verified** — same standing limitation,
  but this is the one fix in this whole chain with a concrete, measured
  root cause (a `UInt16` overflow, confirmed by counting real vertices at
  real game scale) rather than a screenshot-driven guess.
- **2026-08-10 — pillar orientation balanced across every wall meeting
  there, same day, fifth revision.** The index-overflow fix above
  actually shipped a readable screenshot for the first time in this
  whole chain, and it showed the real remaining flaw directly: "the
  pillars are not centered on the wall in all directions." `addJunctionPost`
  anchored a pillar's own rotation to `departures[0]` alone — exact when
  every wall meeting there is *exactly* 120° from the next, which the
  honeycomb-vertex reasoning makes true *on average* but not exactly
  (measured back when diagnosing the index overflow: real 2-segment
  junctions range roughly 113°–126°, not a fixed 120°). Anchoring to one
  wall gave it a perfect fit and left whichever other wall(s) meet there
  to whatever residual the real angle happened to land on.

  `bestFitReference` replaces the single-departure anchor: every
  departure's own angle (relative to an arbitrary zero direction) gets
  folded into a single 60°-period residual — hex face-normals repeat
  every 60° — and those residuals are *circular*-averaged (the standard
  trick for a periodic quantity: scale the period up to a full turn
  before averaging, so a residual near one edge of the fold doesn't
  average incorrectly with one near the other edge of it). The result is
  the single rotation minimizing total misalignment across every wall at
  that junction at once, rather than favoring whichever happened to be
  first.

  Exit checks: rather than reach into `bestFitReference`/`tangentDirection`
  directly — neither is `public`, on purpose, matching `GeodesicCollisionTest`'s
  own "real machinery over private internals" preference — the new test
  builds two real wall segments 110° apart (not the ideal 120°) through
  the public `buildWallMesh`, extracts the built pillar's own corners by
  index, and independently recomputes both the naive (anchor-to-one-wall)
  and actual worst-case misalignment from that extracted geometry,
  asserting the actual one is smaller. `make fmt`/`lint`/`check`/`test`
  all clean (38,491 assertions). **Not yet visually verified** against
  this specific fix — the report that prompted it was itself a visual
  check of the *previous* commit, so the loop is closing, just one commit
  behind as always.
- **2026-08-10 — the pillars are confirmed good; `GeodesicCollision` now
  slides along a blocked wall instead of stopping dead, same day, sixth
  revision.** With the visuals settled, asked directly about the last
  rough edge in this whole chain: "movement along the walls does not work
  well... let's have the player slide along the wall rather than get
  stumped." `WALL_CLEARANCE` (two fixes back) only ever had one move: full
  step or full revert — fine for a graph-only block where there's no wall
  geometry to work with, but once `boundarySegments` gives every wall a
  real position, a shallow-angle approach stopping dead instead of
  sliding is exactly the itch `biomes.common.grid.GridCollision.slideAlong`
  already scratches on the square grid, and this grid never got its own
  version.

  Ported, not reinvented: `GeodesicCollision.slideAlong` keeps the same
  projection (drop the component of the attempted move that runs *into*
  the wall, keep the component that runs *along* it) `GridCollision`'s own
  doc walks through, adapted to this grid's own wall representation — a
  `BoundarySegment`'s own two endpoints and their chord, rather than
  `GridModel`'s row/column wall geometry the square grid derives its own
  tangent from. `tryMove` now: attempts the full step as before; on a
  block, finds the nearest closed segment at the *attempted* landing spot
  (`nearestClosedWallSegment`, a new split out of what `nearestClosedWallDistance`
  already computed — the distance-only version now just calls this and
  reads `.distance`), projects the original direction onto that segment's
  own tangent, and retries as a slide from the *original* position — never
  partway. A near-square hit projects to a near-zero slide distance
  (squashed below `1e-9`, the same floating-point-noise guard
  `GridCollision.slideAlong` already uses), and a slide that's *also*
  blocked (a corner, nowhere to go) reverts fully rather than leaving the
  player half-committed. Gated behind `boundarySegments != null` and the
  existing airborne-above-`WALL_HEIGHT` exemption — every pre-thickness
  call site keeps its old all-or-nothing behavior untouched.

  Also closed the one open `docs/open/bug-tracker.md` entry while verifying
  this: "walk towards the solitary end of a wall... camera can still enter
  it a little" — confirmed fixed (moved to `docs/archive/changelog.md`), a side
  effect of `WALL_CLEARANCE`'s own point-to-segment math already covering
  a segment's endpoints, not just its middle.

  Exit checks: two new `GeodesicCollisionTest` cases build a real
  (non-degenerate) wall segment by hand — `wallPointAt`'s existing
  degenerate single-point fixture won't do here, since a zero-length
  segment has a zero tangent, which would squash every slide to nothing.
  A shallow 0.8/0.6 approach angle confirms the player ends up displaced
  *along* the wall, not toward it; a square-on approach confirms the
  player stops exactly where they started, not a fraction of a unit off
  from floating-point noise. `make fmt`/`lint`/`check`/`test` all clean
  (38,496 assertions). **Not yet visually verified** — same standing
  limitation as ever.
