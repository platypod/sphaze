# Architecture

The technical half of the direction. One provable blocker, one
replacement, one engine decision, and an honest account of what survives
the transition.

## The blocker, and it is a proof rather than an opinion

`biomes.common.space.common.Space` is the abstraction the whole spatial
layer rests on:

```haxe
function upAt(pos:h3d.Vector):h3d.Vector;
function moveAlong(pos:h3d.Vector, forward:h3d.Vector, direction:h3d.Vector,
                   distance:Float, radius:Float):{pos:h3d.Vector, forward:h3d.Vector};
```

Positions are `h3d.Vector` — points in ambient Euclidean 3-space — and
`moveAlong` transports them by 3D rotation. Every implementation
(`SphereSpace`, `FlatSpace`, `MobiusSpace`, `SphereExteriorSpace`) works
because its surface is **isometrically embedded in ℝ³**. That assumption
reaches **53 of 122 source files**.

The hyperbolic plane admits no such embedding. **Hilbert's theorem**
(1901), sharpened by **Hilbert–Efimov**: there is no complete C²
isometric immersion of the hyperbolic plane into ℝ³. Not "hard", not
"not yet found" — impossible, proved, 125 years old.

> The current architecture cannot represent the game's most important
> space, and no amount of engineering will make it. This is the single
> most important technical fact in this document.

Everything below follows from taking that seriously rather than looking
for a workaround.

## The replacement: one representation, parameterised by curvature

Drop ambient ℝ³. Represent points **intrinsically**, in a homogeneous
model whose signature is set by a single curvature parameter κ.

Take the bilinear form on ℝ³

```
⟨u, v⟩_σ  =  u₁v₁ + u₂v₂ + σ·u₃v₃        σ = sign(κ)
```

and put points on its unit quadric:

| κ | Form | Surface | Isometry group | "Move forward by d" |
|---|---|---|---|---|
| **> 0** | ⟨p,p⟩ = +1 | sphere | SO(3) | rotation |
| **= 0** | degenerate | Euclidean plane | ISO(2) | shear |
| **< 0** | ⟨p,p⟩ = −1, z>0 | hyperboloid | SO(2,1) | **Lorentz boost** |

The three cases unify through the generalised trigonometric functions

```
cos_κ(d) = cos(√κ·d) | 1 | cosh(√−κ·d)
sin_κ(d) = sin(√κ·d)/√κ | d | sinh(√−κ·d)/√−κ
```

so **one code path handles all three geometries, with κ as a number.**
This is what HyperRogue does, and it is the reason the world map in
[world-and-threads.md](world-and-threads.md) can be a curvature scale:
in the code it genuinely *is* one scalar.

The hyperboloid (Minkowski) model specifically, rather than Poincaré or
Klein, for the *simulation* side — it has the better numerical behaviour
and its isometries are plain matrix multiplications.

### The spaces are products, which de-risks everything

The game is not "walking in hyperbolic 3-space". The player walks a
**surface**, with a height dimension for walls, blocks and jumping. So the
actual geometries are the product geometries

```
S²×ℝ   ·   E²×ℝ (= E³)   ·   H²×ℝ
```

three of Thurston's eight. That matters practically:

- The curvature lives entirely in the **surface** factor. The **height**
  factor stays Euclidean.
- So gravity, jumping, wall heights, block extrusion, the standable-live-
  cell mechanic — all the vertical work already built — remain ordinary
  Euclidean code.
- Only the 2D surface component needs the κ-machinery.

That is a much smaller and better-bounded rewrite than "port the game to
hyperbolic space" suggests.

### The new interface

```haxe
interface CurvedSpace {
    var curvature(get, never):Float;              // κ
    function origin():Isometry;                   // identity frame
    function translate(distance:Float):Isometry;  // forward by d, κ-aware
    function rotate(angle:Float):Isometry;        // in the tangent plane
    function compose(a:Isometry, b:Isometry):Isometry;
    function distance(a:Point, b:Point):Float;    // intrinsic metric
    function project(p:Point):h3d.Vector;         // model → clip, for rendering only
}
```

The player's state stops being `(pos, forward)` and becomes **a single
isometry** — the frame that takes the origin to where the player is,
facing where they face. Movement is matrix composition. This also
quietly deletes a whole bug class: the pole-singularity problems recorded
at length in `PROJECT_LOG.md` were symptoms of coordinates, and an
isometry has no coordinates to be singular in.

## What survives, and it is the valuable part

The single largest investment in this repo is the geodesic
cellular-automaton work. **All of it ports unchanged**, because a
cellular automaton runs on a *graph*, and a graph has no curvature:

| Ports unchanged | Why |
|---|---|
| `GeodesicSphere` topology, `GeodesicTopology` | adjacency lists |
| `GeodesicVentrellaState` / `Rule` / `Lifecycle` | pure graph CA |
| `GeodesicPentagonEngraving` | graph + BFS |
| `MazeCarver`, `MazeStyle`, `MazeTopology`, braiding | pure graph |
| `GeodesicReactivity`, `GeodesicCoarseMaze` | graph |
| the whole glider-search toolchain | graph |
| `Process` tree, fixed timestep, `Entity`, events | geometry-agnostic |

Swapping the frequency-11 icosahedral hex sphere for Margenstern's
ternary heptagrid `{7,3}` is **a different adjacency list**, not a
different program. Everything downstream keeps working. The rule itself
will need re-tuning for the heptagrid's 7 neighbours instead of the hex
sphere's 6 — that is a real research task, and this project has already
done exactly that research once (the multi-rule glider search), so the
method exists.

| Must be rebuilt | Size |
|---|---|
| `Space` + 4 implementations | small, and the replacement is smaller |
| `PlayerModel` position/facing | small |
| `Camera` | small |
| collision (`GeodesicCollision`, `GridCollision`, …) | **medium — the real work** |
| mesh building (vertex positions only) | medium, mechanical |
| `GeodesicLookup` (position → node) | medium |

The expensive *intellectual* work is all in the first table. The rebuild
is mostly mechanical, and much of it is code this project has already
rewritten once for good reasons.

## Rendering

Two viable approaches.

**Recommended: rasterise, with a Klein projection.** After applying the
κ-isometry, project through the Klein (projective) model, which maps
geodesics to straight lines — so triangles stay triangles and the
rasteriser's assumptions survive. The vertex shader becomes:

1. transform vertex by the κ-isometry (world → view)
2. Klein-project
3. ordinary perspective and viewport

That is a *small* shader, and it must be applied to every material in the
game.

**Alternative: ray-march.** Coulon, Matsumoto, Segerman and Trettel
([Ray-marching Thurston geometries](https://arxiv.org/pdf/2010.15801),
*Experimental Mathematics* 2022) give a complete, geometry-independent
framework covering all eight Thurston geometries including H²×ℝ, plus
quotients and orbifolds. It is more correct and far more flexible —
and much more expensive, and hostile to authored art assets. **Use it as
the reference for correctness, not as the shipping renderer**, unless the
world turns out to be mostly implicit surfaces.

### The gift in that paper

They adapt Phong lighting to non-euclidean geometry, and note that light
intensity depends on the **area density of geodesic spheres**. In
hyperbolic space that area grows *exponentially* — so physically correct
light falloff in the Sprawl is exponential rather than inverse-square.

**Darkness closes in exponentially, for real physical reasons, and that is
exactly the legibility law that space needed** ("see near, not far", see
[world-and-threads.md](world-and-threads.md)). The correct renderer and
the design intent produce the same image. Do not fake this; derive it.

## Engine decision: stay on Haxe + Heaps, rewrite the spatial core

Asked for an explicit argument, so here it is including the case against.

**For staying:**

1. **No engine gives you non-euclidean.** It is fully custom everywhere,
   so the usual "engine features" argument mostly does not apply.
2. **Large engines actively fight you.** Frustum culling, physics, LOD,
   shadow mapping, occlusion, navmesh — every one assumes Euclidean space,
   and every one becomes a system to disable and reimplement. A thin
   engine is an *asset* here. Hyperbolica shipped on Unity, so it is
   clearly possible; it is not evidence that the engine helped.
3. **HxSL is unusually well suited to this specific problem.** Heaps'
   shaders are composable fragments assembled and optimised at runtime,
   not monolithic programs. The non-euclidean vertex transform must be
   injected into *every* material in the game — which in HxSL is one
   fragment written once, and in a conventional engine is either editing
   every shader or writing a full custom render pipeline. This is the
   strongest technical argument and it is specific rather than
   sentimental.
4. **Production-proven.** Dead Cells, Northgard, Evoland — Shiro Games'
   entire stack.
5. **The simulation ports regardless**, so switching engines buys nothing
   on the largest existing asset while costing everything else.

**Against staying, honestly:**

1. **Tooling.** 8-15 hours of content and Heaps gives you no editor. This
   is the real cost.
2. **Small ecosystem** — sparse docs, small hiring pool, fewer answers
   when stuck.
3. **Console ports** are a weak story if that ever matters.
4. **Existing friction**, already recorded in the repo's own README: no
   HashLink JIT on Apple Silicon, so the fast local dev loop the
   guidelines describe still is not wired up.

**Resolution.** Stay, because the decisive work must be custom in any
engine and the thinnest engine fights you least. Mitigate the tooling
gap deliberately rather than by hoping: this world's content is
*mathematical and procedural* (tilings, rules, initial conditions), so it
needs **parameter tooling and in-game debug authoring**, not a level
editor — and that is a thing to budget explicitly in Phase 1, not
discover in Phase 3.

**Named revisit trigger** — revisit the engine if any of these become
true, and do not relitigate otherwise:

- After the vertical slice, **more than ~30% of development time is going
  into engine-level plumbing** rather than the game.
- Console release becomes a goal.
- A second full-time programmer joins, and Haxe is the reason hiring is
  hard.

Artists and composers are unaffected by this choice: an artist works in
Blender and exports, a composer works in a DAW. Neither touches Haxe.

## Migration plan

Ordered so the existential risk is answered first and nothing is rewritten
speculatively.

1. **`CurvedSpace` + `Isometry`, headless, with tests.** No rendering. Test
   against known identities: κ>0 reproduces the current sphere's numbers;
   κ=0 reproduces flat; κ<0 satisfies the hyperbolic law of cosines. This
   is pure math with an existing test culture — the strongest possible
   start, and cheap.
2. **The HxSL projection fragment**, and one bare `{7,3}` room to walk.
   **This is Phase 0 of the roadmap and the project's kill criterion** —
   see [roadmap.md](roadmap.md).
3. **Port collision** to the intrinsic metric.
4. **Port `GeodesicLookup`** (point → cell) into model coordinates.
5. **Re-tune the CA rule** for the heptagrid's 3 neighbours, reusing the
   existing multi-rule search harness.
6. **Then**, and only then, port the existing biomes forward.

Steps 1 and 2 are perhaps two months of work and they answer whether the
whole direction is viable. Nothing after step 2 should begin until step 2
has been *played*.

## A note on the existing test culture

This project has 38,000+ assertions and a blocking pre-commit hook. That
is unusually strong for a hobby game, and it is the main reason a rewrite
this deep is proposable at all: **the geometry is testable without a
renderer.** Hyperbolic trigonometry has closed-form identities; the CA has
known patterns; parallel transport has invariants. Nearly everything in
the migration plan above can be verified headlessly, which is exactly the
kind of change this repo is already equipped to make safely.
