# Robot production-D: bounded package asset promotion

Parent explicitly authorized source-only robot promotion after reviewing the
full robot-anatomy front/rear/underside, props and production-mounts images.
Parent `2c39d1ad` was merged as `e59a7625`, retaining the earlier Parallax promotion.
The delivered assets are from `3b6a3e79`, activation hooks from `93622961`, and
production evidence from `8aeb610b`. No assets or native evidence were rebuilt.

## Scope of acceptance

Accepted for bounded art integration: three distinctive shield/quadruped/skirmisher
skins with three LODs each, six shallow service fixtures, nine runtime GLBs, nine
editable masters, three skeletal references and six activation hooks. Props stay
inside the unchanged existing-cover envelope; this does not introduce full-depth
interactive prop mechanics. Runtime animation remains the original contact/event
pipeline. The rigid robot imports retain their actual 30 Hz importer settings;
fighter-specific animation policies are not applied.

`port/expansion-three/robots/ACCEPTANCE.md` and
`tools/godot-robots/production-d.json` retain their original pending-parent text
and native history. This later authorization supplies bounded asset promotion.
Recorded native results: 60,593 checks, 4,320 joint parity checks, 51,168 Campaign
and 86,016 Horde targeting probes, plus controlled source-authority replays.
They do not establish a hosted ordinary-input final journey or human feel.
Grant D's recorded release at 23:24:34Z reports all 44 owned groups empty.

## Receipt reconciliation, without asset rebuild

Original fixed robot receipt SHA-256:
`e0e5bf6defc6bc8dacb0093070089aea1953554f1a72af26ba2d333c7d4a3f94`.
On merge, exactly one of its 100 supporting inputs differed:
`tools/godot-package/production_resources.mjs`, advanced by the legitimate Parallax
packaging work. Source hashes, embedded fingerprints, masters, exports and hooks
all matched. That original receipt remains retrievable at `e59a7625`.

The reconciled robot receipt is
`tools/godot-package/production_receipts/robots.json`, SHA-256
`e0667a6bc7295f30f337f571301f3e7747b84c265835e96c2a310b5ba5e00d85`.
It now binds **130 package inputs**: the prior 100, 27 explicit image/import paths,
the production-D evidence record, the new robot import verifier and the scenery
adapter dependency described below. Its original
`packageInputHashes`, `accepted:false` and pending producer fields remain historical
producer snapshots. Current package identities use `packageInputs`; authorization
is the explicit requirement promotion and this review record.

Parallax retains its actual assets, source hashes, hooks and raw GLB inventory.
Its auxiliary reconciliation changes only the validator hash and adds the new
imported verifier module (59 package inputs). Its previous receipt SHA-256 is
`f0d2b15ddb6c1d1609a2be5f1bc37cbf486b4b7034bf7fa6973577af9e79e6d0`;
the current receipt SHA-256 is
`3c7d26b851d031ff1509aa50e7aa81dc26df5f8836b5668e00ad7af2fef39ab5`.
Each receipt has an explicit `packageReconciliation` with previous commit/path/hash,
old/new supporting hash and every added path. The reconciliation command refuses
other existing-input drift, removed inputs or uncommitted input bytes.

During this work parent handed off `cf0e8def` / `fa2e5fd8`, which was merged
before freezing the promotion. Its production runtime change is
`godot/biomes/expansion/scenery_pack.gd` (atomic installer). The original robot
receipt bound terrain as a runtime hook, but its recipe-root helper closure did
not include this scenery dependency. It is now an explicit added supporting input;
`supportingRuntimeRevision` records both the original parent and new adapter hashes.
Terrain, robot hooks, recipes, output fingerprints and asset bytes remain unchanged.
Parent reported nine scenery source/geometry/journey contract tests passing.
**D robot native checks were not run against this new adapter.** Its native import,
lifecycle and final runtime acceptance remain pending. Optional absent scenery
continues to use the source fallback contract; scenery itself is not promoted.

## Actual extracted-image and import contract

Each of the nine declared exports has exactly one embedded PNG named
`MothLocal_Switchyard_vertex_enamel`. Its committed sibling
`<export>_MothLocal_Switchyard_vertex_enamel.png` is **byte-identical** to that
embedded image. Names derive from this bounded producer contract, never a glob.
All nine GLB sidecars specify `gltf/embedded_image_handling=1`, making the extracted
images relevant dependencies. Closure now binds:

- Nine PNGs as runtime resources, with exact equivalence to embedded image bytes.
- Nine GLB and nine PNG `.import` files as source provenance, not loadable resources.
- Correct scene/texture importer and `source_file` identities, extracted-image mode
  and `meshes/ensure_tangents=true`.
- Authored non-white `COLOR_0` and the sole local `TEXCOORD_0` stream. No normal
  textures are invented or required by this import contract.

The builder now checks committed production PNG/import bytes after import and
export, alongside the existing exact fighter sidecar checks. A rewrite aborts.
No engine was run to exercise those prepared staging checks in this source lane.

## Evidence and source checks

Review root:
`/home/mojo/.tmp-on-disk/cocs-expansion-three-robots-evidence-20261002/production-d/20261002T231436.880071Z/`.

| Parent-reviewed image | SHA-256 |
|---|---|
| `robot-anatomy.png` | `d8aa7f983b4a08b17f957294f229230ded817d4d7dbc9576709fee1132cbae06` |
| `props.png` | `3068881445fd6328aec8e9b65ed13a486e4504dea2d5aa260f9a00ba882aaa80` |
| `production-mounts.png` | `b641baa97620856d09c892f98d97c92e0f8ce364c6f0fe8d2337c9045b7efc18` |

Packaging verified 29 existing final review/native/contact/targeting evidence
file hashes against production-D. This verifies evidence integrity, not a rerun.
Source tests cover actual missing exports/images/sidecars, changed PNGs, refreshed
receipt hashes with wrong image bytes/import identities/tangent policy, stale
mesh fingerprints, white vertex-color replacement, historical validation and
preserved two-unit production identities read from recorded Git objects.
Evidence logs: packaging evidence directory, `robot-promotion-tests.log` and
`robot-promotion-audit.json`.

**Current status: two promoted / five pending.** Vehicles, scenery, Vesper Viaduct,
Abyssal Pressureworks and Stormglass Causeway still require their real outputs,
receipts, activation hooks and applicable accepted registrations. Strict export
preflight still refuses those five. Full ordinary-input/native acceptance, final
manual/audio review, Windows verification and export remain pending. No heavy
production, engine/import, Blender, render, CI or publication was performed here.
