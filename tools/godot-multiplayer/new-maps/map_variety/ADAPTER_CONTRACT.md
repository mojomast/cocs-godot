# Shared Moth adapter integration

The canonical adapter is Sol-owned, committed in `6ff4079e` at
`tools/map-variety-pipeline/{material_adapter,material_pack}.py`. Do not copy a
different adapter into this namespace. Heavy production requires that committed
adapter (plus its owner-approved fixes) in the integration worktree.

## Exact callable and normalization

```python
load_materials(root, bindings, *, output_dir=None, with_report=False)
```

Canonical `bindings` is a PBR-only dictionary keyed by exact exported material
name. Each value is `{material: packID, role: surface|team, normal: bool,
metallic?: float}`; a team binding additionally requires
`teamColorSource: COLOR_0`. With `with_report=True`, the result is
`(materials, densities, receipt)`; otherwise it is `(materials, densities)`.

These candidates have a richer map registry (`variety_bindings.json`).
`map_materials.adapter_bindings()` explicitly normalizes each surface binding's
`resource` to `material`, supplies `normal: True`, and excludes preserved entries.
Unknown registry roles/maps/preserved names fail closed. The canonical adapter
deliberately rejects `preserve`; none are sent to it.

Map-owned `map_materials.PRESERVED` transcribes accepted Helix glass and Vesper
glass/water/letter palette and BRDF constants with source references. Vesper's
accepted letter material is opaque, not emissive. The new Helix grotto pool has
an explicit candidate liquid BRDF using Helix's green palette; it does not claim
an inherited accepted water material. Parallax's accepted opaque sea palette
and BRDF are preserved too, including its original palette-to-linear exponent.

The builder applies the registry's reviewed normal strengths and UV densities
after loading; original pack densities remain in the adapter receipt, with map
overrides recorded separately. No world-coordinate texture mapping is used.

## Colour, normals, roughness, and portable masters

All immutable pack channels are linear. The adapter resolves pack IDs/channel
keys and verifies manifest hashes. It derives a separate sRGB-encoded albedo PNG
and binds it as an sRGB image. Original PNGs remain unchanged. Normals are
Non-Color OpenGL +Y; roughness reads the source red channel.

`map_materials.load_reviewed_materials()` packs every bound texture image before
saving the editable master and changes external image paths to relative packed
references. Build and reopen-export both reject unpacked material images.
The complete adapter receipt (pack hashes and source/converted image hashes),
explicit preserved BRDFs, and map overrides are stored in the scene and report.

`export_audit.py` verifies actual embedded GLB images with standard-library PNG
decoding: albedo RGB must equal IEC linear→sRGB transfer (one-byte quantization
tolerance), alpha must be unchanged, normal pixels must match the immutable
OpenGL source, and packed roughness G must match source roughness R. It verifies
normal strength and tangent attributes too. Source and derived/export hashes
are distinct evidence fields, never incorrectly required to be identical.

Total triangles use a **150000-triangle advisory target**, not an acceptance
ceiling. Source plans, evaluated scenes and exported GLBs report `triangleAdvisory`
(the evaluated build field is `evaluatedTriangleAdvisory`): `policy: advisory`,
`measurement`, `totalTriangles`, `targetTriangles`, `overTarget`,
`overageTriangles`, and `status: pending-performance-visual-review`. Even a
below-target measured count does not imply native acceptance. Higher counts are
reviewed using actual renders, loading, memory and gameplay performance.

The 24000-triangle per-source/batch constraints, 64-primitive limit, valid integer
counts, export topology and material/pixel checks remain strict. Plans are
unmodified-source estimates, not measurements; Blender evaluation and native
acceptance run serially under the heavy owner after integration.
