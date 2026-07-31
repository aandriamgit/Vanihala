# TUTO BY AANDRIAM
* `git clone git@github.com:aandriamgit/Vanihala.git`
* `cd Vanihala`
* `bin/` is gitignored - the built `.so` lands there

# DOCS
* [`docs/study_plan.md`](docs/study_plan.md) — mastery study plan (concepts + exercises + acceptance checks) for every phase below

# ROADMAP
1. Phase 1: Settle the 2.5D render
    * Ortho camera - RTS rig
    * soft pastel material - pastel ramp lighting
    * Single tight 2048 directional cascade
    * Foliage MultiMesh billboards
    * Default post stac - compositor_effects
    * Tilt-shift

2. Phase 2: Performance backbone (C++ DOD core - all in CppSrc/)
   * CppSrc/sim/ + bind/ + bench/ structure
   * SoA foundations - zero allocation in hot paths
   * Job system - lock-free SPSC queues to Godot main thread
   * Fixed-timestep tick - double-buffered snapshots
   * Tracy profiler - sim + Godot side

3. Phase 3: DOD feature - terrain
    * SoA heightmap
    * Streaming around camera 
    * Foliage placement from sim
    * Delta persistence

4. Phase 4: Deferred
    * Macro world gen
    * Procedural buildings - path wall masonry roof etc etc
    * Vic3 economy
    * 4X layer
    * Kenshi local sim - staggered AI
    * UI
    * SIMD / polish
