# Note — what rule-driven walls would cost the codebase

Engineering answer to a design question asked on 2026-07-29 ("do we need to
change anything to anticipate walls that behave by a rule?"). Lives here rather
than in [ideas-backlog.md](../ideas-backlog.md) because it's about the code, not
the design — the backlog entry links to it. Short version: **much less than
expected, but not nothing.**

## The good news: one chokepoint

Wall state already has exactly one: `biomes.common.grid.GridModel.isOpen`.
Rendering (`GridMesh`'s own `WallBuilder`), collision
(`GridModel.wallZoneNeighbor` → `GridCollision`) and decoration placement
(`GridModel.isWellClearOfWalls`) all ask it rather than reading
`GridData.openEdges` themselves. So "walls that change" is a change *behind*
one call, not a change to every consumer.

**The rule to preserve:** nothing snapshots `openEdges` into a private copy. One
thing already derives state at load time — `biomes.maze.MazeExitWall.find`,
cached as each biome's own `exitWall` — and would need re-deriving (or pinning)
whenever a rule-driven layout mutates.

## The three real gaps

1. **Rebuild cadence is the actual cost.** `GridMesh.build` builds the whole
   sphere's walls as one `h3d.prim.Polygon`, and `Biome.build` only runs on
   entry. `biomes.conway.ConwayBiome` proves per-step rebuilding is viable at its
   own 0.75s cadence; a full grid maze rebuilt at 60 Hz is not. A rule-driven
   biome therefore needs either rebuild-on-change-only (fine for
   corridors-close-behind-you, where changes are rare and player-driven) or
   walls split into per-cell meshes so only changed cells rebuild.
2. **A wall arriving around a *stationary* player has no decided rule.**
   `wallZoneNeighbor`'s test is deliberately "am I deeper into this wall's zone
   than I was last tick" — a *movement* test, which by construction cannot fire
   for a player standing still while geometry closes on them. Pick a rule
   (refuse the close, eject along the nearest open tangent, or harm the player)
   before any biome depends on it, rather than discovering it as a
   stuck-in-a-wall bug.
3. **Serialization needs the rule's phase, not just the edges.**
   `Biome.serialize` encodes open edges alone, which is enough for a static
   maze; a rule-driven one has to save its tick/phase too, or an exported bug
   report won't reproduce.
