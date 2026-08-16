# Project guideline — sphaze

A 3D maze wrapped onto the inside of a sphere: the player walks the interior surface, and can raise their head to see clear across to the far side — but not what's in their immediate vicinity. Built in Haxe + Heaps, primarily vibe-coded (Claude does most of the writing, hooman directs and reviews).

This file holds the non-negotiables — the "what". Everything else lives
under [`docs/`](docs/README.md), which is sorted by how much it binds you:

- **[`docs/game/`](docs/game/README.md) — what this game *is*.** Read
  [`docs/game/README.md`](docs/game/README.md) first if you are new, and
  [`docs/game/world.md`](docs/game/world.md) before touching any biome.
- **[`docs/rules/`](docs/rules/philosophy.md) — what must be respected**:
  the design pillars, the full engineering guidelines (this file is their
  short version), and the spatial architecture.
- **[`docs/building/`](docs/building/development.md)** — setup, roadmap,
  engineering notes.
- **[`docs/open/`](docs/open/ideas-backlog.md)** — the ideas backlog and
  the bug tracker. Nothing there is decided.
- **[`docs/archive/`](docs/archive/project-log.md)** — history: the
  project log, the decision records, the changelog. Read only to answer
  "why is it like this".

## Architecture

- Fixed timestep simulation (accumulator around `hxd.App.update`), decoupled from rendering. Never make gameplay logic depend on frame rate.
- Object model: `Entity` base class + composable data components (`Health`, `Movement`, `Inventory`, etc.). No full ECS library/scheduler.
- Foundation is a custom, minimal `Process` tree (update/pause/fixed-step propagation) — not an external base library. Keep it small and understood.
- Gameplay data (stats, item defs, level layouts) lives in external data (JSON / `hxd.Res`), not hardcoded in classes. Code reads data; it doesn't embed it.
- Game/UI flow and any per-entity behavior modes use explicit state machines, not boolean-flag soup.
- Systems communicate through events/signals, not direct cross-references.
- Object pooling only where profiling shows it's needed (bullets, particles, high-frequency spawns) — don't pool by default.
- Mobile input (touch controls) is a later iteration, not a day-one architecture decision — build for mouse/keyboard first (see `docs/rules/guidelines.md` §1.8).

## Haxe code standards

- `lowerCamelCase` for variables/methods, `UpperCamelCase` for types **and enum constructors** (`PoleNode`, not `poleNode`). `public static function`, not `static public function`. K&R braces.
- Explicit type annotations on all public/exported function signatures. Local variables may rely on inference.
- **Null safety: `Strict`, project-wide.** Every new class/module must be null-safety clean.
- `-D analyzer-optimize` stays on.
- **No new custom macros without discussing it first.** Use Heaps' built-in macros (`hxd.Res`, etc.) otherwise.
- Comment *why*, not *what*. If you deviate from a rule in this file on purpose, say so in a comment so it isn't "fixed" back later.

## Heaps specifics

- Assets only ever referenced through `hxd.Res` — never raw string paths.
- Prefer the scene graph (`h3d.scene.Object`/`Mesh`) for transforms/composition over manual matrix math.
- FBX exports: FBX 2010/7.x, one Skin per object (merge meshes if needed), Blender exports need "FBX Units Scale" + Simplify=0 on animation.
- Web build target is JS/WebGL (`-js`), not WebGPU — WebGPU is still too fragmented on mobile browsers, while WebGL2 is ubiquitous. HashLink remains useful for fast local dev/debugging even though the shipped build is JS.

## Git workflow

- **Every change gets committed** — small, atomic commits, so anything can be traced or rolled back individually. Don't batch unrelated changes into one commit.
- **Commit messages follow platypod's house style** (Conventional Commits, matching every other repo in the org):
  `type(scope): short lowercase description` — no trailing period, description imperative/descriptive ("add", "fix", "gate new videos by...").
  Types actually in use across the org: `feat`, `fix`, `refactor`, `doc` (singular, not `docs`), `chore`, `release`. Scope is whatever's most useful — a module/system name, or a comma-separated list if several are touched (`feat(homepage, dashy): ...`).
- For anything non-obvious, add a body explaining *why*, wrapped like prose, `backticks` for code/flags/paths.
- **When Claude authors or materially contributes to a commit, do not add a trailer:** `Co-Authored-By: Claude <model> <noreply@anthropic.com>`.

## Design & bug tracking

- New feature/mechanic ideas that aren't being implemented right now go in
  `docs/open/ideas-backlog.md` — check them against
  `docs/rules/philosophy.md` first; an idea that cuts against a
  pillar is a reason to raise it explicitly rather than add it silently.
  Design decisions (chosen + rejected alternatives + why) are recorded in
  `docs/archive/decisions.md`.
- A bug found but not fixed immediately goes in `docs/open/bug-tracker.md`.
- When a bug gets fixed: remove its entry from `docs/open/bug-tracker.md` and add
  one to `docs/archive/changelog.md` (date, one-line description, fixing commit).

## Workflow / verification loop

Before considering any non-trivial change done:
1. Compile (`haxe build.hxml`) clean.
2. Run the formatter (`haxe-formatter`) and linter (`haxe-checkstyle`).
3. Run the `utest` suite — covers game logic (state machines, combat/inventory math, save/load, data parsing), not rendering/scene code.
4. CI runs the same compile + test suite on every push (GitHub Actions) — treat a red CI run as blocking.

**Pre-commit hook (local, blocking):** `.githooks/pre-commit` (wired via `git config core.hooksPath .githooks`) runs `make fmt lint check test` before every commit — the same targets CI runs. A failing pre-commit blocks the commit; use `git commit --no-verify` only for genuinely exceptional cases.

When touching multiple files or anything architectural, check `docs/rules/guidelines.md` first — don't improvise a pattern that contradicts it. If a task seems to require breaking one of the rules above (especially the macro rule), stop and ask rather than proceeding.

## Manual/interactive verification

Claude cannot reliably drive the game itself in this project's browser preview: keyboard input (movement, turning, jump) does not consistently reach the canvas in that automated environment, so "walk over there and check" attempts burn time without producing a trustworthy result (hooman, directly: "You are inefficient for those tasks"). When a change needs to be exercised interactively (movement, collision, triggers, camera/look behavior) rather than just observed from a fixed spawn/screenshot, ask hooman to drive it and report back, rather than attempting to reproduce it live. Static verification (compile, formatter, linter, `utest`, reading a screenshot from a fixed vantage point) remains fine to do directly.
