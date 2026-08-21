# TUTO BY AANDRIAM
* `git clone git@github.com:aandriamgit/Vanihala.git`
* `cd Vanihala`
* `bin/` is gitignored - the built `.so` lands there

# WHAT THIS IS
A Kenshi-like sandbox RPG with a Victoria 3-style simulated economy and a 4X macro layer, rendered in a **painterly NPR style** (ramp-shaded lighting, object-space grain, soft edges, limited palette), set on a world generated with **Geographically-Accurate-Planet-Simulator-level realism** — tectonic plates, continental drift, boundary-driven mountains, climate and biomes — all in **C++ DOD**, deterministic from seed, built to **run on potato hardware**.

# DOCS
* [`docs/study_plan.md`](docs/study_plan.md) — mastery study plan (concepts + exercises + acceptance checks) for every phase below
* [`AGENTS.md`](AGENTS.md) — architecture, roadmap, performance contracts, do/don't list

# ROADMAP
1. Phase 1: NPR/Painterly rendering foundation
    * Ramp shading (NdotL → gradient LUT, Half-Lambert base)
    * Object-space grain (triplanar/3D noise, temporal stability, mipmaps)
    * Edge bleeding via domain warping
    * 3D LUT palette grading
    * Simplified silhouette-driven procedural forms

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
    * UI (diegetic/skeuomorphic)
    * SIMD / polish