# Ideas backlog

Not implemented yet — parked here until we get to them. Check new entries
against [philosophy.md](philosophy.md) before adding; when an idea gets
implemented, delete it from here (the implementation itself, plus
`../PROJECT_LOG.md`, is the record from then on).

## Mechanics

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
