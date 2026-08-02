# AGENTS.md — Vanihala (Godot 4.6 + C++ DOD GDExtension)

## What this project is
Vanihala is a **Kenshi-like sandbox RPG** with a **Victoria 3-style simulated economy** and a **4X macro layer**, rendered in a **Tiny Glade-like 2.5D diorama style** (soft pastel, orthographic miniature look — NOT hard cel-shading, NOT pixel-art-on-3D), set on a world generated with **geographically-accurate-planet-simulator-level realism** (tectonic plates, continental drift, climate-driven biomes). The game must **run on potato hardware**; performance is the backbone of every design decision.

Core pillars, in priority order:
1. **2.5D render settled first** — Tiny Glade look (soft shading, pastel, diorama framing, tilt-shift optional).
2. **Geographic realism** — the world is generated like a real planet: tectonic plates → continental drift → boundary-driven mountains → temperature/precipitation → biomes, in C++ DOD, deterministic from seed, one-shot at world creation. (Reference: Devote Games' "Geographically Accurate Planet Simulator" — GAPS — ported to a flat map with horizontal wrap-around: X = longitude, seamless — no hard edges; Y = latitude with poles at top/bottom.)
3. **Performance on a potato** — low internal resolution + upscale, streaming, tight budgets, whole-world generation < 1–2 s.
4. **C++ with data-oriented design (DOD)** — the simulation core is pure C++ SoA code, benchmarkable headless.
5. **Procedural everything** — biggest map possible via seeded generation + streaming + delta saves (fixed seed).

## Architecture: three layers
The game is three simulations at different scales. Never blur them.

| Layer | Scope | Tick rate | Where it lives |
|---|---|---|---|
| **4X macro** | Whole world: terrain base (plates, elevation, climate, biome), provinces, factions, diplomacy, trade routes | 1 Hz + event-driven | C++ sim, few tens of MB of data |
| **Zone sim** | Player's active zone: squads, agents, combat, buildings | 10–20 Hz movement, 1–4 Hz AI decisions | C++ sim, SoA arrays |
| **Presentation** | Rendering, camera, input, UI, audio | 60 fps | Godot 4.6 (GDExtension) |

Key principle: the macro layer covers the entire world cheaply as pure data (generated once from the seed, then frozen); only the player's active zone is materialized as 3D. This is how a huge map runs on weak hardware.

## Repository layout
- `docs/` — project docs. `docs/study_plan.md` is the mastery plan (concepts + exercises + acceptance checks) for all roadmap phases — consult it when working on any phase.
- `project.godot` — Godot 4.6, Forward Plus, Jolt Physics, 1920×1080. Will be reworked for low internal res + FSR upscale.
- `scenes/` — main scene is `scenes/levels/mini_main.tscn` (NOTE: `main.tscn` referenced in older docs does not exist).
- `systems/` — GDScript systems (`camera_system/camera_rig.gd`, `readme_node/` is junk).
- `addons/` — reusable plugins: `3d_rts_camera/` (orbit camera to adapt for 2.5D ortho), `compositor_effects/` (30+ compute-based post-process effects — keep the framework, keep only cheap effects in the default stack).
- `assets/shaders/` — `cel_shader.gdshader` + `.gdshaderinc` (to be given a "soft pastel" mode), `foliage_cel_shader.gdshader` (billboard MultiMesh foliage — the cheap path, keep), `outlines.gdshader` (probably NOT part of the Tiny Glade look — keep around, default off).
- `CppSrc/` — **ALL C++ lives here** (`sim/` + `bind/` + `bench/`), the only C++ in the project.

## Build system
- Native C++ builds via **SCons** in the external repo `godot_test_gdextension` (hardcoded in `Makefile`). Never run `scons` inside this repo.
- **Target structure for `CppSrc/` (Phases 2–4 of roadmap):**
  - `CppSrc/sim/` — pure C++ DOD static lib, **zero Godot dependencies**. Contains `sim/worldgen/` (the geographic generation module — the heart of the project).
  - `CppSrc/bind/` — thin GDExtension binding layer (sim ⇄ Godot).
  - `CppSrc/bench/` — CLI benchmark/test harness, runs headless without Godot; also dumps PPM maps so generation can be eyeballed without a GPU.
- The compiled `.so` lands in `bin/linux/libManalooka00.linux.template_debug.x86_64.so` (`bin/` is a real dir, gitignored).

## Roadmap
2. **Phase 1 — Settle the 2.5D Tiny Glade render**: ortho camera (adapt RTS camera), soft pastel material mode, one tight 2048 directional cascade, foliage MultiMesh, default post stack = color grade + vignette only, tilt-shift DoF as optional toggle, "glade" test diorama scene, freeze the look in `docs/phase1_look.md`. Full concepts + exercises in `docs/study_plan.md` (Phase 1).
3. **Phase 2 — Performance backbone (C++ DOD core)**: restructure `CppSrc/` into `sim/` + `bind/` + `bench/`, SoA foundations (no allocation in hot paths), job system with lock-free SPSC queues to Godot main thread, fixed-timestep tick model with double-buffered snapshots, **Tracy profiler** on both sides. NOTE: only **2.1 (the sim/bind/bench skeleton)** gates Phase 3 — worldgen is pure C++, headless, and can be built the moment the skeleton exists.
4. **Phase 3 — Geographic world generation (`sim/worldgen`)**: the GAPS pipeline in C++ DOD on a **flat, seamlessly wrapped map** — seeded fBm/ridged noise, Voronoi tectonic plates, one-shot continental drift (`age` = drift steps is a world parameter), boundary-classified elevation (C+C mountains / C+O subduction / O+O island arcs / divergent rifts), fractal ridge blending, temperature (latitude + altitude lapse) + precipitation → Whittaker-style biomes, cheap budgeted hydraulic erosion (rivers for free). Horizontal wrap-around (equirectangular): X = longitude wraps modulo width, Y = latitude with poles at top/bottom — no hard edges anywhere; drift/BFS/distance fields use wrap-aware neighbor lookups. Whole world (2048×1024 coarse cells, one cell = one future 64×64 chunk) generated in < 1–2 s on a potato, bit-identical determinism, ~20 MB. Bench `--dump` writes PPM maps: realism is verified headless, before any Godot work.
5. **Phase 4 — Terrain streaming in Godot (first integrated DOD feature)**: chunk sampler reads the frozen worldgen data (coarse base + fine seeded octaves + biome/foliage masks → chunk-local float32), dirty-chunk mesh rebuild → Godot ArrayMesh, streaming around camera (jobs + SPSC from Phase 2, wrap-aware: chunks near the seam also spawn their wrapped duplicate), foliage placement from sim, delta persistence (save = seed + age + params + edits; world re-derived from seed).
6. **Deferred** (only after foundation is settled): macro gameplay layer on top of the worldgen data (provinces/factions drawn from biome + plate-boundary data) → procedural buildings (path → wall → masonry → roof) → Vic3 economy (aggregated pop groups, dirty-flag market ticks) → 4X layer → Kenshi local sim (staggered AI 1–4 Hz, hierarchical pathfinding) → UI → SIMD/polish passes.

## Performance contracts (aspirational, to be validated in Phases 3–4)
- Frame ≤ 16.6 ms at 60 fps; render ≤ 8 ms GPU at low internal res (960×540/1280×720) + FSR upscale to 1080p.
- Sim tick ≤ 2 ms on worker threads; empty-world tick < 1 ms.
- **Worldgen:** whole world (2048×1024) ≤ 1–2 s on a 4-core potato, headless; same seed + params → bit-identical world; coarse world ≤ ~25 MB; chunk sample < 1 ms; erosion pass ≤ 20% of generation time.
- Save format: seed + params + deltas; streaming radius keeps memory < ~512 MB.
- Precision: sim uses int64/fixed-point world coords; Godot render uses chunk-local float32 (no jitter beyond 10 km).

## Design constraints to respect
- **The world is generated once, then frozen.** Continental drift runs at world creation only (`age` parameter); geography never changes at runtime — this is what keeps saves small (seed + deltas) and the map stable for gameplay.
- **The world is a flat map with horizontal wrap-around — never a sphere.** Equirectangular layout: X = longitude (0 wraps to width−1, no hard edges), Y = latitude (poles at top/bottom). No spherical geometry, no orbiting planet camera — the GAPS pipeline runs on this seamless plane.
- **Sim entities are never Godot Nodes.** Simulation state lives in C++ SoA arrays; Godot receives snapshots (meshes, MultiMesh data). Only interactive entities get Nodes.
- **No per-agent thinking every frame** — staggered AI decision ticks (1–4 Hz).
- **No individual pops** — aggregated pop groups per province (Vic3 model).
- **Economy recomputes on dirty flags only** — 95% of markets idle per tick by design.
- **Default rendering is cheap.** DoF, bloom, outlines etc. exist as toggles; the default stack is color grade + vignette (+ grain if free).

## What NOT to do
- Do not run `scons` in this repo; build in `godot_test_gdextension`.
- Do not commit binaries (`.so` in `bin/`).
- Do not hand-edit large baked sections of `.tscn` files (e.g., MultiMesh transform buffers).
- Do not add GDExtension classes that wrap Godot nodes into the sim; keep `CppSrc/sim/` Godot-free.
- Do not add gameplay systems (economy/4X/combat) before Phases 0–4 are done — the foundation is the point.
- Do not implement spherical planets, orbiting cameras, or runtime tectonic drift — the world is a flat, frozen, seed-derived map; seamless horizontally only (never vertical wrap, never sphere geometry).


## what to do if the user is asking for help
- give them the exact steps, ordered, with exact file paths and exact code changes described. Keep it tight and actionable. No edits allowed; just the instructions.
- give the exact file at the exact line from what to what if things are needed to be changed.
- chirurgical changes and minimal
- you have to always double check what you are saying
