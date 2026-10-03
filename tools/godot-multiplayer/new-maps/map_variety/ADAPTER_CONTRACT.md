# Shared Moth material adapter contract

`tools/map-variety-pipeline/material_adapter.py` is **Sol-owned**. The three map
builders (`*/asset_author.py`) and the kit do not implement Moth binding; they
import the adapter through
`tools/godot-multiplayer/new-maps/map_variety/material_adapter_contract.py`.
Until this module exists, `--plan` runs (pure Python) and `--build` fails with
`MISSING SOL ADAPTER HOOK`.

## Exact interface

```python
def load_materials(root: pathlib.Path, bindings: dict) -> tuple[dict, dict]:
    ...
```

* `bindings` is the per-map `variety_bindings.json` (`schema
  map-variety-bindings/v1`). Materials are keyed by the **exact GLB material
  name**.
* Returns `(materials, density)`:
  * `materials[name]` is a `bpy.types.Material` for every key, preserved
    materials included;
  * `density[name]` is that material's tiles-per-metre (`0 < d <= 16`), matching
    `bindings['materials'][name].tilesPerMeter`.

## Resource resolution

For each non-preserved binding, resolve
`manifest.materials[resource].channels[channel]` -> `manifest.textures[key].path`
against the merged candidate pack
(`assets/moth/map-variety-20261003/candidate-v2/manifest.json` plus the
`candidate-v3` overlay). Bind by **ID/channel key**, never by array position or
file glob. Reject unknown resource ids, missing channels and PNG hash mismatches.

## Channels and colour management

All five pack channels are **linear, including albedo**.

* Set every image `colorspace_settings.name = 'Non-Color'`.
* Albedo connects to the shader's linear Base Color. The PNG bytes are **not**
  re-encoded here; the glTF base-color sRGB encoding is the exporter stage's job.
* Normal is OpenGL **+Y** (image rows down, UV v up) into a Normal Map node
  (tangent space) at the binding `normalStrength`.
* Roughness drives Roughness. Height/wear are decorative inputs only, never
  collision authority.
* Preserved materials (`glass`, `water`, emissive/`letter`) keep no Moth texture.

## Why this must not be guessed

The kit builder must not invent fallback colours, world-coordinate shaders or a
global palette. Acceptance depends on the exported albedo/normal/roughness bytes
matching the pack PNG hashes; a guessed adapter produces unbindable evidence.
