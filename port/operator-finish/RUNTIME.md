# Operator finish runtime integration

## Install order and exact content dependencies

FPS collects original source materials and installs its private team alias, sets
the initial team, builds fitted overlays, then calls the instance binder once.
Team switches retain the original `team_material` alias and update its color plus
the binder's body/overlay clones in place. The SVG updater runs only in fallback.
Identity changes clear bindings before freeing the old source. Binding duplicates
the unmodified source/overlay base each time; it does not compound texture tint.

Runtime requires the content lane's exact paths:

- `godot/source_operators/moth_finish/manifest.json`
- `godot/source_operators/moth_finish/profiles/{chatgpt,claude,grok,meta,gemini,deepseek,mistral,kimi,qwen}.json`
- Real PNG resources referenced under `res://source_operators/moth_finish/assets/`.

Profile v1 / manifest v1 are as defined in `CONTRACT.md`. All three numeric finish
fields are required finite numbers in `[0,1]`; optional normal/roughness maps are
omitted if absent. For a roughness map, `roughness_gain` is its scalar multiplier:
the actual L8 pixels already encode perceptual roughness, so gain 1 samples them
directly without multiplying the original material scalar. Without a roughness map,
the original scalar is multiplied by the gain. `metallic` supplies the finish scalar.
Texture RGB modulates the original palette
once. No runtime source-engine authority or provenance claims are made.

The source-only closure validator consumes the delivered top-level `textures`
table keyed by resource path: `png_sha256`, `dimensions`, `channels`, `color_space`,
`moth_keys`, `pixel_sha256` and `derivation`. It verifies every used resource and
all 63 finish tokens, then follows each texture's real Moth input keys to
`provenance.moth_sources` and the existing Moth registry. Source PNG hashes,
dimensions, recorded pixel hashes/color spaces, generator, original catalog,
GLBs, art references and baked registry source hashes must agree. Content's own
validator additionally decodes pixel hashes and normal vectors; deterministic
reproduction is a separate check. Both were run successfully after content merge.
See `RECONCILIATION.md` for the preserved original failure and corrected results.

## Coverage and protective behavior

The report exposes `installed`, `matched`, `excluded`, `unmatched`, `textures`,
`errors`, and `fallback`. Matched entries identify the actual mesh/surface,
source material, finish, team status and retained render traits. Unmatched declared
bindings are explicit; the source validator rejects them. Team markers, weapon
subtrees, profile preserve rules, emissive/transparent/pretextured materials remain
protected. A selected unsupported material, absent UV/tangent, invalid profile or
missing texture prevents **all** pending assignments. FPS emits an explicit fallback
warning. A source with no data still uses existing authored SVG overlays.

No mesh material resource is mutated. Only per-instance surface overrides are
installed. Clear restores overrides only while they are still owned by this binder,
so another renderer's later override is respected. Base resource names are retained.
Imported alpha, emission, cull, vertex-color, UV transforms, filter, render priority
and other state survive `duplicate()`. Normal maps use StandardMaterial3D's fitted
UV tangent path. There are no world projections or per-frame texture/material loads.
Texture references are per binder, capped at 81; clear releases them. Fallback
material keys include base resource instance identity and every stored base property;
fallback mesh
and material caches are capped at 128 each (eviction retains live actor references).

## Source inspection result and native gates

All primitives in **all nine** source GLBs contain UV0 with VEC2 accessor counts
matching POSITION. GLBs have no explicit TANGENT attributes. All nine checked-in
`.glb.import` files explicitly configure `meshes/ensure_tangents=true`; the imported
result still needs native verification before accepting normal-map coverage. Binder tests
the imported mesh arrays and fails atomically if tangents are unavailable. Fitted
overlay tangents are generated once from their existing UV0 via SurfaceTool.
The content's matte-hand/rubber finishes intentionally omit normal maps because
their actual UV triangles include degeneracy. Runtime neither requires tangents
for these omitted maps nor supplies a substitute normal texture.

Material numbers differ by operator. SourceMaterial1 is emissive, while the team
armor is sourceMaterial4 or sourceMaterial5 depending on identity. Other emissive,
weapon and light surfaces vary. Inspect the generated inventory rather than assuming
material0 or a shared numbered role.

`tools/fighting/animation/blender_pipeline.py` imports native source meshes, groups
by material/LOD/shadow, and joins them with `bpy.ops.object.join()` while retaining
vertex groups. This suggests UV preservation but is **not native export proof**.
No fighting GLBs were generated or inspected here. Gate final acceptance on native
exported UV0, tangent/skin/material-name closure, all nine animated attachments,
Meta/Mistral paired timing first, then the full roster. The separate fighting patch
only binds after successful configure and clears before model release; it changes
no animation, pair phase, skeleton, LOD or root logic.

## Verification commands

Lightweight (allowed now):

```sh
python3 tools/operator-finish/runtime/validate.py --inventory-only --output /tmp/opencode/operator-material-uv-inventory.json
python3 tools/operator-finish/runtime/test_validate.py
# After content merge, require actual profile/resource/provenance closure:
python3 tools/operator-finish/runtime/validate.py --output /tmp/opencode/operator-finish-coverage.json
```

Native (deferred to grant holder Astra; not run in this lane):

```sh
godot --headless --path godot --script res://source_operators/moth_finish/lifecycle_test.gd
godot --path godot res://source_operators/moth_finish/gallery.tscn
```

The gallery presents simultaneous red/blue SVG and Moth rows for all nine. It cycles
fire recoil, walking, reload, melee, team switching, all LODs and pose resets;
`C` selects a closeup and `R` reloads the scene. Record overview and individual
moving-light/closeup frames. The lifecycle fixture checks all nine source bindings,
two simultaneous teams, immutable imported colors, 200 allocation-free team updates,
rebind counts and idempotent clear. Final native fighting shots must still cover
skeletal deformation, pair motion, reset/load/rewind and preserved unique motion.
Pixel statistics and grammar checks do not certify attachment or appearance.

JSON profiles/manifest must be included in export filters; add the authored asset
paths to the package resource closure. Check imported tangent generation, runtime
report resolutions and all retained render traits in the final exported package.
