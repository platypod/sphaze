# sphaze
3D maze wrapped on the inside of a sphere — Babylon.js prototype

The player walks a maze skinned onto the interior surface of a sphere: raise
your head and you can see clear across to the far side, but not what's in
your immediate vicinity.

## Stack

TypeScript + [Vite](https://vite.dev) + [Babylon.js](https://www.babylonjs.com).
No deployment pipeline yet — local dev server only while this is still in
early prototyping.

## Dev

```sh
npm install
npm run dev        # start the dev server with HMR
npm run typecheck  # tsc --noEmit
npm run lint       # eslint .
npm run test       # vitest run
npm run build      # production build to dist/
```

Press `i` while the dev server is running to toggle the Babylon.js inspector.

## Backlog / ideas

Not implemented yet — parked here until we get to them.

- Add a `docs/` section.
- Within `docs/`, a `philosophy.md` capturing the game's design philosophy/intent,
  so future decisions (mine or Claude's) can be checked against it.
- **"Mark now, see later" mechanic**: let the player leave marks on the ground
  (e.g. an arrow at a path junction pointing back the way they came). A mark
  isn't legible up close — it only becomes readable once the player is far
  enough away to see it and its surroundings from across the sphere, letting
  them retrace their route (or deduce a better one) from the opposite side.
  Unproven idea — worth prototyping before committing to it.
- **Scouting mechanic**: send something off in a direction — a rolling ball,
  a burst of colored gas, whatever reads well — to reveal a bit of the path
  ahead before the player commits to walking it themselves.
