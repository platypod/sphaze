# The mathematics

Every geometric idea the game actually uses, in one place: what it is,
why it is here, and where it lives in the code.

Nothing here is decorative. Each entry is load-bearing for at least one
space, one mechanic or one rendering decision, and the last column of
every table says which.

**Figures** are linked from Wikimedia Commons rather than redrawn, with
author and licence given beneath each. Following the caption link reaches
the source page and its full terms.

---

## 1. Curvature

The single axis the whole world is arranged along. Curvature κ measures
how a surface's geometry departs from the plane, and only its **sign**
matters for the game.

| κ | Circle of radius *r* has circumference | Triangle angles sum to | Growth of area | Spaces |
|---|---|---|---|---|
| **> 0** spherical | `2π sin r` — *less* than `2πr` | more than π | bounded, then shrinks | the Fold, the Weft |
| **= 0** flat | `2πr` exactly | exactly π | quadratic | the Repeat, the Turn, the Defect, the Ribbon |
| **< 0** hyperbolic | `2π sinh r` — *more* than `2πr` | less than π | **exponential** | the Sprawl, the Knot |

The exponential row is the one the game's premise rests on. See
[§6 Amenability](#6-amenability-and-the-garden-of-eden).

**In code:** `geometry.Curvature` is literally this table as an enum, and
`geometry.CurvedSpace` is one implementation parameterised by it —
`cosK`/`sinK` are generalised trigonometric functions that specialise to
`cos`/`sin`, `1`/`d`, and `cosh`/`sinh`. One code path, three geometries.

---

## 2. Models of the hyperbolic plane

The hyperbolic plane cannot be drawn faithfully on paper or embedded in
ordinary space (see [§3](#3-hilberts-theorem-why-the-sprawl-needed-new-code)),
so it is always *represented*. The game uses two representations for two
different jobs, and keeping them apart is the single most important
implementation fact in this document.

### The hyperboloid model — used for computing

Points are triples on the upper sheet of `⟨p,p⟩ = −1` under the Minkowski
form `⟨u,v⟩ = u₁v₁ + u₂v₂ − u₃v₃`.

[![Hyperboloid model](https://commons.wikimedia.org/wiki/Special:FilePath/HyperboloidProjection.png?width=420)](https://commons.wikimedia.org/wiki/File:HyperboloidProjection.png)

*The hyperboloid (top) and its projection to the disc below.*
[HyperboloidProjection.png](https://commons.wikimedia.org/wiki/File:HyperboloidProjection.png)
by Selfstudier, CC0.

Chosen because **isometries are plain matrix multiplications** and the
numerics stay well-behaved far from the origin — a disc model crowds
everything toward a rim and loses precision exactly where the interesting
distances are.

**In code:** `biomes.common.space.hyperbolic.HyperbolicSpace`,
`geometry.CurvedSpace`, `geometry.Isometry`.

### The Beltrami–Klein model — used for drawing

The whole plane compressed into a unit disc, with a point at distance *d*
landing at radius `tanh d`.

[![Klein model](https://commons.wikimedia.org/wiki/Special:FilePath/Klein_model.svg?width=300)](https://commons.wikimedia.org/wiki/File:Klein_model.svg)
[![{7,3} tiling in the Klein model](https://commons.wikimedia.org/wiki/Special:FilePath/Uniform_tiling_73-t1_klein.png?width=300)](https://commons.wikimedia.org/wiki/File:Uniform_tiling_73-t1_klein.png)

*Left: geodesics in the Klein model are straight chords.*
[Klein model.svg](https://commons.wikimedia.org/wiki/File:Klein_model.svg)
by Vladimir0987, CC BY-SA 3.0. *Right: a hyperbolic tiling drawn in it.*
[Uniform tiling 73-t1 klein.png](https://commons.wikimedia.org/wiki/File:Uniform_tiling_73-t1_klein.png)
by Tomruen, public domain.

Two properties earn it the job:

- **Geodesics map to straight lines.** A hyperbolic polygon projects to a
  Euclidean polygon, so an ordinary triangle rasteriser works unchanged.
  Poincaré would bend every wall into an arc.
- **Bearing at the viewer is exact**, which is what makes a first-person
  view read as first-person at all.

The cost is that distance compresses to `tanh`, so the entire infinite
plane piles up against the rim. That is not an artifact to fight — it *is*
the Sprawl's legibility law ("see near, not far"), arriving free from
correct mathematics.

**In code:** `geometry.HyperbolicProjection`.

---

## 3. Hilbert's theorem — why the Sprawl needed new code

**No complete surface of constant negative curvature can be isometrically
immersed in ℝ³.** There is no shape you can build that *is* the hyperbolic
plane.

Consequences, in order of how much they cost:

1. There is no mesh that is a hyperbolic floor, and no camera position
   that is the player. The camera is instead **pinned at the origin and
   the world transformed around it** every frame.
2. Ambient distance between two coordinate triples is meaningless;
   collision must use the intrinsic metric.

**What it does *not* forbid**, and this was got wrong once at real cost:
it forbids an isometric *embedding*, not a coordinate *model*. Three
floats can perfectly well be hyperboloid coordinates. The sphere had been
using the same trick all along — a unit 3-vector *is* the natural model of
S², not an embedding of it — which is why `HyperbolicSpace` needed no
change to the `Space` interface.

**In code:** `biomes.sprawl.SprawlBiome`, `biomes.knot.KnotBiome`.

---

## 4. Isometries, and the frame as a matrix

An isometry is a distance-preserving transformation. Every geometry here
stores one as a **3×3 matrix** over the model coordinates, and a player's
whole spatial state is the isometry taking the origin, facing +x, to where
they are and how they face.

| Operation | Is |
|---|---|
| walk forward by *d* | `compose(frame, translation(κ, d))` |
| turn by θ | `compose(frame, rotation(θ))` |
| where am I | `apply(frame, origin)` |

Two things fall out for free:

- **No coordinate singularities.** Latitude/longitude goes singular at the
  poles; a matrix has no coordinates to be singular in. This was found the
  hard way on the sphere, where the view "pivoted at mach-speed" walking
  through a pole, and the fix is structural here.
- **Only `translation` reads the curvature at all**, so one representation
  serves all three geometries.

Inversion is exact by group structure rather than by general matrix
inversion: `J·Mᵀ·J` with `J = diag(1, 1, σ)` for the sphere and hyperbolic
plane, and a separate case for flat space, where `J` is singular and that
identity says nothing.

**In code:** `geometry.Isometry`.

---

## 5. Quotients — one plane, many surfaces

A closed surface is not built, it is **quotiented**: take a plane, pick a
discrete group of isometries, and declare points in the same orbit to be
the same point. The group is called the *deck group*; the plane is the
*universal cover*.

The player never leaves the cover. Movement, collision and rendering all
happen unwrapped, where everything is ordinary. The quotient appears in
exactly two places — folding a position back so it cannot run to infinity,
and listing which copies of the world to draw.

[![Fundamental polygon of the torus](https://commons.wikimedia.org/wiki/Special:FilePath/Fundamental_polygon_of_the_torus.svg?width=260)](https://commons.wikimedia.org/wiki/File:Fundamental_polygon_of_the_torus.svg)
[![Torus from a rectangle](https://commons.wikimedia.org/wiki/Special:FilePath/Torus_from_rectangle.gif?width=260)](https://commons.wikimedia.org/wiki/File:Torus_from_rectangle.gif)
[![Fundamental polygon of the Klein bottle](https://commons.wikimedia.org/wiki/Special:FilePath/Fundamental_polygon_of_the_Klein_bottle.svg?width=260)](https://commons.wikimedia.org/wiki/File:Fundamental_polygon_of_the_Klein_bottle.svg)

*A square with edges identified becomes a torus; change one identification
and it becomes a Klein bottle instead.*
[Fundamental polygon of the torus.svg](https://commons.wikimedia.org/wiki/File:Fundamental_polygon_of_the_torus.svg)
by Stefan Birkner, svg by Actam, CC BY-SA 3.0 ·
[Torus from rectangle.gif](https://commons.wikimedia.org/wiki/File:Torus_from_rectangle.gif)
by Lucas Vieira, public domain ·
[Fundamental polygon of the Klein bottle.svg](https://commons.wikimedia.org/wiki/File:Fundamental_polygon_of_the_Klein_bottle.svg)
by Beao, CC BY-SA 3.0.

| Surface | Cover | Group | Space |
|---|---|---|---|
| flat torus | E² | two translations (a lattice) | — |
| Möbius band | E² | one **glide reflection** | the Turn |
| Klein bottle | E² | glide reflection + translation | — |
| genus-2 | H² | the octagon surface group | the Knot |

### Glide reflection, and orientability

A glide reflection reflects across a line and slides along it. It is
**orientation-reversing** — determinant −1 — which no product of
translations and rotations can be, and that is exactly why a
non-orientable surface needs one.

[![Glide reflection](https://commons.wikimedia.org/wiki/Special:FilePath/Glide_reflection.svg?width=300)](https://commons.wikimedia.org/wiki/File:Glide_reflection.svg)
[![Möbius strip](https://commons.wikimedia.org/wiki/Special:FilePath/Mobius_strip_animation_plain.gif?width=260)](https://commons.wikimedia.org/wiki/File:Mobius_strip_animation_plain.gif)

*Reflect, then slide — and the strip that results has one side and one
edge.*
[Glide reflection.svg](https://commons.wikimedia.org/wiki/File:Glide_reflection.svg)
by Kelvinsong, CC0 ·
[Mobius strip animation plain.gif](https://commons.wikimedia.org/wiki/File:Mobius_strip_animation_plain.gif)
by Lemondoge, CC0.

Worth knowing for the Turn specifically: **a Möbius band has one boundary
curve, not two**, of twice the band's own period. The two apparent rails
are one rail, which is what licenses painting its halves differently as a
readout of which lift the player is on.

The pictured strip is the *embedded* Möbius band, which is bent and
therefore curved. The game's Turn is the **flat** one — a strip of the
plane quotiented by a glide reflection, with the twist in the
identification rather than in the geometry. That distinction is the
difference between a κ = 0 space and a decoration.

### The genus-2 surface

A regular hyperbolic octagon whose interior angles are all `2π/8`, with
opposite sides identified. The angle condition is exactly what lets eight
octagons close up around a vertex, which collapses all eight of the
octagon's own vertices to a single point of the surface.

[![Genus two surface](https://commons.wikimedia.org/wiki/Special:FilePath/Genus_two_surface_with_symmetry_axis.png?width=320)](https://commons.wikimedia.org/wiki/File:Genus_two_surface_with_symmetry_axis.png)

*Two handles — hence two independent families of loop.*
[Genus two surface with symmetry axis.png](https://commons.wikimedia.org/wiki/File:Genus_two_surface_with_symmetry_axis.png)
by Schala163, CC0.

Euler then fixes the genus. One face, four edges (eight sides in pairs),
one vertex:

```
χ = V − E + F = 1 − 4 + 1 = −2        χ = 2 − 2g   ⟹   g = 2
```

**In code:** `geometry.DeckGroup`, `geometry.DeckGroups`.

---

## 6. Amenability, and the Garden of Eden

The theorem the whole premise rests on.

A **Garden of Eden** is a configuration of a cellular automaton with no
predecessor — a state the system can be in but can never have reached.

**Moore–Myhill:** a cellular automaton has a Garden of Eden **iff** it is
not pre-injective (two configurations differing in finitely many cells
have the same successor). The equivalence holds **iff the underlying group
is amenable** (Ceccherini-Silberstein, Machì and Scarabotti; converse by
Bartholdi).

Amenability is, informally, whether a space's boundary can be made
negligible against its interior. Flat and spherical groups are amenable;
hyperbolic ones contain free subgroups and are **not**.

| | amenable (κ ≥ 0) | non-amenable (κ < 0) |
|---|---|---|
| Boundary vs interior | boundary is negligible | boundary is as large as the interior |
| Every state accountable backwards? | yes, up to an erasure | **no** |
| What this means in the fiction | to be uncaused, something must have been erased | you may simply have no past |

That table is the game. The player begins somewhere everything can be
accounted for, and walks toward somewhere it cannot.

**A correction worth keeping**, because getting it wrong would have made
the whole design dishonest: Gardens of Eden **do** exist in flat space —
orphan patterns in Conway's Life on ℤ² have been known since 1971. The
premise is *not* "uncaused existence only happens in negative curvature".
It is that in an amenable world, being uncaused requires an erasure
somewhere; in a non-amenable one, it requires nothing.

---

## 7. Cellular automata

### Life-like rules on a tiling

The Fold runs a four-state rule on the hex/pentagon faces of a geodesic
sphere. A **glider** is a pattern that returns to its own shape displaced
— it travels.

[![Game of Life glider](https://commons.wikimedia.org/wiki/Special:FilePath/Game_of_life_glider.svg?width=180)](https://commons.wikimedia.org/wiki/File:Game_of_life_glider.svg)

*The canonical glider: five cells that walk.*
[Game of life glider.svg](https://commons.wikimedia.org/wiki/File:Game_of_life_glider.svg)
by Bryan.burgers, public domain.

This is where the game's oldest pillar becomes a theorem rather than a
preference: **a glider is only a glider from a distance.** Up close it is
five meaningless cells. "See far, not near" is a fact about patterns, not
a camera trick.

### Elementary automata, and Rule 110

One dimension, two states, three-cell neighbourhoods — 256 rules, numbered
by which of the eight neighbourhoods survive.

**Rule 110 is Turing-complete** (Cook, 2004). It is the strongest
available evidence that a cellular world is *really a computation*, and
the Ribbon is built so a player can walk on that evidence.

[![Rule 110 spacetime diagram](https://commons.wikimedia.org/wiki/Special:FilePath/Sample_run_of_Rule_110_elementary_cellular_automaton,_starting_from_single_cell.png?width=420)](https://commons.wikimedia.org/wiki/File:Sample_run_of_Rule_110_elementary_cellular_automaton,_starting_from_single_cell.png)

*Time runs downward from a single live cell. The Ribbon lays this out as
terrain and lets the player walk **up** it, into the past.*
[Sample run of Rule 110…png](https://commons.wikimedia.org/wiki/File:Sample_run_of_Rule_110_elementary_cellular_automaton,_starting_from_single_cell.png)
by LucasVB, CC0.

Because an elementary automaton's entire history is two-dimensional, "the
past is terrain" is expressible *as terrain* — which is true of no other
automaton in the game.

**In code:** `biomes.ribbon.RibbonAutomaton`, `tools.geodesic.*`.

---

## 8. Holonomy and concentrated curvature

Carry a direction around a closed loop, keeping it as parallel as the
surface allows, and it may come back **rotated**. The rotation is the
*holonomy* of the loop, and it equals the curvature enclosed.

Two consequences the game uses directly:

- **Parallel transport is path-dependent.** Which way you went matters.
- **Curvature can be concentrated.** It need not be spread evenly; it can
  live entirely at isolated points.

A **cone point** is exactly that: flat absolutely everywhere except one
spot, where a wedge of angle δ has been removed and the edges glued. Walk
a loop enclosing it and you return turned by δ; walk one that does not,
and nothing happens.

[![Angular defect on a polyhedron](https://commons.wikimedia.org/wiki/Special:FilePath/Polydera_with_positive_defects_convex.svg?width=300)](https://commons.wikimedia.org/wiki/File:Polydera_with_positive_defects_convex.svg)

*Angles around a polyhedron's vertex summing to less than 2π — the missing
wedge is the defect.*
[Polydera with positive defects convex.svg](https://commons.wikimedia.org/wiki/File:Polydera_with_positive_defects_convex.svg)
by Mangledorf, public domain.

**Descartes' theorem:** the defects of a convex polyhedron sum to 4π. This
is why the geodesic sphere has **exactly twelve pentagons**, and why the
Defect is designed to pay that off retroactively: the sockets on the
player's home world are the same object as the puzzle in that space.

The cone is also, unlike the hyperbolic plane, *isometrically embeddable*
— you can roll it out of paper. The game deliberately does not, because
this space's whole point is that nothing **looks** bent.

**In code:** `biomes.defect.DefectModel`, `tools.geodesic.*`.

---

## 9. Gauss–Bonnet

Total curvature is a topological invariant:

```
∫∫ K dA + ∮ k_g ds = 2π·χ
```

Used twice, both times as a *check* rather than as content:

- A regular hyperbolic octagon with all angles `2π/8` has area
  `6π − 8·(2π/8) = 4π`. Since a hyperbolic disc of radius *R* has area
  `2π(cosh R − 1)`, the Knot should show about `(cosh R − 1)/2` octagons
  within *R* — which is how the genus-2 group is verified numerically.
- Descartes' `4π` above is the polyhedral case, and it is what forces the
  twelve pentagons.

---

## 10. Tilings

Regular tilings are written `{p,q}`: p-gons, q meeting at each vertex.
They are spherical, flat or hyperbolic according to `(p−2)(q−2)` against 4.

| Tiling | `(p−2)(q−2)` | Geometry | Used for |
|---|---|---|---|
| `{6,3}` | 4 | flat | the hex reference case |
| `{7,3}` | 5 | hyperbolic | the Sprawl's floor |
| `{8,8}` | 36 | hyperbolic | the Knot's fundamental octagon |

[![{7,3} tiling in the Poincaré disc](https://commons.wikimedia.org/wiki/Special:FilePath/Uniform_tiling_73-t0.png?width=340)](https://commons.wikimedia.org/wiki/File:Uniform_tiling_73-t0.png)

*Heptagons, three to a vertex. Every tile is the same size; the shrinking
is the projection.*
[Uniform tiling 73-t0.png](https://commons.wikimedia.org/wiki/File:Uniform_tiling_73-t0.png)
by Tomruen, CC BY-SA 3.0.

The number that matters for gameplay: in `{7,3}` each ring of cells grows
by roughly **φ² ≈ 2.618** times the last. A cell is inherently about one
curvature radius across, so a neighbouring cell already sits four fifths
of the way to the horizon. Nothing has to be authored to make the Sprawl
illegible at distance — the tiling does it.

A regular polygon's radii, which the code needs constantly:

```
cosh(inradius)     = cos(π/p) / sin(π/q)
cosh(circumradius) = cot(π/p) · cot(π/q)
```

**In code:** `geometry.HyperbolicTiling`.

---

## 11. Product geometries

The game's spaces are **surface × height**: S²×ℝ, E²×ℝ, H²×ℝ. Three of
Thurston's eight geometries, though the game uses them for a duller reason
than that pedigree suggests — height is simply a Euclidean factor bolted
onto a curved surface.

The practical consequence is worth stating because it looks like a bug
otherwise: "up" is **not** expressible in the surface coordinates.
`HyperbolicSpace.upAt` returns a render-space constant, and that is
correct rather than a shortcut. Jumping, falling and eye height all behave
completely normally in every space, including the hyperbolic ones.

---

## Where each idea is used

| Idea | Spaces |
|---|---|
| Curvature sign | all — it *is* the world map |
| Hyperboloid + Klein models | the Sprawl, the Knot |
| Hilbert's theorem | the Sprawl, the Knot |
| Isometries as frames | all |
| Quotients / deck groups | the Turn, the Knot |
| Glide reflection | the Turn |
| Amenability, Garden of Eden | the premise; paid off in the Sprawl and the endings |
| Life-like automata | the Fold, the Weft |
| Rule 110 | the Ribbon |
| Holonomy, cone points | the Defect; retroactively the Fold |
| Gauss–Bonnet, Descartes | the Fold's twelve pentagons; verifying the Knot |
| Regular tilings | the Sprawl `{7,3}`, the Knot `{8,8}` |
| Product geometries | all |
