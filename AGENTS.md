# AGENTS.md — Vanihala (Godot 4.6 C++/GDExtension project)

## What this repo is
A Godot 4.6 3D pixel-art base project with a custom C++ GDExtension (`Manaloka00`). Key systems: cel-shaded materials, custom post-process compositor effects, procedural terrain generation, and an RTS-style camera rig.

## Build system
- Native C++ is built via **SCons** from a separate source repo (`godot_test_gdextension`), NOT inside this repo.
- `Makefile` shortcuts exist but **hardcode an external path** (`/home/aandriam/Godot/godot_test_gdextension`).
  - `make` / `make all` — compiles the GDExtension (`scons compiledb=yes`).
  - `make clean` — cleans the external build.
  - `make re` — clean rebuild.
- The compiled `.so` is symlinked into this repo as `bin/linux/libManaloka00.linux.template_debug.x86_64.so`.
- The `.gdextension` file (`Manaloka00.gdextension`) maps the library load path.

## Architecture & entry points
- **Godot project root**: `project.godot` — configured for **Jolt Physics**, Forward Plus rendering, 1920×1080.
- **Main scene**: `scenes/levels/main.tscn` — instantiates the world, camera, lighting, and terrain.
- **GDExtension classes registered** (`CppSrc/register_types.cpp`):
  - `Summator` — trivial example class.
  - `traficLight` — UI texture-switching node.
  - `rtsCamera` — RTS-style camera (WASD, mouse rotate, zoom).
  - `terrainAPI` — procedural terrain (512×512 mesh generated via `antSim/terrain/` C++ module).
- **Key directories**:
  - `systems/` — GDScript gameplay systems (camera rig, main renderer, readme node).
  - `addons/` — reusable plugins/compositor effects (3D RTS camera, post-process levels).
  - `assets/shaders/` — custom `spatial` and `canvas_item` shaders; includes `shaderincs/` for `.gdshaderinc` reuse.

## Shaders & rendering pipeline
- **Cel shading**: `assets/shaders/spatial/cel_shader.gdshader` + `.gdshaderinc` helper.
- **Outlines/crease detection**: `assets/shaders/spatial/outlines.gdshader` — screen-space edge detection using depth/normal roughness.
- **Foliage**: `assets/shaders/spatial/foliage_cel_shader.gdshader` — billboard sprite foliage with sway and cel-ramp lighting.
- **Post-process**: `addons/compositor_effects/levels/post_process_levels.gd` — compute-based levels adjustment; requires `levels.glsl` SPIR-V shader.

## Important operational notes
- The `bin/` directory is a **symlink** to the external GDExtension build output. Do not commit binaries.
- `main.tscn` bakes large `MultiMesh` transform buffers inline — avoid editing that section by hand.
- The project uses custom input actions (`rotate_left`, `rotate_right`, `zoom_in`, `zoom_out`, etc.) defined in `project.godot`.
- Physics engine: **Jolt Physics** (set in `project.godot`).

## What NOT to do
- Do not run `scons` directly in this repo — it will fail; build happens in the external `godot_test_gdextension` repo.
- Do not modify `.gdextension` paths unless the build output location changes.
