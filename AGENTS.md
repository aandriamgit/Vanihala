# AGENTS.md — Vanihala (Godot 4.6 + C++ DOD GDExtension)

## What this project is
Vanihala is a **Kenshi-like sandbox RPG** with a **Victoria 3-style simulated economy** and a **4X macro layer**, rendered in a **painterly NPR style** (ramp-shaded lighting, object-space grain, soft edges, limited palette), set on a world generated with **geographically-accurate-planet-simulator-level realism** (tectonic plates, continental drift, climate-driven biomes). The game must **run on potato hardware**; performance is the backbone of every design decision.

Core pillars, in priority order:
1. **Geographic realism** — the world is generated like a real planet: tectonic plates → continental drift → boundary-driven mountains → temperature/precipitation → biomes, in C++ DOD, deterministic from seed, one-shot at world creation. (Reference: Devote Games' "Geographically Accurate Planet Simulator" — GAPS — ported to a flat map with horizontal wrap-around: X = longitude, seamless — no hard edges; Y = latitude with poles at top/bottom.)
2. **Painterly NPR rendering** — ramp shading (NdotL → gradient LUT), object-space grain (triplanar/3D noise, temporal-stable via mipmaps), edge bleeding via domain warping, limited palette via 3D LUT color grading, simplified silhouette-driven forms for procedural geometry. Not PBR, not hard cel — a soft, painterly middle ground.
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

## Visual style targets (NPR / painterly rendering)

### Ramp shading (lighting model)
- **Ramp shading / Toon ramp / Gradient ramp shader** — replace continuous PBR falloff with a 1D gradient LUT sampled by NdotL. Softer than hard cel (2–3 bands); target = painterly gradient with multiple soft stops.
- **NdotL** — `max(dot(NORMAL, LIGHT), 0)` — the value fed into the ramp. Every ramp shader reference uses this term.
- **Lookup texture (LUT)** — the gradient image used as the ramp. 1D or 2D, typically 256×1 or 16×1. Distinct from color-grading LUT but same concept.
- **Half-Lambert** — softens the lit/unlit terminator before ramp sampling; produces a smoother transition than raw Lambert, often used as the ramp input for painterly looks.
- **Complementary shadow color** — tint shadows toward cool hues instead of just darkening; standard painting theory applied to shading.
- **Dynamic time-of-day** — the ramp must read correctly as sun direction/color changes (sunrise, noon, sunset, night); not baked for one light setup.

### Object-space grain (paint texture on geometry)
- **Object-space shading / Object-space texturing** — effects computed in the object's coordinate system, not screen-space.
- **Triplanar mapping** — projects grain from three axes onto arbitrary geometry without UVs; the practical path for procedural meshes.
- **World-space noise / 3D noise texture** — grain from a noise function sampled at world/object position, stays "attached" to the surface.
- **Temporal stability / Temporal aliasing** — grain must not flicker/swim/shimmer as camera moves; the key integration challenge.
- **Mipmapping** — reduces aliasing/shimmer on fine grain at distance; critical for LOD stability.
- **Procedural noise functions** — Perlin, Simplex, Worley/Voronoi: the math behind organic-looking grain.
- **Texture tiling / seamless tiling** — grain texture must not show visible repetition across large procedural surfaces.
- **Stochastic texturing** — techniques to break up tiling patterns on repeated procedural terrain.

### Edge bleeding / watercolor edges
- **Edge detection** — Sobel, Roberts cross, depth/normal-based: find silhouettes and internal edges in 3D.
- **Depth-based / Normal-based edge detection** — use G-buffer data for reliable 3D edges (not color contrast alone).
- **Screen-space post-processing** — the category; applied to the rendered image, not per-object.
- **Domain warping / Noise-based UV distortion** — distort the sample position with a noise field to create bleeding/wobbling on edges.
- **Turbulence function** — layered Perlin noise used for organic distortion; common in watercolor-shader tutorials.
- **Alpha bleeding / Pigment diffusion** — advanced fluid simulation of watercolor pigment on wet paper; the "high-end" version.

### Limited / consistent color palette
- **Color grading** — real-time post-process (usually 3D LUT) remapping all colors toward a target palette.
- **3D LUT (Look-Up Table)** — cube lookup that maps input RGB → graded output RGB; the direct answer to enforcing a limited palette across a generated world.
- **Palette quantization / Color quantization** — reduce distinct colors in the final image; more aggressive than grading alone.
- **Posterization** — reduce continuous gradients to discrete bands; related to palette limiting and ramp shading.
- **Material authoring constraints** — constrain what colors procedural systems may assign upstream of any shader.

### Simplified forms / composition for procedural generation
- **Silhouette readability** — shape identifiability from outline alone; core constraint for stylized art direction.
- **Procedural modeling constraints / Shape grammar** — rule systems constraining procedural architecture/terrain to specific silhouette/complexity rules.
- **LOD (Level of Detail)** — detail culling at distance to keep compositions clean, not just for performance.
- **Detail density budget** — limit distinct visual elements/objects on screen; art-direction lever in open worlds.
- **Low-poly stylization** — simplified geometry + flat/near-flat shading, commonly paired with NPR shaders.

### UI integration
- **Diegetic vs non-diegetic UI** — diegetic = in-world (stylistically integrated), non-diegetic = clean overlay (HUD). Core design decision.
- **Skeuomorphic UI design** — UI mimics physical/painted materials (parchment, ink, brushstrokes); the direction if UI should "belong" to the painterly world.

### Performance / stability under free camera
- **Temporal Anti-Aliasing (TAA)** — can smear or dampen object-space grain if not handled carefully; common integration bug.
- **LOD bias / Distance-based effect falloff** — reduce shader cost/complexity (grain, edge detection, ramp) at distance.
- **Screen-space effect cost / Full-screen pass** — edge detection and color grading are full-resolution passes; cost scales with resolution, not scene complexity.
- **Overdraw** — relevant if grain/edge effects involve transparency or layered passes; budget for open world.

## Repository layout
- `docs/` — project docs. `docs/study_plan.md` is the mastery plan (concepts + exercises + acceptance checks) for all roadmap phases — consult it when working on any phase.
- `project.godot` — Godot 4.6, Forward Plus, Jolt Physics, 1920×1080. Will be reworked for low internal res + FSR upscale.
- `scenes/` — main scene is `scenes/levels/mini_main.tscn` (NOTE: `main.tscn` referenced in older docs does not exist).
- `systems/` — GDScript systems (`camera_system/camera_rig.gd`, `readme_node/` is junk).
- `addons/` — reusable plugins: `3d_rts_camera/` (orbit camera), `compositor_effects/` (30+ compute-based post-process effects — keep the framework).
- `assets/shaders/` — keep existing shaders as reference (`cel_shader.gdshader`, `outlines.gdshader`, `foliage_cel_shader.gdshader`).
- `CppSrc/` — **ALL C++ lives here** (`sim/` + `bind/` + `bench/`), the only C++ in the project.

## Build system
- Native C++ builds via **SCons** in the external repo `godot_test_gdextension` (hardcoded in `Makefile`). Never run `scons` inside this repo.
- **Target structure for `CppSrc/` (Phases 2–4 of roadmap):**
  - `CppSrc/sim/` — pure C++ DOD static lib, **zero Godot dependencies**. Contains `sim/worldgen/` (the geographic generation module — the heart of the project).
  - `CppSrc/bind/` — thin GDExtension binding layer (sim ⇄ Godot).
  - `CppSrc/bench/` — CLI benchmark/test harness, runs headless without Godot; also dumps PPM maps so generation can be eyeballed without a GPU.
- The compiled `.so` lands in `bin/linux/libManalooka00.linux.template_debug.x86_64.so` (`bin/` is a real dir, gitignored).

## Roadmap
1. **Phase 1 — NPR/Painterly rendering foundation**: ramp shading (NdotL → gradient LUT, Half-Lambert base), object-space grain (triplanar/3D noise, temporal stability, mipmaps), edge bleeding via domain warping, 3D LUT palette grading, simplified silhouette-driven procedural forms. Build the visual language before the sim foundation.
2. **Phase 2 — Performance backbone (C++ DOD core)**: restructure `CppSrc/` into `sim/` + `bind/` + `bench/`, SoA foundations (no allocation in hot paths), job system with lock-free SPSC queues to Godot main thread, fixed-timestep tick model with double-buffered snapshots, **Tracy profiler** on both sides. NOTE: only **2.1 (the sim/bind/bench skeleton)** gates Phase 3 — worldgen is pure C++, headless, and can be built the moment the skeleton exists.
3. **Phase 3 — Geographic world generation (`sim/worldgen`)**: the GAPS pipeline in C++ DOD on a **flat, seamlessly wrapped map** — seeded fBm/ridged noise, Voronoi tectonic plates, one-shot continental drift (`age` = drift steps is a world parameter), boundary-classified elevation (C+C mountains / C+O subduction / O+O island arcs / divergent rifts), fractal ridge blending, temperature (latitude + altitude lapse) + precipitation → Whittaker-style biomes, cheap budgeted hydraulic erosion (rivers for free). Horizontal wrap-around (equirectangular): X = longitude wraps modulo width, Y = latitude with poles at top/bottom — no hard edges anywhere; drift/BFS/distance fields use wrap-aware neighbor lookups. Whole world (2048×1024 coarse cells, one cell = one future 64×64 chunk) generated in < 1–2 s on a potato, bit-identical determinism, ~20 MB. Bench `--dump` writes PPM maps: realism is verified headless, before any Godot work.
4. **Phase 4 — Terrain streaming in Godot (first integrated DOD feature)**: chunk sampler reads the frozen worldgen data (coarse base + fine seeded octaves + biome/foliage masks → chunk-local float32), dirty-chunk mesh rebuild → Godot ArrayMesh, streaming around camera (jobs + SPSC from Phase 2, wrap-aware: chunks near the seam also spawn their wrapped duplicate), foliage placement from sim, delta persistence (save = seed + age + params + edits; world re-derived from seed).
5. **Deferred** (only after foundation is settled): macro gameplay layer on top of the worldgen data (provinces/factions drawn from biome + plate-boundary data) → procedural buildings (path → wall → masonry → roof) → Vic3 economy (aggregated pop groups, dirty-flag market ticks) → 4X layer → Kenshi local sim (staggered AI 1–4 Hz, hierarchical pathfinding) → UI (diegetic/skeuomorphic) → SIMD/polish passes.

## Performance contracts (aspirational, to be validated in Phases 3–4)
- Frame ≤ 16.6 ms at 60 fps; render ≤ 8 ms GPU at low internal res (960×540/1280×720) + FSR upscale to 1080p.
- **NPR render passes:** full-screen effects (edge detection, color grading LUT, grain overlay) ≤ 2 ms total GPU at 1280×720 internal; TAA must not smear object-space grain (validate visually).
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
- **Grain is object-space, not screen-space.** Must not shimmer/swim with camera movement; use triplanar mapping or 3D noise, not a flat screen overlay.
- **Edge detection is depth/normal-based**, not color-contrast-based; must work on procedurally generated meshes without clean UVs.
- **Palette is enforced upstream** via material authoring constraints + 3D LUT grading; shader alone cannot fix an uncontrolled palette.
- **Default rendering is cheap.** Grain, edge bleeding, bloom etc. exist as toggles; the default stack is ramp shading + color grade + vignette. Full-screen passes scale with resolution, not scene complexity.

## What NOT to do
- Do not run `scons` in this repo; build in `godot_test_gdextension`.
- Do not commit binaries (`.so` in `bin/`).
- Do not hand-edit large baked sections of `.tscn` files (e.g., MultiMesh transform buffers).
- Do not add GDExtension classes that wrap Godot nodes into the sim; keep `CppSrc/sim/` Godot-free.
- Do not add gameplay systems (economy/4X/combat) before Phases 0–4 are done — the foundation is the point.
- Do not implement spherical planets, orbiting cameras, or runtime tectonic drift — the world is a flat, frozen, seed-derived map; seamless horizontally only (never vertical wrap, never sphere geometry).
- Do not use screen-space grain (flat overlay) — it shimmers on camera movement; always object-space or 3D noise.
- Do not use color-contrast edge detection — it fails on uniform-colored procedural terrain; always depth/normal-based.
- Do not bake ramps for one fixed light setup — the ramp must integrate with dynamic time-of-day lighting.


## what to do if the user is asking for help
- give them the exact steps, ordered, with exact file paths and exact code changes described. Keep it tight and actionable. No edits allowed; just the instructions.
- give the exact file at the exact line from what to what if things are needed to be changed.
- chirurgical changes and minimal
- you have to always double check what you are saying