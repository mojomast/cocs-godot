# Handoff — material-language library (interface + integration notes)

Audience: the material **application** lane, and lead. Everything here is
implemented and green in this worktree; no other lane's files were edited.

## 1. Frozen interface

```gdscript
const Language = preload("res://material_language/library.gd")

Language.families() -> PackedStringArray            # 8 stable ids, tab order
Language.describe(family) -> Dictionary             # {} for unknown
Language.material(family, options := {}) -> Material   # null for unknown/overflow
Language.apply_to(node, family, options := {}) -> int  # surface slots assigned
Language.normal_map(key) -> Texture2D               # baked first, derived fallback
Language.derived(key) -> Texture2D                  # exact key, or bare source name
Language.coverage() -> Dictionary                   # consumers per key + unused list
Language.budget() -> Dictionary                     # PNG/VRAM bytes, caps, materials
Language.DEFAULT_FAMILIES                           # PackedStringArray (static, read-only by convention)
```

Extras the applying lane may use: `has_family`, `variants(family)`,
`set_clock(seconds)`, `set_glow(bool)`, `cache_stats()`, `clock_follows_engine()`,
`reset()`.

Family ids: `pearl-ceramic`, `enamel-glaze`, `brushed-alloy`, `oxidised-copper`,
`bioluminescent-membrane`, `regolith`, `polar-ice`, `hazard-industrial`.

## 2. Semantics that matter

* **Shared materials.** `material()` is a cache keyed by
  `family + canonical options`. Identical calls return the *same*
  `ShaderMaterial` object. Never clone it per surface.
* **`apply_to(node, family, options)`** walks the subtree:
  * `MeshInstance3D` → `set_surface_override_material(i, shared)` for every
    surface; returns the count of surface slots assigned.
  * `MultiMeshInstance3D` → `material_override = shared` (this *replaces* an
    existing batch override, e.g. a scenery plate batch); counts the batch's
    mesh surface slots once, not the instance count.
  * Anything else is skipped; the return value is the total surface slots
    assigned. Unknown family → 0 and nothing is touched.
* **Options** are bounded and canonicalised to 4 decimals; unknown keys and
  non-finite numbers are ignored (never forwarded to the shader):
  `variant` (string, from `variants(family)`), `tint` (Color),
  `tiles_per_metre` [0.05, 4], `texture_strength`, `texture_saturation`,
  `albedo_gain` [0, 12], `normal_strength`, `detail_strength`, `ao_strength`,
  `detail_fade` [2, 200] m, `roughness`, `roughness_variation`, `metallic`,
  `specular_strength`, `lut_phase`, `lut_gain` [0, 4], `lut_t_gain`,
  `lut_fresnel_bias` [-1, 1], `accent_mask_strength`, `accent_crease_strength`,
  `pulse_speed` [0, 2], `pulse_depth`, `glow` (bool).
* **Clock.** By default materials follow engine `TIME`, so animated accents live.
  Call `set_clock(seconds)` if you need a deterministic phase (captures, replays);
  `clock_follows_engine()` tells you which mode you are in.
* **Glow.** `set_glow(false)` removes the LUT accent from every cached material —
  the intended user-facing quality switch. The look is designed to hold with glow
  off (see the `*-glow-off.png` evidence).
* **Unknown family** returns `null` / `{}` / `0` / `null` — fail closed, no
  partial application. The cache cap is 96 materials; overflow returns `null` and
  increments `cache_stats().rejected` (no log spam).

## 3. Applying it

`describe(family)` returns label, story, roles, palette, variants, base
textures, the normal (with `resolved` = `baked:<key>` / `derived:normal--<key>`),
the emissive record (LUT, phase, gain, colour, documented behaviour), density
(tile px, tiles/m, px/m, triplanar), response (roughness, variation, metallic),
budget and sampler count. Suggested role mapping is in DESIGN.md §2; it is a
suggestion, not a constraint.

Two integration warnings:

1. **This shader writes normal opaque depth.** `res://moth/surface.gdshader` adds
   a `1e-6 · UV.x` coplanar priority bias for semantic support surfaces. If you
   replace a material that relied on that, report it to lead rather than assuming
   the bias carries over.
2. **No IBL in the scenes we captured.** Metallic above ~0.5 goes dark under
   plain directional lighting in GL Compatibility, which is why `brushed-alloy`
   ships at 0.45 metallic. If you apply families in a scene with reflection
   probes or a sky, re-check the metal reading.

## 4. Derived assets

`node tools/godot-moth/derive.mjs` regenerates `godot/moth/derived/**`
(28 PNGs + `manifest.json`). Each record carries the source key and its bake hash,
the algorithm id, the full parameter set, measured stats, and a SHA-256 for the
pixel plane and the file. `--check` re-derives into a temp directory and compares
bytes with the committed bucket; `node --test tools/godot-moth/derive.test.mjs`
does the same twice plus import-policy checks. The tool also repairs
`detect_3d/compress_to=0` in its own `.import` files after Godot rewrites them —
do not hand-edit those.

Runtime lookups: `Moth.derived_manifest()`, `Moth.derived_texture(key)`,
`Moth.derived_keys()`, `Moth.derived_cache_stats()` (separate bounded cache, so
the baked 101-plane accounting is untouched). `Language.derived(key)` accepts the
full key (`data--rock`) or the bare source name (`rock`).

## 5. Evidence in this worktree

`python3 tools/godot-moth/verify_material_language.py` runs, in order: a
parse/compile check, the derived tests, the literal coverage scan, the moth
contract (101 planes), the material-language contract, the shader-lab contract,
the moth-scenery verify, the VFX regression, the viewer smoke, Godot import,
then private-Xvfb captures at 960x640 and 1280x800 (both sheets, grazing floors,
five close families, viewer screenshots). The normal/glow A/B is measured
pixel-by-pixel on the single-viewport family panels (the sheets skip it for
software-render budget) and the toggled frames are saved next to each panel. Each
step runs in its own process group so a timeout can never leave an orphan
renderer behind. Everything is retained under
`port/native-material-language/evidence/run-*/` including failures; the accepted
run is referenced in the README.

## 6. Left for others

* Applying the families to the six playable maps and the nine locked maps
  (render-only, arena hashes unchanged) — the other lane.
* `industrial_mesh` texture and the `effect-capture-ring` / `quantum-rift` effect
  sheets remain unused; they belong to other lanes or to a later pass.
* A dedicated collision/OCC map, LOD bands and terrain blending are out of scope:
  this lane is render-only, and `apply_to` never touches collision or nav.
