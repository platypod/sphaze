# Systems

What the player actually *does*, minute to minute. This is the file that
answers "pale prototype" — the current game has a hook, a simulation and
no verbs; this proposes eight, of which **five already have working
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

## The eight verbs

| # | Verb | What it is | State in repo |
|---|---|---|---|
| 1 | **Walk** | first-person movement on a curved surface | **built** |
| 2 | **Look** | read a space by its own legibility law | **built** (sphere's law) |
| 3 | **Become** | change which configuration you are | **new — the core system** |
| 4 | **Tick** | control the rate the rule runs at | **built** (`HourglassModel`) |
| 5 | **Seed** | write cells into the substrate at a socket | **built this week** (pentagon engraving) |
| 6 | **Read** | learn a configuration by watching it | **new** |
| 7 | **Carry** | move a pattern between geometries | backlog (cross-biome displacement) |
| 8 | **Zoom** | shift between walking and pattern scale | backlog (zoom-between-biomes) |

Five of eight already exist in some form. The game is much closer than
"pale prototype" suggests — what it lacks is not mechanisms but a **spine
that makes them one system**, which is what [README.md](README.md)
provides.

---

## 3. BECOME — morphology as moveset

**The core system, and the one that makes this a game rather than a
walking simulator.**

You are a configuration. You can hold a library of configurations and take
any of them. They are not upgrades — they are **bodies**, each with a real
cost, and the game is largely the tactical problem of choosing which to
wear.

| Body | What you gain | What it costs you | Its geometry lesson |
|---|---|---|---|
| **Still life** | stable under the rule; nothing can disrupt you; you become standable terrain | you cannot move at all | the only truly safe state is indistinguishable from having stopped |
| **Oscillator** | you act on the world's tick; you can pass barriers that open on your own period | you are on a clock you don't control; you return to exactly yourself every *p* generations | persistence without change |
| **Glider** | translation — real movement across the world | **you cannot stop.** A glider that stops is not a glider | commitment; direction as a thing you spend |
| **Spaceship** | faster translation, greater range | longer commitment; harder to place precisely | speed costs precision |
| **Gun** | emit gliders — act at a distance, scout, deliver | you are immobile while firing; what you send is gone | influence without presence |
| **Orphan** | *no predecessor* | see [world-and-threads.md](world-and-threads.md) — this one is not a movement ability | the endgame |

### How a glider actually plays

The most important thing in this document to get right, because it's the
one that proves the whole "you are a pattern" conceit can be a *control
scheme* rather than a fiction.

A glider translates one cell diagonally every *p* generations, and it is
only itself at phase 0. So, in first person: **you move continuously at a
fixed speed, and you may only change direction at phase boundaries.** In
between you are committed.

That is a genuinely distinctive movement mode — closer to a chess knight
or a momentum-puzzle than to a shooter — it derives entirely from the
mathematics, and it converts the world's tick into something the player
feels in their hands. It also makes the `Tick` verb immediately
meaningful: slowing the world down lengthens the gap between decisions.

### Switching

Switching bodies takes one generation, can be done anywhere, and is
physically visible: you cycle through the shapes you know, wearing each
briefly. There is no list and no menu — **the act of switching is the
inventory display.** The vulnerability of that one generation is the cost
that stops switching from being free.

---

## 6. READ — how the game remembers without a journal

Pillar 4 forbids a journal; Pillar 3 says knowledge is the only key. The
join:

> **You learn a configuration by watching it complete one full cycle.**

Observation *is* acquisition. Sit and watch a glider travel one period and
you have it — you can now become it. Watch an oscillator return to itself
and it is yours.

This is the best idea in this file for four reasons:

1. **It needs no UI whatsoever.** Nothing is awarded, logged or announced.
2. **It makes attention the core skill**, which suits a contemplative game
   and rewards exactly the player who is already enjoying it.
3. **It is diegetically exact.** In an automaton, to know a pattern *is*
   to know its evolution.
4. **It makes the world teach by running.** Every space is a lecture that
   delivers itself whether or not anyone is present.

And it is the answer to "where's the ship log": **your body is the log.**
What you know and what you can do are the same list, and you inspect it by
looking at yourself.

### The knowledge web

Gates are understanding, never permission. Concretely, in the shape Outer
Wilds proved and this game arrives at differently:

- A wall in the Fold opens only on even generations → you need an
  oscillator body with the right period → you must have watched one → the
  nearest is in the Repeat → which needs no body at all, just the walk.
- The Sprawl's centre cannot be found by looking → you need the algorithm
  → the algorithm is *demonstrated* by a raven's flight path, if you
  watch one long enough from the Fold's far side.
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

- **Slow** — thinking time, precise placement, longer gaps between glider
  decisions.
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
([../ideas-backlog.md](../ideas-backlog.md), 2026-07-29).

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
**decay to your most stable body** and reform at the last socket. You lose
the moment, never knowledge — knowledge is understanding, and understanding
cannot be taken back.

This suits the scale of game agreed (8-15h exploration): death as
punctuation, not as punishment.

---

## The other verbs, briefly

**5. SEED.** Write cells into the substrate at a socket — the pentagon
engraving built this week, generalised. Sockets are the tiling's *defects*
(the Fold's 12 pentagons; the Defect's cone point), which is why they are
writable: regularity is what makes a space unwritable, and a defect is a
place where the space admits it was made.

**7. CARRY.** Move a pattern from one geometry to another. The core
puzzle: **a glider that works on the Fold may not survive in the Sprawl**,
because the neighbour count differs (6 on the hex sphere, 7 on the
heptagrid) and a rule tuned to one is not tuned to the other. That is a
genuine, already-measured property of this project's own simulation work,
and it turns "take this over there" into a real question rather than
fetch-carrying.

**8. ZOOM.** Inspection. Hold to see the cellular truth. Some things are
legible only zoomed (a glider is only a glider from outside); some only at
walking scale (the Defect's rotation is invisible from above). Scale is a
second axis of the legibility pillar.

**1-2. WALK and LOOK.** Built. What changes is that `Look` becomes
plural — each space's legibility law is its own instrument, and the game's
skill curve is largely the accumulation of *reading* techniques.

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
- **"Noir-leaning" as an art brief.** Replaced by something specific in
  [art-and-audio.md](art-and-audio.md).
