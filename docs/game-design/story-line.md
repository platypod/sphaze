# Story line

The **current state** of the main-story exploration: live candidates and
open decisions only. Rejected, absorbed, or set-aside material lives in
[design-decisions-records.md](design-decisions-records.md) — this file
should always read as "where we are", not "everywhere we've been". When a
decision lands: fold the winner in here, push its pillar consequences into
[philosophy.md](philosophy.md), move the losers to the records file with
the why, note it in `../PROJECT_LOG.md`, and reshape
[ideas-backlog.md](ideas-backlog.md) entries to hang off the winner.

## Requirements (common ground for any candidate)

Distilled from the exploration so far (2026-07-22 onward) — treat these as
requirements for any new candidate too:

- The player's actions must **visibly accumulate in the hub** ("impact on
  the world" made literal — which in turn needs persistence across
  sessions, not yet built).
- Progression is **curiosity/knowledge-gated**, per the "interconnected,
  not a level select" pillar.
- Storytelling stays **fully diegetic** — no cutscenes, no journal UI.
- The hourglass's existing gold-sand unlock
  (`entities.hourglass.HourglassModel.unlocked`) becomes the **first story
  beat** — the moment its meaning is revealed.

## Leading candidate — Alternative 6: Twisted mythologies

Not one more storyline but an engine the surviving candidates can plug
into. Premise: real myths (Greek, Egyptian, Norse, anywhere — famous or
obscure, all public domain) revisited and bent. The player's pre-installed
mythic literacy is free grounding and free misdirection: say "labyrinth"
and they expect the bull, so the game earns its curiosity the moment it
whispers that the story they know is the cover story (hooman's seed
example: the Minotaur isn't a huge bull-monster but a scheming goblin
steering visitors toward a real monstrous bull — or toward a made-up one).
Sometimes the monster is the hero; characters cross and interlap between
myths.

Structural frame: every myth exists twice — *as told* (displayed in the
hub; paintings are exactly what myths already are to us, painted scenes,
which makes the backlog's "enter real paintings" idea native) and *as
found* (inside, twisted). The player witnesses the found version and
carries it home; the hub's record repaints to the uncovered — or, when a
myth stays ambiguous, *chosen* — version, so the world the player
accumulates is their own edition of the mythology.

Odd worlds: myths supply them natively (the cosmic egg = a world on a
sphere's interior; Ouroboros/Valhalla's replaying battle = the Möbius
strip; Sisyphus or Babel = the tower; the Labyrinth = the maze; the Duat's
nightly sun-crossing = a biome on the hourglass's clock), and where a myth
has none we assign one by choice.

Main risk, named as structural: "Greek wing / Norse wing / Egyptian wing"
is exactly the flat level select the pillars forbid — the main story
thread below isn't decoration, it's what makes it one game. NOTE: hooman
rejected the first implementation pass wholesale (see the records file) —
keep the engine, re-derive all implementations from whichever motive
below wins.

### Main story thread — why we revisit the myths

The load-bearing open decision: which single motive owns the game. Hooman's
current preference (2026-07-22): **A and C liked, both in play** (a third
candidate, "The Vacant Throne" (ambition), was set aside — see the records
file). The two threads are less opposed than they look — both give the
overlooked their due, the extra from inside the myths, the faded gods from
outside them — so an A+C synthesis (the hospice's young teller *is* the
nameless extra) is a deliberately unexplored door.

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

## Parked candidates (alive, not leading)

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
  driver is restoration (warm, melancholy, finite). Composes with
  alternative 6: "the painter painted the myths wrong" is a possible skin
  for the twisted-mythologies engine.
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
  moment-to-moment progression of the parked candidates.
