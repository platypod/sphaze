# Bug tracker

Known bugs not yet fixed. When one gets fixed: remove it from here and add an
entry to `docs/CHANGELOG.md` (date, one-line description, fixing commit).

## Open

### `Space.rightOf` is named for the opposite of the side it returns

`biomes.common.space.common.Space.rightOf` returns `forward × up`, the
standard right-handed "right" — but Heaps' camera is left-handed
(`s3d.camera.rightHanded == false`), so the screen's right is the
*negative* of it. `game.GameLoop` negates at the strafe site to
compensate, and every space now has to return a vector matching that
inverted convention in order for the one negation to keep working —
including `hyperbolic.HyperbolicSpace`, which has no ambient cross
product to take and therefore negates a vector that was already
screen-right, purely to satisfy the convention.

Not fixed with the change that surfaced it (2026-08-16, adding
`turn`/`rightOf` to `Space` for the Sprawl), because flipping the sign
would also flip `entities.player.Camera.applyTo`'s pitch axis and so
which way `PlayerModel.lookUp` tilts in every existing biome — a
behaviour change across the whole game, in service of a naming
cleanup, in the middle of unrelated work.

**Fix:** flip `AmbientFrame.rightOf` and `HyperbolicSpace.rightOf` to
return screen-right, drop `GameLoop`'s negation, and negate the pitch
axis inside `Camera.applyTo` instead. Then walk each biome and confirm
strafe and look-up are both unchanged — this is the kind of sign that
every existing test passes straight through, so it needs eyes.
