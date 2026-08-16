# Systems

What the player actually *does*, minute to minute. This is the file that
answers "pale prototype" — the current game has a hook, a simulation and
no verbs; this proposes seven, of which **four already have working
prototypes in the repo**.

## The two scales

The game is played at two scales, and the relationship between them is the
premise made operable.

- **Walking scale.** First person, on a surface, in whatever curvature
  you're standing in. This is the existing game.
- **Pattern scale.** Zoomed out, the same place shown as what it actually
  is: cells on a tiling, switching state under a rule.

You are visible at both. At walking scale you're a figure; at pattern
scale you're a small configuration of live cells, and so is everything
else. The first time the game shows you this it is a story beat. After
that it is an instrument.

**Design rule:** some things are legible only at one scale. A glider is
five meaningless cells up close and an unmistakable travelling object from
outside — which is the *original* "see far, not near" pillar, restated as
a fact about scale rather than distance. The Garden of Eden candidate
already noticed this ("a glider is only a glider from afar"); making zoom
a verb is what turns the observation into a mechanic.

## The seven verbs

| # | Verb | What it is | State in repo |
|---|---|---|---|
| 1 | **Walk** | first-person movement on a curved surface — free and unrestricted | **built**, and hyperbolic walking **validated by playtest 2026-08-12** |
| 2 | **Look** | read a space by its own legibility law | **built** (sphere's law) |
| 3 | **Tick** | control the rate the rule runs at | **built** (`HourglassModel`) |
| 4 | **Seed** | write cells into the substrate at a socket | **built** (pentagon engraving) |
| 5 | **Read** | learn a configuration by watching it | **new**, and now the progression spine |
| 6 | **Carry** | move a pattern between geometries | backlog (cross-biome displacement) |
| 7 | **Zoom** | shift between walking and pattern scale | backlog (zoom-between-biomes) |

Four of seven already exist. The game is much closer than "pale
prototype" suggests — what it lacks is not mechanisms but a **spine that
makes them one system**, which is what [README.md](README.md) provides.

---

## What you are, and why there is no `BECOME`

You are **a pattern that has already evolved well past the primitives** —
not a still life learning to be an oscillator, not a glider hoping to
become a spaceship. That climb is behind you and the game never replays
it.

Which inverts the relationship the old design had backwards:

> **Primitive life is *subject to* the rule. You *operate* it.**

Gliders, oscillators, still lifes and guns remain everywhere and remain
central — but as **subject matter**, not as costumes. You study them,
seed them, carry them, and read them. You are never one of them, and the
distance between you and them is the point: it is the evidence that
something happened to you, and working out *what* is the game (see Thread
1 in [world-and-threads.md](world.md)).

**Movement is free and modern**: unrestricted from the first minute, no
modal states, no committed directions, nothing to switch into. Plus **one
or two permanent traversal abilities** — lasting gains, never modes, and
never something you toggle. What makes traversal interesting here is that
space is strange, not that your legs are complicated.

---

## Perception unlocks — what progression is made of

With `BECOME` gone, this carries the progression spine. Agreed
**Knowledge, plus a small number of capabilities that change
what you can *perceive*** — never what you can do to things, and never a
mode you enter.

Why perception rather than power:

- **It is retroactive by nature.** A new way of seeing re-reads
  everywhere you have already been. That is the single strongest fit with
  "interconnected, not a level select" available, and it was already filed
  independently in [../ideas-backlog.md](../open/ideas-backlog.md) as
  "retroactive rediscovery via a gained sense" before this direction
  existed.
- **It cannot make the game easier in a boring way.** More reach, more
  speed and more damage all flatten a world; more *sight* deepens it.
- **It is diegetically exact for what you are.** You are a pattern that
  evolved past the primitives. What that plausibly buys you is
  discrimination — the ability to notice structure a simpler
  configuration could not.

Candidates, roughly in the order they would be earned:

| Unlock | What it changes | Where it re-reads |
|---|---|---|
| **Colour** | the world starts desaturated; gaining colour reveals routes that were always physically there | every earlier space at once — the flagship retroactive moment |
| **Pattern scale** | `Zoom` — seeing the cellular truth under the walking-scale view | everywhere; the first use is a story beat |
| **Period sight** | reading an oscillator's period on sight instead of by counting | the ghosts, who become legible as what they are |
| **Reverse reading** | running the rule *backwards* over what you can see | the Sprawl, where it is the only way to notice a pattern has no predecessor |
| **Ring sense** | counting hyperbolic distance by ear, per [art-and-audio.md](art-and-audio.md) | the Sprawl's navigation problem |

Nothing here is an item and nothing is a menu entry: each is a change to
how the world is drawn or heard, so it is inspected by *looking at the
world*, not at yourself.

---

## 6. READ — how the game remembers without a journal

Pillar 4 forbids a journal; Pillar 3 says knowledge is the only key. The
join:

> **You learn a configuration by watching it complete one full cycle.**

Observation *is* acquisition. Sit and watch a glider travel one period and
you have it — you can name it, recognise it elsewhere, seed it yourself,
and predict what it will do. Watch an oscillator return to itself and its
period is yours.

This is the best idea in this file for four reasons:

1. **It needs no UI whatsoever.** Nothing is awarded, logged or announced.
2. **It makes attention the core skill**, which suits a contemplative game
   and rewards exactly the player who is already enjoying it.
3. **It is diegetically exact.** In an automaton, to know a pattern *is*
   to know its evolution.
4. **It makes the world teach by running.** Every space is a lecture that
   delivers itself whether or not anyone is present.

And it is the answer to "where's the ship log": **the world is the log.**

It is not "your body
is the log" — what you knew and what you could *be* were the same list.
With `BECOME` cut there is no such list, and the replacement is better:
because progression is perception, **everything you have understood is
visible in the world itself.** A space you could not read before now
reads. A pattern you could not name is now named. You know what you know
by looking outward, not at an inventory — which is a stronger form of the
same no-UI discipline, since there is nothing to display even in
principle.

### The knowledge web

Gates are understanding, never permission. Concretely, in the shape Outer
Wilds proved and this game arrives at differently:

- A wall in the Fold opens only on even generations → you have to *read*
  its period, which means recognising the oscillator driving it → the
  clearest example to learn one from is in the Repeat → which needs
  nothing but the walk and the patience to watch.
- The Sprawl's centre cannot be found by looking → you need the algorithm
  → the algorithm is *demonstrated* by a raven's flight path, if you
  watch one long enough from the Fold's far side — concretely, ring
  boundaries crossed at a learnable rate; see
  [world-and-threads.md](world.md)'s own Sprawl entry for the
  worked-out mechanism, including its bearing half.
- A pattern in the Sprawl has no predecessor *and nothing was erased to
  balance it* → you can only recognise that as remarkable if you have
  already learned to run the rule *backwards* and to audit what it
  destroys, which the Ribbon teaches by making history walkable.

Nothing in that chain is a key or a flag. Every link is something the
player must *understand*, and every one is learnable by watching the world
run.

---

## 4. TICK — the clock you can slow but not stop

The world advances in generations. The hourglass (built) sets the rate,
globally, and this is now a primary verb rather than a curiosity:

- **Slow** — thinking time, precise placement, and the only way to watch
  a fast structure closely enough to read it.
- **Fast** — make a long propagation actually happen; skip to the far end
  of a chain reaction you have already reasoned out.
- **Stop** — safe, and useless. Nothing can hurt you and nothing can
  progress. The Still Life hub is this condition made architectural.

**You cannot pause forever**, and the reason is the antagonist:

## The antagonist is settling

There are no enemies, and there should not be. The pressure comes from
what cellular automata actually do, which this project has already
measured and written down: random soup *"evaporates within a few dozen
generations into scattered still lifes and blinkers"*
([../ideas-backlog.md](../open/ideas-backlog.md), 2026-07-29).

That measured disappointment is the theme. **The world is dying by
settling.** Not violently — it is running out of interesting states,
resolving into stable accounted configurations that can never surprise
anyone again. A fully settled world is a fully *accounted* world, which is
precisely the amenable condition the player is trying to escape.

So the clock is real, the tension needs no monsters, and the antagonist is
the same force as the thesis. Regions visibly calcify. The ghosts —
oscillators, looping forever — are what "surviving" the settling actually
looks like, and they are the argument against simply enduring.

## Failure

Cheap, informative, and rare. If your configuration is disrupted you
**reform at the last socket**, losing the moment and nothing else. You
never lose knowledge — knowledge is understanding, and understanding
cannot be taken back — and since progression is perception rather than
possessions, there is literally nothing else to drop.

This suits the scale of game agreed (8-15h exploration): death as
punctuation, not as punishment.

---

## The other verbs, briefly

**SEED.** Write cells into the substrate at a socket — the pentagon
engraving built this week, generalised. Sockets are the tiling's *defects*
(the Fold's 12 pentagons; the Defect's cone point), which is why they are
writable: regularity is what makes a space unwritable, and a defect is a
place where the space admits it was made.

**CARRY.** Move a pattern from one geometry to another. The core
puzzle: **a glider that works on the Fold may not survive in the Sprawl**,
because the neighbour count differs (6 on the hex sphere, 7 on the
heptagrid) and a rule tuned to one is not tuned to the other. That is a
genuine, already-measured property of this project's own simulation work,
and it turns "take this over there" into a real question rather than
fetch-carrying.

**ZOOM.** Inspection. Hold to see the cellular truth. Some things are
legible only zoomed (a glider is only a glider from outside); some only at
walking scale (the Defect's rotation is invisible from above). Scale is a
second axis of the legibility pillar.

**WALK and LOOK.** Built. `Walk` is free and unrestricted, plus one or
two permanent traversal abilities and nothing modal. `Look` becomes
plural — each space's legibility law is its own instrument, and the
game's skill curve is largely the accumulation of *reading* techniques,
which is also where the perception unlocks land.

---

## What this replaces

For honesty about what the direction costs, three existing things go:

- **The maze as the primary content.** Carving remains useful as texture,
  but a maze is a *route-finding* problem and this game is a
  *comprehension* problem. Nine mazes would be nine of the same thing;
  nine geometries are nine different things. The maze-style work
  (`MazeStyle`, braiding, per-biome recipes) survives as decoration on
  spaces whose identity comes from elsewhere.
- **The fall counter / tower.** No home in this direction as it stands.
  Keep the biome, lose the counter, or repurpose the tower as a fibered
  space (a circle's worth of stacked flat layers) — genuinely open.
- **`BECOME`, and Thread 1 as a climb.** Cut after its Phase 0
  harness was played — see the note at the top of this file, and Thread 1
  in [world-and-threads.md](world.md) for what the spine
  became instead.
- **"Noir-leaning" as an art brief.** Replaced by something specific in
  [art-and-audio.md](art-and-audio.md).
