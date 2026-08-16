# Development & build tooling

The unbegotten build system is a self-documented `Makefile`. Run `make help` to see all targets and their descriptions.

## Prerequisites

- **Haxe** (tested with 4.3.x+)
- **Node.js** (for running JS/WebGL game + test suite)
- **neko** (lightweight VM for one-off tools like `bake` and `search`)

All are installed via Homebrew on macOS; see your platform's Haxe docs for other OS setups.

## Main targets

### `make fmt` / `make fmt-check`

Format Haxe source with `haxe-formatter`, or check without modifying.

- **When**: Before every commit (the pre-commit hook runs this automatically).
- **CI**: `fmt-check` runs on every push; red CI blocks merge.

### `make lint`

Lint Haxe code with `haxe-checkstyle` (ruleset in `checkstyle.json`).

- **When**: Before every commit (pre-commit hook).
- **CI**: Runs on every push.
- **If it fails**: Usually a violation of the conventions in [CLAUDE.md](../../CLAUDE.md) or `checkstyle.json`. Read the error and fix the source.

### `make check`

Compile check via `haxe build.hxml` (no output, just verify syntax/types).

- **When**: Before every commit (pre-commit hook). Before interactive testing if you've made major changes.
- **CI**: Runs on every push.
- **If it fails**: A type error or missing dependency. `haxe build.hxml` output will say where.

### `make test`

Run the utest suite (unit tests for game logic: state machines, combat/inventory math, save/load, data parsing).

- **When**: Before every commit (pre-commit hook). Anytime you refactor core systems.
- **CI**: Runs on every push; red CI blocks merge.
- **Scope**: Does NOT test rendering, scene graph, or interactive gameplay (keyboard/collision). Those require manual verification in the real game.

### `make build`

Production web build: compile `build.hxml`, copy `index.html` into `bin/`, producing a self-contained static web root ready to deploy.

- **When**: Before deploying to production or creating a release artifact.
- **Output**: `bin/` becomes a static site (HTML + JS + assets).

### `make serve`

Build, then serve `bin/` at `http://localhost:8080` (Ctrl+C to stop).

- **When**: Quick sanity check before deployment. Verifies the built artifact runs.
- **Note**: For development, use `make build` once, then point your editor's built-in server/preview at `bin/`.

## One-off tools

These are neko-compiled exploratory scripts, not part of the regular build.

### `make bake-geodesic`

Regenerate the baked geodesic sphere data asset (`res/geodesic/`).

- **Input**: The geodesic sphere generation code (`src/tools/geodesic/GeodesicSphere.hx`, `GeodesicLifeState.hx`, etc.).
- **Output**: `res/geodesic/sphere_f10.json` (frequency-10 sphere neighbor topology, baked once, used by the game at runtime).
- **When**: Only when you change the sphere generation logic. Otherwise, this asset is stable.
- **How it works**:
  - Compiles `tools.geodesic.GeodesicBake` (main entry point) to neko bytecode (`bin/bake.n`).
  - Runs `neko bin/bake.n`, which constructs a geodesic sphere, writes its topology to JSON.
  - Game loads that JSON at startup and uses it for all hexagonal-grid queries.

### `make search-gliders`

Run an exhaustive multi-rule glider search across hexagonal CA rulesets.

- **Input**: The geodesic sphere (already baked) and three cellular automata rules:
  - `B2/S34`: Current baseline (birth at 2 neighbors, survive at 3-4).
  - `B24/S46`: Alternative candidate (birth at 2,4; survive at 4,6). Documented to produce period-8 gliders with multi-unit movement.
  - `B35/S2`: Alternative candidate (birth at 3,5; survive at 2). Well-studied in hex-CA research.
- **Output**: A text report listing, per rule:
  - Number of 2-ring candidate patterns screened (16k+ total for populations 3-5).
  - Number of patterns that show periodic motion (screened positive).
  - Number of patterns confirmed as actual travelers (not bounded shuttles).
  - List of confirmed travelers with their cell populations and drift rates.
- **When**: When exploring whether alternative rulesets produce richer spaceship fauna than B2/S34h.
- **How it works**:
  - Compiles `tools.geodesic.GeodesicGliderSearchMultiRule` to neko bytecode.
  - Runs `neko bin/search.n`, which:
    - Generates a frequency-10 geodesic sphere.
    - Extracts a 2-ring patch (center + neighbors' neighbors, up to 19 cells).
    - Enumerates all subsets with populations 3–5 (~524k candidates per rule).
    - For each candidate under each rule:
      - **Screens** it (40 generations of CA). Flags if it shows periodic motion with drift ≥ 0.01 units.
      - **Confirms** positive hits (2000 generations). Measures whether centroid keeps trending away (traveler) or bounces back (shuttle).
    - Prints summary: how many screened, confirmed, and their drift rates.
  - Runtime: ~5–10 minutes total (all three rules), depending on machine and confirmation hit rate.
- **Example output**:
  ```
  Rule B2/S34: 1234 candidates → 45 screened → 12 confirmed travelers
    [B2/S34] pop=3 drift=0.042/step cells=[45,67,89]
    [B2/S34] pop=4 drift=0.031/step cells=[45,67,89,92]
  Rule B24/S46: 1234 candidates → 67 screened → 18 confirmed travelers
    ...
  ```

## CI pipeline

GitHub Actions (`.github/workflows/`) runs on every push:

1. **Compile check** (`make check`): Verify Haxe syntax and type safety.
2. **Format check** (`make fmt-check`): Reject any unformatted code.
3. **Linting** (`make lint`): Enforce style conventions.
4. **Tests** (`make test`): Run utest suite, reject if any test fails.

All four must pass before a PR can merge. Use `git commit --no-verify` only for genuinely exceptional cases (and explain why in the commit message or PR).

## Build configuration files

### `build.hxml`

Main game build: Haxe→JavaScript (WebGL2), `-D analyzer-optimize` for dead-code elimination, null-safety strict, resource preprocessing.

### `test.hxml`

Test build: Same dependencies as `build.hxml`, but entry point is `Main` (not `Main` in game — actually `test.hxml` specifies `-main test.Test` or similar; check the file). Outputs `bin/test.js`.

### `search.hxml`

Search tool build: Compiles `tools.geodesic.GeodesicGliderSearchMultiRule` to neko bytecode.

### `bake.hxml`

Bake tool build: Compiles `tools.geodesic.GeodesicBake` to neko bytecode.

## Troubleshooting

### `make check` fails: "Module not found" or "Type X not found"

- Verify you haven't introduced a circular import or a typo in a class name.
- Check that any new file follows the package/path naming convention: `src/path/to/ClassName.hx` → `package path.to;` at the top.
- Rebuild from scratch: `rm -rf bin/ && haxe build.hxml`.

### `make lint` fails with a style violation

- Read the error message — it names the file and line.
- Check [CLAUDE.md](../../CLAUDE.md) §2 (Haxe code standards) to see if the violation is intentional.
- If unintentional, fix it. If intentional (e.g., you deviated to solve a specific problem), add a comment explaining why (per CLAUDE.md).
- Run `make fmt` to auto-fix formatting issues.

### `make test` fails: "Assertion error in Test_X"

- Read the assertion failure message — it usually names the failing value.
- Add a `trace()` or examine the test code to understand what went wrong.
- Unit tests cover game logic (math, state machines, data parsing), not rendering or interaction. If the failure looks like it needs interactive verification, check [CLAUDE.md](../../CLAUDE.md)'s "Manual/interactive verification" section.

### `make build` fails: Large file or memory error

- Haxe can be memory-intensive on large projects. Try increasing heap: `haxe -D analyzer-optimize -jar haxelib.jar build build.hxml` (or set `HAXE_STD_PATH` / `HAXELIBPATH` env vars).
- Or run `make check` first to verify the code is syntactically correct, then try `make build` again.

### `make search-gliders` is slow or doesn't output anything for a long time

- The search is CPU-bound. 16k+ candidates × 3 rules = ~1–2 million CA generations minimum.
- Neko is interpreted bytecode, not JIT. Expect 5–15 minutes on modern hardware.
- If it's been >20 minutes with no output lines, check if the process is actually running: `ps aux | grep neko`.
- If it's hung, Ctrl+C and check if there's a syntax error in the search code: `haxe search.hxml` (compile check without running).

## Further reading

- [CLAUDE.md](../../CLAUDE.md): Project guidelines, architecture, coding standards, workflow/verification.
- [rules/guidelines.md](../rules/guidelines.md): Detailed design principles and rationale for each architectural choice.
- [docs/README.md](../README.md): the whole documentation map, sorted by how much it binds you.
