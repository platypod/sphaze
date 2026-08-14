# Direction

The whole-game direction, written 2026-08-11 in one long session, from a
brief that asked for a step change: *from the pale prototype it currently
is towards a real video game* — Garden-of-Eden lines, non-euclidean
geometry as sculpting material, several story threads, no menu, Outer
Wilds as a lesson rather than a template, and explicit permission to
challenge the oldest directives.

Target agreed before writing: **8-15 hours**, quality bar of something
that *could* be sold (destination undecided), **artist and composer
hireable**, **engine choice open**.

## Where this sits in the doc lifecycle

[../README.md](../README.md) defines a lifecycle where each file holds one
kind of content and content *moves* between files as its status changes.
This folder is a new slot in it, and it needs its own movement rule:

| | |
|---|---|
| **Holds** | The whole-game direction: what this game *is*, at a level above any single mechanic. Changes rarely and deliberately. |
| **Feeds** | [../ideas-backlog.md](../ideas-backlog.md) — when a piece of direction becomes something you could actually build next, it gets a backlog entry with the usual shape (*Fits*/*Unproven*/*Cost*), and this folder keeps only the *why*. |
| **Answers to** | [../philosophy.md](../philosophy.md) — where direction and pillars disagree, that's a decision to make explicitly, not silently. This document proposes pillar changes rather than assuming them (see below). |
| **Records** | Decisions land in [../design-decisions-records.md](../design-decisions-records.md) as usual. Nothing here is a decision yet — it is a *proposal*, in full, ready to be argued with. |

**Status: proposed, not adopted.** Nothing in this folder has been agreed.
It's written as though committed because a direction hedged at every
sentence is unreadable and unarguable — but every load-bearing choice is
flagged where it's genuinely open, and [roadmap.md](roadmap.md) ends with
the questions I could not answer alone.

## The thesis

The current game is a maze on the inside of a sphere. It has a real hook
("see far, not near"), a genuinely deep piece of engineering nobody asked
for (a geodesic cellular automaton with 12 pentagon defects), and a
leading story candidate about being a pattern that outgrew its automaton.
Those three things have been sitting next to each other without being
*the same thing*.

They are the same thing. Here is the sentence that joins them:

> **A cellular automaton runs on a graph. A graph has a geometry. And
> whether a pattern can exist without a cause depends on which geometry
> it runs on.**

That is not a metaphor. It is a theorem, and it is the whole game.

### The theorem

A **Garden of Eden** (or **orphan**) is a configuration with no
predecessor — not an unknown parent, but *no possible* parent. It cannot
be the output of the rule applied to anything. If one exists, it was
never caused.

The **Garden of Eden theorem** (Moore 1962, Myhill 1963) ties orphans
rigidly to the rule's own bookkeeping: a cellular automaton is surjective
if and only if it is pre-injective. Cause and effect balance exactly.

But that theorem is a statement about the *shape of the space the
automaton runs on*. Ceccherini-Silberstein, Machì and Scarabotti extended
it to all **amenable** groups. Then Bartholdi proved the converse — and
this is the door:

> **The Garden of Eden theorem holds if and only if the group is
> amenable.** On any non-amenable group it *fails*: there exist automata
> that are pre-injective but not surjective, and vice versa.

A sphere is compact. Its symmetry group is amenable. The theorem holds
there, and the accounting between cause and effect is complete and
exact — nothing exists that the rule did not make.

A hyperbolic tiling group contains free subgroups. It has exponential
growth. It is **not amenable**. The theorem fails there.

**Uncaused existence is available only in negative curvature.**

### What that makes the game

You are a pattern in an automaton. You wake on a sphere: finite, closed,
no boundary, every direction returns. It is a perfect prison, and its
perfection *is* its compactness — there is no "away", only the long way
around. The bookkeeping is exact. You are an effect of something.

To become an orphan — to be a thing that was never caused — you must
reach a space whose geometry cannot account for you. You must walk down
the curvature scale, from κ > 0, through flat, into κ < 0, until you
stand somewhere the theorem does not hold.

> **Freedom is a curvature.**

And the reason you can be free there is *the same reason you get lost
there*. Non-amenability means no region is ever mostly-interior: in
hyperbolic space the boundary of any patch is as large as the patch
itself. **Everywhere is edge.** You cannot be surrounded, contained, or
accounted for — and you cannot find your way home. Freedom and
disorientation are one fact, expressed as a shape you walk through.

That is the game. Every system below is downstream of it.

## Why this is worth doing

Three checks, because a premise this tidy deserves suspicion:

- **Is it novel?** HyperRogue does hyperbolic tilings; Manifold Garden
  does Euclidean quotient space; Antichamber does impossible rooms;
  Miegakure does 4D; *Conway's Game of Life* has a thousand toys. Nobody
  has made *you* a pattern whose available ways of existing are determined
  by the curvature you stand in. The join is the new thing, not either
  half.
- **Does it use what exists?** Yes, and more than expected — see
  [architecture.md](architecture.md). The cellular-automaton work is
  graph-based, and a graph does not care about curvature, so all of it
  ports to hyperbolic tilings unchanged. That is the single largest
  investment in the repo and it survives whole.
- **Does it survive contact with the pillars?** Mostly it *sharpens* them.
  See below.

## Proposed pillars

Against the current [../philosophy.md](../philosophy.md). Three survive
sharpened, one is promoted from [../inspirations.md](../inspirations.md),
one is new and expensive, one is demoted.

1. **Geometry is content, not setting.** *(promotion)* Already written in
   [../inspirations.md](../inspirations.md) as the distilled HyperRogue
   rule — "a biome's mechanic should be a corollary of the sphere, not a
   decoration on it" — and parked pending real use. It has now judged an
   entire world (see [world-and-threads.md](world-and-threads.md)) and it
   earned promotion. Generalised past the sphere: *every space exists to
   demonstrate a property of its own curvature or topology. If the mechanic
   works unchanged in a flat rectangular room, it is a reskin, not a place.*

2. **Every space has its own legibility law.** *(generalises "see far, not
   near")* The original pillar is the sphere's *particular* law, and it was
   always the deepest thing here. Now it becomes a family: the sphere shows
   you everything except your feet; the hyperbolic plane hides everything
   past arm's reach; the torus shows you infinite copies of your own back.
   **Learning to read a space is the gameplay.** The old pillar isn't
   weakened — it's revealed as the first instance of a bigger rule.

3. **Knowledge is the only key, and your body is the record.** *(new,
   replaces nothing)* Nothing is locked by an item or a flag; doors are
   locked by not understanding. Where Outer Wilds banks understanding in a
   ship log, ours is banked in **what you can be** — see the `BECOME`
   system in [systems.md](systems.md). Look at yourself to see what you
   know. This is how the game keeps pillar 4 while still having
   progression.

4. **Diegetic absolutely.** *(sharpened)* Was "diegetic over UI chrome";
   the brief says no menu, so this hardens from a preference to a
   prohibition. No menu, no HUD, no journal, no map. Progress is legible
   as your own shape and the state of the world.

5. **The simulation is honest.** *(new, and the expensive one)* The
   automaton really runs, really deterministically, really by the same rule
   in the same space everywhere — no scripted set-piece wearing emergence
   as a costume. This is a promise to the player that the world will reward
   being reasoned about. It is also the most costly commitment in this
   document, and [roadmap.md](roadmap.md) flags the honest question of how
   absolute to make it.

6. **Prototype unproven mechanics before committing.** *(kept verbatim)*
   Now load-bearing in a way it never was: this direction's single
   existential risk is whether walking in hyperbolic space is *pleasant*,
   and Phase 0 of the roadmap exists solely to answer that before anything
   else is built.

**Demoted: "coherent, noir-leaning atmosphere."** Not abandoned — promoted
*out* of the pillars into a real art direction with a specific brief (see
[art-and-audio.md](art-and-audio.md)), because "noir-leaning" was doing
the job of a placeholder for an art direction that didn't exist yet. Now
one does, and it is more specific than noir: hue encodes curvature.

## The documents

| File | What it holds |
|---|---|
| [world-and-threads.md](world-and-threads.md) | The geometries, what each teaches, and the four story threads that run through them; the endgame and its three endings |
| [systems.md](systems.md) | Moment-to-moment gameplay: the verbs, the `BECOME` system, how knowledge gates progress without a journal |
| [architecture.md](architecture.md) | The technical plan — why the current `Space` abstraction provably cannot hold this game, what replaces it, and the engine decision with its revisit trigger |
| [art-and-audio.md](art-and-audio.md) | Art and audio direction, written as briefs a contractor could be handed |
| [roadmap.md](roadmap.md) | Phases, honest timeline, risk register, and the questions I could not answer alone |
| [names.md](names.md) | The game is not called sphaze any more. Candidates, with a recommendation |

## Sources

The theorems this direction rests on, so the claims can be checked rather
than trusted:

- [The Garden of Eden theorem: old and new](https://arxiv.org/pdf/1707.08898) — survey; Moore–Myhill, the amenable extension, and Bartholdi's converse
- [Gardens of Eden and amenability on cellular automata](https://ems.press/journals/jems/articles/1812) (Bartholdi) — the converse: non-amenable groups always break the theorem
- [Amenability of groups is characterized by Myhill's Theorem](https://arxiv.org/pdf/1605.09133) — the sharpened statement
- [Cellular Automata in Hyperbolic Spaces](https://link.springer.com/rwe/10.1007/978-3-642-27737-5_53-5) (Margenstern) — CAs on the pentagrid and ternary heptagrid are a real, developed field
- [A weakly universal cellular automaton in the heptagrid](https://arxiv.org/pdf/1606.09488) — universality on {7,3}
- [Hilbert's theorem on immersion of the hyperbolic plane](https://math.uchicago.edu/~may/REU2020/REUPapers/Dewhurst.pdf) — why the current architecture cannot hold hyperbolic space
- [Hyperboloid model](https://en.wikipedia.org/wiki/Hyperboloid_model) — the representation [architecture.md](architecture.md) proposes
- [HyperRogue: Playing with Hyperbolic Geometry](https://www.archive.bridgesmathart.org/2017/bridges2017-9.pdf) — already in [../inspirations.md](../inspirations.md); the prior art for both the rendering and the design rule
