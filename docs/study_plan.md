# Vanihala — Mastery Study Plan (Phases 1–5)

Goal: learn each concept **by doing**, on the actual repo, with a measurable acceptance test per exercise.
Convention: every exercise ends with a **check** — a concrete thing you can observe/measure.
Recommended pacing: 1 concept cluster per day, 3–5 days per phase, revisit any failed check before moving on.

---

# PHASE 1 — NPR/Painterly rendering foundation

Target: ramp shading, object-space grain, edge bleeding, limited palette, silhouette-driven forms. Build the visual language first; everything else renders through it.
Related files: `assets/shaders/`, `addons/compositor_effects/`, `scenes/levels/mini_main.tscn`.

## 1.1 Ramp shading (NdotL → gradient LUT)

### Concepts to master
- **Ramp shading / Toon ramp / Gradient ramp shader** — replace continuous PBR falloff with a 1D gradient LUT sampled by NdotL.
- **NdotL** — `max(dot(NORMAL, LIGHT), 0)` — the value fed into the ramp. Core term for every ramp shader reference.
- **Lookup texture (LUT)** — the gradient image used as the ramp (1D or 2D, typically 256×1 or 16×1). Distinct from color-grading LUT but same underlying concept.
- **Half-Lambert** — softens the lit/unlit terminator before ramp sampling; smoother transition than raw Lambert, often used as ramp input for painterly looks.
- **Complementary shadow color** — tint shadows toward cool/complementary hues instead of just darkening; standard painting theory applied to shading.
- **Dynamic time-of-day** — the ramp must read correctly as sun direction/color changes (sunrise, noon, sunset, night); not baked for one light setup.

### Repo references
- `assets/shaders/spatial/cel_shader.gdshader` — the main shader (already wired to the inc).
- `assets/shaders/shaderincs/cel_shader.gdshaderinc` — `toon_light()`, ramp uniforms, `light_wrap`, `steepness`, `shadow_strength`.

### Exercises
1. Create a 16×1 gradient ramp texture (soft stops, pastel palette) and assign it to `cel_ramp`. Swap between a soft ramp and a hard 2–3 band ramp to see the difference.
2. Tune `light_wrap` + `shadow_strength` until a sphere under a directional light keeps a lit side and a soft-blue shadow side — no pure black.
3. Test under a rotating directional light: the ramp must read correctly at sunrise, noon, sunset angles. Adjust if bands shift or break.

**Check:** rotating the light never produces a visible hard "cut" line on a smooth mesh; no pure black anywhere; the ramp adapts to time-of-day changes.

## 1.2 Object-space grain (paint texture on geometry)

### Concepts to master
- **Object-space shading / Object-space texturing** — effects computed in the object's coordinate system, not screen-space.
- **Triplanar mapping** — projects grain from three axes onto arbitrary geometry without UVs; the practical path for procedural meshes.
- **World-space noise / 3D noise texture** — grain from a noise function sampled at world/object position, stays "attached" to the surface.
- **Temporal stability / Temporal aliasing** — grain must not flicker/swim/shimmer as camera moves; the key integration challenge.
- **Mipmapping** — reduces aliasing/shimmer on fine grain at distance; critical for LOD stability.
- **Procedural noise functions** — Perlin, Simplex, Worley/Voronoi: the math behind organic-looking grain.
- **Texture tiling / seamless tiling** — grain texture must not show visible repetition across large procedural surfaces.
- **Stochastic texturing** — techniques to break up tiling patterns on repeated procedural terrain.

### Repo references
- `addons/compositor_effects/` — the post-process framework (grain may live as a compositor effect or per-material).
- Any existing shader with triplanar or noise sampling patterns.

### Exercises
1. Implement a grain overlay using triplanar mapping on a test sphere. Sample a 3D noise texture at object position. Observe it stays attached as the camera orbits.
2. Add mipmapping to the grain texture. Compare at distance: with mipmaps, grain stabilizes; without, it shimmers.
3. Test temporal stability: walk the camera around the scene. Grain must not swim, flicker, or pop. If it does, add temporal damping (blend with previous frame's grain sample).
4. Test tiling: use a large procedural surface. If grain repeats visibly, apply stochastic offset or a second noise layer to break the pattern.

**Check:** grain stays "painted on" the surface as camera moves; no shimmer at distance; no visible tiling repetition on large surfaces.

## 1.3 Edge bleeding / watercolor edges

### Concepts to master
- **Edge detection** — Sobel, Roberts cross, depth/normal-based: find silhouettes and internal edges in 3D.
- **Depth-based / Normal-based edge detection** — use G-buffer data for reliable 3D edges (not color contrast alone).
- **Screen-space post-processing** — the category; applied to the rendered image, not per-object.
- **Domain warping / Noise-based UV distortion** — distort the sample position with a noise field to create bleeding/wobbling on edges.
- **Turbulence function** — layered Perlin noise used for organic distortion; common in watercolor-shader tutorials.
- **Alpha bleeding / Pigment diffusion** — advanced fluid simulation of watercolor pigment on wet paper; the "high-end" version.

### Repo references
- `assets/shaders/spatial/outlines.gdshader` — existing edge detection shader.
- `addons/compositor_effects/` — post-process framework for screen-space edge passes.

### Exercises
1. Read the existing `outlines.gdshader`. Identify how it detects edges (depth-based? normal-based? color-based?). Document which method it uses.
2. Implement a post-process edge pass using depth+normal detection. Verify it works on procedurally generated meshes without clean UVs.
3. Apply domain warping to the edge detection: distort the UV sample with a turbulence function. The hard edge lines should become soft and "bleeding."
4. Tune the warp strength: too little = still hard; too much = edges dissolve. Find the watercolor sweet spot.

**Check:** edges are soft and organic (not pixel-perfect clean lines); the effect works on meshes with no UVs; toggling the effect changes only visual quality, never performance below budget.

## 1.4 Limited / consistent color palette

### Concepts to master
- **Color grading** — real-time post-process (usually 3D LUT) remapping all colors toward a target palette.
- **3D LUT (Look-Up Table)** — cube lookup that maps input RGB → graded output RGB; the direct answer to enforcing a limited palette across a generated world.
- **Palette quantization / Color quantization** — reduce distinct colors in the final image; more aggressive than grading alone.
- **Posterization** — reduce continuous gradients to discrete bands; related to palette limiting and ramp shading.
- **Material authoring constraints** — constrain what colors procedural systems may assign upstream of any shader.

### Repo references
- `addons/compositor_effects/color_correction/` — existing color grading post-process.

### Exercises
1. Read `post_process_color_correction.gd` + `.glsl`. Understand how the CompositorEffect reads scene color and writes graded output via a 3D LUT.
2. Build a 3D LUT that maps the full color space into a limited pastel palette (5–8 dominant hues). Apply it. The entire scene should feel "painted."
3. Test with procedural content: generate terrain with various biome colors. The LUT must unify them into the palette without making everything identical.
4. Optionally combine with quantization: reduce the graded output to N discrete color bands. Compare posterized vs non-posterized.

**Check:** the palette is consistent across the entire scene regardless of material source; no single object "breaks" the palette; the LUT is cheap (verify GPU cost < 0.1 ms at 1280×720).

## 1.5 Simplified forms / composition

### Concepts to master
- **Silhouette readability** — shape identifiability from outline alone; core constraint for stylized art direction.
- **Procedural modeling constraints / Shape grammar** — rule systems constraining procedural architecture/terrain to specific silhouette/complexity rules.
- **LOD (Level of Detail)** — detail culling at distance to keep compositions clean, not just for performance.
- **Detail density budget** — limit distinct visual elements/objects on screen; art-direction lever in open worlds.
- **Low-poly stylization** — simplified geometry + flat/near-flat shading, commonly paired with NPR shaders.

### Exercises
1. Take a procedural building or terrain mesh. Evaluate silhouette readability: does the shape read clearly from its outline alone? Simplify geometry until it does.
2. Define a detail density budget: how many distinct objects/materials are allowed in a 50×50 m area? Enforce it in a test scene.
3. Test LOD: move the camera far from a detailed mesh. At what distance does detail become noise? Set LOD transition to cull detail before that point.

**Check:** shapes are identifiable from silhouette; no "visual clutter" at distance; compositions stay clean under free camera movement.

## 1.6 UI integration + performance budget

### Concepts to master
- **Diegetic vs non-diegetic UI** — diegetic = in-world (stylistically integrated), non-diegetic = clean overlay (HUD). Core design decision.
- **Skeuomorphic UI design** — UI mimics physical/painted materials (parchment, ink, brushstrokes); the direction if UI should "belong" to the painterly world.
- **Temporal Anti-Aliasing (TAA)** — can smear or dampen object-space grain if not handled carefully; common integration bug.
- **LOD bias / Distance-based effect falloff** — reduce shader cost/complexity (grain, edge detection, ramp) at distance.
- **Screen-space effect cost / Full-screen pass** — edge detection and color grading are full-resolution passes; cost scales with resolution, not scene complexity.
- **Overdraw** — relevant if grain/edge effects involve transparency or layered passes; budget for open world.

### Exercises
1. Decide: diegetic or non-diegetic UI? Create a mockup of one UI element (health bar, inventory) in the painterly style. Does it "belong" to the world?
2. Measure full-screen post-process stack cost: ramp shading + edge detection + color grading + grain overlay. Total must be ≤ 2 ms GPU at 1280×720.
3. Test TAA + object-space grain: enable TAA, walk the camera. If grain smears or dampens, adjust grain sampling or disable TAA on grain passes.

**Check:** UI feels integrated with the painterly world; full post stack is under 2 ms GPU; TAA does not destroy object-space grain.

### Phase 1 completion gate
- Ramp shading reads correctly under dynamic time-of-day lighting.
- Object-space grain is temporally stable, mipped, non-tiling.
- Edge bleeding works on UV-less procedural meshes.
- 3D LUT enforces a consistent limited palette across the scene.
- Simplified silhouette-driven forms validate under free camera.
- Full NPR post stack ≤ 2 ms GPU at 1280×720 internal resolution.

---

# PHASE 2 — Performance backbone (C++ DOD core)

Target: restructure `CppSrc/` into `sim/` + `bind/` + `bench/`; SoA sim core; job system; fixed timestep; Tracy.
Related files: `CppSrc/` (currently only `gen/` + `register_types.*` stubs), `Makefile` (builds in `godot_test_gdextension`, never scons here).
NOTE: only **2.1 (the sim/bind/bench skeleton)** gates Phase 3 — `sim/worldgen` is pure C++ and headless; it can be built the moment 2.1 lands, without waiting for 2.2–2.5.

## 2.1 C++ structure: sim / bind / bench

### Concepts to master
- Static library layering: `sim/` = zero-Godot pure C++ (compiles headless, testable), `bind/` = thin GDExtension glue, `bench/` = CLI harness.
- GDExtension lifecycle: `register_types.cpp` (existing stub), `GDExtensionInitialize`, class registration via `ClassDB::register_class` or extension APIs.
- Headless testing: the bench must run without a Godot binary — this is how you prove sim speed without GPU.

### Repo references
- `CppSrc/register_types.cpp` + `register_types.h` — the only existing bind code.
- `Makefile` — the build entry point (external repo `godot_test_gdextension`).

### Exercises
1. Create `CppSrc/sim/` with a `sim_math.h/.cpp` (no Godot includes) exposing e.g. `clamp`, `fast_rand`; create `CppSrc/bench/` with a `main.cpp` that runs it and prints results.
2. Make `Makefile` build the bench as a standalone binary (add a target) and run it from CLI.
3. Add a single trivial registered class from `bind/` that calls into `sim/` and exposes one method to Godot.

**Check:** `make bench && ./bin/bench` works with no Godot installed; the `.so` still loads in Godot and the bound method returns the sim's value.

## 2.2 SoA foundations (zero allocation in hot paths)

### Concepts to master
- AoS vs SoA: `struct { pos; vel; hp }[N]` vs `float pos_x[N], pos_y[N], ...` — cache locality and SIMD-friendliness.
- Why: iterating 100k agents touches 100k cache lines with AoS (sparse), ~N/8 with SoA (dense).
- No allocation in hot paths: preallocate arrays at init (`std::vector` resize once, or arena/`std::pmr`), swap-out/swap-in free lists instead of new/delete per entity.
- Fixed-size pools + free lists: entity slots, `alive` bitmask, index indirection for stable handles.
- Compile-time vs runtime sizes: template `<size_t N>` or capacity constants over dynamic growth in tick code.

### Repo references
- None yet — this is the phase that builds it. Study patterns in `CppSrc/sim/` you'll create.

### Exercises
1. Write `CppSrc/sim/agent_soa.h`: SoA arrays for position/velocity/health/type, fixed capacity 65536, a `spawn/despawn` free-list.
2. Add a tick that integrates positions. Write the AoS version too. Bench both in `bench/` at N=65536 for 1000 ticks.
3. Run under `perf stat` (or Tracy later) and observe cache-miss differences (LLC-load-misses).

**Check:** SoA beats AoS measurably at N≥8192; allocations happen zero times inside the tick loop (`malloc` count via `ltrace`/Tracy stays flat during ticks).

## 2.3 Job system + lock-free SPSC queues

### Concepts to master
- Job/worker pool: N workers (one per core), task queue, `std::atomic` work counters, `std::jthread`/pthread workers with condition variables OR spin-wait.
- SPSC (single-producer single-consumer) ring buffer: `std::atomic<size_t>` head/tail, no mutex needed — the correct primitive for sim→Godot snapshot handoff.
- Lock-free vs lock-based: why the sim thread must NEVER block on the render thread (and vice-versa).
- Producer/consumer pattern: sim writes snapshot #N while render reads snapshot #N-1 (double buffering, see 2.4).
- Memory ordering: `memory_order_acquire/release` semantics; when `seq_cst` is (un)necessary.

### Exercises
1. Implement an SPSC ring buffer of `Snapshot` structs in `CppSrc/sim/spsc_queue.h`. Unit-test with one producer thread + one consumer thread, 10M messages.
2. Add a small job pool (e.g. `thread_pool.h`) with `submit(Job)`; parallelize the agent tick across 4 workers; validate results match single-threaded exactly.
3. Bench throughput with `perf`/Tracy; prove scaling (2× on 4 cores for the parallelizable part).

**Check:** SPSC test passes with `-fsanitize=thread`; tick wall-time scales with cores; zero mutexes in the hot path.

## 2.4 Fixed-timestep tick + double-buffered snapshots

### Concepts to master
- Fixed timestep: sim advances in fixed Δt (e.g. 20 Hz zone, 1 Hz macro) independent of render fps; render interpolates between snapshots.
- Determinism: same seed+inputs → same result; float non-associativity is why order must be fixed (SoA iteration order = deterministic).
- Double buffering: sim writes buffer B while render reads buffer A; swap when B complete (atomics + fences, no locks).
- Snapshot design: packed structs/arrays (positions, health, state), not Godot objects; the ONLY thing crossing the boundary.
- Godot side: `_physics_process` vs `_process`; polling the latest snapshot each frame and interpolating for smoothness.

### Exercises
1. Design `Snapshot { uint32_t frame; uint32_t count; float* pos_x; float* pos_y; ... }` in sim; sim produces 60/s, render consumes at 60 fps with interpolation.
2. Implement the swap protocol with two atomics (`write_index`, `ready_flags`); prove no tearing: render never sees a half-written snapshot even with stress.
3. Add Tracy markers (2.5) around tick + swap; verify tick ≤ 2 ms with empty world (AGENTS contract).

**Check:** render at 30 fps still shows smooth sim motion (interpolation works); sim tick time is invariant to render fps; `-fsanitize=thread` clean.

## 2.5 Tracy profiler (sim + Godot)

### Concepts to master
- Tracy basics: `TracyZoneScoped` / `TracyPlot`, `TracyCZoneBegin/End` in C; server UI shows thread timelines, allocations, lock contention.
- Instrumenting both sides: sim side native, Godot side via GDExtension (there's no first-class Tracy in Godot — you bridge via your bind layer, e.g. a debug call that marks zones or sends data).
- Frame vs tick view: GPU/Godot frame on one thread, sim ticks on workers — the two must be visually separable in the timeline.

### Exercises
1. Add Tracy to the sim build; mark tick, swap, and job regions.
2. Add a minimal Godot-side integration (GDExtension callable that starts/stops a zone via the same Tracy API, guarded by a `bench=yes` define).
3. Produce a screenshot of the Tracy timeline showing sim ticks on worker threads under 2 ms, never blocking the Godot main thread.

**Check:** you can point at the timeline and prove: tick ≤ 2 ms, no lock contention in hot paths, no allocation spikes.

### Phase 2 completion gate
- `CppSrc/{sim,bind,bench}` compiles independently; bench runs headless.
- SoA pool + parallel tick passes unit tests and beats AoS.
- SPSC queue + double-buffer handoff stress-tested clean under TSan.
- Tracy shows tick ≤ 2 ms on workers, empty world < 1 ms (AGENTS contracts).

---

# PHASE 3 — Geographic world generation (`sim/worldgen`)

Target: the GAPS pipeline ("Geographically Accurate Planet Simulator" by Devote Games) ported to a **flat map** in pure C++ DOD, zero Godot deps, headless-benchmarkable, deterministic from seed. This is the heart of the project — it IS the world.
Related files: `CppSrc/sim/worldgen/` (new), `CppSrc/bench/` (new). Gates on Phase 2.1 only.

Pipeline order (each step is a milestone with its own dump + bench proof):
`noise → plates → drift → boundaries/elevation → mountains → climate → erosion`.

## 3.1 Seeded noise foundations (`noise.h`)

### Concepts to master
- Hash-based value noise vs gradient noise (Perlin/Simplex): integer hashing = bit-deterministic and branchless, no float non-associativity across runs.
- fBm (fractal Brownian motion): layered octaves with frequency doubling + amplitude halving — the base shape of continents.
- Ridged fBm: shift noise down, `abs()`, flip/re-normalize — the abs creates sharp V-shaped ridges (this is the raw material for mountain ridges).
- Fixed iteration order = determinism: the same seed must produce bit-identical arrays, every run, any core count.
- Coordinate systems: integer grid coords for the coarse world; per-chunk sub-cell sampling via hash-interpolated noise (no global float drift).

### Exercises
1. Implement `sim/worldgen/noise.h`: seeded value-noise + fBm + ridged fBm, over a 2048×1024 grid, SoA (one contiguous float array).
2. Determinism test in bench: generate twice with the same seed, `memcmp` the arrays — must be bit-identical.
3. `bench --dump noise` writes a PPM of the fBm field; eyeball that octaves layer cleanly.
4. Bench cost: samples/second at full world size.

**Check:** same seed → bit-identical output; PPM shows smooth layered continents, not blobs or grid artifacts; generation is well under the world budget (see Phase 3 gate).

## 3.2 Tectonic plates + continental drift (`plates.h`)

### Concepts to master
- Voronoi partition on a grid: seed cells → every cell takes the nearest seed's ID. Cheap via multi-source flood fill (BFS from all seeds in parallel passes) or a KD-tree over seeds — bench both, keep the faster.
- Sub-points: a handful of sub-points per plate seed add organic variety to plate shapes (GAPS's trick; doubles shape quality at ~2× lookup cost — mitigated by the KD-tree).
- Continental drift = iterated absorption: pick a random cell in a plate, cast a radius until it hits another plate's color, shift the pick point toward a random direction, convert all cells inside the radius. Repeat `age` times. One-shot at world creation — NEVER at runtime.
- `age` as a world parameter: same seed + more drift steps = "older" world with different continents. This is how you get world variety without new seeds.
- Wrap-around (seam): the grid is horizontally toroidal — neighbor lookups use `x = (x + W) % W`; plates glide across the seam and never see an edge. This is the flat-map equivalent of a planet's surface (X = longitude, Y = latitude).
- Crust typing: continental seeds grow first (flood fill with land-ratio budget), oceanic fills the rest; oceanic plates' elevation is shifted down (continents = plate geometry, not noise).
- Determinism under parallelism: drift steps are sequential; parallel passes must use fixed iteration order (no `parallel_for` with nondeterministic accumulation).

### Exercises
1. Implement plate generation + sub-points on the coarse grid; 12–50 plates by parameter.
2. Implement the drift loop; `age` is a CLI parameter (`bench --age N`).
3. Dump `plates` (plate ID) and `plate_type` (oceanic/continental) maps; compare against GAPS screenshots — plates must look Earth-like, NOT blocky rectangles.
4. Determinism test: `--age 500` twice → bit-identical plate arrays.
5. Seam test: dump the plate map and verify column 0 and column W−1 match seamlessly (same plate IDs across the wrap); a plate straddling the seam is one plate, not two.

**Check:** plate boundaries are organic (no straight-line Voronoi artifacts at chunk scale); drift visibly reshapes continents; same seed+age → identical plates; drift step cost scales linearly with `age` and stays small; nothing special happens at the seam.

## 3.3 Boundaries + elevation (`elevation.h`)

### Concepts to master
- Boundary detection that handles multi-plate junctions (not just 2-plate edges).
- Boundary classification from relative plate motion: compare velocity vectors of adjacent plates (dot products across the edge) →
  - convergent C+C → mountain range,
  - convergent C+O → oceanic subduction: trench on the oceanic side + volcanic arc on the continental side,
  - convergent O+O → island arc / coastline,
  - divergent → rift (low elevation, new crust),
  - transform → neutral (no elevation change).
- Multi-source distance fields: BFS from boundary cells inward — elevation falls off with distance from the boundary (mountains hug the boundary, not the plate center). All BFS/neighbor passes are wrap-aware (column 0 and W−1 are neighbors; Y stays flat with poles at rows 0 and H−1).
- Base elevation = boundary-driven value + fBm with the **first octave capped/remapped** (GAPS's fix for blobby continents) + edge smoothing across boundaries.
- Sea level parameter: threshold on elevation splits ocean/land; oceanic plates sit below by default.

### Exercises
1. Implement boundary classification per boundary cell; store boundary type per cell.
2. Implement multi-source distance fields (one pass per boundary class, parallel over cells, fixed order).
3. Compose elevation: boundary field + capped-octave fBm + smoothing; apply sea level; dump `elevation` (grayscale PPM: deep ocean → peaks).
4. Sweep `sea_level` and `land_ratio` params in bench; verify coastline extent responds.

**Check:** mountain ranges follow plate boundaries as continuous chains (Himalayas/Andes-like), no blob mountains at continent centers; trenches are visible as low strips next to ranges; deterministic.

## 3.4 Mountains — fractal ridge blending (`mountains.h`)

### Concepts to master
- Why Perlin mountains look "blobby": smooth gradients can't produce the sharp ridgelines that millions of years of water erosion create.
- Ridge noise: take fBm, shift down, `abs()` (every negative becomes positive → a sharp V at the zero crossing), flip and renormalize to [0,1]; layer octaves of this for detail.
- Blending: base Perlin decides WHERE mountains are; ridge octaves are added only inside the mountain mask; smooth blend (mask = boundary strength × elevation) so there's no hard cut.
- Detail octaves confined to mountain zones — cost control (don't pay for ridges in the plains).

### Exercises
1. Implement ridge-noise octaves + mountain mask + smooth blend.
2. Dump before/after (base elevation vs ridged): valleys between sharp ridges must be visible.
3. Bench: ridge cost as % of total gen time; tune octave count to budget.

**Check:** ridgelines are sharp and continuous, valleys read as valleys, snow-less "blob" mountains are gone; cost stays inside budget.

## 3.5 Climate + biomes (`climate.h`)

### Concepts to master
- Temperature = latitude falloff + **altitude lapse rate** (temp drops ~6.5 °C/km) + noise. Flat-map latitude = Y coordinate (top = pole, bottom = pole, middle = equator); horizontal wrap does not affect latitude bands — the seam must never show a temperature jump.
- Precipitation: moisture originates over ocean cells and advects along prevailing wind belts (simplified: latitude-dependent prevailing direction + moisture decay inland + orographic boost/rain shadow from ridges — GAPS page mentions rain shadow; cheap version = wind-weighted distance from ocean minus ridge blocking).
- Biome lookup: Whittaker-style table temp × precipitation → biome (rainforest/tundra/desert/taiga/grassland...). A 2D lookup table, not a decision tree.
- Snow: below a temperature threshold terrain turns to ice; gate by **steepness** (GAPS's trick: snow only on flatter parts → natural peaks, not icy cliffs).
- Params: `temp_bias`, `precip_bias`, `ocean_amount` — the "12 sliders" GAPS exposes, mapped to ~6-8 core params.

### Exercises
1. Implement temperature map; dump `temperature` (blue cold → red hot): poles must be cold, equator hot, high mountains cold (lapse).
2. Implement precipitation (wind-belt advection from ocean + rain shadow); dump `precipitation`.
3. Implement biome table + snow (temp threshold + steepness gate); dump `biome` with a GAPS-like biome palette.
4. Sweep `temp_bias`/`precip_bias`; verify desert bands at ~30° latitude, green tropics, ice at poles — like Earth.

**Check:** biome map reads like a real planet: no "noise soup", deserts and rainforests in plausible bands, mountain peaks snow-capped only where they should be; deterministic.

## 3.6 Erosion + rivers (`erosion.h`)

### Concepts to master
- Hydraulic erosion (cheap budgeted form): for a fixed number of iterations, move water downhill, pick up sediment on steep slopes, deposit on flat; carve valleys, round hills. Cost-capped: must stay ≤ 20% of total gen time.
- Downhill flow accumulation: sum of upstream water per cell → **rivers** for free from the final heightmap; rivers flow to the sea, coast at sea level.
- Erosion operates on the coarse elevation; fine chunks inherit it (they must not re-erode per-chunk or chunk borders would tear).
- Determinism: fixed iteration order over cells; same seed → same rivers.

### Exercises
1. Implement the erosion pass with an iteration budget; dump before/after (valleys carved, sediment deposited).
2. Implement flow accumulation; dump `rivers` (brightness = flow) over the elevation map.
3. Bench: erosion % of total gen time; tune iterations to the 20% contract.

**Check:** erosion cost ≤ 20% of generation; valleys carve into ridges; rivers drain to the ocean (no inland dead ends); deterministic.

### Phase 3 completion gate
- Whole world 2048×1024 coarse cells generated < 1–2 s on a 4-core potato, headless (`bench --world 2048x1024 --seed S --age A`).
- Same seed + params → bit-identical world (automated test across all stages).
- Coarse world ≤ ~25 MB (~9 bytes/cell SoA).
- Erosion ≤ 20% of gen time; chunk sample < 1 ms.
- Dumps (plates, elevation, temperature, precipitation, biome, rivers) look GAPS-plausible when compared side-by-side.
- Bench prints per-stage timings; Tracy (2.5) shows the pipeline stages and any parallel passes.

---

# PHASE 4 — Terrain streaming in Godot (first integrated DOD feature)

Target: chunks materialize the frozen worldgen data in Godot: sampler → ArrayMesh, streaming, foliage, delta saves. The old "first DOD feature: terrain" phase, now driven by `sim/worldgen`.
Related files: `CppSrc/sim/worldgen/chunk.h` (new), `CppSrc/bind/`, `scenes/levels/mini_main.tscn`.

## 4.1 Chunk sampler from worldgen (`chunk.h`)

### Concepts to master
- A chunk (64×64) samples the coarse world data (plate, elevation, biome per cell) + fine seeded octaves (fBm + ridge, chunk-local seed derived from world seed + chunk coords) → 64×64 float32 heights + biome/foliage masks.
- Chunk-local float32 for Godot meshes vs sim int64/fixed world coords (AGENTS precision contract).
- Sampling must be idempotent and cheap: same chunk → same data, no cross-chunk reads at fine scale (only coarse reads), so chunks are independent (streaming-friendly).
- Seam safety: fine noise must be a pure function of world coords (hash the coordinate, not the chunk), so chunk borders never tear.

### Exercises
1. Implement `sample_chunk(world, cx, cy)`: heights + biome mask + slope + foliage-density mask.
2. Bench: sample a 10×10 block of chunks headless; verify same chunk twice → identical floats.
3. Dump one chunk's heightfield as PPM; zoom-check that it matches the coarse map it samples.

**Check:** chunk sample < 1 ms; no visible seams when neighboring chunks are dumped side-by-side; determinism per chunk.

## 4.2 Dirty-chunk mesh rebuild → Godot ArrayMesh

### Concepts to master
- Mesh building from heightmap: vertex buffer (positions/normals/uv) + index buffer (triangles); Godot `ArrayMesh` / `SurfaceTool` (or raw `Mesh` API from bind).
- Dirty flags: chunk has `dirty` bool; rebuild only on edit/stream-in, never every frame. Idle chunks = zero mesh work.
- Triangle winding & normals: consistent winding for correct lighting; per-vertex normals from height gradients.
- Chunk-local float32 coordinates (no jitter beyond 10 km — AGENTS contract).

### Exercises
1. Implement `rebuild(chunk)` producing packed `PackedVector3Array/Array` for Godot.
2. GDScript side: receive dirty chunk IDs, rebuild only those, set on a `MeshInstance3D` per chunk.
3. Apply a brush; verify ONLY the affected chunk rebuilds (check mesh generation count in profiler).

**Check:** sculpting one spot rebuilds exactly 1 (or a small set of) chunks; idle frame does zero mesh work.

## 4.3 Streaming around the camera

### Concepts to master
- Radius streaming: load/generate chunks within R of camera, unload beyond R+margin; "biggest map possible" without holding it in memory.
- Load/unload queue: async generate on worker threads (job system from 2.3), hand off ready chunks to Godot main thread (SPSC from 2.3).
- Seam handling: chunks within R of column 0 also spawn their wrapped duplicate at column W−1 (and vice-versa); the camera crossing the seam re-centers smoothly — the player never sees an edge. Chunk coords are stored modulo W for sim identity, with render-local x for Godot.
- LOD (optional now): far chunks at lower vertex density — noted for later, not required Phase 4.
- Memory budget: ~512 MB ceiling (AGENTS); streaming radius sized by chunk size × footprint.

### Exercises
1. Walk the camera; keep 5×5 chunks resident, generate/unload as you cross chunk borders.
2. Ensure generation happens off the main thread (Tracy: generation zones on workers, never on Godot thread).
3. Measure: memory flat during a long walk, no frame spikes > 16.6 ms while streaming.
4. Walk the camera across the seam; verify the wrapped duplicates appear, chunks unload on the far side, and there is no visible edge, pop, or hitch.

**Check:** FPS stays stable while crossing chunk borders AND the world seam; memory footprint flat over a 10-minute walk.

## 4.4 Foliage placement from sim + delta persistence

### Concepts to master
- Sim-owned placement: foliage is DATA in sim (positions/types/variation arrays), not nodes — render materializes it into the MultiMesh.
- Placement rules: density from biome/foliage masks + slope + noise in sim (the masks from 4.1); per-chunk foliage arrays that stream with chunks.
- Delta persistence: save = seed + age + params + edits ONLY; world re-derives from seed. Edits = brush stamps + placed/moved foliage + (later) buildings.
- Save format: versioned binary, deltas keyed by chunk coords; loading = regenerate + replay deltas.

### Exercises
1. Add foliage array per chunk in sim; place ~100 instances/chunk from biome/slope/noise rules; expose to Godot as MultiMesh data.
2. Implement save/load: serialize seed + age + params + edit stamps + foliage edits; load → regenerate → apply deltas; verify bit-identical to before save.
3. Bench save/load for a 10×10 area; delta file should be kilobytes (not the full world).

**Check:** save after edits is small (seed + age + params + deltas), reload matches exactly (compare height arrays), foliage reappears in same spots.

### Phase 4 completion gate
- Chunks stream from worldgen data, deterministic, seam-free, < 1 ms each.
- Brush edits rebuild dirty chunks only; camera streaming with no main-thread stalls; memory flat.
- Foliage rendered from sim data; save = seed+deltas round-trips exactly.

---

# PHASE 5 — Deferred systems (concept mastery)

These come AFTER the foundation (AGENTS: "do not add gameplay systems before Phases 0–4"). Learn the concepts; do NOT implement yet.

## 5.1 Macro layer on top of worldgen data
- Concepts: the coarse world from Phase 3 IS the macro map — provinces drawn from biome + plate-boundary data (plate ID = province parent, boundaries = borders), river cells, elevation-constrained regions; adjacency graph over the coarse grid; factions seed on continent/plate clusters; trade routes follow land/ocean adjacency.
- Mastery check: province graph over a generated world builds in < 1 s headless; borders follow geographic features (rivers/mountains), not noise.

## 5.2 Procedural buildings (path → wall → masonry → roof)
- Concepts: footprint outline → wall segments → masonry (window/door placement rules, pattern grammar) → roof (gable/hipped via edge classification); L-systems as an optional alternative; building = graph, not mesh art.
- Mastery check: a one-line footprint in → valid building mesh out, every time; roof slopes drain water (no inverted faces).

## 5.3 Vic3-style economy
- Concepts: aggregated pop groups per province (NOT individuals); goods + market pools; supply/demand → price via clearance; dirty-flag recomputation (only touched markets tick); trade routes between markets; feedback loops + stability (why laissez-faire vs price caps oscillate).
- Mastery check: explain the dirty-flag model on paper; simulate 100 markets with 95% idle per tick and verify tick cost scales with dirty count, not market count.

## 5.4 4X layer
- Concepts: turn-based event loop on top of the 1 Hz tick; factions/AI personality budgets (spend per turn, not per frame); diplomacy matrices; fog-of-war & territory graphs; trade route edges = the macro↔zone bridge.
- Mastery check: 32 factions ticking in < 1 ms total; no faction iterates every frame.

## 5.5 Kenshi local sim (staggered AI + hierarchical pathfinding)
- Concepts: staggered AI — each agent thinks 1–4 Hz on a round-robin/offset schedule, not every frame; utility AI (needs + context → score actions); hierarchical pathfinding (region graph first, then local grid within region); avoidance vs pathfinding separation (local steering, global graph); combat as job-graph (pairs/triples, not O(n²) collisions).
- Mastery check: 1000 agents, 20 Hz movement, 2 Hz decisions, bounded per-tick budget; pathing a cross-world route takes ms, not seconds.

## 5.6 UI
- Concepts: Godot UI off the sim thread (UI reads snapshots only); event-driven refresh (dirty flags) not per-frame redraw; list virtualization for long lists; UI must never call into sim functions directly.
- Mastery check: opening a 1000-row market list is instant and stays stable at 60 fps while sim runs.

## 5.7 SIMD / polish pass
- Concepts: SIMD (SSE/AVX/NEON) via intrinsics or `std::simd`-style libraries; auto-vectorization (why SoA matters — loop vectorizes when arrays are flat); profiling-guided optimization: Tracy first, SIMD only where hot (the 20% that takes 80% of time).
- Mastery check: hot loops vectorize (check compiler report `-Rpass=loop-vectorize`); 2–4× speedup on identified hot spots, measured, not assumed.

---

# Cross-phase principles (revisit every phase)
1. **Determinism:** same seed + same inputs → same world. Nothing breaks this (fixed iteration order, fixed point where needed).
2. **The world is generated once, then frozen.** Drift runs at world creation only (`age` param); geography never changes at runtime — saves stay seed+deltas, the map stays stable for gameplay.
3. **The world is seamless:** a flat map with horizontal wrap-around (X = longitude, modulo width) — no hard edges anywhere; Y = latitude with poles at top/bottom. Never a sphere, never vertical wrap.
4. **Sim ≠ Godot:** sim owns data in SoA; Godot owns pixels. The boundary is snapshots and dirty flags only.
5. **Realism is verified headless:** every worldgen stage has a PPM dump — eyeball it in an image viewer BEFORE touching Godot.
6. **Dirty-flag everything:** idle work must cost ~nothing. If it ticks every frame, it's wrong by design.
7. **Bench before beauty:** every phase has a `bench/` proof. If it isn't measurable, it isn't done.
8. **Potato budget:** frame ≤ 16.6 ms, sim tick ≤ 2 ms, empty world < 1 ms, memory < ~512 MB, whole world gen < 1–2 s. Re-verify each phase.