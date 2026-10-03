# Moth opaque surface depth split

`moth/surface_opaque.gdshader` is the general Moth surface: the triplanar albedo,
world-space normal, roughness, metalness, vertex colour, and optional LUT code is
statement-for-statement identical to the priority variant, with no `DEPTH`
assignment. `moth/surface.gdshader` remains the priority variant for the authored
coplanar world terrain; its exact `FRAGCOORD.z + (vertex_tint ? UV.x * 0.000001 : 0.0)`
bias is unchanged. `MothSurfaces.create_surface(..., priority = true)` opts into
that variant at `world/environment_style.gd:terrain_material`. Ordinary uses,
including Aurora Basin's vertex-tinted meshes (whose UV.x is zero), select the
opaque variant. No texture, gain, tint, normal, LUT, or lighting policy changed.

## Verification / acceptance

- Repeatable source parity and exact priority expression: `python3 godot/tests/graphics_depth/check_shader_parity.py` (runs without the engine); `git diff --check` passes.
- Native GDScript parsing/shader compilation and `godot --headless --path godot --script res://tests/graphics_depth/variants.gd`, `godot --headless --path godot --script res://tests/world_weather/spatial.gd`, and `godot --headless --path godot --script res://tests/moth/validate.gd` are pending the exclusive native-engine grant. These scripts parse the changed weather code and variant fixture. The variants test checks executable shader-body and material/uniform/LUT parity; the spatial weather test exercises both Moth shader leases, patterned wetness, original uniforms and textures, dry state and repeated restore. Run `godot --path godot --rendering-method gl_compatibility --script res://tests/world_weather/spatial.gd` for actual shader-uniform reflection; headless's dummy renderer can lack reflection and falls back to parsing uniform declarations.
- Run the graphical Compatibility test **without `--headless`**: `godot --path godot --rendering-method gl_compatibility --resolution 1200x800 --script res://tests/graphics_depth/capture.gd -- /tmp/opencode/moth-depth-after after`. Require `high_pixels == 81` in every priority case and `order_controls_pass == true`; compare to a capture of the baseline commit on the same renderer/adapter/size. The unchanged priority shader still supplies that test's material.

Removing the explicit depth write from ordinary opaque materials may permit
ordinary early-depth handling on the Compatibility path; this is a **potential**
pipeline benefit, not an observed GPU-time or FPS improvement. No benchmark was
run. Runtime/package closure must include the new
`res://moth/surface_opaque.gdshader` (and its Godot import UID when generated).

## Weather integration

`ambience/weather_look.gd` recognizes both Moth shader paths, and
`ambience/wet_surface.gd` leases both using their identical roughness anchor.
Weather still duplicates materials per binding, changes roughness and metalness
only on the copy, then restores each original material on clear. Neither the
world-terrain priority lease nor ordinary opaque sheen depends on an implicit
shader resource identity. No atmosphere colour or brightness values changed.
