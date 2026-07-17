# sphaze

3D maze wrapped onto the interior surface of a sphere: raise your head and you
can see clear across to the far side, but not what's in your immediate
vicinity.

## Stack

Haxe + [Heaps](https://heaps.io/), compiling to WebGL for the browser (desktop
and mobile) with HashLink for fast local dev/debugging.

Coding standards, architecture decisions, and the git/commit workflow are in
[`CLAUDE.md`](CLAUDE.md) (short version) and
[`docs/GUIDELINES.md`](docs/GUIDELINES.md) (full detail + rationale).
[`docs/PROJECT_LOG.md`](docs/PROJECT_LOG.md) has the chronological history of
how the project got here, and is where new decisions get logged as the
project continues.

## Dev

```sh
haxelib install heaps utest formatter checkstyle  # once per machine
git config core.hooksPath .githooks                # once per clone

make help    # list targets
make check   # compile
make test    # run utest suite
make build   # production web build -> bin/ (self-contained static web root)
```

**HashLink caveat:** Homebrew's `hashlink` formula ships no `hl` (JIT VM) on
Apple Silicon — only HashLink/C native compilation is supported on ARM
([hashlink#557](https://github.com/HaxeFoundation/hashlink/issues/557)). The
"fast HL dev loop" `docs/GUIDELINES.md` §6.1 describes isn't wired up yet as a
result; `make check`/`make test`/`make build` all currently target JS (run via
`node` for tests), which needs no extra toolchain. See
`docs/PROJECT_LOG.md` for the full note.

## Deployment

The game is a static web build (Heaps → JS/WebGL), deployed as a service in
platypod's `stack` `games` module (alongside `pokeclicker`, `rommapp`),
behind Authelia SSO like the rest of the homelab.

### Release build (implemented)

Pushing a git tag triggers [`.github/workflows/build.yml`](.github/workflows/build.yml),
which builds a multi-arch image (`linux/amd64` + `linux/arm64`, via Docker
Buildx) and pushes it to `ghcr.io/platypod/sphaze:<tag>` (+ `:latest`).
[`Dockerfile`](Dockerfile) is a two-stage build — `haxe:4.3.7-alpine` compiles
`bin/` (matching `make build`'s output exactly), then `nginx:alpine` serves
it with no language runtime in the shipped image. Same pattern as
`mediarvester`/`prompt-meter`; no cluster credentials are involved in this
step.

**First tag only — make the GHCR package public.** GitHub creates new GHCR
packages as **private**. After the first tag push, set it public once:
`github.com/orgs/platypod/packages` → `sphaze` → *Package settings* →
*Danger Zone* → *Change visibility* → **Public**. Persists across all future
versions. There's no REST API for changing package visibility (a GitHub
limitation), so it's a one-time manual step — same as every other platypod
image.

Traefik doesn't change here — it's a reverse proxy/router, not a web or file
server, so it can't host the static files itself (that's a deliberate scope
choice in Traefik's design, unlike e.g. Caddy which can do both). It routes
to our pod exactly like it already routes to every other service in the
`games` module (`Deployment` + `Service` + `IngressRoute`, same pattern as
`pokeclicker`/`rommapp`); the nginx/Caddy container is just what runs *inside*
that pod to actually serve the files.

### Prod deploy (open — deliberately deferred)

Getting that new image actually running on prod is the part still undecided.
The constraint driving this: **no cluster credential should ever be stored in
GitHub**, even scoped/short-lived, because that's a credential capable of
touching prod sitting on a third party's infrastructure. Three ways to square
that with "deploy on release":

1. **Manual deploy (matches the org today).** CI stops at pushing the image to
   GHCR; deploying is `make deploy MODULE=games ENV=prd`, run locally with the
   kubeconfig already on your machine. This is what every other platypod repo
   does, and it's not a compromise — it's *already* credential-free, because
   GitHub Actions never touches the cluster at all in this flow. Zero new
   infrastructure. Downside: a manual step between "release tagged" and
   "live."

2. **GitOps (Flux CD) for genuine credential-free automation.** Run a
   controller *inside* the cluster that watches GHCR itself for new image
   tags and deploys them — the cluster pulls, GitHub never pushes, so there's
   nothing to leak on GitHub's side by construction. This is the standard
   answer to "auto-deploy without trusting a third party with prod access."
   The real cost: it's infrastructure work spanning the `stack`/`infra`
   repos (installing Flux, wiring `image-reflector-controller` +
   `image-automation-controller`), and a new standing service to maintain —
   not something to introduce as a side effect of shipping one game. Worth a
   dedicated conversation if/when auto-deploy actually matters.

3. **Small self-hosted webhook receiver.** A custom in-cluster service that
   GitHub pings on tag push, authenticated with a narrow shared secret that
   can only trigger "redeploy the games module" — nothing else. Smaller
   blast radius than a kubeconfig, less infrastructure than Flux, but it's
   bespoke code with its own maintenance burden.

**Current state: staying on option 1 (manual) until there's a real reason to
invest in 2 or 3.** Revisit this section and log the decision in
`docs/PROJECT_LOG.md` when that happens.

## Design, backlog & bug tracking

- [`docs/game-design.md`](docs/game-design.md) — design philosophy (what
  this game is trying to be, checked against before adding anything new)
  and the backlog of not-yet-implemented ideas.
- [`docs/bug-tracker.md`](docs/bug-tracker.md) — known bugs not yet fixed.
- [`docs/CHANGELOG.md`](docs/CHANGELOG.md) — bugs that have been fixed.