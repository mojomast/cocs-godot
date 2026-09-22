# Shader-lab integration contract

Baseline: **`7bfb473`**. Branch: **`graphics/shader-lab`**. Owned paths are `godot/shader_lab/`, `godot/tests/shader_lab/`, and `port/native-shader-lab/`.

## Lead launcher hook

Register the **native-only** experience **`--experience=shader-lab`** with scene **`res://shader_lab/demo.tscn`**. This is an offline material gallery: it needs no map, mode, endpoint, authority or session. All scene resources are self-contained apart from the inherited `godot/moth/` library/assets.

At the baseline, `tools/godot-dev/launch_options.mjs` assumes every non-combat experience has a locked map/mode, and `tools/godot-dev/launch.mjs` starts an authority for every local experience. The lead should add a standalone-presentation route (also reusable by the particle lab) that returns a plan equivalent to:

```js
{
  args: ['--path', 'godot', 'res://shader_lab/demo.tscn'],
  sessionOptions: [],
  experience: 'shader-lab',
  smoke: null,
  endpoint: null,
  standalone: true,
}
```

Have `launch.mjs` skip authority creation and endpoint injection for `standalone` plans. Reject map/mode/endpoint/gameplay flags for this route, add it to help and launcher tests, and retain normal engine version/import checks. Merely inserting a `scene` entry into `EXPERIENCES` will still hit the baseline map/mode validation. This hook is intentionally returned to the shared launcher owner.

Direct native entry already works:

```sh
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
"$GODOT_BIN" --path godot --rendering-method gl_compatibility \
  --resolution 1280x800 res://shader_lab/demo.tscn
```

## Reusable factory API

```gdscript
const ShaderLab = preload("res://shader_lab/factory.gd")
var effects := ShaderLab.new() # main thread; keep for the owning scene's lifetime
var material := effects.create_material("conduit", {
    "material": "brushed_metal",
    "palette": "solar",
    "intensity": 0.9,
})
mesh_instance.material_override = material

# Supply ABSOLUTE local presentation seconds from the caller's pause/replay clock.
effects.update_time(presentation_seconds)
effects.configure(material, {"intensity": 1.2})
var debug_snapshot := effects.material_state(material)
var budget_snapshot := effects.state()

# Replay/scene reset restores each live material's creation options and time zero.
effects.reset()
# Optional explicit release before the mesh/material is freed:
effects.release(material)
# On owning scene teardown, discard tracking. Live external materials stay valid.
effects.clear()
```

Public methods:

| Method | Contract |
| --- | --- |
| `create_material(effect, options={})` | New caller-owned `ShaderMaterial`, or null for unknown effect / full 64-live-material budget. Shader and source textures are shared immutable resources. |
| `configure(material, changes)` | Merge and sanitize named options. False for foreign/released/null material. Resource changes rebind the named sources; ordinary changes update uniforms only. |
| `update_time(seconds)` | Finite numeric absolute seconds, clamped to **0–3600**. Allows backwards seek. NaN/Inf/wrong type returns false and preserves the previous clock. No raw `TIME`, wall clock, wrapping or automatic advancement in the factory. |
| `state()` | Caller-owned `{time, materials, limit, shared_shaders, moth_cache}`. Prunes dead weak references. |
| `material_state(material)` | Caller-owned `{effect, time, options}` or `{}`. |
| `reset()` | Restore each live material's original sanitized creation options; set time to zero. |
| `release(material)` | Stop tracking/updating this caller's material. It remains valid at its last state. |
| `clear()` | Drop all tracking and set factory clock zero. Does not mutate live external materials or the shared Moth cache. |

The factory owns no mesh, timer, node or material strong reference. Pruning happens on create/time/state/reset. The gallery releases its entire scene normally, and teardown is tested. Callers should use `configure` rather than bypassing finite bounds with raw uniform writes.

### Names and options

Effects: **`shield`**, **`conduit`**, **`phase`**.

Named materials:

| Option | Moth albedo / normal |
| --- | --- |
| `holographic_grid` | `holographic_grid` / `holographic_grid` |
| `brushed_metal` | `brushed_metal` / `metal` |
| `circuit_board` | `circuit_board-etch` / `metal` |
| `riveted_armor` | `riveted_armor` / `metal` |
| `hex_paneling` | `hex_paneling` / `hex_paneling` |

Palettes: **`ion`** (cyan/violet), **`solar`** (amber/cyan), **`orchid`** (violet/mint). `lut` accepts the inherited `entanglement`, `entanglement-arcane`, `entanglement-ember`, `entanglement-ceramic`, and `entanglement-void` names. Unknown named values fall back to the effect's defaults. Arbitrary resource paths are not accepted.

Defaults: shell = holographic grid / ion / arcane LUT; conduit = brushed metal / solar / ember LUT; phase = riveted armor / orchid / arcane LUT.

| Numeric option | Range | Default |
| --- | --- | --- |
| `intensity` | 0–2.5 | 1.0 |
| `opacity` (shell) | 0–0.8 | 0.68 |
| `texture_scale` | 0.1–4 | 1.0 |
| `texture_saturation` | 0–1 | 0.28 |
| `normal_strength` | 0–0.65 | 0.2; phase creation default 0.38 |
| `field_strength` | 0–1 | 1.0 |
| `lut_strength` | 0–2 | 0.65 |
| `lut_phase` | 0–1 | 0.8 |
| `dissolve` (phase) | 0–1 | 0.43 |
| `edge_width` (phase) | 0.015–0.2 | 0.065 |
| `height_span` (phase, local units) | 0.1–20 | 2.4 |

Non-finite/wrong-type numeric input uses the finite table default (`normal_strength` fallback is 0.2). `effect_enabled` is a strict boolean, default true; false removes the shell coverage, conduit emission, or phase cutoff/edge respectively. The phase threshold is independently caller-controlled: advancing time shimmers the edge but does not implicitly remove more of a prop. At 0% it is fully intact, at 100% all prop fragments are discarded. Intensity changes emission/coverage, not scene lighting.

## Material behavior and use recommendations

- **Shell:** use a closed outward-facing sphere or shell with sensible UVs and normals, viewed from outside. Back-face culling, alpha mix, normal opaque depth testing, **no transparent depth writes**; alpha is explicitly capped at 0.8. Set the shell node's `cast_shadow` to `SHADOW_CASTING_SETTING_OFF`, as the gallery does. Put solid details inside to make translucency readable. Several intersecting transparent shells can still have ordinary alpha-sort limitations; that configuration is unverified.
- **Conduit:** use a stable UV-mapped tube, reactor or accent panel. UV.x defines eight channels and UV.y the packet travel direction. Base/normal texture detail is object-triplanar; source flow-field RG bends the channels and packet phase. This is one opaque depth-writing surface, suitable for an object accent rather than a map-wide pass.
- **Phase:** use a static prop with normals, centered local geometry, and `height_span` matching its local Y size. No UVs/tangents are required. Combined subparts should share the same local mesh origin to keep a continuous cutoff (the gallery assembles its module once). Ordinary opaque depth writes plus `discard` leave real holes; no transparent full-mesh sorting is involved. Keep this a presentation-only transition on static props. The shader does not alter collision or gameplay visibility.
- All motion is per-fragment uniform-driven. No vertex displacement, per-frame mesh generation, camera/full-screen effect, particle system, screen/depth texture dependency, glow, SSAO or Forward+-only feature is used.
- Albedo and the shield RGB motif use `source_color`; **normal RGB including Z, flow/macro fields, and RGB R/T LUTs stay linear**, with no normal repacking hint. Palette saturation/gain are runtime artistic parameters; original Moth bytes are untouched. The inherited `surfaces.create_surface` is used for gallery hardware/stage details.
- Moth source texture/effect alpha is never mistaken for transparency. The shell uses the first exact `effect-shield` frame's RGB as a moving surface motif and derives coverage from rim/patterns. The source's opaque alpha cannot create a card rectangle. Conduit ignores source alpha; phase uses a scalar macro-organic threshold and opaque discard.
- Original LUTs are sparse grayscale masks, not color gradients. R/T half-phase sampling stays linear. Shell/conduit address them through a Fresnel coordinate; phase also uses its threshold field so the flat cut-front can reach a nonzero source region. Named palettes supply the color. Shader outputs and public controls are bounded.
- Prefer a small number of hero/object accents. The 64-material factory limit is a resource-lifecycle bound, not a tested performance budget for 64 simultaneous full-screen shells. Keep `texture_scale` near 1 and default intensities around 0.7–1.2; the maximum exists for inspection.

## Export resources / package owner hooks

1. Include **all `godot/shader_lab/**`**, including **`moth_common.gdshaderinc`**, alongside inherited `godot/moth/**`. The factory preloads all three shaders; `demo.tscn` preloads the gallery script. These are native resource paths, not external filesystem paths.
2. Moth lookup is dynamic: `library.gd` reads **`res://moth/generated/manifest.json`**, then loads imported PNG paths. Add **`moth/generated/*.json`** to every applicable export preset's `include_filter`, preserving existing content. At baseline this is needed in both `godot/export_presets.cfg` and the preset string generated by **`tools/godot-package/build.py`**. The lead may already have the same Moth hook from the base graphics lane.
3. Keep **`export_filter="all_resources"`** and import the assets before export, or explicitly include the Moth PNGs when using a selected-resource export. The runtime option set can address every named material and every LUT above. `effect("effect-shield")` currently loads the whole inherited sequence even though this shader samples its first frame; include all of that sequence. Preserving all `moth/generated/**` is simplest and keeps the shared library contract intact.
4. The baseline package builder's tracked `godot` file collection automatically includes this runtime directory once committed; custom allowlists must include `.gd`, `.gdshader`, `.gdshaderinc`, `.tscn`, inherited Moth PNG/import resources and the manifest. Exclude `godot/tests/shader_lab/` and `port/native-shader-lab/` from a player package.
5. The lead should test the final exported native app by opening the gallery and instantiating each factory effect/preset from the PCK. This lane verified imported native project rendering, not the lead's final package or launcher route.

Verification command, accepted screenshots, exact quantitative findings, software-only frame proxy and preserved failures: **[README.md](README.md)**. No paid assets/services or additional source assets are required.
