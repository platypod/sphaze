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
- **Cute characters**: cats, ghosts, ravens, something with a coherent
  theme, rather noir.

### Controls

- **Mobile controls** (see `docs/GUIDELINES.md` §1.8): deliberately
  undesigned until there's a playable desktop version to adapt from.
