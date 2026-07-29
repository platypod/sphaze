# Design assets — how to make and retake them

Conventions live in [`../../game-design/README.md`](../../game-design/README.md);
this file is the *how*.

## Diagrams (the `.svg` files here)

Hand-drawn house style, authored as text so they diff and edit like code:

- Cream paper (`#f6efe0`) with a rounded rect behind everything. This isn't only
  a look — it guarantees the ink stays legible in both GitHub light and dark
  themes, where a bare black-stroke SVG disappears.
- Ink `#3b3226`, muted labels `#7a6c58`, one accent `#c9762a`, walls `#d8cbb0`,
  marks `#d1477f`.
- Handwriting stack: `"Bradley Hand", "Segoe Print", "Comic Sans MS",
  "Chalkboard SE", cursive`.
- **Strict horizontal bands**: art in the middle, text only in reserved margins
  at the top and bottom. The first attempt at the two-sided diagram put labels
  over the drawing and became unreadable — bands are the fix.
- `role="img"` and a real `aria-label` on the root `<svg>`, plus a `<title>`.

## Screenshots

There's a capture key in the game: **press `P`** and the current view downloads
as `sphaze-<biome>-<date>-<time>.png`. It fires inside the render frame, in
`Main.render` → `GameLoop.captureIfRequested`, rather than where the key is read.
That split is necessary, and measured rather than assumed: Heaps builds its
WebGL context without `preserveDrawingBuffer`, and a `toDataURL` taken outside
the frame comes back **entirely black** (checked on 2026-07-29 — the readback
sampled exactly one distinct colour, `0,0,0`).

**Not yet confirmed end to end.** The chain from keypress to a file on disk
couldn't be exercised from the automated browser preview: it doesn't deliver
keystrokes to the canvas reliably (see `CLAUDE.md`'s note on interactive
verification) and its downloads never reach the filesystem. The capture code
compiles and is wired in the right place; whether `P` actually drops a PNG in
your downloads folder wants one manual check in a real browser. If it doesn't,
the likely culprit is the download rather than the capture.

Workflow:

1. `make serve`, open the game, walk to the vantage you want (the game starts in
   the debug hub, so every biome is one portal away).
2. Press `P`. Move the file from your downloads into this folder, named
   `<biome>-<what-it-shows>.png`.
3. Reference it with alt text, and put the date + short commit in the caption.

**A screenshot older than the mechanic it illustrates is a bug.** Date every one,
and retake it when the mechanic changes.

### Wanted, and why

Captures worth having, with the vantage that makes each one legible. None of
these exist yet — this is the shot list.

| File | Biome | Vantage | Shows |
|---|---|---|---|
| `maze-across-the-sphere.png` | `maze` | stand anywhere, look up ~75° | the core hook: the far side laid out overhead |
| `maze-corridor.png` | `maze` | ground level in a corridor | the other half of the hook: near geometry tells you nothing |
| `wind-far.png` | `wind` | look up ~75°, hold still | the grass combing along the corridors |
| `wind-near.png` | `wind` | ground level | the constant downwind lean, at eye height |
| `two-sided-inside.png` | `two-sided` | inside face, look up | walls rising both ways off one shell |
| `two-sided-outside.png` | `two-sided` | outside face, at a jump's apex | the vantage a leap buys, and a mark post standing out of the ground |
| `exterior-horizon.png` | `exterior` | ground level, look up | nothing above the horizon: the hook inverted |
| `conway-tiles.png` | `conway` | look up ~60° | live cells as raised blocks across the sphere |
| `mobius-strip.png` | `mobius` | on the ribbon, looking along it | the twist, and the forest |
| `tower-shaft.png` | `tower` | top floor, look down | the stacked floors and the drop |
| `debug-hub.png` | `debug-hub` | spawn point | the dev room's ring of labelled portals |

The two-sided and wind ones matter most: both docs make claims about what those
biomes *look* like, and a claim about appearance should have the appearance next
to it. That's not decoration — on 2026-07-29 the wind biome's docs asserted the
grass field read as directional grain when it showed nothing at all, and it took
someone looking at the screen to catch it.
