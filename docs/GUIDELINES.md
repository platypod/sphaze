# Guidelines — full detail

This is the detailed reference behind `CLAUDE.md`. `CLAUDE.md` states the rules; this document explains why, and gives enough specifics to apply them consistently. See `docs/PROJECT_LOG.md` for how we got here and for anything decided after this document was last updated.

## 1. Architecture

### 1.1 Game loop
Fixed timestep: an accumulator collects real elapsed time each frame and drains it in fixed-size steps (e.g. 1/60s), so gameplay/physics update at a constant rate regardless of render frame rate. Rendering interpolates between the last two simulation states for smooth visuals even if the simulation step is coarser than the render rate. Implemented as a wrapper around Heaps' `hxd.App.update(dt:Float)`. Chosen to keep the door open for deterministic behavior (multiplayer sync, replays) without a later rewrite — variable timestep is easy to get subtly wrong for this later since gameplay code tends to accumulate frame-rate-dependent assumptions.

### 1.2 Object model: hybrid Entity + components
- `Entity` is the base class for anything that exists in the game world (player, enemies, items, projectiles...).
- Behavior/state is split into small, composable data pieces attached to an `Entity` (e.g. `Health`, `Movement`, `Inventory`) rather than expressed through deep subclassing.
- This is *not* a full ECS: there's no global component registry, no system scheduler iterating archetypes. Components are just data owned by their entity; logic that operates on a component lives near it (either as a method on the component, or in a clearly-named function/class operating on that entity+component).
- Rationale: full ECS (e.g. `echoes`) is more scalable for large numbers of varied entities but adds real conceptual overhead and an external dependency. Pure inheritance (classic `Entity` subclassing, à la Deepnight's `gameBase`) is faster to start but is where AI-assisted edits tend to drift — new behavior gets bolted onto whichever subclass is nearest rather than a well-defined place. The hybrid keeps things simple while still giving each change a clear, bounded home.
- When adding new behavior: ask "is this data belonging to an entity, or a one-off need?" If it's data other entities might also need, make it a component. If it's truly one-off, a subclass method is fine.

### 1.3 Foundation: custom Process/Entity tree
Rather than adopting Deepnight's `gameBase`/`deepnightLibs` (proven in *Dead Cells*, but built around pure-inheritance `Entity`), we roll a small custom equivalent:
- A `Process` class handling `update`/`fixedUpdate`/pause, arranged in a parent-child tree (root → game states → entities/systems). Pausing a parent pauses its children.
- An `Entity` class (see 1.2) that is itself a `Process`.
- Keep this foundation minimal — it should be fully readable in one sitting. If it starts growing significantly beyond update/pause/parent-child propagation, that's a signal to stop and reconsider rather than let it sprawl.

### 1.4 Data-driven content
Gameplay data — enemy stats, item definitions, level layouts, anything that's "content" rather than "logic" — is defined in external data (JSON files under `res/data/`, loaded via `hxd.Res`) rather than hardcoded into Haxe classes. Code should read and interpret this data, not embed it. This keeps content iteration (balance tweaks, new items, new maze layouts) separate from logic changes, which matters generally but especially for vibe-coding: content edits shouldn't need to touch — or risk breaking — logic files.

Practical notes to settle as they come up (not yet decided, revisit when the first real content type is added):
- Exact schema/validation approach (hand-rolled parsing vs. a schema library).
- Where the line is between "data" (goes in JSON) and "logic" (stays in code) for anything with embedded behavior (e.g. a maze mark's "on reveal" effect).

### 1.5 Game states & entity states: finite state machines
Top-level flow (Boot → Menu → Playing → Paused → GameOver, etc.) and per-entity behavior modes (player idle/walk/look) are both modeled as explicit FSMs — a fixed set of named states, one active at a time, explicit enter/update/exit per state. Avoid boolean flags (`isPaused`, `isLooking`) accumulating in update logic; that's the classic source of state-interaction bugs and is hard for an AI-assisted edit to reason about safely. An FSM also constrains *where* new behavior for a given state is allowed to go.

### 1.6 Event-driven decoupling
Systems that need to react to something happening elsewhere (player reveals a mark → update UI, play sound) subscribe to an event/signal rather than being called directly by the system that caused the event. Keeps systems independently testable and stops cross-references from tangling as features get added.

### 1.7 Object pooling
Apply only where profiling (or obvious high-frequency spawn/destroy) shows it's needed. Don't pool speculatively — it adds complexity that's wasted if the object type isn't actually a hot path.

### 1.8 Mobile input — deferred by design
The game targets both desktop and phone browsers (see §6), but 3D games are normally played with mouse-look + WASD, neither of which exists on a touchscreen. Decision: **build for mouse/keyboard first; treat touch controls as a later iteration**, not a day-one architecture decision — designing a control scheme (virtual joystick, drag-to-look, tap/swipe gestures) before there's a game to control would be guessing. When it's time to address this, it's a gameplay/UX design pass (candidates: on-screen virtual joystick + drag-to-look, or redesigning interaction around simpler touch gestures given the maze's "look across the sphere" mechanic might not need full free-look at all) — revisit and log the decision in `docs/PROJECT_LOG.md` when it happens, and update this section.

## 2. Haxe language standards

### 2.1 Naming & formatting
- `lowerCamelCase`: variables, properties, methods.
- `UpperCamelCase`: types (classes, enums, typedefs), enum constructors.
- Modifier order: `public static function`, `public static var` (not `static public`).
- K&R brace style (opening brace on the same line), enforced via `haxe-formatter`.
- Function names should be self-documenting but not padded (`shootEnemy()`, not `shoot()` or `performEnemyShootingAction()`).

### 2.2 Typing
Explicit type annotations required on all public/exported function signatures (parameters + return type) — this is the contract other code (and the AI, and you) can check against without reading the implementation. Local variables may use inference freely; don't add noise annotating obvious locals.

### 2.3 Null safety
`Strict` null safety, enabled project-wide (via `--macro nullSafety(...)` covering the project's packages, or `@:nullSafety(Strict)` per-class as a fallback if a specific interop boundary needs it). Every new class should be null-safety clean before being considered done. This is deliberately stricter than the Haxe default (`Loose`) because a meaningful fraction of the codebase will be AI-written, and null safety catches a class of bug an AI won't reliably reason about on its own.

### 2.4 Static analyzer
`-D analyzer-optimize` stays enabled globally. Disable per-type/field with `@:analyzer(no_module)` only if it's demonstrably causing a problem (e.g. with something timing-sensitive) — not preemptively.

### 2.5 Macros
No new custom macros without discussing it first — raise it explicitly rather than writing one inline. Heaps' own macros (`hxd.Res` resource generation, etc.) are fine to rely on as-is. Reasoning: macro code is compile-time metaprogramming, which is unusually hard to review quickly (bugs can be confusing, and a human skimming a diff can easily miss what a macro actually generates) — exactly the kind of thing that benefits from a deliberate human decision rather than an autonomous one.

### 2.6 Comments
Comment *why*, not *what* — comments restating the code rot as the code changes. One addition for this project specifically: if a change intentionally deviates from a rule in `CLAUDE.md`/this document (e.g. "not pooling this, it's rare"), say so in a comment, so a future edit doesn't "helpfully" revert it.

## 3. Heaps specifics

### 3.1 Project layout
```
project/
├── res/
│   ├── data/        # JSON gameplay data (see 1.4)
│   ├── models/       # FBX source + baked .hmd
│   ├── sprites/, sound/, ...
├── src/
│   ├── Main.hx
│   ├── game/         # Process tree, Entity, states
│   ├── entities/      # entity subclasses + components
│   ├── data/          # data-loading/parsing code
│   └── ui/
├── build.hxml (+ per-target hxml, see §6.1)
├── Makefile           # fmt/lint/check/test/build targets, see §5
├── .githooks/         # versioned pre-commit hook, see §5.2
└── .vscode/
```
Subject to revision once real code exists — treat as a starting point, not dogma.

### 3.2 `hxd.Res`
All assets go under `res/`; Heaps generates typed fields at compile time (`hxd.Res.sprites.player_png`), so never reference assets by raw string path — that defeats the whole point (compile-time safety against typos/missing files). Watch for name collisions: same name + different extension gets suffixed (`base.png` + `base.json` → `base_png` / `base_json`); paired formats merge (`font.fnt` + `font.png` → just `font`).

### 3.3 Scene graph
`h3d.scene.Object` = transform-only container, `h3d.scene.Mesh` = drawable base, `h3d.scene.Scene` = root. Prefer composing through the scene graph (parenting, local transforms) over manual matrix math. Keep the tree reasonably flat — don't parent high-count objects to a moving parent if it's not needed, since that's matrix-update cost for no benefit.

### 3.4 Materials
PBR (color, roughness, metalness) is Heaps' default. Worth noting: Heaps has no built-in physics engine or XR support — there's no "batteries included" story beyond the material system itself, so those are on us to build or do without. For now, Heaps' PBR defaults are treated as sufficient for a small, non-physics-heavy game.

### 3.5 3D model pipeline (FBX → HMD)
- Export FBX 2010/7.x (binary or text) from your DCC tool. Heaps' glTF importer is explicitly a **prototype** (partial mesh/skeletal-animation support) — FBX is the supported path, not glTF, despite glTF being the modern standard elsewhere (Babylon, Three.js, Blender's default export).
- One Skin per object — merge meshes (with multiple materials if needed) rather than sharing a Skin across objects.
- Blender: set "FBX Units Scale" under Apply Scaling, and Simplify = 0 under Animation, when exporting — avoids armature scale bugs and animation jitter.
- Animation playback: `h3d.prim.ModelCache` → `loadLibrary()` / `loadModel()` / `loadAnimation()` → `obj.playAnimation()`.

## 4. Git workflow & commit conventions

### 4.1 Commit every change
Every modification gets its own commit — small and atomic, one logical change per commit. This is what makes history actually useful for tracing a regression or rolling back a single change, rather than a handful of giant commits that mix unrelated things. Especially important here since a lot of changes will be AI-authored: a granular history is what makes "what did that last edit actually do" answerable by reading `git log`/`git diff`, not by re-deriving it.

### 4.2 Commit message format — inferred from the platypod org
Inspected commit history across `platypod/stack`, `platypod/mediarvester`, and `platypod/prompt-meter`, plus the org's own README, which states: *"Ideally, please follow the Conventional Commits standards"* with the example `git commit -m '<type>[optional scope]: <description>'`. The actual commit history confirms this is really followed, not just aspirational. Examples pulled directly from the org:

```
feat(grafana): add node filter and tooltip.mode multi everywhere it's relevant
fix(youtube): don't record a total per-item failure as a done download
feat(homepage, dashy): restructure homepage and add dashy to compare
refactor(enable): rename all isEnabled, enabled, enable to enable
doc(md): update README, TODO and Claude
release(0.1.0): release first prototype
```

Rules, as actually practiced (not just the spec):
- **Format:** `type(scope): description`. Scope is required in practice even though the spec marks it optional.
- **Types observed:** `feat`, `fix`, `refactor` (once misspelled `refacto` — treat that as a typo, not a variant), `doc`, `release`. Standard Conventional Commits types not yet observed but consistent with the pattern (`chore`, `test`, `ci`, `build`, `perf`) are fine to use as needed.
- **One deliberate deviation from the spec:** the org uses `doc`, singular — not the spec's `docs`. Match the org's actual usage, not the spec, since the goal is consistency with the rest of platypod.
- **Scope:** a module/system/feature name; can be a comma-separated list when a commit spans several (`feat(homepage, dashy): ...`, `fix(rommapp, jellyseerr, readarr, mediarvester): ...`).
- **Description:** lowercase, no trailing period, reads as imperative or plainly descriptive (`add`, `fix`, `gate new videos by follow date, not download history`, `don't record a total per-item failure as a done download`).
- **Body (optional, for anything non-obvious):** free-form prose paragraph(s), wrapped at a reasonable width, `backticks` around code/flags/paths, explaining *why* rather than restating the diff. Example, from `platypod/prompt-meter`:
  > The Claude Code SessionEnd hook now runs a plain `prompt-meter … --detach`
  > instead of `nohup &` / `start /b` + redirect, so it works regardless of the
  > shell Claude Code uses (esp. on Windows). ...
- **`release(x.y.z): ...`** marks version-bump commits, paired with a matching git tag (`vX.Y.Z`).
- **Not codified as a rule, but seen once:** a `wip - feat(...): ...` prefix for an exploratory/checkpoint commit. Treat as an occasional exception for genuinely unfinished work, not a pattern to lean on.

### 4.3 AI co-authorship trailer
No `Co-Authored-By: Claude ...` trailer on commits, even when Claude authors or materially contributes. `platypod/prompt-meter` does use one (e.g. `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`), but this repo deliberately deviates from that — a call hooman made explicitly, not an oversight.

## 5. Tooling & workflow

### 5.1 Makefile — the org's convention
Every platypod repo drives quality gates and builds through a self-documented `Makefile` (`## comment` after each target, `make help` as the default goal) rather than a task runner or framework — no repo in the org uses `pre-commit`/`husky`/`lefthook`. We follow the same shape:

```makefile
.DEFAULT_GOAL := help

fmt:      ## Format all source (haxe-formatter)
lint:     ## Lint (haxe-checkstyle)
check:    ## Compile check (haxe build.hxml)
test:     ## Run the utest suite
build:    ## Production web build (see §6.1)

help:     ## Show this help
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'
```
CI (§ see repo's `.github/workflows/ci.yml` once set up) calls these same targets — never a separately-maintained set of commands, so local and CI checks can't drift apart.

### 5.2 Pre-commit hook
Versioned at `.githooks/pre-commit` (not the unversioned `.git/hooks/`), wired once per clone via:
```sh
git config core.hooksPath .githooks
```
The hook runs `make fmt lint check test` and blocks the commit on any failure — format+lint+compile-check+tests, matching what CI verifies. `git commit --no-verify` remains the standard escape hatch for genuinely exceptional cases; it shouldn't become routine.

### 5.3 Formatting & linting
- **Formatting:** `haxe-formatter`, run on save / via `make fmt`.
- **Linting:** `haxe-checkstyle`, ruleset tuned together as it comes up (not blind defaults).

### 5.4 Testing
`utest`. Coverage target is game logic — state machines (1.5), inventory/interaction logic, save/load, data parsing (1.4) — not rendering/scene code, which isn't practically unit-testable.

### 5.5 CI
GitHub Actions, hand-written (no off-the-shelf Haxe+Heaps template exists). On every push: install Haxe, `make check` (compile), `make test`. Treat a red run as blocking, same as any other project. See §6.3 for the release/deploy workflow.

### 5.6 Verification loop for AI-assisted changes
After any non-trivial change — compile clean, format + lint, run relevant tests — before treating a task as finished. Review diffs before committing; if a change touches files beyond what was asked, that's a signal to pause and check the prompt/task boundary rather than accept it silently.

## 6. Web build & deployment

### 6.1 Compiling to the browser
Heaps compiles straight to JS/WebGL — no third-party engine wrapper needed. Minimal `web.hxml`:
```
-cp src
-main Main
-lib heaps
-js bin/game.js
```
Paired with an `index.html` containing a `<canvas id="webgl">`; Heaps' own reference template already includes mobile-friendly viewport meta tags (`width=device-width`, `user-scalable=no`, etc.) out of the box, which is a good starting point rather than something to invent from scratch.

**Target choice — WebGL, not WebGPU:** WebGPU is still fragmented on mobile (iOS only got it with iOS 26/macOS Tahoe 26, Android needs recent Qualcomm/ARM GPUs on Chrome 121+), while WebGL2 has been ubiquitous on phone browsers for years. Heaps' HTML5 target uses WebGL, which is precisely the reach this project needs.

**Local dev:** the HashLink target remains useful for fast iteration/debugging even though the shipped build is JS — faster compiles, native debugging, no browser round-trip. Keep both `.hxml` files (`hl.hxml` for dev, `web.hxml` for the shipped build) rather than developing directly against the JS target.

### 6.2 Container & platypod stack integration
platypod's `stack` repo already has a `games` module (`src/games/`, currently `pokeclicker` and `rommapp`) with a consistent Helm pattern we'll follow: a `Deployment` + `Service` + Traefik `IngressRoute`, gated by `.Values.<service>.enable`, image pulled from `ghcr.io/platypod/<name>`.

Unlike `pokeclicker` (which wraps a Node.js app and runs `npm start`), our container is much lighter: the Heaps web build output (`index.html` + `game.js` + `res/`) is static, so the runtime image is just those files served by a minimal static file server (nginx or Caddy) — no language runtime needed at all in the final image. A multi-stage `Dockerfile` (stage 1: Haxe + haxelib + heaps, run `make build`; stage 2: copy `bin/` into `nginx:alpine` or `caddy:alpine`) keeps the shipped image small.

Traefik itself doesn't change: it's a reverse proxy/router, not a web or file server, so it can't host the static files directly (a deliberate scope choice in Traefik's design, unlike e.g. Caddy which does both). It routes to our pod exactly like it already routes to every other service in the module — the static server container is what runs behind that routing, same shape as `pokeclicker`/`rommapp`, not an addition to the ingress layer.

**Access control:** the game sits behind Authelia SSO, same as every other service in the `games` module — reachable only by authenticated platypod accounts, consistent with the rest of the homelab rather than a public exception.

### 6.3 Release & deploy process
Matches the org's existing pattern for `mediarvester`/`prompt-meter`: pushing a git tag triggers a GitHub Actions workflow that builds a multi-arch (`linux/amd64` + `linux/arm64`) image via Docker Buildx and pushes it to `ghcr.io/platypod/sphaze:<tag>` (+ `:latest`). No cluster credentials are involved in this step.

**Deploying that image to prod is intentionally left open** — see `README.md` for the deploy-automation options under consideration (manual `make deploy MODULE=games ENV=prd`, a GitOps/Flux pull-based setup, or a scoped webhook receiver) and why "store a kubeconfig in GitHub Actions secrets" was ruled out. Revisit and log the decision here once made.
