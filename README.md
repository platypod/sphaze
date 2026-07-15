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

Not implemented yet — the `Makefile` (`fmt`/`lint`/`check`/`test`/`build`
targets) and `.githooks/pre-commit` hook described in
[`docs/GUIDELINES.md` §5](docs/GUIDELINES.md#5-tooling--workflow) land with
the first real code.

## Deployment

The game is a static web build (Heaps → JS/WebGL), deployed as a service in
platypod's `stack` `games` module (alongside `pokeclicker`, `rommapp`),
behind Authelia SSO like the rest of the homelab.

### Release build (settled)

Pushing a git tag triggers a GitHub Actions workflow that builds a multi-arch
image (`linux/amd64` + `linux/arm64`, via Docker Buildx) and pushes it to
`ghcr.io/platypod/sphaze:<tag>`. The image itself is lightweight: Heaps' web
output is static files (`index.html` + `game.js` + `res/`), served by a
minimal static file server (nginx or Caddy) with no language runtime in the
shipped image. No cluster credentials are involved in this step.

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

## Backlog / ideas

Not implemented yet — parked here until we get to them.

- A `docs/philosophy.md` capturing the game's design philosophy/intent, so
  future decisions (mine or Claude's) can be checked against it.
- **"Mark now, see later" mechanic**: let the player leave marks on the
  ground (e.g. an arrow at a path junction pointing back the way they came).
  A mark isn't legible up close — it only becomes readable once the player
  is far enough away to see it and its surroundings from across the sphere,
  letting them retrace their route (or deduce a better one) from the
  opposite side. Unproven idea — worth prototyping before committing to it.
- **Scouting mechanic**: send something off in a direction — a rolling ball,
  a burst of colored gas, whatever reads well — to reveal a bit of the path
  ahead before the player commits to walking it themselves.
- **Mobile controls** (see `docs/GUIDELINES.md` §1.8): deliberately
  undesigned until there's a playable desktop version to adapt from.
