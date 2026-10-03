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

- Static source parity and exact priority expression checked locally; `git diff --check` passes.
- Native shader compilation and `godot --headless --path godot --script res://tests/graphics_depth/variants.gd` and `res://tests/moth/validate.gd` are pending the exclusive native-engine grant. The variants test checks executable shader-body and material/uniform/LUT parity.
- Run the graphical Compatibility test **without `--headless`**: `godot --path godot --rendering-method gl_compatibility --resolution 1200x800 --script res://tests/graphics_depth/capture.gd -- /tmp/opencode/moth-depth-after after`. Require `high_pixels == 81` in every priority case and `order_controls_pass == true`; compare to a capture of the baseline commit on the same renderer/adapter/size. The unchanged priority shader still supplies that test's material.

Removing the explicit depth write from ordinary opaque materials may permit
ordinary early-depth handling on the Compatibility path; this is a **potential**
pipeline benefit, not an observed GPU-time or FPS improvement. No benchmark was
run. Runtime/package closure must include the new
`res://moth/surface_opaque.gdshader` (and its Godot import UID when generated).

## Weather integration dependency

`ambience/weather_look.gd` allowlists only the original Moth shader and
`ambience/wet_surface.gd` only anchors that shader for wet-sheen leasing. The
atmosphere owner must add the opaque shader to both allowlists with the same
roughness anchor to retain patterned wet response on general Moth surfaces.
Until then, its wet shader binding skips those surfaces. This is an explicit
integration prerequisite before shipping this branch's routing change.
