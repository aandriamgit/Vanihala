# AGENTS.md — Vanihala (Godot 4.6 + C++ DOD GDExtension)

## What this project is
Vanihala is a **Kenshi-like sandbox RPG** with a **Victoria 3-style simulated economy** and a **4X macro layer**, rendered in a **Tiny Glade-like 2.5D diorama style** (soft pastel, orthographic miniature look — NOT hard cel-shading, NOT pixel-art-on-3D). The game must **run on potato hardware**; performance is the backbone of every design decision.

Core pillars, in priority order:
1. **2.5D render settled first** — Tiny Glade look (soft shading, pastel, diorama framing, tilt-shift optional).
2. **Performance on a potato** — low internal resolution + upscale, streaming, tight budgets.
3. **C++ with data-oriented design (DOD)** — the simulation core is pure C++ SoA code, benchmarkable headless.
4. **Procedural everything** — biggest map possible via seeded generation + streaming + delta saves (fixed seed).

## Architecture: three layers
The game is three simulations at different scales. Never blur them.

| Layer | Scope | Tick rate | Where it lives |
|---|---|---|---|
| **4X macro** | Whole world: provinces, factions, diplomacy, trade routes | 1 Hz + event-driven | C++ sim, few MB of data |
| **Zone sim** | Player's active zone: squads, agents, combat, buildings | 10–20 Hz movement, 1–4 Hz AI decisions | C++ sim, SoA arrays |
| **Presentation** | Rendering, camera, input, UI, audio | 60 fps | Godot 4.6 (GDExtension) |

Key principle: the macro layer covers the entire world cheaply as pure data; only the player's active zone is materialized as 3D. This is how a huge map runs on weak hardware.

## Repository layout
- `project.godot` — Godot 4.6, Forward Plus, Jolt Physics, 1920×1080. Will be reworked for low internal res + FSR upscale.
- `scenes/` — main scene is `scenes/levels/mini_main.tscn` (NOTE: `main.tscn` referenced in older docs does not exist).
- `systems/` — GDScript systems (`camera_system/camera_rig.gd`, `readme_node/` is junk).
- `addons/` — reusable plugins: `3d_rts_camera/` (orbit camera to adapt for 2.5D ortho), `compositor_effects/` (30+ compute-based post-process effects — keep the framework, keep only cheap effects in the default stack).
- `assets/shaders/` — `cel_shader.gdshader` + `.gdshaderinc` (to be given a "soft pastel" mode), `foliage_cel_shader.gdshader` (billboard MultiMesh foliage — the cheap path, keep), `outlines.gdshader` (probably NOT part of the Tiny Glade look — keep around, default off).
- `CppSrc/` — **ALL C++ lives here** (`sim/` + `bind/` + `bench/`), the only C++ in the project.

## Build system
- Native C++ builds via **SCons** in the external repo `godot_test_gdextension` (hardcoded in `Makefile`). Never run `scons` inside this repo.
- **Target structure for `CppSrc/` (Phase 2 of roadmap):**
  - `CppSrc/sim/` — pure C++ DOD static lib, **zero Godot dependencies**.
  - `CppSrc/bind/` — thin GDExtension binding layer (sim ⇄ Godot).
  - `CppSrc/bench/` — CLI benchmark/test harness, runs headless without Godot.
- The compiled `.so` lands in `bin/linux/libManaloka00.linux.template_debug.x86_64.so` (`bin/` is a real dir, gitignored).

## Roadmap (locked order)
2. **Phase 1 — Settle the 2.5D Tiny Glade render**: ortho camera (adapt RTS camera), soft pastel material mode, one tight 2048 directional cascade, foliage MultiMesh, default post stack = color grade + vignette only, tilt-shift DoF as optional toggle, "glade" test diorama scene, freeze the look in a reference doc.
3. **Phase 2 — Performance backbone (C++ DOD core)**: restructure `CppSrc/` into `sim/` + `bind/` + `bench/`, SoA foundations (no allocation in hot paths), job system with lock-free SPSC queues to Godot main thread, fixed-timestep tick model with double-buffered snapshots, **Tracy profiler** on both sides.
4. **Phase 3 — First DOD feature: terrain**: SoA heightmap, seeded noise gen, sculpting brushes, dirty-chunk mesh rebuild → Godot ArrayMesh, streaming around camera, foliage placement from sim, delta persistence (save = edits only; world re-derived from seed).
5. **Deferred** (only after foundation is settled): macro world gen → procedural buildings (path → wall → masonry → roof) → Vic3 economy (aggregated pop groups, dirty-flag market ticks) → 4X layer → Kenshi local sim (staggered AI 1–4 Hz, hierarchical pathfinding) → UI → SIMD/polish passes.

## Performance contracts (aspirational, to be validated in Phase 3)
- Frame ≤ 16.6 ms at 60 fps; render ≤ 8 ms GPU at low internal res (960×540/1280×720) + FSR upscale to 1080p.
- Sim tick ≤ 2 ms on worker threads; empty-world tick < 1 ms.
- Save format: seed + deltas; streaming radius keeps memory < ~512 MB.
- Precision: sim uses int64/fixed-point world coords; Godot render uses chunk-local float32 (no jitter beyond 10 km).

## Design constraints to respect
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
- Do not add gameplay systems (economy/4X/combat) before Phases 0–3 are done — the foundation is the point.
