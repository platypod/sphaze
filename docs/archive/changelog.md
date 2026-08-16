# Changelog

Bugs that have been fixed, oldest first. When a bug in `docs/open/bug-tracker.md`
gets fixed, move its entry here and add the date and fixing commit.

Fixes that predate this file live only in git history
(`git log --grep='^fix'`) and in `docs/archive/project-log.md`'s narrative entries —
not backfilled here.

---

<!-- Add new entries below this line, oldest first. Format:

## YYYY-MM-DD — Short title

One-line description of the bug and the fix. Commit: `<hash>`.

-->

## 2026-08-10 — Camera could enter a wall's solitary end

Walking toward the dead end of a wall (no neighbouring segment) at the wrong
angle could still let the camera clip into it a little. Fixed as a side
effect of `GeodesicCollision`'s new distance-based wall clearance check
(`WALL_CLEARANCE`), which keeps the player away from a closed segment's own
thickness by point-to-segment distance — including near either endpoint, not
just along its middle. Commit: `1a713e9`.
