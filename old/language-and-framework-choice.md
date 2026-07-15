# Tech Stack Decision: Browser-Playable 3D Game

**Date:** July 2026
**Status:** Decided — building with Haxe + Heaps, Rust + Bevy as fallback

## Goal

A small 3D game, built for the love of it, playable in a browser on any OS
and on mobile phones. Started in TypeScript + Babylon.js; wanted to move
away from TypeScript toward "a proper language" without giving up a
pleasant, low-drama path to shipping something people can actually play.

## Starting point: why not just stay in TypeScript?

Not fond of the language. Open to alternatives as long as the result can
still run in a browser. First instinct was OCaml, prompting a review of
whether OCaml is still relevant at all.

**OCaml today:** niche but real. ~200+ verified industrial users (Jane
Street, Meta, Microsoft, Docker, Bloomberg, Citrix, Tarides, OCamlPro,
Tezos), concentrated in finance, infra, and academia — domains where
compiler-enforced correctness pays for itself. Tooling (Dune, Merlin,
opam with 10,000+ packages) has matured a lot. Not mainstream (TIOBE
~#32), but stable and not going anywhere.

## Round 1: OCaml-to-browser options

- **js_of_ocaml** — compiles OCaml bytecode to JS, has WebGL bindings.
  Works, but "compiling to JS" felt like it could only be a worse version
  of the original language/runtime.
- **wasm_of_ocaml** — same OCaml, targets WebAssembly instead of JS text.
  Near drop-in replacement for js_of_ocaml, generally faster, still
  compatible with jsoo's web/JS bindings (so Babylon is still callable).
- **Melange** — compiles OCaml to small, readable JS with strong JS
  interop ergonomics; no ready-made Babylon bindings exist, so you'd
  write your own thin `external` glue.

Key correction made here: "translating to JS" (js_of_ocaml, Melange,
Fable, TypeScript itself) and "compiling to WebAssembly" are not the same
kind of translation. Wasm is a real near-native binary target, not "JS
with extra steps."

## Round 2: widening the net — F# + Fable, and Rust + a native renderer

Three contenders emerged: **Melange**, **F# + Fable**, **Rust + a
Rust-native renderer**.

- **F# + Fable** — ML-family language, compiles to clean JS, mature
  10+ year old toolchain. The existing Babylon binding package
  (`Fable.Import.Babylonjs`) is stale (last updated 2019); realistic path
  is regenerating bindings from Babylon's current `.d.ts` via `ts2fable`,
  or hand-writing dynamic interop with `Fable.Core.JsInterop`.
- **Rust** — mature Wasm toolchain (`wasm-bindgen`), but direct
  Babylon.js/Three.js bindings are thin, unmaintained side projects.
  The solid path in Rust isn't "wrap Babylon," it's "use a Rust-native
  renderer" (Bevy, or raw wgpu) instead — a bigger architectural swing.

### Decision indicators used (Melange vs Fable vs Rust+Bevy)

| Indicator | Melange | F# + Fable | Rust + Bevy |
|---|---|---|---|
| Keeps Babylon investment | Yes | Yes | No — different renderer |
| Binding freshness | None off-the-shelf | Stale (2019) | N/A, no JS bindings needed |
| Output target | JS | JS | WebAssembly |
| "Real OCaml" | Yes | No (F#) | No (Rust) |
| Ecosystem maturity | Small, niche | Mature (.NET tooling) | Fast-moving, pre-1.0 |
| Debugging | jsoo-family source maps; Melange lacks them | Mature JS source maps | Rust panics via wasm-bindgen, no JS devtools stepping |
| Long-term risk if unmaintained | Low (Babylon does the work) | Low | Medium (you own the render pipeline) |

## Deep dive: WebAssembly

What it is: a binary instruction format browsers run in a sandboxed,
near-native-speed VM alongside JS; you compile to it, you don't write it
directly.

What it brings (2026): WasmGC shipped in Chrome/Firefox/Safari, fixed
SIMD widely supported, threading standardized but requires
cross-origin-isolation headers.

Where it hurts for this project: no reliable multithreading without
server config; WebGPU (which Bevy leans on) is fragmented on mobile —
Safari only got it with iOS 26/macOS Tahoe 26, Android needs Chrome 121+
on recent Qualcomm/ARM GPUs, in-app browsers (WebView/WKWebView) don't
ship it by default at all. Debugging is one step removed from familiar
JS devtools.

## Deep dive: Bevy and alternatives

**Bevy** — most capable, most popular Rust engine, ECS architecture,
WebGPU with WebGL2 fallback, largest community. Still **pre-1.0** as of
0.19 (June 2026): breaking API changes every release, maintainers
describe upgrades as "stressful until 1.0." Open, unresolved issues
around touch input on Wasm/mobile (misaligned coordinates, UI buttons
not registering, Android touch events not firing in some setups).
Community's own framing: shipping to mobile is "possible, but not easy."

Alternatives considered:
- **Fyrox** — closest to a full 3D engine with a visual editor.
- **Macroquad** — fastest path to "something on screen," thinner feature
  set, better for jams than a real game.
- **ggez** — 2D only, not relevant here.
- **godot-rust** — Rust as the language, Godot's mature engine, editor,
  and (importantly) Godot's proven export pipeline for web/mobile/desktop.

## Babylon vs Bevy: maturity, mobile reach, "will I hit walls"

**Babylon.js** — Microsoft-backed, batteries included (physics, XR,
asset pipelines, visual editor), WebGPU production-ready since v5 with
automatic WebGL2 fallback everywhere else. Runs on essentially any modern
phone browser today because WebGL2 has been ubiquitous for years.

**Bevy** — exciting, improving fast, but not yet the low-risk choice for
"any phone, any OS." WebGPU mobile fragmentation means you'd lean on
WebGL2 fallback for mobile reach anyway; open touch-input bugs on
mobile/Wasm; pre-1.0 breaking changes.

**Conclusion at this stage:** the tension was real — Rust is
appealing as a language, but "pleasant and sure, reaches any phone" was
Babylon's strength, not Bevy's, at the time.

## Round 3: non-JS-family languages with Babylon integration

Explicitly ruled out JS/TS and "the likes." Surveyed:

| Language | Existing Babylon bindings | Maintained today | Static types | Effort to start |
|---|---|---|---|---|
| **Haxe** | Yes, versioned externs on Haxelib | Yes | Yes | Low |
| Melange (OCaml) | No | — | Yes | Medium (write your own) |
| Scala.js | Yes, but dated (Scala 2.11-era) | No | Yes | Medium–high (rewrite likely) |
| Kotlin/JS | No | — | Yes | Medium–high, on Kotlin's least-invested target |
| Fable (F#) | Yes, but stale (2019) | No | Yes | Medium (regenerate via ts2fable) |
| ClojureScript | No (raw interop only, no facade needed) | — | No | Low, but no type safety |

**Haxe** stood out as the one language where someone had already done
the tedious part: `babylon`/`babylonjs` externs on Haxelib are versioned
to track Babylon's own releases.

## Deep dive: Haxe

- Started 2005 by Nicolas Cannasse (successor to his ActionScript tooling
  MTASC), Haxe 1.0 in 2006, macro system added 2011. Cannasse still leads
  the project.
- Real algebraic sum types, pattern matching, strong inference, structural
  typing, generics, and a genuine compile-time macro/AST system.
- Multi-target compiler: JS, C++, C#, Java/JVM, Python, Lua, and its own
  bytecode VM (HashLink) — same codebase can ship to web *and* native.
- ~20 years old, stable, Haxe Foundation backed partly by Docler Holding.
  Niche job market concentrated in gamedev studios and interactive
  agencies, notably strong demand in Latin America. Smaller community and
  learning-resource base than Rust or TS, but not going anywhere.

### Two Haxe paths for Babylon-style 3D

1. **Haxe + Babylon.js externs** — full-featured JS engine (physics, XR,
   PBR) via maintained typed bindings.
2. **Haxe + Heaps** — a 2D/3D engine written *natively* in Haxe (no JS
   library wrapped) by Shiro Games (Dead Cells, Northgard, Evoland,
   Darksburg). Compiles straight to HTML5/**WebGL** (not WebGPU — avoids
   Bevy's mobile fragmentation problem) and to native
   Windows/macOS/Linux/Android/console from the same codebase.

## Haxe+Babylon vs Haxe+Heaps: where's the catch

No prior write-up comparing these two directly exists — this is a niche
enough crossover that the research had to be stitched together from
Heaps' own docs, its GitHub wiki, and community threads.

**Catches found on the Heaps side:**

- Nearly every famous Heaps game (Dead Cells, Northgard, Evoland) is 2D.
  The one confirmed shipped 3D title is **Darksburg** (Shiro Games, 2020,
  isometric co-op) — real proof the 3D module (`h3d`) works and ships,
  but a single, stylized data point rather than a deep track record.
- **No batteries included**: no built-in physics, no built-in XR/PBR
  material system the way Babylon has them. Heaps' own community frames
  this explicitly — you invent the mechanics other engines already ship.
- **Asset pipeline is FBX-first**; the glTF importer is explicitly
  labeled **prototype** (partial mesh/skeletal-animation support only),
  while glTF is the modern standard everywhere else (Babylon, Three.js,
  Blender's default export).
- **Documentation is uneven** (some call it "1st rate," others
  "lackluster") and clearly written by/for the core devs first, giving it
  a real learning-curve bump for newcomers.
- **Small community**, centered on Discord/Gitter and heavily tied to
  Shiro Games — some bus-factor risk, mitigated by ~10+ years of
  continuous open-source maintenance already.

**Opinion formed:** for a small, for-the-love-of-it 3D game (not
physics-heavy, not asset-pipeline-heavy), Heaps' missing pieces are
proportional costs, not blockers — FBX export from Blender is a
well-documented path even without glTF, and a small game may not need a
full physics engine at all. In exchange, Heaps delivers the thing that
actually motivated this whole search: writing real code against a real
engine in a real language, rather than annotating someone else's JS
object model — plus the same reliable mobile-browser reach as Babylon
(WebGL2, not WebGPU). The recommendation would flip toward
Haxe+Babylon if the project later needs real physics, PBR materials, or
XR out of the box.

## Decision

**Building with Haxe + Heaps.**
**Fallback: Rust + Bevy**, to reconsider if Heaps' rough edges (missing
physics, prototype glTF import, thin docs, small community) become a
real blocker rather than a manageable cost.

## Reference links

- OCaml: [Industrial Users](https://ocaml.org/industrial-users) · [Platform Roadmap](https://ocaml.org/tools/platform-roadmap)
- js_of_ocaml / wasm_of_ocaml: [js_of_ocaml](https://github.com/ocsigen/js_of_ocaml) · [wasm_of_ocaml](https://github.com/ocaml-wasm/wasm_of_ocaml) · [Tarides intro](https://tarides.com/blog/2023-11-01-webassembly-support-for-ocaml-introducing-wasm-of-ocaml/)
- Melange: [melange.re](https://melange.re/v1.0.0/melange-for-x-developers/)
- Fable: [Fable.Import.Babylonjs](https://www.nuget.org/packages/Fable.Import.Babylonjs/)
- WebAssembly: [State of WebAssembly 2025–2026](https://platform.uno/blog/the-state-of-webassembly-2025-2026/) · [Feature status](https://webassembly.org/features/)
- Bevy: [Bevy 0.19 release notes](https://bevy.org/news/bevy-0-19/) · [Production readiness discussion](https://github.com/bevyengine/bevy/discussions/21911) · [Touch input issue](https://github.com/bevyengine/bevy/issues/10694)
- Rust engines comparison: [Bevy vs Macroquad vs ggez vs Fyrox 2026](https://aarambhdevhub.medium.com/rust-game-engines-in-2026-bevy-vs-macroquad-vs-ggez-vs-fyrox-which-one-should-you-actually-use-9bf93669e83f)
- Babylon.js: [vs Three.js production comparison](https://dev.to/devin-rosario/babylonjs-vs-threejs-the-360deg-technical-comparison-for-production-workloads-2fn6)
- Other languages: [Scala.js Babylon facade](https://github.com/cyberthinkers/babylonjs-facade) · [Kotlin for Web — JetBrains](https://blog.jetbrains.com/kotlin/2025/05/present-and-future-kotlin-for-web/) · [ClojureScript + Babylon demo](https://forum.babylonjs.com/t/3d-character-controller-demo-clojurescript-babylonjs-odoyle-rules/44027)
- Haxe: [History](https://haxe.org/manual/introduction-haxe-history.html) · [haxe-babylon externs](https://github.com/firefalcom/haxe-babylon)
- Heaps: [heaps.io](https://heaps.io/) · [H3D docs](https://heaps.io/documentation/h3d.html) · [Unofficial FAQ](https://gist.github.com/Yanrishatum/ae3725a9e2b45e0766c065e573ed1f24) · [glTF prototype thread](https://community.heaps.io/t/prototype-gltf-importer-and-convex-hull-collision-detection/676) · [Shiro Games stack](https://haxe.org/blog/shirogames-stack/) · [Darksburg on Steam](https://store.steampowered.com/app/939100/Darksburg/)
