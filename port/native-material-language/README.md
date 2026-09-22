# Native material language — library and derived assets

One lane's half of the asset coverage pass: **named material families built from
the baked Moth set, a deterministic offline derivation tool for the maps the bake
lacks, and a review surface**. The other half (applying the families to real map
geometry) codes against the interface below.

* Interface contract: [HANDOFF.md](HANDOFF.md)
* Design language: [`godot/material_language/DESIGN.md`](../../godot/material_language/DESIGN.md)
* Measured coverage: [COVERAGE-AFTER.md](COVERAGE-AFTER.md) (baseline: [COVERAGE-BASELINE.md](COVERAGE-BASELINE.md))
* Evidence: `evidence/run-ez0umlsd/` (all steps passed; logs, 30 images, A/B JSON, summary)

## Deliverables

| Item | Where |
|---|---|
| Library (`families`, `describe`, `material`, `apply_to`, `normal_map`, `derived`, `coverage`, `budget`) | `godot/material_language/library.gd` |
| Eight family records (palette, normal, LUT accent, density, response) | `godot/material_language/families.gd` |
| One triplanar family shader | `godot/material_language/family.gdshader` |
| Review viewer (orbit, lighting cycle, F glow, N normals) | `godot/material_language/gallery.tscn` + `gallery.gd` |
| Review props (floor slab, wall, rail, prop, rounded object) | `godot/material_language/props.gd` |
| Capture layouts + measured A/B | `godot/material_language/sheet.gd`, `godot/tests/material_language/gallery_capture.gd` |
| Contracts test (family stability, cache reuse, derived determinism, budget, unknown-family failure) | `godot/tests/material_language/validate.gd` |
| Derived assets: 24 data, 2 normals, 2 masks + their manifest | `godot/moth/derived/**` |
| Derivation tool + tests + coverage scan | `tools/godot-moth/derive.mjs`, `derive.test.mjs`, `coverage.mjs` |
| Verification runner | `tools/godot-moth/verify_material_language.py` |

## How to run

```bash
# library contracts, then the whole lane with images and evidence
godot --headless --path godot --script res://tests/material_language/validate.gd
python3 tools/godot-moth/verify_material_language.py

# regenerate derived assets (byte-identical) and verify the committed bucket
node tools/godot-moth/derive.mjs
node tools/godot-moth/derive.mjs --check
node --test tools/godot-moth/derive.test.mjs

# review the look interactively (F glow, N normals, L lighting, 1-8 families)
godot --path godot res://material_language/gallery.tscn
```

## What changed in the asset set

* All 13 baked normals and all 5 baked LUTs now have named family consumers
  (baseline: ~1 normal, 2 LUTs).
* Textures referenced literally went from ~9 to 30 of 31; the library binds 25.
* 28 derived planes were added under their own bucket and manifest, derived from
  the exact shipped pixels; the 101-plane inventory asserted by
  `tests/package_inspect.gd` and `tests/moth/validate.gd` is unchanged.
* One shader, shared materials only. A station of 8 meshes renders in 8 draw
  calls with the language and 8 with one plain `StandardMaterial3D`: the swap adds
  none. Total payload 374 KB across 76 planes (1.29 MB VRAM estimate).

## Honest limitations

See DESIGN.md §9 (shallow baked normals, heuristic derived AO, near-black ice
tile, invisible-by-design regolith accent, 96 px/m density ceiling) and
COVERAGE-AFTER.md (the three keys still unused, and why the `void` sky key is
weaker evidence than the others). Nothing in this lane modifies world geometry,
collision, terrain, spawn, pickups or nav, and no arena compiler was re-run.
