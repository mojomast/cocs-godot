# Moth asset coverage — after the coverage pass

Same method as `COVERAGE-BASELINE.md`: a literal scan of `godot/**/*.{gd,gdshader,
gdshaderinc,tscn,tres}` for each key in `godot/moth/generated/manifest.json`.
Reproduce with `node tools/godot-moth/coverage.mjs --json=port/native-material-language/coverage-after.json`.
The machine-readable report (per key, per file) is `coverage-after.json`.

## Totals

| Bucket | Keys | Baseline referenced | Now referenced | Now unused |
|---|---:|---:|---:|---|
| textures | 31 | ~9 | **30** | `industrial_mesh` |
| **normals** | **13** | **~1** | **13** | — |
| sky | 5 | 2 | 5 | — |
| materials (LUTs) | 5 | 2 | 5 | — |
| effects | 10 | 3 | 8 | `effect-capture-ring`, `quantum-rift` |
| **all keys** | **64** | **~17** | **61 (95.3%)** | **3** |

Two independent scans are computed: `literal` (substring) and `strict`
(identifier-delimited with `[A-Za-z0-9_-]` boundaries). Both report 61/64, so the
result is not an artifact of short keys matching inside longer words.

## What the material language consumes

* **All 13 baked normals.** Every family binds exactly one, and the family table
  names it: `hex_paneling`, `holographic_grid`, `metal`, `metal_grating`,
  `diamond_plate`, `grass`, `rough_stucco`, `weathered_concrete`, `sand`, `rock`,
  `ice`, `hazard_stripes`, `corrugated_metal`.
* **All 5 LUTs**, each at a declared phase and with a documented accent
  behaviour: `entanglement-ceramic` (pearl, enamel), `entanglement` (alloy, ice),
  `entanglement-void` (copper, regolith), `entanglement-arcane` (membrane),
  `entanglement-ember` (hazard).
* **30 of 31 textures** are referenced somewhere in `godot/**` (21 as family base
  atlases across the 22 variants, `flow-field` as the linear pulse field, the rest
  as normal or mask sources named in the family table); the *library itself* binds
  25 distinct texture keys, which is the number `Language.coverage().counts`
  reports. `industrial_mesh` remains unused and is not claimed.
* The runtime view (from `Language.coverage()`, captured in the evidence JSON)
  reports 25 textures / 13 normals / 5 LUTs / 28 derived keys bound and an
  `unused_total` of 11: six textures that other lanes consume
  (`carbon_fiber`, `circuit_board`, `dust-field`, `holographic_grid`,
  `industrial_mesh`, `rough_stucco`) and five effect sheets.
* **Derived bucket**: 28 generated planes (24 data, 2 normals, 2 masks), all 28
  mapped to at least one consumer by `Language.coverage().derived_keys`. The
  literal scan sees only 4 of them because the runtime builds those names by
  construction (`"data--" + albedo_key`); the family table itself names the two
  derived *normals* and the two *masks* literally.

## Caveats (deliberately not papered over)

* `effect-capture-ring` and `quantum-rift` remain unused by any lane that this
  scan can see; they belong to the VFX presentation lane, not to the material
  language, and are not counted as covered here.
* The sky bucket's five keys are consumed by the atmosphere/map lanes
  (`graphics_atmosphere/atmosphere.gd`, `cinder_array`, `aurora_basin`,
  `identity_maps`), not by this lane. The `void` key also matches the GDScript
  `-> void` return type in several files, so its "referenced" status is weaker
  evidence than the other four; the atmosphere lane's `"sky": "void"` entries in
  `coverage-after.json` are the real reference.
* The literal scan cannot see keys reached through variables or dictionaries; it
  is a lower bound, exactly like the baseline. `Language.coverage()` is the
  runtime view and reports consumers per family/variant.
* The applying lane owns what actually lands on the six playable maps. This
  document measures the library and its reachable asset surface, not the applied
  result.

## Unused list, exactly

| bucket | unused keys |
|---|---|
| textures | `industrial_mesh` |
| normals | *(none)* |
| materials | *(none)* |
| effects | `effect-capture-ring`, `quantum-rift` |

## Runtime coverage API

`Language.coverage()` returns, in one call: the family list, `keys`
(`bucket/key → [family/variant, …]`), `derived_keys` (`derived key → consumers`),
`unused` (per bucket, computed against the live manifest), the recorded external
effect consumers, and counts. The contract test asserts that every baked normal
and LUT has a family, that every coverage key exists in the bake, that every
derived key exists in the derived manifest, and that the unused total is bounded.
