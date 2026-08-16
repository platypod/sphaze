# Inspirations

External references worth borrowing from, each with the *specific*
transferable lesson rather than a general "this game is good" — and, where
it applies, which [ideas-backlog.md](../open/ideas-backlog.md) entry it feeds. Added
after a 2026-07-29 research pass looking for ways to make each biome's maze
feel like its own thing (see [`../archive/project-log.md`](../archive/project-log.md)).

Rule for this file: an entry earns its place by carrying a lesson we can
actually act on. If a reference only justifies something we'd have done
anyway, it doesn't need to be here. Entries stay even after the idea they
fed ships — unlike backlog entries, which get deleted on implementation —
because "why is it shaped like this" outlives the shipping.

## The distilled rule

The load-bearing takeaway from the whole pass, mostly from HyperRogue:

> **A biome's mechanic should be a corollary of the sphere, not a decoration
> on it.** If the mechanic would work unchanged in a flat rectangular maze,
> it's a reskin, not a biome.

This isn't (yet) a pillar in [philosophy.md](../rules/philosophy.md) — it's a strong
candidate for one, deliberately parked here until it's been used to judge a
few real biome ideas rather than promoted on the strength of one research
session. It already sorts the backlog usefully, though: the antipode-pairs,
great-circle, inverse-legibility and centre-shadow entries pass it hardest;
"a maze but foggy" passes it least.

## References

### [HyperRogue](https://www.roguetemple.com/z/hyper/) — 72 lands, one geometry

The closest structural match to unbegotten's problem, and the reason for the
rule above. Every one of its lands exists to demonstrate a *different
property of the hyperbolic plane*: Camelot is a huge circle whose centre you
cannot find with Euclidean intuition (you have to derive an algorithm);
Burial Grounds gives you a sword that holds its angle relative to your own
motion, which is only awkward *because* of how hyperbolic parallel transport
works. The geometry is the content — there is no "hyperbolic-themed" land,
because that would be nothing. Design paper:
[HyperRogue: Playing with Hyperbolic Geometry (Bridges 2017)](https://www.archive.bridgesmathart.org/2017/bridges2017-9.pdf).

Feeds: the geometry-corollary rule above, and by extension the antipode
pairs, great-circle corridors, latitude-economy and centre-shadow entries.

### [Legend of Zelda dungeon design](https://www.gamedeveloper.com/design/depicting-the-level-design-of-a-legend-of-zelda-dungeon) — one verb per dungeon

The order of operations is the lesson: designers pick the *gameplay* first,
then a theme that suits it, then build the space as a teaching machine for
one reusable item that changes how the player interacts with the world.
Applied here: pick one verb per biome and let the maze exist to make the
player fluent in it — not five twists layered into one level.

Feeds: the "one verb per biome" discipline noted on most backlog entries.

### [The Witness](https://gameranx.com/features/id/36898/article/the-witness-puzzle-types-and-rules-guide/) — an area whose lesson is a deleted rule

The elimination-mark area teaches that one rule you had been relying on can
be cancelled. That's a biome generator on its own, because unbegotten has
explicit rules to delete: see-far-not-near (→ candlelight), "exactly one
path between any two cells" (→ braided mazes, where a dead end no longer
*proves* a wrong branch), wall permanence (→ corridors that close), the
floor existing at all (→ the tower, already built).

Feeds: the perception-rules and rule-driven-walls entries.

### [Void Stranger](https://thinkygames.com/games/void-stranger/) — the player edits the maze

Its whole grammar is one verb: lift a floor tile, place it in a hole. A
maze becomes a resource-management puzzle rather than a route-finding one.
Also, relevantly, it treats its own dungeon's geometry as a liar — the
stairs go down wherever you put them.

Feeds: the wall-carry idea inside the antipode-pairs entry, and the
"floor-as-Life" variant in the rule-driven-walls entry.

### [Blue Prince](https://blueprince.wiki.gg/wiki/Drafting) — you draft the level as you walk it

Rooms are chosen from a small offered hand at each door, under constraints,
and the layout doesn't persist between days. The relevant part isn't the
roguelike loop, it's that *choosing the layout is the gameplay*, and choosing
it with incomplete information is what makes it a decision rather than a
menu.

Feeds: the junction-drafting entry.

### [Manifold Garden](https://www.gamedeveloper.com/design/designing-i-manifold-garden-i-s-believably-unbelievable-world-and-puzzles) — repetition as a readable structure

Arbitrarily deep recursion, used so that seeing the same world repeat is
*information* rather than vertigo. The useful transfer for us is the
maquette/replica idea: a scale model of a space, readable from outside it,
which is exactly what a sphere's centre offers to every point at once.

Feeds: the centre-maquette variant in the perception-rules entry.

### [Dead Cells](https://deepnight.net/tutorial/the-level-design-of-a-procedurally-generated-metroidvania/) — biome identity from restriction, and hybrid generation

Two lessons. First, its biomes get their identity from what they *forbid* —
the sewers are tight specifically to restrict jumping and dodging, which
changes how you fight there. Second, its generation is a hybrid: a
hand-authored concept graph (entrance, exit, special rooms, then filler)
filled in procedurally, rather than pure noise. Ours is currently pure
procedure everywhere.

Feeds: the per-biome maze-recipe entry; a future "authored skeleton,
generated detail" pass if pure generation ever stops carrying a biome.

### [Ravensburger's Labyrinth](https://www.amazon.com/Ravensburger-Labyrinth-Board-Game-Adults/dp/B00000J0JF) — the walls move as a move

The oldest, cheapest proof that a maze whose walls shift under the players
is fun rather than merely unfair: shifting a passage *is* your turn, so the
maze is an opponent you also get to use.

Feeds: the rule-driven-walls entry.
