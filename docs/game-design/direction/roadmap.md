# Roadmap, risks, and what I could not decide

Written against the agreed target: **8-15 hours**, sellable quality bar,
artist/composer hireable, engine open.

## The honest headline

**An 8-15 hour non-euclidean game is a 3-5 year project** at solo pace
with contract art and audio. That is not pessimism, it is the arithmetic:
the genre has no reusable middleware, every spatial system must be built
twice (once to work, once to be comfortable), and content that teaches
rather than decorates cannot be mass-produced.

Two things make it survivable, and both are structural rather than
motivational:

1. **The world is mathematical, so the expensive content is cheap.** Nine
   geometries are nine parameter sets, not nine hand-built levels. The
   costly authored content is the *thread beats*, and there are perhaps
   thirty of those.
2. **The vertical slice must be independently shippable.** See Phase 1.
   The strongest de-risking available is that the first year's output is a
   complete small thing rather than an unfinished large one.

## Phase 0 — Answer the question that can kill this

**~2 months. Nothing else starts until this is done and *played*.**

The direction has exactly one existential risk, and it is not scope,
budget or engine:

> **Is walking in hyperbolic space pleasant, or is it nauseating?**

Everything in this folder is worthless if the answer is the second one.

Build:
- `CurvedSpace` + `Isometry`, headless, tested against closed-form
  identities (steps 1-2 of the migration plan in
  [architecture.md](architecture.md))
- the HxSL projection fragment
- **one bare `{7,3}` room**, no art, no simulation, no content — just
  geometry you can walk

**Kill criteria, decided in advance so they cannot be rationalised away
later:**

- If hyperbolic first-person walking is nauseating for the developer
  within 10 minutes, and no amount of FOV, movement-speed or turn-rate
  tuning fixes it → **the direction changes**. Fall back: hyperbolic
  spaces become things you *look at and manipulate* rather than walk
  through, and the game keeps the thesis but not the first-person
  traversal.
- If it is merely disorienting but not sickening → proceed, and treat
  comfort as a *design constraint from day one*, not a settings menu
  bolted on in year three.

Get three other people to walk it. Motion tolerance varies enormously and
a sample of one is not a sample.

## Phase 1 — Vertical slice *(shippable on its own)*

**~9 months. Hire the artist during this phase, not before.**

Scope:
- **The Fold** (exists) and **The Sprawl** (new), plus the transition
  between them — the game's entire thesis is that transition
- `BECOME` with three bodies: still life, oscillator, glider
- `READ` (learn by watching), `TICK`, `SEED`, `ZOOM`
- One Thread 2 beat: **the ghost** — the whole of
  [first-hour.md](first-hour.md), essentially
- Art direction proven on two curvature bands
- Audio system proven (the automaton playing an instrument)
- **Comfort options as first-class features**, not a checkbox

Target: **60-90 minutes that genuinely represent the game**, ending on the
arrival in the Sprawl.

**Make it shippable as a free standalone.** Not as a demo — as a complete
short thing with an ending. This is the single best decision available in
this whole plan: it converts a terrifying five-year bet into a one-year
project with a real audience, real feedback on whether non-euclidean
walking works for *other people*, and something to point at when hiring or
funding. If the response is flat, that is worth knowing in year one.

**Budget the tooling here.** [architecture.md](architecture.md) names the
engine's real weakness: no editor. This world needs parameter tooling and
in-game debug authoring. Build it in Phase 1, when it is cheap, not in
Phase 3 when it is desperate.

## Phase 2 — The spine

**~18 months.**

- All nine spaces
- The full Ascent (Thread 1) — all six bodies
- All four threads' beats placed and interlocked
- The knowledge web tuned: every gate an understanding, none a flag
- The endgame and its three endings

The hard problem of this phase is not building spaces, it is **the
knowledge web**. Outer Wilds' hardest work was ensuring every player could
always find *something* to pull on. Expect this to need several full
playtest-and-rewire passes with people who have never seen the game, and
schedule them.

## Phase 3 — Production

**~12 months.**

Density and secrets; accessibility (unusually load-bearing here —
non-euclidean space is hostile to motion-sensitive players and comfort
work is a moral obligation, not a nice-to-have); localisation; store page,
trailer, demo, festivals; a full authored-audio pass on the punctuation
moments.

---

## Risk register

| # | Risk | Severity | Mitigation |
|---|---|---|---|
| 1 | **Motion sickness** — hyperbolic walking is intolerable | **existential** | Phase 0 exists solely for this; kill criteria written in advance; comfort as a design constraint |
| 2 | **The `{7,3}` rule may have no interesting life** | medium (*corrected down* — see below) | rule space is larger than the hex grid's, but persistent travelling structures in negative curvature are unproven |
| 3 | **Navigational frustration** — lost stops being wonder and becomes rage | high | landmark alphabet; hue-encodes-curvature; teach every skill in the safe warm sphere before removing it |
| 4 | **Scope** — 8-15h is enormous for this genre | high | geometries are procedural; concentrate authored content in ~30 thread beats; Phase 1 ships standalone |
| 5 | **"The simulation is honest" is expensive** | medium | decide *how* honest explicitly — see open questions |
| 6 | **Engine bet** | medium | named revisit trigger in [architecture.md](architecture.md); do not relitigate otherwise |
| 7 | **Solo burnout over 3-5 years** | high | Phase 1 ships; visible progress; the hub gaining curvature is a progress bar for the *developer* too |
| 8 | **`BECOME` may not be fun** — the core system, never played | **existential** (*added on review*) | moved into Phase 0; three bodies on flat ground, ten minutes, before any world is designed around it |
| 9 | **Repeated-traversal locomotion may be boring** — the Turn specifically needs the loop walked more than once, on purpose | high (*added 2026-08-12*) | see [world-and-threads.md](world-and-threads.md)'s own Turn entry: either the movement itself has to be a *Race the Sun*-grade pleasure, or every lap needs its own improvable skill. Unresolved; blocks judging that space's chirality mechanism at all |

### Risk 2, in detail — because it is the one that hides

> **Corrected 2026-08-11, same session.** The first version of this entry
> claimed `{7,3}` gives *three* neighbours per cell and a rule space of
> only ~256, and rated the risk "high". That was wrong, and wrong in the
> direction of alarm. **"Ternary" names three tiles around a *vertex*, not
> three neighbours per cell** — a `{7,3}` cell is a heptagon with **seven**
> edge-neighbours. The corrected entry stands below; the error is left
> visible because a design doc that quietly rewrites its own risk register
> cannot be trusted.

The Sprawl runs on `{7,3}`: **seven neighbours per cell.** A two-state
outer-totalistic rule there has a rule space of roughly 2⁸ × 2⁸ = 65,536
rules — *larger* than the hex sphere's 6-neighbour space (~16,384), not
smaller. On rule-space size alone the heptagrid is **more** promising than
what this project is already running on, not less.

The real risk is different, and it survives the correction:

**Rich dynamics on a hyperbolic tiling are unproven for this project's
purposes.** A large rule space does not imply interesting life — this
project has already been burned by exactly that gap on the *hex* grid,
where the multi-rule search found **zero** confirmed travellers among
2166 candidates, and the only known spaceship for `B2/S34H` came from
Catagolue's ~100 billion soups rather than from local search. Add the
specifically hyperbolic complication: neighbourhoods grow *exponentially*
with radius, so a pattern's influence disperses far faster than on any
flat or spherical grid, and "a small configuration that holds together
while translating" is a harder thing to be there than here.

So the question to answer is not *"is the rule space big enough"* (it is)
but **"do compact, persistent, translating structures exist at all in
negative curvature?"** — and that is genuinely open.

**Mitigations, in order of preference:**

1. **More states.** Margenstern's universal heptagrid automata use four
   or more, and this project *already switched to a 4-state Ventrella
   rule* for a closely related reason. The tooling and the instinct both
   exist.
2. **Larger neighbourhood** — 2-ring instead of 1-ring, at the cost of
   legibility.
3. **`{5,4}` instead** — the pentagrid, five neighbours, also well studied
   by Margenstern, if the heptagrid proves unfriendly.

**Spike this in Phase 0**, alongside the walking test. It is cheap and
headless, the `GeodesicLifeReport`-style harnesses already exist, and the
combinatorial tiling can be generated without any of the geometry work —
so it can run in parallel with everything else. Discovering it in Phase 2
would be catastrophic.

**Severity after correction: medium, not high.** Still the second risk
worth spiking early, but no longer a plausible project-killer.

**Partially spiked, same session — see
[../notes/hyperbolic-simulation-findings.md](../notes/hyperbolic-simulation-findings.md).**
`{7,3}` sustains life *easily*: 972 sampled rules survived 120 generations
without dying or saturating, many churning every generation — a markedly
better starting position than the hex sphere ever gave. Travelling
structures still unsearched, so the risk is narrowed rather than closed.

That spike also turned up a finding that **changes the build order**: a
finite hyperbolic patch is mostly boundary (617 faces, 85 usable) and
grows *worse* with size, because ring populations grow by φ² forever. The
fix is to use a compact hyperbolic surface rather than a patch — which
means **The Knot (genus-2) may need to be built before The Sprawl**,
inverting the ordering in Phase 2 above. Not yet folded into the phases;
flagged here because it is a real ordering decision, not a detail.

---

## What I could not decide alone

Genuinely open — these need a person with taste and ownership, and
guessing would have been worse than asking.

1. **How honest is the simulation, exactly?** Pillar 5 says the automaton
   really runs everywhere, deterministically. That is expensive and it
   constrains authored moments hard — a scripted beat cannot happen at a
   chosen dramatic moment if the rule decides when things happen. The
   spectrum runs from *absolute* (beautiful, brutal) to *honest where the
   player can check* (pragmatic, slightly a lie). **My instinct: absolute
   in the Fold and the Sprawl, authored in the Garden — and never admit
   which is which.** But this is a values question about the game's soul.

2. **Is there a visible body?** First-person with no body is cheap and
   standard; seeing your own configuration is thematically loaded and
   makes `BECOME` legible. A shadow that shows your current configuration
   might be the whole answer.

3. **Are the three endings equal?** I wrote them as genuinely equal
   (autonomy / legacy / rest) and refused to rank them. Some games are
   better with a true ending. This changes how Thread 4 is written.

4. **Combat: confirmed absent?** I designed none. Tension comes from the
   settling world and from commitment costs. This is the right call for
   the tone, but it is a big commitment and you should confirm it rather
   than inherit it.

5. **The name.** [names.md](names.md) recommends **UNBEGOTTEN** with
   **ORPHAN** a close second. It is your game and this one is taste plus a
   trademark search.

6. **Asynchronous traces of other players?** Thematically extraordinary —
   patterns left behind by real people, indistinguishable from
   predecessors, and Thread 2 would land differently if the ghosts were
   *real* ghosts. Also a large scope increase and an online dependency.
   Flagged because it is the one idea I regret not having room to develop,
   not because I recommend it.

7. **Does the Tower survive?** It has no home in this direction as-is.
   Repurpose as a fibered space (stacked flat layers over a circle), or
   retire it and keep the fall-counter idea for something else.

---

## Added on review (2026-08-12): two judgements the first pass ducked

### Cut the world from nine spaces to five

Nine spaces was generous rather than considered. Each one has to *teach*
something and be authored well enough to be worth visiting, and the
roadmap's own claim that "geometries are cheap" is only true of the
geometry — not of the thread beats, landmark alphabets, audio palettes and
playtesting each space drags behind it.

Recommended core five, keeping one space per distinct *lesson*:

| Keep | Because |
|---|---|
| **The Fold** (κ>0) | exists, and it is the cradle the whole story needs |
| **The Defect** (cone) | cheapest space in the set and the one that teaches what curvature *is* |
| **The Ribbon** (1D history) | cheap, unique, and the only place Thread 3 can pay off |
| **The Sprawl** (κ<0) | the turn of the game; non-negotiable |
| **The Knot** (genus-2) | now the *technically correct* substrate too — see the findings note |

Defer **The Weft**, **The Repeat**, **The Turn** to a post-launch or
second-act decision. The Turn (Möbius) hurts most to lose since it already
exists — but "already exists" is a sunk cost, not a reason.

This is a recommendation, not a rewrite: the nine remain described in
[world-and-threads.md](world-and-threads.md), and the cut is a decision
for whoever owns the project.

### "Is BECOME actually fun?" belongs in Phase 0, not Phase 1

The first pass rated exactly one existential risk (motion sickness) and
put the `BECOME` system in Phase 1 as though it were a build task. That
was an inconsistency: `BECOME` is asserted throughout
[systems.md](systems.md) to be "the core system, and the one that makes
this a game rather than a walking simulator", and **no part of it has ever
been played.**

The glider body in particular — *you move at fixed speed and may only
change direction at phase boundaries* — is claimed to be "a genuinely
distinctive movement mode". It might equally be an infuriating one. That
claim carries as much weight as the hyperbolic-walking claim and got a
tenth of the scrutiny.

**Add to Phase 0**, alongside the walking test and cheaper than it: three
bodies, flat ground, no art, no simulation. Can you enjoy being a glider
for ten minutes? Kill criterion: if committed-direction movement is merely
annoying rather than interesting, `BECOME` needs redesigning **before**
the world is designed around it, because six of the nine spaces assume it.

## The single most important sentence in this folder

If only one thing survives this document:

> **Build Phase 0 before believing any of the rest of it.**

Everything here is downstream of an assumption that a person can walk
around in negative curvature and enjoy it. That assumption is testable in
about two months, and it is the difference between a five-year project and
a five-year mistake.
