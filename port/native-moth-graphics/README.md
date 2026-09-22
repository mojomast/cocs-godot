# Native Moth assets and surfaces

Complete offline conversion and runtime surface lane, based on `b0ac0b5`.
Integration contract, exact unapplied build/world hooks, APIs, sampling details and limitations: [HANDOFF.md](HANDOFF.md).

## Accepted verification

Final evidence is [evidence/run-c62wpwed/summary.json](evidence/run-c62wpwed/summary.json). All seven steps pass: independent offline export tests, Godot import, native runtime/hash tests, both material resolutions, texture contact sheet, and sky/LUT/effect contact sheet. Pinned engine: `4.5.2.stable.official.6ce3de25a`; native GL Compatibility on Mesa llvmpipe. The expected software-driver V-Sync warning is retained. No script, shader or resource errors in the accepted run.

Images actually opened and visually inspected after the final shader change:

* [Material comparison — 960×640](evidence/run-c62wpwed/materials-960x640.png)
* [Material comparison — 1280×800](evidence/run-c62wpwed/materials-1280x800.png)
* [All 31 textures + 13 normals — 1280×800](evidence/run-c62wpwed/textures-1280x800.png)
* [All 5 skies + 10 LUT planes + 42 effect frames — 1280×800](evidence/run-c62wpwed/extras-1280x800.png)

The material sheet compares identical no-UV meshes under identical cameras/lights: semantic color, world-triplanar texture with normals, and the same surface plus a linear LUT accent. Source patterns visibly survive on top/front/side faces. Concrete shows soft mottled texture, hex paneling reads as a restrained teal grid, diamond plate retains the source's purple/green motif with reduced saturation, and the unusually dark original rock tile remains visibly crosshatched. Normal contribution is intentionally subtle, verified by an actual rendered toggle rather than a uniform-only assertion.

At 1280×800, turning normals off changes **4,907 / 1,124 / 1,150 / 1,893** pixels above the defined RGB-difference threshold across the four material rows. Disabling vertex tint changes **16,308 / 16,296 / 16,331 / 16,089** pixels. The optional LUT changes **1,807 / 1,746 / 1,687 / 1,955** pixels. Full per-row measurements at both resolutions are adjacent `*.png.json` files. The screenshot dimensions are asserted against the requested size.

All **101 imported base images** reproduce the exact original decoded byte hashes, including RGB LUTs. Source alpha is preserved; all shipped effect alpha bytes are opaque, so effect compositing must be selected by the consumer rather than inferred as transparency.

## Preserved discovery/failure evidence

* `run-0x6bjhoq`: native exact-byte validation **failed** for linear normal/data textures because PNG `gAMA=1.0` caused Godot decoding conversion. Full failure log retained. Fixed by leaving linear PNG data untagged and expressing color space through the shader sampler/manifest. The independently decoded PNGs already matched; this failure demonstrates why native import validation is necessary.
* `run-b913q7vt`: pixel validation passed, but visual inspection found the file called `materials-960x640.png` was actually 1280×800 with unused margins. That run's summary predates dimension assertions and is **not accepted as 960×640 evidence**. It also retains the earlier over-bright material treatment. Fixed by passing Godot `--resolution` explicitly and asserting actual screenshot dimensions; lighting, gain and saturation were tuned after inspection.
* `run-cfg0z733`: corrected resolution, tuned surfaces, and expanded normal/vertex-tint/LUT A/B tests all passed. The final shader adjustment makes unknown-key fallback exactly plain tint, so `run-c62wpwed` supersedes these material captures.

## Scope and limitations

No shared world/session/viewer/environment/build/CI code was edited. This delivery supplies committed resources, runtime lookup, textured surface rendering and evidence; the lead applies semantic mapping/terrain grouping and package hooks. No full-map, full-package, hardware-GPU, web, or Three.js pixel-parity claim is made. The source skies/LUTs/effects retain their existing darkness and sparse content. Asset-rights findings remain unresolved as recorded in the source audit; this conversion provides no new clearance.
