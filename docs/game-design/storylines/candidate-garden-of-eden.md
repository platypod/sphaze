# Candidate — Garden of Eden

**Leading candidate.** See [README.md](README.md) for how this fits against
the other candidates, and the requirements every candidate has to meet.

> **Superseded in scope, 2026-08-11.** This candidate was developed into a
> whole-game direction — see [../direction/](../direction/README.md).
> Everything below survives; what changed is that the premise turned out
> to have a *theorem* under it (uncaused existence is available only in
> negative curvature, via amenability and the Garden of Eden theorem),
> which promotes it from "a story we could tell" to the spine of the
> entire game. Keep this file as the record of the candidate before that
> was noticed; the direction folder is where it lives now.

The player is a pattern in a cellular automaton that became something the
rules don't account for, fell out of its grid during a crash, perahsp,
and landed in the developer's machine. The hub could be the computer seen
from inside; paintings recast as glowing windows into running programs.

Driver: evolution up the real CA taxonomy, each stage a gameplay unlock —
still life (walk), oscillator (act on the world's tick), glider
(jump/traversal), spaceship (speed), gun (emit scout patterns — the
backlog's scouting mechanic), and finally Garden of Eden: a configuration
with no possible predecessor, the mathematical proof the player did not evolve
from the system. Each infiltrated program yields a rule fragment; Life iterations
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

## The glider stage, made literal — the geodesic Conway biome (2026-08-10, hooman)

Not yet reconciled with the rest of this candidate — raised as a direct
narrative reading of what `biomes.conway`'s geodesic sphere already is
mechanically (12 pentagon beacons + hexagons, see
[../ideas-backlog.md](../ideas-backlog.md)'s "Deliberate pentagon
activation" and "Walls that behave by a rule" entries for the built
mechanic itself — this section is only the story reading of it, not a
mechanic spec).

The glider evolution stage's own trial *is* this biome: spawning a
configurable cellular structure at (or near) a pentagon at regular
intervals, and reading whether it stabilizes into a genuine traveler —
a glider — is the same test the taxonomy already runs on the player one
stage up. Solving the maze by letting a chain reaction of gliders open
walls at the right place and time, or by riding one to jump a wall the
normal walk never could, is the glider stage teaching itself: the player
doesn't just *become* a glider narratively, they first have to *build*
one and watch it travel, on a board they can see is the same taxonomy
they're climbing. The reward for solving it — new information plus a new
gameplay mechanism, per the ask that raised this — reads naturally as
the next rule fragment: whatever ability the spaceship or gun stage
unlocks.

## Perception as an evolution stage — colourblind, then not (2026-08-10, hooman)

Also not yet reconciled with the rest of this candidate, and distinct
from the mechanic above. The ask: start colourblind, and only later gain
the ability to see colour — discovering that biomes already visited had
obvious paths invisible to the player's own eye the whole time.

This slots into the driver's existing "each stage a gameplay unlock"
structure as a perception unlock rather than a movement one — closer in
kind to [../ideas-backlog.md](../ideas-backlog.md)'s "Perception rules as
the biome's own variable" table (candlelight, inverse-legibility walls,
etc.), except *persistent and retroactive* rather than a fixed per-biome
constant: today every entry in that table is a biome's own rule, gated on
which biome you're standing in; this is gated on which *stage* you are,
so it changes how every biome already visited reads, not just the one
you're in when you unlock it. That's a stronger fit for "interconnected,
not a level select" than any single perception rule can be on its own —
it makes the whole hub retroactively re-legible, the same way
`gun`-stage scouting or `spaceship`-stage speed would, except aimed at
*reading* rather than *moving*. Diegetic reading: an early automaton
generation genuinely has no colour rule running yet — perceiving colour
is itself something the pattern had to evolve, same as anything else on
this ladder, not a lens bolted on for a puzzle.

Open, same as the rest of this candidate: which stage colour vision
attaches to, which already-built biome gets the first retroactive
reread, and whether "colourblind" reads as a real rendering constraint
(desaturated until unlocked) or only as a fictional frame around an
existing perception-rule biome.
