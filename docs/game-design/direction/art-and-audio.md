# Art and audio

Written as **briefs a contractor could be handed**, since hiring an
artist and/or composer is on the table. Both directions are derived from
the thesis rather than chosen for taste — in a game about geometry, art
that is merely pretty is art that is lying.

---

# Art direction — "Legible Impossibility"

## The brief in one paragraph

> This is a first-person game set in spaces that do not obey Euclidean
> geometry. Left alone, such spaces are nauseating and unreadable. **The
> art department's primary job is not beauty — it is legibility.** Every
> decision should be judged by: *does this help the player understand
> where they are and what kind of space they are in?* Beauty is what we
> get when that succeeds.

That inversion is the whole brief. It should be on the wall.

## The master stroke: hue encodes curvature

**Colour temperature maps to κ**, consistently, everywhere, forever.

```
κ > 0  ·  warm — amber, ember, brass        closed, finite, safe, accounted
κ = 0  ·  neutral — bone, slate, ash        flat, repeating, indifferent
κ < 0  ·  cool — cold blue, violet, black   open, exponential, free, lost
```

Why this is the right decision and not a preference:

- **It teaches the mechanic before the player has words for it.** People
  feel warm/cold long before they can say "negative curvature". The player
  will *know* the Sprawl is different the instant they see it, and only
  understand why hours later.
- **It makes the world map visible from inside it.** The curvature scale
  in [world-and-threads.md](world-and-threads.md) becomes a colour
  gradient the player is walking along.
- **Precedent that it works:** Manifold Garden colour-codes gravity
  direction, and it is the single reason that game is playable rather than
  bewildering. Already in [../inspirations.md](../inspirations.md) for a
  different lesson; this is the second one.
- **It gives the endgame its image for free.** The journey from amber to
  black is the story, drawn on every frame.

Discipline required: **no other system may use hue as its primary
channel.** Life/death, interactables, threads — all must be distinguished
by value, motion, shape or emission, never by hue competing with
curvature. This is a real constraint and it will be inconvenient at least
once a month.

## Light, and the gift from the mathematics

In hyperbolic space the area of a geodesic sphere grows **exponentially**
with radius, so physically correct light falloff there is exponential
rather than inverse-square (Coulon et al. —
[architecture.md](architecture.md)).

**Do not fake this, and do not fight it.** It means darkness closes in
exponentially in the Sprawl, for real physical reasons, which is exactly
the legibility law that space is supposed to have ("see near, not far").
The correct renderer and the design intent produce the same picture. This
is the strongest possible art direction: *the mathematics is the mood.*

Correspondingly, on the sphere: light wraps. You are inside a closed
surface, so distant geometry is lit by the same sources you are, and the
far side of the world is a *legible, readable surface* across the void.
That is the "see far, not near" pillar rendered rather than scripted.

**No directional sunlight anywhere.** There is no "outside" in any of
these spaces, and a fake sun would be the one asset in the game that lies
about the geometry. Light comes from the world: emissive cells, sockets,
the pentagons, and ambient. This is also a production saving — no shadow
maps to fight in curved space, which is one of the systems
[architecture.md](architecture.md) notes big engines would have forced us
to reimplement anyway.

## Material language

Everything is made of the same substance, because it is:

- **Everything is cells.** Faceted, tiled, discrete. Nothing organic,
  nothing sculpted, no smooth blobs. If it exists, it is a configuration.
- **Alive = emissive. Dead = matte.** The only self-lit things in the
  world are living cells. This makes the automaton legible at a glance,
  at any distance, in any geometry — and it makes a settling world
  visibly *go dark*, which is the antagonist ([systems.md](systems.md))
  rendered without a word.
- **Still lifes read as architecture**, because they are — and because of
  Thread 2, the terrain is made of people who stopped. The art should
  quietly support the reveal: standable blocks want a *posture*, something
  faintly figural that nobody notices for six hours.
- **Defects are ornamented.** Pentagons, cone points, sockets — the places
  where regularity breaks are the only places with detail. Regularity is
  cheap and it is also the point: a defect is where a space admits it was
  made.

## Landmark language

The single hardest navigation problem: in hyperbolic space you cannot see
far, and everything nearby is locally identical. Standard landmark design
(a tall tower visible across the level) **does not work** — there is no
"across the level".

Therefore:

- **Landmarks must be legible at arm's length**, not at distance.
  Local, dense, and individually distinguishable — closer to reading a
  street sign than seeing a mountain.
- **A vocabulary of ~12 unmistakable cell-scale glyphs**, distinguishable
  by silhouette alone, in any orientation, at any rotation (parallel
  transport will rotate them — see the Defect).
- **Route memory over position memory.** The player will navigate the
  Sprawl by remembering a *sequence* of glyphs, not a map. Design them as
  an alphabet, not as scenery.

## Reference board

| Reference | Take specifically |
|---|---|
| **Manifold Garden** | colour-as-mechanic; repetition made legible rather than vertiginous |
| **NaissanceE** | monochrome oppressive scale; architecture as an indifferent process |
| **Antichamber** | stark white void + single-colour accents; impossible space kept readable |
| **HyperRogue** | the only serious prior art on making hyperbolic tilings *readable* |
| **INSIDE** | lighting and atmosphere carrying narrative with no UI at all |
| **Sethian / FRACT OSC** | a world that is visibly a system you are learning to operate |
| **Kentucky Route Zero** | flat-shaded drama; how far tone travels on very few polygons |

## What to hire, and when

Do **not** hire before Phase 1. The art direction cannot be evaluated
until hyperbolic walking is proven tolerable (Phase 0), and hiring into an
unproven direction wastes the budget and the relationship.

When hiring, the first deliverable is **not** assets. It is:

1. One "geometry key frame" per curvature band (three images) proving the
   hue system reads.
2. The ~12-glyph landmark alphabet.
3. A material/shader style guide that a programmer can implement, because
   most of this world is procedurally generated and cannot be
   hand-placed.

**The artist must be comfortable authoring *systems and rules*, not
props.** This world is generated. An artist who needs to hand-place every
object will be miserable here, and it is kinder to say so in the job post.

---

# Audio direction — "The Rule Sings"

## The brief in one paragraph

> The cellular automaton **is** the score. We are not writing music that
> plays over a simulation; we are building an instrument that the
> simulation plays. Your job is to design the instrument — the palettes,
> the voicing rules, the harmonic constraints — and then let the world
> perform it. Every player hears a different piece, and every piece is
> literally the state of the world.

## Why this is the right call, not a gimmick

1. **It is thematically exact.** In a game about a deterministic rule
   producing unpredictable beauty, the soundtrack being generated by that
   rule is not a metaphor.
2. **It is cheap to produce and infinite in extent** — synthesis and
   sample palettes, not hours of recorded score for an 8-15h game.
3. **It sonifies the mechanic**, giving the player a second channel for
   reading a space, which directly serves the legibility pillar. Players
   with visual difficulty in non-euclidean space get a real alternative
   instrument.
4. **It solves the settling problem audibly.** As a region calcifies, it
   goes quiet. The antagonist is *heard* approaching as silence.

## The mapping

| World event | Sound |
|---|---|
| generation tick | the beat — the world's pulse, rate set by the hourglass |
| cell birth | note on |
| cell death | note off / damped |
| local density | harmonic richness, voice count |
| your own configuration | your personal timbre — you can hear what body you're wearing |
| a settled region | silence |

**Per-geometry palettes, derived from the geometry:**

- **The Fold (κ>0).** Sound wraps. It is a closed surface, so a loud event
  on the far side arrives at you *across the interior* — and at the
  antipode, from every direction at once. Use it: the sphere's acoustics
  are a navigation instrument, and antipodal focusing is a real property
  of a sphere, not an effect.
- **The Repeat (κ=0).** Everything echoes as exact repetition — the same
  motif returning at fixed delay, because it is literally the same event
  arriving the long way round.
- **The Sprawl (κ<0).** Exponentially many cells within earshot, so sound
  **crowds** — density rises with distance until the far field is an
  illegible wash. The audio has the same legibility law as the light, for
  the same mathematical reason. This should be genuinely oppressive and it
  should resolve to clarity the moment you look at what is close.

## Composer brief

Deliverables are a **system**, not a soundtrack:

1. **Instrument palettes per curvature band** (3), each a small set of
   voices with defined register and attack.
2. **Voicing and harmony rules** — a constraint set that keeps arbitrary
   cell-birth patterns from becoming noise. This is the hard, valuable
   part: the automaton will produce rhythmically arbitrary events and the
   ruleset must make them *musical* without quantising away the truth.
3. **Density curves** — what happens as population rises, and crucially
   what happens as it falls to nothing.
4. **Three or four authored pieces** for the moments that must land
   exactly: the first zoom-out reveal, the arrival in the Sprawl, and each
   of the three endings. Authored music is for punctuation; the system
   carries the rest.

References: Rez, Panoramical, Proteus, FRACT OSC, Mini Metro — all cases
where simulation state drives the audio and the result reads as composed.

## The one hard constraint

**The audio must never lie about the simulation.** If it sounds busy, the
region is busy. Pillar 5 ("the simulation is honest") applies to the ears
as much as the eyes — a player who learns to trust the sound is a player
who can navigate the Sprawl blind, and that is a skill worth building and
worth protecting.
