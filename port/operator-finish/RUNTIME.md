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
omitted if absent. `roughness_gain` multiplies the original scalar roughness;
`metallic` supplies the finish scalar. Texture RGB modulates the original palette
once. No runtime source-engine authority or provenance claims are made.

The source-only closure validator recognizes nested texture/source records with
`path`, `sha256`, `width`, `height`, or `source_path`/`source_sha256` and
`moth_source_path`/`moth_source_sha256` pairs. Paths may be repository-relative or
`res://`. Actual texture dimensions/hashes and existing Moth source file hashes
must match. Run the content lane's deterministic reproduction command separately;
hash matching alone does not prove derivation. If that lane publishes another
record shape, reconcile this read-only validator with its documented schema.

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
matching POSITION. GLBs have no explicit TANGENT attributes: native Godot import
must produce tangents before installing a profile with a normal map. Binder tests
the imported mesh format and fails atomically if tangents are unavailable. Fitted
overlay tangents are generated once from their existing UV0 via SurfaceTool.

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
