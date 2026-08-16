# The world, and the threads through it

Read [README.md](README.md) first — this file assumes the amenability
thesis and the proposed pillars.

## The map is a number line

The world is not a hub with spokes. It is **the curvature scale**, walked
from one end to the other:

```
   κ > 0                    κ = 0                       κ < 0
compact, amenable      flat, amenable          exponential, NON-amenable
 everything returns    everything repeats         everywhere is edge
 ────────┬───────────────────┬──────────────────────────┬────────
     The Fold            The Repeat                 The Sprawl
     The Weft            The Turn                   The Knot
                        The Defect                  The Garden
```

That is the whole progression, and it is legible from the first hour
without a word of exposition: you begin somewhere closed and you are
walking toward somewhere open. The pillar *geometry is content* is
satisfied at the level of the world map itself, not just per-space.

**This is also the difficulty curve, the story arc, and the art
direction** (hue encodes κ — see [art-and-audio.md](art-and-audio.md)).
One axis carrying all four is the strongest structural argument for this
direction.

## The spaces

Nine places. Each entry: what it *is* geometrically, the one property it
exists to teach, its **legibility law** (pillar 2), its verb, its story
function, and what already exists in the repo.

---

### 0. The Still Life — the hub

**Geometry:** flat, small, bounded. The only place that does not tick.

**Teaches:** nothing. That's the point — it is the one space where the
rule is not running, which is why it is safe, and why nothing here can
ever help you. Safety and stagnation are the same condition.

**Legibility law:** total. You can see all of it. It is the only honest
map in the game, and it is a map of the one place that doesn't matter.

**Verb:** return.

**Story function:** the accumulator. The brief's oldest requirement — *the
player's actions must visibly accumulate in the hub* — is answered
literally: **the hub gains curvature as you do.** It begins flat and
small. Each geometry you come to understand bends it a little. By the
endgame the "safe room" is itself a non-euclidean space you had to learn
to read, and the player who returns will realise they walked into it
without noticing. That is the progress bar, and it is diegetic.

**Exists:** `biomes.hub.HubBiome`, the paintings-as-doorways decision
(2026-07-17), the hourglass. All reusable; the paintings become windows
onto other curvatures.

---

### 1. The Fold — the sphere *(κ > 0)*

**Geometry:** the existing geodesic sphere. Interior surface, walked from
inside. Icosahedral hex tiling, 12 forced pentagons.

**Teaches:** **compactness.** Finite, closed, no boundary. Every straight
line returns to itself. There is no direction that is "away". You cannot
leave a sphere by walking, and the game spends its first hours making sure
you feel that as a fact rather than hearing it as a line.

**Legibility law:** *see far, not near* — the original pillar, unchanged.
Raise your head and the entire world is visible across the interior; look
down and you cannot see past the wall beside you. **You can see your whole
cage but never your own cell.**

**Verb:** walk, look across, mark.

**Story function:** home, cradle, prison — and the mid-game reveal
(Thread 3) that those are the same word. The 12 pentagons are the only
places where the tiling's regularity breaks, and they are therefore the
only places you can write into the substrate: they are the **sockets** of
the world.

**Exists:** essentially all of it. `tools.geodesic.*` — the baked
frequency-11 sphere, `GeodesicVentrellaState`, the confirmed traveling
glider, the coarse maze, wall reactivity, and the pentagon-composing
engraving built this week. This space is *done* to prototype standard.

**To explore:** add relief to the sphere, with various heights levels,
maybe making the maze more complex. Could also be made into a 3D maze
altogether, breaking the 2-dimensionality of the sphere.

---

### 2. The Weft — the sphere, wired to itself *(κ > 0)*

> **Corrected 2026-08-12, in conversation.** The first version of this
> entry called the Weft "the projective plane, walkable" — a genuine
> quotient manifold, points literally identified, half the walkable area
> of a sphere. That doesn't cohere with the mechanic actually attached to
> it: **remove/add, opposite** (chosen the same conversation) needs two
> *distinct* walls to be opposite to each other, and a true quotient has
> only one wall per identified edge — there is nothing for it to be
> opposite *to*. Caught by asking what the player's own antipodal image
> should physically do, which has no good answer under a real quotient
> (there's no second body to ask the question of) and an easy one under
> the corrected model below. Left visible rather than silently fixed, same
> as the thesis correction in [README.md](README.md).

**Geometry:** an ordinary sphere — the same one the Fold walks — with no
manifold-level trick at all. What's authored is a **rule laid over it**:
every wall has a partner at its geometric antipode, and toggling one
toggles the other to the *opposite* state. Nothing is glued; there are
always two distinct, independently-existing locations. The player has
exactly one body and it is never anywhere but where you'd expect.

**Legibility law:** stand still and look toward your own antipode, and you
see a **reflection** — a non-solid rendering of what's there, not a second
body, not a second you, no collision, nothing you can ever touch. It
exists purely so you can read the far side of a pairing without walking
to it, the same "see far, not near" instrument the Fold already trades
in, aimed specifically at your own paired location instead of the world
in general.

That reflection is also the tell for the *opposite* rule, for free: watch
your own echo glide cleanly through a gate the instant you close yours,
and you've just watched the rule work rather than been told about it.

**Verb:** pair, opposite. Close a wall here; its antipodal partner opens.
The puzzle is route-planning against your own actions at a distance —
closing the door in front of you may be the only way to open the one you
actually need, on the far side of the world.

**Story function:** the first hint that the geometry was *chosen* — not
because the manifold was glued (it wasn't), but because *this specific
correspondence*, wall to distant wall, is an authored rule with no
geometric necessity behind it. Someone decided these two things would
answer to each other.

**A cheap beat worth keeping from the original pitch:** walk specifically
*toward your own reflection* rather than any arbitrary direction, and
"arriving" at it can be staged to feel like coming home — mirrored,
familiar — even though you've genuinely walked a quarter or half
circumference to a real, distant place. The illusion of identification,
without needing the real manifold to produce it.

**Exists:** the antipode-pairs backlog entry is exactly this space's
mechanic, already worked out including the key transform and the pole
edge case (`theta → pi - theta`, `phi → phi + pi`), and it already
specifically names "opposite" as "the more interesting puzzle and the
more dangerous one." Promote it here. The reflection rendering is new —
cheap, since it's the same geometry pass the Fold's own far-side
visibility already needs, just aimed at one fixed antipodal point instead
of the whole hemisphere.

---

### 3. The Repeat — the flat torus *(κ = 0)*

> **Revised 2026-08-12, in conversation.** The original entry gave this
> space a legibility law (learn the period, discount the echoes) and no
> mechanism — a thing to notice, not a thing to do. Not an error like the
> Weft's, so no correction callout, just a straightforward rewrite: asked
> directly for "riddles and tricks" rather than a contemplative read, and
> for a way to *create or reveal differences by doing something*. This
> replaces the passive version with an active one.

**Geometry:** not a single simulated region rendered many times by
wraparound — **many separate tiles**, each genuinely its own simulation,
that happen to have started from the same seed under the same rule.
Determinism is what keeps them identical: same initial state, same rule,
same future, forever — unless something has actually intervened. Walking
a straight line and arriving somewhere indistinguishable from home isn't
identification, it's just two places that have never had reason to
differ. (Same fork the Weft hit: a true quotient would mean there's only
ever one tile, nothing to compare. This space needs the looser model for
the same reason "opposite" needed it there.)

**Teaches:** that *sameness is evidence of a shared cause*, not a property
in itself — and that it's fragile. Two tiles stay identical only as long
as nothing has touched either of them; the instant one diverges,
"identical" stops meaning "the same place" and starts meaning "still
innocent." The whole game's causation theme, rehearsed at space #2
instead of saved for the ending.

**Legibility law:** the far view tells you nothing — sameness carries no
information, the opposite failure mode from the Fold, where distance is
legible. The only place information lives here is in a *comparison*: hold
what you remember of one tile against what's actually in front of you in
the next. Reading this space is an act of memory, not of sight.

**Verb:** compare. Walk exactly one measured period and, instead of
finding a copy, look for what isn't one.

**The mechanism.** Each divergence you correctly find isn't just noticed,
it's *opened*: whatever changed that tile's own history left it
standable, reachable, or open somewhere the reference tile is not — a
wall that's a live block here and dead there, a passage a settled cell
closed on the way you came from but never closed here. Recognising the
difference and reaching the new ground are the same act; there's no
separate puzzle bolted on top of noticing.

Do that across a handful of tiles and the individual differences stop
reading as noise. Overlaid, they compose into something specific — **a
mark, not the player's own**, deliberate rather than incidental, the same
object this project's own mark mechanic already knows how to render and
(per [ideas-backlog.md](../ideas-backlog.md)'s "someone messes with the
marks" entry) already knows how to make feel like it belongs to somebody.
Each solved tile contributes one fragment; enough of them and the shape
resolves into unmistakable intent. That's the proof — not a cutscene, a
picture the player assembles themselves out of several checkable facts
about the cell states.

**Story function:** the first hard evidence, this early, that you are not
the first pattern to have been here — Thread 2 material, planted well
before the ghosts or the ravens make it explicit. The loneliness beat
survives, sharpened rather than replaced: most of what surrounds you
really is alone, running unattended and identical since whenever it
started. But not all of it. Something else once stood exactly where
you're standing, and left a mark specifically so it could be found this
way.

**Exists:** nothing yet. Cheapest new pieces: per-tile "solved" state (the
same shape the pentagon engraving already keeps per socket) and the
composite-mark reveal, which can reuse `entities.painting`/`MarkModel`
rendering wholesale rather than inventing new geometry.

---

### 4. The Turn — the Möbius band *(κ = 0, non-orientable)*

**Geometry:** the existing Möbius biome. One surface, two lifts, a half
twist.

**Teaches:** **chirality.** Go around once and come back mirrored. Your
handedness is not a property you carry; it's a property the space assigns
you.

**Legibility law:** your own handedness is information, and it is the only
information the space gives you for free — but it is only readable
*relative* to something you left behind. This is where marks stop being a
convenience and become the only instrument.

**Verb:** mirror. The mechanical payoff: **a chiral glider that meets its
own reflection annihilates.** That's a real Life behaviour, a real
non-orientability consequence, and a puzzle verb, all at once — the
geometry-is-content pillar at its cleanest.

**Story function:** the first space that changes *you* rather than
obstructing you.

**Exists:** `biomes.mobius.*` and `MobiusMath`, with the flip identity
already derived and tested, and the "one side affects the other" backlog
entry pointing straight at this.

---

### 5. The Defect — the cone *(κ = 0 everywhere, except one point)*

**Geometry:** flat everywhere, with a single cone point carrying an angle
defect. Walk a loop around it and you return rotated by the defect angle,
having never turned.

**Teaches:** **holonomy** — that curvature can be *concentrated* rather
than spread, and that parallel transport is path-dependent. This is the
most underrated space in the set: it is nearly free to implement, and it
is the one that makes players understand what curvature *is*.

**Legibility law:** the space looks entirely ordinary. Nothing is visibly
bent. The lie is only detectable by returning somewhere and finding
yourself turned.

**Verb:** circle — loop a defect deliberately, to rotate yourself or a
carried pattern into an orientation you could not otherwise reach.

**Story function:** curvature becomes a *substance* — something that can
be placed, concentrated, and (Thread 4) eventually moved. The 12 pentagons
on the Fold are cone points too. The player should realise this
themselves, and it should land hard: **the sockets on your home world are
the same thing as the puzzle here.**

**Exists:** nothing, and it barely needs anything — this is the cheapest
big idea in the document.

---

### 6. The Ribbon — the one-dimensional automaton *(a special place)*

**Geometry:** a world that is a *line*. The second walkable axis is
**time**: the ground you walk north across is the spacetime diagram of a
one-dimensional automaton, generation by generation.

**Teaches:** that a configuration has a *history*, and that history has a
shape. Walking north walks into the past.

**Legibility law:** the past is terrain. You can see where you came from —
literally, as landscape — and the further you walk the older the world you
are standing on gets.

**Verb:** read history as ground.

**Story function:** **this is where you find your own predecessor.** Walk
north far enough and the terrain thins, simplifies, and ends — at
generation zero, the initial condition. Somebody typed it. Thread 3 pays
off here.

Tonally this is the odd one out, and deliberately so: it should feel like
a museum or a graveyard rather than a place with weather. Elementary
1D automata are also where the strongest "this is really a computation"
evidence lives — Rule 110 is Turing-complete, and a player who has spent
ten hours in a cellular world should be allowed to *see* that.

**Exists:** nothing, but it is trivially cheap — an elementary CA is a few
lines, and the rendering is a heightfield.

---

### 7. The Sprawl — the hyperbolic plane *(κ < 0)* — **the turn of the game**

**Geometry:** the ternary heptagrid `{7,3}` — seven-sided cells, three
around each vertex. Margenstern's own environment for hyperbolic cellular
automata, so the simulation side rests on developed literature rather than
improvisation.

**Teaches:** **exponential growth, and non-amenability.** The number of
cells within *n* steps grows exponentially. There is no useful notion of
"the area around here". Every region's boundary is proportional to its
own interior — **there are no Følner sets, so everywhere is edge.**

**Legibility law:** **the Fold's law, inverted.** *See near, not far.*
Space crowds in: exponentially many things compete for the horizon, so
everything beyond a short distance compresses into an illegible band. On
the sphere you could see the whole world and not your feet. Here you can
see your feet and nothing else. The player who has spent hours learning to
navigate by the far side arrives here and finds that skill *deleted* —
which is exactly The Witness's lesson, already in
[../inspirations.md](../inspirations.md).

**Verb:** navigate by algorithm rather than by memory. HyperRogue's
Camelot problem is the model: you cannot find the centre of a large circle
by Euclidean intuition, you have to *derive a procedure* and execute it.
Getting lost is not a failure state here, it is the ambient condition.

**Story function:** **the first non-amenable space — where the theorem
fails.** Everything the game has taught about cause and effect stops being
guaranteed. Patterns appear that cannot have come from anywhere. The
player arrives able to recognise that this is impossible, which is the
entire payoff of the preceding hours.

And: you cannot yet become one. You've seen the door. You're the wrong
shape.

**Exists:** the CA layer ports unchanged (a graph is a graph); the spatial
layer does not and cannot — see [architecture.md](architecture.md).

---

### 8. The Knot — genus-2 surface *(κ < 0, higher topology)*

**Geometry:** a hyperbolic surface of genus 2 — the octagon with edge
identifications. Two independent handles, so two independent families of
loop.

**Teaches:** **topology beyond curvature.** Negative curvature was about
*how much* space there is; this is about *how it's connected*. Which loop
you took matters, and "back where I started" becomes ambiguous in a new
way.

**Legibility law:** position is insufficient; you must track your *route*.
The first space where the honest answer to "where am I" is a word in a
group rather than a point.

**Verb:** braid.

**Story function:** late-game mastery. The space that proves you have
learned to think in geometries rather than in maps.

---

### 9. The Garden — the endgame

**Geometry:** non-amenable, and *authored*. Not a natural space — a made
one. The Gardener's own work.

**Story function:** where the three endings live. See below. Its being
non-amenable is the whole point: it is the one place she built where
freedom is free, which is the closest she could come to undoing what she
did.

---

## The four threads

Braided, not sequenced. Any of them can be pulled at any time; each gates
on understanding rather than on permission. No journal — see
[systems.md](systems.md) for how the game remembers without a UI.

### Thread 1 — The Ascent *(the mechanical spine)*

Climbing the real taxonomy of cellular-automaton life, each rung a body
you can take (`BECOME`, [systems.md](systems.md)):

**still life → oscillator → glider → spaceship → gun → orphan**

Each rung is simultaneously a movement ability, a lesson about the rule,
and a step in the story. This is the only thread with a fixed order,
because the taxonomy has one, and it is the thread that gates physical
reach.

It ends at a rung that is not a movement at all. The first five let you
*do* something. The sixth changes what you *are*.

### Thread 2 — The Predecessors *(who was here before)*

You are not the first pattern to wake up. The others are still here, and
what became of them is written in the rule's own vocabulary — this is the
thread where the existing cast (ghosts, ravens, cats) survives translation
with full rigour rather than as decoration:

- **The ghosts are oscillators.** They achieved stability by looping: a
  period-*p* pattern returns to itself forever. They are awake, they can
  be spoken to, and **they cannot learn**, because every period returns
  them exactly to what they were. A ghost will greet you identically the
  fourth time. This is the most affecting idea in the document and it is
  mathematically exact.
- **The still lifes are the ones who stopped.** They are stable,
  permanent, and standable. **The terrain is made of people who gave up.**
  The game already renders live cells as standable blocks — the mechanic
  exists; only the meaning is new.
- **The ravens are gliders.** They left, and are still travelling. You see
  them crossing distant parts of the Fold — which is precisely what the
  existing "see far, not near" pillar makes visible. Intercepting one is a
  real navigation problem, and it carries news from wherever it has been.
- **The cats** are the ones nobody can classify. Keep them
  unexplained — every rigorous world needs one thing that isn't.

The thread's end: one predecessor did none of these. Finding out what she
did instead is the bridge to Thread 3.

### Thread 3 — The Gardener *(who made this, and why)*

Evidence accumulates that the automaton was **seeded**, not eternal:

- Generation zero exists and can be walked to (**The Ribbon**).
- The rule is not the only possible rule; regions run variants.
- The sphere's parameters are *suspiciously kind*: compact, amenable,
  small, forgiving. Nothing that lives is ever truly lost, because nothing
  can leave.

**The mid-game reveal: the prison is a cradle.** The Fold is closed and
amenable *on purpose* — an accounted world is a safe place to grow
something, because nothing in it can be lost and nothing can get in. You
were not imprisoned. You were **incubated**.

Which immediately poses the real question, and it is a better one than
"how do I escape": *leaving the cradle is the thing you were made for, and
it is also abandoning the only place that will ever hold you.*

The Gardener herself: a previous orphan — **and she did it the cheap
way.** She became uncaused *here*, in the amenable world, which by the
theorem in [README.md](README.md) means the rule erased something to
balance her. Someone was spent so that she could be free.

She built the Fold afterwards. **The hub is an apology**, and the player
should be able to derive that from the mathematics rather than be told
it. Which sharpens the thread's real question from "was this a gift or a
cage" to something better: *she is offering you the chance to not do what
she did* — and the only way to take it is the long walk into negative
curvature, where the same freedom costs nobody anything.

### Thread 4 — The Rule *(can it change)*

The latest thread and the most dangerous. The rule is editable — locally,
slowly, at the sockets. But **your body is only stable under the current
rule**, so editing the rule is self-modification with lethal stakes. A
change that makes a new pattern possible may make *you* impossible.

This thread is what turns the endgame into a choice rather than a
destination.

---

## The endgame: three endings

All three are reached by *walking somewhere and doing something*, with no
menu, no prompt, no confirmation. All three are real positions on the same
question, and none is the "good" one.

**1 — Become the orphan, honestly.** Make the walk into non-amenable
space and become uncaused *there*, where no erasure balances you. You are
free in the strongest sense the mathematics allows, and nobody paid.

The reason this is an ending rather than a lap of honour: it is also the
**slowest and hardest** of the three, and the game has spent hours
offering you the shortcut. Becoming an orphan on the Fold is available
from the mid-game onward and it works — it just costs a predecessor.
Thread 2 exists to make sure you know exactly who.

And an orphan has no predecessor **in either direction of the
conversation**: nothing that follows can trace itself to you. You are free
and utterly unreachable. Perfect autonomy is indistinguishable from
perfect isolation — which is the discovery the Gardener already made, and
why she built a cradle afterwards.

**2 — Become the Gardener.** Stay in the amenable world. Use what you have
learned to seed the conditions for others to wake. You remain caused,
accounted, embedded — and the price is that you personally never become
free. The reward is that freedom becomes *possible* for someone.

**3 — Return to quiescence.** Let the rule take you. Not despair, and the
writing must be careful here: the dignity of a pattern that chooses to
stop rather than to persist at any cost. The oscillators — the ghosts —
are the argument against endless persistence, and they've been arguing it
all game.

The three endings are *autonomy*, *legacy*, and *rest*, and the game
should refuse to rank them.
