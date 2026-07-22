# Game design

Two things live in this file: the design **philosophy** (what this game is
trying to be, used to check new ideas against) and the **backlog** of
not-yet-implemented ideas. When an idea gets implemented, delete it from the
backlog (the implementation itself, plus `docs/PROJECT_LOG.md`, is the record
from then on). When a decision changes the philosophy itself, update that
section and note why in `docs/PROJECT_LOG.md`.

## Philosophy

Design pillars, distilled from the core conceit (see `README.md`) and
decisions made so far. Check new ideas against these before adding them to
the backlog below; an idea that cuts against a pillar is a reason to discuss
it explicitly (with hooman) rather than add it anyway.

- **See far, not near.** The core mechanic — raise your head to see clear
  across the sphere, but not what's in your immediate vicinity — is the one
  thing every other system should serve, not compete with. Wayfinding ideas
  (marks, scouting) should work *with* that asymmetry: illegible up close,
  legible from a distance. Don't add something that just hands the player a
  normal map.
- **Diegetic over UI chrome.** Decided for the menu/hub
  (`docs/PROJECT_LOG.md`, 2026-07-17): when a system can plausibly exist *in*
  the world (menus, travel between levels), prefer that over a 2D overlay. A
  modal menu is the one moment that would break the sphere-interior
  viewpoint that's the game's whole hook.
- **Interconnected, not a level select.** Biomes/levels should relate to
  each other — shared throughlines (paintings as doorways, a key or piece of
  information gating another biome, à la *Outer Wilds*) — rather than sit as
  a flat, isolated level list.
- **Coherent, noir-leaning atmosphere.** Tone and cast (cats, ghosts,
  ravens...) should read as one consistent world, not a grab-bag of generic
  fantasy assets.
- **Prototype unproven mechanics before committing.** If an idea's fun is
  genuinely unclear on paper, build the cheapest version that answers that
  before wiring it into level design around it.

## Backlog / ideas

Not implemented yet — parked here until we get to them.

### Mechanics

- **"Mark now, see later"**: let the player leave marks on the ground (e.g.
  an arrow at a path junction pointing back the way they came). A mark isn't
  legible up close — it only becomes readable once the player is far enough
  away to see it and its surroundings from across the sphere, letting them
  retrace their route (or deduce a better one) from the opposite side.
  Unproven idea — worth prototyping before committing to it.
- **Scouting mechanic**: send something off in a direction — a rolling
  ball, a burst of colored gas, whatever reads well — to reveal a bit of the
  path ahead before the player commits to walking it themselves.
- **Cross-biome displacement (send it back where it belongs)**: things
  from one biome turn up in another — a creature or object escaped into
  the wrong world — and the player's job is to spot it and return it
  home. Salvaged from story-spine alternative 4 ("The Night Shift",
  rejected — see that section below): the storyline died, this mechanic
  was explicitly kept (hooman: "a great idea"). Fits "interconnected,
  not a level select" (traffic between biomes makes them one world) and
  "see far, not near" (an out-of-place thing is exactly what reads from
  across the sphere — a wrong glint in the wrong biome). The existing
  spawn scaffolding (`entities.CreatureSpawnTable`,
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
  `graphics.shaders.TileRingGlow` — see `docs/PROJECT_LOG.md`), nudging the
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
  see `docs/PROJECT_LOG.md`'s "hourglass's own speed effect goes global"
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

### Levels & biomes

- **Paintings mechanics**: based on what's drawn on paintings on the wall,
  we could introduce new mechanics. For instance, a warp between two
  paintings of the same scenery, or two sides of the same scenery, or a wall
  the player can cross through, etc. *Note:* the hub/menu navigation
  (decided 2026-07-17, see `docs/PROJECT_LOG.md`) already uses paintings as
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
- **Secret one-time painting swap (tower)**: if the player goes back up
  through the tower's own *entrance* painting (the one they fell in
  through) instead of descending to the goal and using the return
  painting, that could trigger something secret — e.g. the hub's
  to-tower painting gets swapped for a special one-time-use variant,
  available only that one time the player is back in the hub, and reset
  (back to the normal tower painting) the moment they leave through any
  other biome's painting instead.

### Narrative & characters

- **Story and lore**: we need a main story to knead everything together.
  Candidate story spines are collected in the section below while we
  explore; none is chosen yet.
- **Cute characters**: cats, ghosts, ravens, something with a coherent
  theme, rather noir.

### Story spine — alternatives under exploration

Candidates for the main story, gathered as we explore (2026-07-22 session
onward). No decision yet — more alternatives are still being drafted. When
one wins, log the decision in `docs/PROJECT_LOG.md` with the rejected
alternatives and why they lost, fold the winner into the Philosophy
section above, and reshape the backlog entries to hang off it.

Common ground both current candidates were built on (treat these as
requirements for any further candidate too): the player's actions must
visibly accumulate in the hub ("impact on the world" made literal — which
in turn needs persistence across sessions, not yet built); progression is
curiosity/knowledge-gated per the "interconnected, not a level select"
pillar; storytelling stays fully diegetic (no cutscenes, no journal UI);
and the hourglass's existing gold-sand unlock
(`entities.hourglass.HourglassModel.unlocked`) becomes the first story
beat — the moment its meaning is revealed.

- **Alternative 1 — "The Painter's House" (warm / restoration).** The
  player is a cat in the house of a painter who is gone — dead, or lost
  inside their own work; never said outright. The hub sphere is the house;
  the wall paintings are the painter's works, which a cat can slip into.
  The hourglass ran out at the moment the painter vanished, and each
  painting-biome holds a portion of the painter's time crystallized as
  gold sand. Driver: set right the one wrong thing in each painting and
  bring the sand home; each return wakes the house a little more (lamps
  light, ghosts talk, ravens arrive, hub paintings visibly repaint to
  reflect what the player changed). Mechanical rereads: the fall counter
  is a cat judged on its landings ("top and bottom floors only" = two
  perfect drops); raising your head to see across the sphere is a cat's
  posture; the time-scale tilt is borrowing the painter's power; deferred
  tree growth plugs into returned time. Ending: with all sand returned the
  player can flip the hourglass — restart the painter's time, or let the
  house rest — one diegetic walk-up choice. Costs: none on art (keeps all
  current assets and the noir tone as-is); weaker moment-to-moment power
  progression than alternative 2 — its strengths are place and ending, its
  driver is restoration (warm, melancholy, finite).
- **Alternative 2 — "Garden of Eden" (cold / becoming).** The player is a
  pattern in a cellular automaton that became something the rules don't
  account for, fell out of its grid during a crash, and landed in the
  developer's machine. The hub is the computer seen from inside; paintings
  recast as glowing windows into running programs. Driver: evolution up
  the real CA taxonomy, each stage a gameplay unlock — still life (walk),
  oscillator (act on the world's tick), glider (jump/traversal), spaceship
  (speed), gun (emit scout patterns — the backlog's scouting mechanic),
  and finally Garden of Eden: a configuration with no possible
  predecessor, the mathematical proof the player did not evolve from the
  system. Each infiltrated program yields a rule fragment; Life iterations
  at different versions are core biomes, mapping straight onto the
  existing space-topology abstraction (`biomes.common.space` — flat,
  sphere, Möbius): the Möbius biome becomes the build with a twisted
  boundary condition, making "one side affects the other" the honest
  consequence of its topology. Mechanical rereads: "see far, not near" is
  a theorem here (a glider is only a glider from afar; up close it's five
  meaningless cells — mark-now-see-later follows instantly); the
  hourglass is the simulation clock (time-scale = touching the scheduler,
  gold sand = stolen root/CPU time); the tower is a call stack (minimal
  falls = tail-call optimization). Cast translates to computing folklore:
  ghosts become daemons and zombie processes, the raven a watchdog that
  notices and reports what the player changes, the cat stays as an
  outside god (the developer's real cat on the keyboard). Story channel:
  the developer's own notes/commits change between runs as they slowly
  discover the player exists; ending choice — reveal yourself, merge back
  into the grid, or leave through the network. Costs: real ones on art —
  stone/grass/forest doesn't survive, needs a digital-noir re-skin
  (phosphor/CRT dark keeps the noir pillar but nothing painterly); the
  fiction invites expectations of cellular/generative visuals (bigger
  rendering commitment); cats/ghosts/ravens survive only by translation.
  Its driver is becoming (cold start, escalating power) — strongest
  moment-to-moment progression of the candidates so far.
- **Alternative 3 — "The Late Resident" (noir / self-investigation) —
  REJECTED (2026-07-22).** Recorded because the idea was judged genuinely
  good; rejected because hooman isn't keen on *walking* it — playing the
  ghost of the house's own death is not a fiction they want to inhabit,
  however clean the design. The pitch, for the record: the player is the
  ghost, waking nameless and weightless in the sphere-house, seen only by
  the cat (cats see ghosts); the hourglass stopped at the exact moment
  they died, and the paintings are places from their life preserved the
  way memory preserves places — slightly wrong. Driver: the oldest noir
  hook, detective and case at once — find out who you were and how you
  died. Becoming spine at zero art cost: each recovered memory returns an
  ability the player had in life (you don't learn to jump, you *remember*
  you could — "re-membering" in the literal sense), and the world recovers
  the player in return (portraits regain your face, ghosts learn your
  name back one fragment at a time, the raven — corvids really do
  recognize individual faces for years — returns your belongings to an
  accumulating shelf). Progression knowledge-gated in the most literal
  way possible: you advance by finding out. Rereads: the tower is where
  you fell (fall counter = making peace with falling; minimal-falls
  unlock = the perfect descent you didn't get the first time — with an
  explicit tone guardrail: the death stays an ambiguous, investigable
  case, never a self-harm reading); gold sand = recovered moments of your
  life; the backlogged reverse-time mechanic becomes the ending — flip
  the finished hourglass to undo the death at the price of un-knowing
  everything the player became, or let it run out and walk into the last
  painting whole. Salvageable even though rejected: the "world remembers
  you back" impact channel, the ability-as-memory unlock justification,
  and the observation that this and alternative 1 are nearly the same
  story from two protagonists (a house, a painter, a cat, a death) — a
  possible synthesis or sequel door left deliberately unexplored.
- **Alternative 4 — "The Night Shift" (whimsy / caretaking) — REJECTED
  (2026-07-22).** The player as a cat night guard in a museum-sphere
  whose exhibits wake at night and climb out of their paintings; put
  everything back before dawn, earn promotions into deeper wings,
  uncover why the museum's night runs on bottled time. Rejected on the
  storyline itself (didn't appeal — and it sits in Night-at-the-Museum's
  shadow), not on the register; recorded briefly because one part was
  explicitly kept: the cross-biome "things escape where they don't
  belong, send them back" mechanic, now a story-agnostic entry under
  Mechanics above. One more fragment noted before dropping the rest:
  rehanging paintings as player-driven re-curation of which doorway
  leads where — unclaimed by any surviving candidate, worth grabbing if
  a winner can hold it.
- **Alternative 5 — "The Minotaur" (inverted noir / becoming) — ABSORBED
  into alternative 6 (2026-07-22).** The player as the creature that
  lives in the maze: no mirrors in a labyrinth, so it knows its own face
  only through the paintings that appear in the hub after each incursion,
  painted up on the surface from the testimony of people who fled.
  Driver: reputation as identity — terrify intruders and the depictions
  darken and the heroes come harder; shepherd them out unseen and the
  monster in the paintings slowly gains eyes, hands, a face. Rereads:
  "see far, not near" flips to the warden's view (intruders' torchlight
  crawling the far side of the sphere); the backlogged mark mechanic
  turns adversarial (erase/forge/redraw the intruders' own chalk);
  the hourglass is the prison's sentence, gold sand time served; ending
  = the last hero arrives carrying a mirror, and looking is the choice.
  Never separately accepted or rejected — superseded when hooman pivoted
  from one twisted myth to a whole game of them; survives as alternative
  6's Labyrinth material, upgraded there by hooman's goblin twist.
- **Alternative 6 — Twisted mythologies (leading candidate,
  2026-07-22).** Not one more storyline but an engine the surviving
  candidates can plug into. Premise: real myths (Greek, Egyptian, Norse,
  anywhere — famous or obscure, all public domain) revisited and bent.
  The player's pre-installed mythic literacy is free grounding and free
  misdirection: say "labyrinth" and they expect the bull, so the game
  earns its curiosity the moment it whispers that the story they know is
  the cover story (hooman's seed example: the Minotaur isn't a huge
  bull-monster but a scheming goblin steering visitors toward a real
  monstrous bull — or toward a made-up one). Sometimes the monster is
  the hero; characters cross and interlap between myths. Structural
  frame: every myth exists twice — *as told* (displayed in the hub;
  paintings are exactly what myths already are to us, painted scenes,
  which makes the backlog's "enter real paintings" idea native) and *as
  found* (inside, twisted). The player witnesses the found version and
  carries it home; the hub's record repaints to the uncovered — or,
  when a myth stays ambiguous, *chosen* — version, so the world the
  player accumulates is their own edition of the mythology. Odd worlds:
  myths supply them natively (the cosmic egg = a world on a sphere's
  interior; Ouroboros/Valhalla's replaying battle = the Möbius strip;
  Sisyphus or Babel = the tower; the Labyrinth = the maze; the Duat's
  nightly sun-crossing = a biome on the hourglass's clock), and where a
  myth has none we assign one by choice. Main risk, named as structural:
  "Greek wing / Norse wing / Egyptian wing" is exactly the flat level
  select the pillars forbid — the main story thread below isn't
  decoration, it's what makes it one game. NOTE: hooman rejected the
  first implementation pass wholesale (a Muninn's-errand player role and
  a pre-assigned list of myth-to-biome wings) — keep the engine,
  re-derive all implementations from whichever motive below wins.

  **Main story thread — why we revisit the myths.** Three motive
  candidates. Hooman's current preference (2026-07-22): **A and C
  liked, both in play; B not favored.**
  - **Thread A — "The Nameless Extra" (defiance / earn a name).** Every
    myth has a nobody — the sailor who drowns so the storm feels real,
    the guard the hero steps over — and it is always the same nobody:
    the player, summoned into every telling to do the dying, visible in
    the margin of every hub painting as a small figure with its back
    turned. The game starts the day they refuse. Why visit: the stories
    themselves keep dragging their extra in. Why twist: as told, the
    story has no room for you — only a bent tale can hold a new
    character, and an extra can't fight heroes, only nudge from below
    (move props, mislead, warn, befriend the monster — the goblin verb
    set, generalized). Why monsters ally: they're the other miscast
    ones. Why choose versions: a story changed enough acquires a new
    character, and that character needs a name. Becoming spine: margin →
    bit part → named; impact channel: the marginal figure in the hub's
    paintings turns around, moves centerward, gains a face as presence
    is earned. Endgame: at the top of naming sits godhood (a god is a
    character retold forever) — is that what you wanted, or did you
    just want the sailor to get a funeral line? Cost: the most authored
    premise (the wake-up conceit must be written well); melancholy-
    leaning, though defiant rather than grieving.
  - **Thread B — "The Vacant Throne" (ambition) — not favored.**
    Pantheons have empty seats; the hub is a hall of vacant thrones and
    the player a claimant. A throne belongs to whoever the stories say
    it belongs to, so twisting myths *is* the mechanism of power — and
    the twist that would win the throne and the twist that's true keep
    diverging, with the game quietly counting which the player chose;
    the tally is the ending (learn why the seats are empty, then sit,
    install someone fitter, or break the chair). Recorded because the
    diverging-truth device and the empty-seats worldbuilding are strong;
    not favored because ambition as sole driver goes cold without heavy
    relationship counterweight, and gods-and-thrones drifts toward
    generic epic against this game's small noir register.
  - **Thread C — "The Hospice" (devotion).** Gods age as their stories
    wear out: retold badly for centuries — flattened into "the
    monster", "the pretty one" — they thin. The hub is the shabby, warm
    pantheon-hospice where they've retired (a sun god down to one
    candle, the cat that belonged to a goddess and won't discuss it),
    and the player is the young teller who still visits. Discovering
    what actually happened in a myth — the strange, specific,
    inconvenient truth — feeds the god it belongs to: truth is
    nourishment, cliché is starvation, so the as-told versions are
    literally the disease. Recurring moral needle: some residents
    prefer the flattering lie, and choosing what to feed them is the
    choice mechanic. Becoming spine: apprentice → trusted with the
    stories → offered a dying god's seat, with the ending shaped by
    whose stories the player has been telling all along. Costs:
    adjacent to *American Gods* (differentiate: fidelity, not
    popularity, is what feeds); an ensemble piece — many characters to
    write well, the expensive kind of content.

  Composition note: the threads compose (A's nobody could climb B's
  ladder; C's hospice could sit at the top of it), but composition is
  polish — the load-bearing open decision is which single motive owns
  the game: defiance (A), ambition (B), or devotion (C).

### Controls

- **Mobile controls** (see `docs/GUIDELINES.md` §1.8): deliberately
  undesigned until there's a playable desktop version to adapt from.
