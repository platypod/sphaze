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

**Built — `biomes.hub.HubBiome`**, with the paintings-as-doorways
mechanic and the hourglass. The curvature accumulation described above is
not built.

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

**Built — `tools.geodesic.*`**, and to the highest standard of the nine: the baked
frequency-11 sphere, `GeodesicVentrellaState`, the confirmed traveling
glider, the coarse maze, wall reactivity, and the pentagon-composing
engraving.

**To explore:** add relief to the sphere, with various heights levels,
maybe making the maze more complex. Could also be made into a 3D maze
altogether, breaking the 2-dimensionality of the sphere.

---

### 2. The Weft — the sphere, wired to itself *(κ > 0)*

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

**Built — `biomes.weft.WeftBiome`.** The pairing, the opposite-state invariant, toggling the
wall you are facing, and the echo standing at your antipode. What is
*not* built is the puzzle — no gate yet specifically requires reaching
through the antipode, because that is level design and wants a mechanic
already known to read.

Three findings, none predictable from the design:

- **The pole edge case landed exactly where this entry predicted.** The
  rows nearest each pole carry an *odd* column count, and the antipodal
  map shifts a row by half its columns — which on an odd row lands on a
  cell boundary. No fixed-point-free pairing of an odd number of cells
  exists at all, so those rows are simply unpaired.
- **Both hemispheres still read as mazes.** A spanning-tree carve opens
  roughly half a grid's edges, so the photographic negative is also
  roughly half — not the open plain one might expect.
- **Connectivity is not preserved.** Complementing half the edges
  destroys the carve's reachability guarantee, so the negative side can
  hold loops and sealed pockets. Survivable, since the space's verb is
  *opening walls* — but a Weft with an authored puzzle needs its own
  generator (carve, complement, repair) rather than the Fold's.

---

### 3. The Repeat — the flat torus *(κ = 0)*

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
(per [ideas-backlog.md](../open/ideas-backlog.md)'s "someone messes with the
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

**Built — `biomes.repeat.RepeatBiome`.** The cell city, tiled deterministically; divergences that
remove exactly one building and open the ground under it; a fragment
standing in the gap; per-tile solved state. What is *not* built is the
composite-mark reveal — the payload — deliberately held until the
comparison mechanic is confirmed to read, since authoring content for a
mechanic that might not work is the expensive mistake.

Two findings from building it:

- **The city has to be low-rise.** The first version had towers up to
  110 units with twelve-unit streets, which is a slot canyon. This
  space's mechanic is comparison against a remembered **skyline**, and
  a city you cannot see across does not have one. Manifold Garden's
  register is big legible geometry seen whole, not a street view.
- **`geometry.DeckGroup` is deliberately unused here**, one commit
  after being built for exactly this shape. The design's own insistence
  on separate-but-identical tiles rules out the quotient, and that is
  right — but it means the framework's first real customer is the Turn,
  not the Repeat.

**Visual dialect:** [art-and-audio.md](art-and-audio.md)'s own "Per-biome
visual dialect" table — a low-poly cell city, Manifold Garden's register,
chosen specifically because a city's hard edges and repeated units give
divergence somewhere obvious to hide.

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

**Mechanism, kept but unresolved .** The direction, agreed:
your handedness is set by *how you route*, not just whether you loop —
send a glider around an odd number of times and it arrives mirrored, even
and it doesn't, so the path you choose determines what arrives. Somewhere
a passage is blocked by a glider of one handedness; the only way through
is to deliberately route its opposite to meet and annihilate it. **Gain:**
a technique — produce a chosen handedness on demand — not a key, reusable
wherever the game later wants a chiral counterpart (Thread 1 material).
**Not yet sold on the setup**: how the player actually *discovers* their
own current state cheaply enough that testing it isn't itself the boring
part this space is trying to avoid. The marks-as-reference idea
(legibility law, above) is the leading candidate, not a settled answer —
revisit once there's something to playtest.

**Locomotion has to be pleasurable, not merely present — and it's the harder problem than the chirality
mechanism itself.** This space's entire premise is *doing the loop more
than once*, deliberately, to test and then to spend your own state. That
is a much higher tolerance for repeated traversal than any other space in
the set asks for, and "walk a long, slowly-unspooling ribbon with
ever-repeating scenery" fails immediately under that much repetition —
boring is disqualifying here in a way it isn't elsewhere. Two ways out,
not mutually exclusive, both open:

1. **Make the movement itself the pleasure** — reference point:
   *Race the Sun*, where traversal alone, well-tuned, carries a whole
   game with near-zero decoration. If moving through the Turn feels good
   in the hand at speed, repetition stops being a cost and starts being
   the loop the rest of the mechanism runs on.
2. **Give each lap its own skill**, something the player does *every*
   time through that has its own improvable curve — timing, a rhythm, a
   precision act tied to the twist itself — so repetition reads as
   practice rather than backtracking.

Whichever way this goes (or both), it needs building and playing before
the chirality mechanism above can be judged at all — a bad ribbon kills a
good mechanic here. See [roadmap.md](../building/roadmap.md)'s Risk 8, which this
sharpens rather than duplicates: that risk was about whether `BECOME`'s
bodies were fun to control (answered: no, and the system was cut); this
is specifically about whether
*this one space's own* repetition budget can be sustained regardless.

**Set aside, deliberately:** the backlog's "one side affects the other"
(a wall and its mirror across the strip's own width, linked) is real and
buildable, but it's a spatial-pairing puzzle — the same shape the Weft
and the Repeat already cover. Keeping this space about a *travelling
pattern's own history* rather than *two static places agreeing* is what
makes it distinct from both.

**Story function:** the first space that changes *you* rather than
obstructing you.

**Built — `biomes.turn.TurnBiome`**, a flat strip quotiented by a glide reflection, built
against this entry's own stated ordering (the ribbon first, since a bad
ribbon kills a good mechanic). It moves at 2.4x walking speed with a
rhythm of obstacles to weave, taking *both* of the ways out named above
rather than choosing. The chirality-routing puzzle is deliberately not
built on top of an unproven ribbon.

`biomes.mobius.*` and `MobiusMath` still exist and are **a different
thing**: that biome embeds a twisted strip in ℝ³, which carries real
curvature everywhere and is therefore not the κ = 0 space this entry
describes. Both are kept; the embedded one is prettier to look at.

**A proposal for the open "how does the player read their own state"
question**, awaiting playtest before it earns a place in this entry: a
Möbius band has a *single* boundary curve, twice the band's own period
long. Painting it pale for one period and dashed for the next makes
"which rail is beside me" a direct readout of which lift you are on —
one glance, at speed, no instrument and no detour. If it reads as being
*told* rather than *discovering*, the marks-as-reference idea above is
still the fallback.

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

**The mechanism.** Unlike the Turn's flip, this
rotation is **continuous, not binary**: loop the same defect twice and you
get twice the angle; loop a second defect with a different angle and the
two compose. That's a real dial, not a coin flip — the thing that keeps
this space distinct from the Turn's own path-dependent trick rather than
being the same idea told twice.

The goal it drives: a socket that only accepts a carried pattern (a
`CARRY`-ed structure, or your own orientation) arriving at one exact
facing. Critically, **there is no in-place
editing tool here** — unlike the Fold's pentagon engraving, you cannot
nudge the orientation once you arrive. It has to already be correct,
which means it was set by *how you routed* on the way in. That is the
mechanical version of the story beat below, not just flavour text: the
Fold's sockets are the convenience version of what this space makes you
do the hard way.

The gain is the reward shape every socket in this set already uses (new
information plus a new mechanism), plus a meta-gain unique to this space:
this is where the player understands *why* the Fold's twelve pentagons
are special at all. Euler's formula forces exactly twelve defects on that
tiling; this space turns "there happen to be twelve odd cells" into "oh —
those are cone points, and I know exactly what those do now." A
retroactive payoff over something the player already spent hours using,
in the Outer Wilds sense — not new information about a new place, new
information about an old one.

**What's actually new here, honestly.** Sound geometry — a cone point's
holonomy is textbook, the local case of Gauss-Bonnet, nothing hand-waved
— but it is not free. `CurvedSpace`/`Isometry` (built this week) only
cover the three *uniform*-curvature geometries; a cone point is curvature
concentrated at a single spot in an otherwise flat plane, a genuinely
different construction, unbuilt. Structurally close to how `MobiusSpace`
already handles its own seam (wrap the parameter, apply a transform on
crossing it) — a good precedent to build from, not a shortcut around
building it. "Nearly free to implement," under **Teaches** above, meant
cheap *relative to the hyperbolic tiling* — still true, just not
literally free.

**Story function:** curvature becomes a *substance* — something that can
be placed, concentrated, and (Thread 4) eventually moved. The 12 pentagons
on the Fold are cone points too. The player should realise this
themselves, and it should land hard: **the sockets on your home world are
the same thing as the puzzle here.**

**Built — `biomes.defect.DefectBiome`.** The cone chart, the seam, the holonomy, and the markers to
read a rotation against — a meridian, concentric rings, a spire on the
apex. The socket is *not* built: it needs `CARRY`, which does not exist.

"Cheap next to the hyperbolic tiling, not literally free" was right, and
so was naming `MobiusSpace`'s seam as the precedent — the cone minus one
ray is isometric to a wedge of the plane, so the whole non-flat content
of the space is one rotation applied at one ray. Two notes from
building it:

- **It is not a `geometry.DeckGroup` quotient either**, which was worth
  finding out: the group would be rotations about the apex, and those
  have a *fixed point*, so the framework's enumeration (which prunes by
  how far an element moves the origin) would find infinitely many
  elements all of displacement zero.
- **The legibility law is bent, and this is the honest statement of
  it.** "Nothing is visibly bent" cannot be fully delivered, because a
  cone cannot be flattened. Markers are drawn in a window centred on the
  player, so everything in view is continuous and correct, and the
  unavoidable gap sits directly behind the apex; the ground is a full
  disc so there is no hole. A seamless cone renderer — properly
  developing the visible neighbourhood — is real remaining work.

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

**Built — `biomes.ribbon.RibbonBiome`.** Rule 110's spacetime diagram as terrain, a monolith on
generation 0, and nothing that ticks. The predecessor content the story
function calls for is not built — the monolith is a placeholder for it.

Two things this space taught, neither of which was predictable from the
design:

- **"Trivially cheap" was right about the automaton and wrong about the
  rendering.** The CA is fifteen lines. Making a 7,300-cell diagram
  actually appear on screen was the work, and it failed silently the
  first time (16-bit index buffer overflow — see `RibbonMesh`).
- **A flat heightfield does not deliver this space's own legibility
  law.** At walking eye height the relief foreshortens to under a pixel
  and the whole history reads as one grey plane. The strip now
  *descends* into the past, so the diagram is a hillside looked down
  across — free geometrically, since a tilted plane is still
  intrinsically flat.

---

### 7. The Sprawl — the hyperbolic plane *(κ < 0)* — **the turn of the game**

**Geometry:** the ternary heptagrid `{7,3}` — seven-sided cells, three
around each vertex. Margenstern's own environment for hyperbolic cellular
automata, so the simulation side rests on developed literature rather than
improvisation.

**Not the exterior of anything** — asked directly,
worth being precise about. Curvature is a property of a surface itself,
not which side you stand on; the outside of a sphere is still positively
curved, still amenable, already a different built biome
(`SphereExteriorSpace`) with nothing to do with this space. The real
intuition: a hexagon has six neighbours around a shared vertex, exactly
enough to lie flat (6 × 60° = 360°). A pentagon has five (300°) — a gap,
and closing it curls the surface inward, which is why the Fold needs
exactly twelve pentagon defects to close into a sphere at all (Euler's
formula, the same fact the Defect teaches). A **heptagon has seven**
(≈449°) — too much material to lie flat, with no way to close the excess
by curling inward, so the surface ruffles outward instead, everywhere,
forever. Not a sphere turned inside out: the geometry of a lettuce leaf, a
coral reef, a hyperbolic crochet piece — every patch saddle-shaped,
curving away from you in every direction at once, never converging back
the way a sphere does and never flattening the way a plane does. A
regular `{7,3}` tiling also has **no forced defects**, unlike the Fold's
twelve pentagons — every cell has exactly seven neighbours, uniformly,
everywhere, which is exactly why there's no landmark to anchor on and
navigation has to be an algorithm rather than a place to look for.

**Teaches:** **exponential growth, and non-amenability.** The number of
cells within *n* steps grows exponentially — measured, not asserted, in
[../notes/hyperbolic-simulation-findings.md](../building/notes/hyperbolic-simulation-findings.md):
ring populations grow by a factor of φ² each step. There is no useful
notion of "the area around here". Every region's boundary is proportional
to its own interior — **there are no Følner sets, so everywhere is edge.**

**Legibility law:** **the Fold's law, inverted.** *See near, not far.*
Space crowds in: exponentially many things compete for the horizon, so
everything beyond a short distance compresses into an illegible band. On
the sphere you could see the whole world and not your feet. Here you can
see your feet and nothing else. The player who has spent hours learning to
navigate by the far side arrives here and finds that skill *deleted* —
which is exactly The Witness's lesson, already in
[../inspirations.md](inspirations.md).

**Verb:** navigate by algorithm rather than by memory. HyperRogue's
Camelot problem is the model: you cannot find the centre of a large circle
by Euclidean intuition, you have to *derive a procedure* and execute it.
Getting lost is not a failure state here, it is the ambient condition.

**The algorithm.** Finding a location genuinely
needs two components, not one — the real structure of the problem, not a
hand-wave:

- **Radius, by ring-counting.** `geometry.HyperbolicTiling`'s own BFS
  already assigns every cell a ring number from a chosen origin, growing
  by φ² a step — real, tested code, not a proposal. A traveller moving
  steadily outward crosses ring boundaries at a learnable, predictable
  rate. This is what [systems.md](systems.md)'s own knowledge-web entry
  meant by "the algorithm is demonstrated by a raven's flight path" —
  made concrete for the first time here: watching one long enough from
  the Fold's far side teaches the player to count rings by eye. Same
  skill, unchanged, works here, because it's the same graph-BFS fact
  either place.
- **Bearing, the part that actually needs a trick.** Ring number alone
  narrows an exponential search, it doesn't finish it. Rather than invent
  a separate system, this reuses the audio direction already written
  ([art-and-audio.md](art-and-audio.md)'s own "The Sprawl" entry): a
  consistent audible pulse or timbre shift exactly at ring boundaries,
  turning what was atmosphere into an instrument — sound carries the
  radius while the player's eyes are busy with the illegible few cells
  actually around them.

**The treasure map, diegetically.** Someone else solved this navigation
problem first — Thread 2 material — and left the solution the way the
Repeat's predecessor left their mark: not one object to find, but
fragments, each legible only once the player has already proven they can
read a piece of it. Reuses the Repeat's own evidence-assembly mechanic
outright rather than inventing a second one — the same skill the player
built two spaces ago, paying off again at higher stakes.

**Story function:** **the first non-amenable space — where the theorem
fails.** Everything the game has taught about cause and effect stops being
guaranteed. Patterns appear that cannot have come from anywhere. The
player arrives able to recognise that this is impossible, which is the
entire payoff of the preceding hours.

And: you cannot yet become one. You've seen the door. You're the wrong
shape.

**Built — `biomes.sprawl.SprawlBiome`.** A `{7,3}` floor, columns for parallax, and one amber home
tile that returns to the hub — the geometry is real and nothing else is.
Under it: `geometry.HyperbolicTiling` (ring populations and φ² growth
tested), `HyperbolicProjection`, `HyperbolicSpace`, and
`HyperbolicView`, which bridges the game's own `pos`/`forward` state to
the view isometry the projection needs.

The CA layer ports unchanged (a graph is a graph). The ring-counting
mechanism, the ring-boundary audio cue and the predecessor-fragment
system are all still unbuilt — deliberately, so that "does walking this
place feel right in the actual game" gets an unambiguous answer before
anything is layered on it.

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

**Built — `biomes.knot.KnotBiome`**, the last of the nine, and the piece
deliberately held back when the quotient framework landed, since it is
real hyperbolic geometry rather than a parameter change.

`geometry.DeckGroups.genusTwo` is the `{8,8}` tiling with opposite sides
identified. It is verified by computation rather than by assertion: the
group's orbit of the origin matches the face centres of an
independently-built `HyperbolicTiling(8, 8)`, the action is free (so the
quotient is a surface, not an orbifold), and the element count matches a
Gauss-Bonnet estimate derived from the geometry alone.

The first screenshot delivers this entry's legibility law without a word
of explanation: **the same landmark repeating in several directions at
once**, because there is one room here and you are looking at many
images of it. The landmark is asymmetric on purpose — with identical
content everywhere, orientation is the only readable information.

The `braid` mechanic is unbuilt. Distinguishing the two independent
families of loop is the content this space exists for, and it wants a
closed surface confirmed to read as closed first.

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

### Thread 1 — The Reconstruction *(the spine)*

You do not climb the taxonomy. **You are already past it** — a
configuration far more complex than anything you will meet, with no
memory of how it got that way.

So the taxonomy becomes an **archaeology instead of a career**. The
primitive forms are everywhere, and every one you come to understand is a
recovered piece of your own origin:

**still life · oscillator · glider · spaceship · gun → what am I?**

Read in that direction it stops being a ladder and becomes a question,
which is the point: *how does something like me arise from rules like
these?* The player's growing fluency with the primitives is the only
instrument for answering it, and the answer arrives in pieces, out of
order, from wherever they happened to look.

**This is also what makes Thread 2 land.** If you are past those rungs
and the things you meet are stuck on them, then the world is not a
tutorial — it is a **graveyard of arrested development**. The ghosts are
oscillators that never got further. The terrain is still lifes that
stopped at the first rung. You are walking on the ones who didn't make
it, and the distance between you and them is exactly the thing you are
trying to explain.

**Where it ends.** The last thing reconstructed is not another rung. It
is that your own configuration has **no predecessor at all** — that the
chain you have been assembling does not reach you, and never did. The
thread's final beat is the discovery that the archaeology fails, and
*why* that is the most important fact about you.

**What carries progression**, now that bodies don't: knowledge, plus a
handful of **perception unlocks** — see
[systems.md](systems.md)'s own section. Each one re-reads everywhere you
have already been, which is precisely how a thread about *retroactive*
understanding should advance.

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
slowly, at the sockets. But **your own configuration is only stable under
the current rule**, so editing the rule is self-modification with lethal stakes. A
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
