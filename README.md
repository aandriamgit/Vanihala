# TUTO BY AANDRIAM
* `git clone git@github.com:aandriamgit/Vanihala.git`
* `cd Vanihala`
* `bin/` is gitignored - the built `.so` lands there

# WHAT THIS IS
A Kenshi-like sandbox RPG with a Victoria 3-style simulated economy and a 4X macro layer, rendered as a Tiny Glade-like 2.5D diorama (soft pastel, ortho miniature look), set on a world generated with **Geographically-Accurate-Planet-Simulator-level realism** — tectonic plates, continental drift, boundary-driven mountains, climate and biomes — all in **C++ DOD**, deterministic from seed, built to **run on potato hardware**.

# DOCS
* [`docs/study_plan.md`](docs/study_plan.md) — mastery study plan (concepts + exercises + acceptance checks) for every phase below
* [`AGENTS.md`](AGENTS.md) — architecture, roadmap, performance contracts, do/don't list

# ROADMAP
1. Phase 1: Settle the 2.5D render
    * Ortho camera - RTS rig
    * Soft pastel material - pastel ramp lighting
    * Single tight 2048 directional cascade
    * Foliage MultiMesh billboards
    * Default post stack - compositor_effects (grade + vignette only)
    * Tilt-shift

2. Phase 2: Performance backbone (C++ DOD core - all in CppSrc/)
    * CppSrc/sim/ + bind/ + bench/ structure
    * SoA foundations - zero allocation in hot paths
    * Job system - lock-free SPSC queues to Godot main thread
    * Fixed-timestep tick - double-buffered snapshots
    * Tracy profiler - sim + Godot side

3. Phase 3: Geographic world generation (C++ DOD, headless — the heart of the project)
    * Seamless wrap - equirectangular, no hard edges (X wraps, Y = latitude/poles)
    * Tectonic plates - Voronoi + sub-points, continental drift (one-shot, `age` param)
    * Boundary-classified elevation - C+C mountains, C+O subduction, O+O island arcs, rifts
    * Fractal ridge blending mountains
    * Temperature + precipitation → Whittaker-style biomes
    * Cheap hydraulic erosion → rivers
    * Whole world < 1–2 s on a potato, bit-identical from seed, PPM dumps to eyeball it

4. Phase 4: Terrain streaming in Godot (first integrated DOD feature)
    * Chunk sampler reads frozen worldgen data → chunk-local float32
    * Dirty-chunk mesh rebuild → Godot ArrayMesh
    * Streaming around camera (jobs + SPSC) - wrap-aware, seam duplicates
    * Foliage placement from sim
    * Delta persistence (save = seed + age + params + edits)

5. Deferred
    * Macro layer on worldgen data (provinces, factions)
    * Procedural buildings - path wall masonry roof
    * Vic3 economy
    * 4X layer
    * Kenshi local sim - staggered AI
    * UI
    * SIMD / polish
