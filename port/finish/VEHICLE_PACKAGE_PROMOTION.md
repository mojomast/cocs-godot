# Vehicle production-E: bounded package asset promotion

Parent explicitly authorized source-only vehicle asset promotion after reviewing
the three LOD0 close images and Titan UI150. Parent `1f129ab2` was merged as
`6e6395a2`, retaining robot and Parallax promotions. Production anchors remain
`105e4083` / `1c26b4bb`, subsequently integrated through `0cb3a4e7` / `1f129ab2`.

## Accepted scope and retained limitations

Parent accepted the bounded vehicle art: distinct Puma gun-truck, Titan tracked
hull and Scout cage silhouettes with muted olive/metal colors and no excessive
lavender. Nine masters, nine runtime GLBs, nine recipes and nine reports cover
all three LODs; aggregate geometry is **163,612 triangles**.

The Titan UI150 bottom instruction is visibly clipped. This promotion does **not**
accept full HUD accessibility or performance. Existing producer `accepted:false`
and historical pending-parent wording remain intact; this later authorization
supplies bounded asset promotion, not a new release attestation.

Read evidence: `port/expansion-four/vehicles/PRODUCTION_E.md`, the committed
`production-e/generic-receipt.json`, all three outcomes, final native/journey
process receipts and `HEAVY_GRANT_RELEASE.json`. Source verification confirmed
generic/packaging source hashes, fingerprints and output identities agree;
outcome GLB and fixture hashes match actual committed files. The serialized
Sunscar combined-arms run records three cases / nine graphical native clients,
all exiting cleanly with code 0 and without forced teardown. Drive/boost/bend,
reverse/fire, crew/passenger behavior, damage, Codex repair, wreck/respawn,
natural results and rematch are historical E results. Controlled wet restoration
and 64-instance lifecycle are separate probes, not natural-weather or GPU proof.
Grant E release is recorded at **2026-10-03T00:49:06.525631Z**, 36 owned groups,
none remaining. This packaging lane reran none of those native checks.

## Exact import closure

`tools/godot-package/vehicle_imports.mjs` derives a bounded inventory from the
nine explicit Puma/Titan/Scout LOD export identities and reviewed image roles.
Each LOD0/1 has eight images; LOD2 has seven (no red coating image):

- **69 extracted PNGs**: 60 albedo images and nine alloy-edge normal images.
- **78 import sidecars**: nine GLB imports and 69 PNG imports.
- Every extracted PNG is byte-identical to its GLB embedded image.
- The verifier requires correct importer/source identities, extracted-image
  handling `1`, tangent generation, and reviewed normal mode/orientation settings.
- Materials bind the sole local UV0 stream. Only alloy edge has a normal texture,
  at the actual approximately 0.08 strength; other coating/rubber/fabric roles
  retain authored normals. White/light albedo or normal pixel values are valid.
- Vehicles use material colors; robot non-white `COLOR_0` requirements are not
  applied. Unexpected vehicle vertex-color multiplication is rejected.

PNGs are runtime resources; `.import` files are provenance, not loadable resources.
The existing builder's after-import and after-export exact-byte checks cover all
these production PNGs and sidecars. No engine run exercised that prepared build
policy here. There are no raw GLB reads in the production vehicle adapters, so the
actual vehicle `rawFiles` remains empty. Parallax retains its raw audit GLB.

## Receipt and supporting-input history

Original vehicle fixed receipt:
`6981afdfd64b22455abe3c36a706667ab94ed842b2509bccf94fb9cc390b1668`.
It bound 38 inputs and six activation hooks. On merge, only its supporting
`tools/godot-package/production_resources.mjs` hash differed. Current inputs,
outputs, source fingerprint and all six hooks were checked before promotion.

Current fixed receipts under `tools/godot-package/production_receipts/`:

| Unit | Inputs | Receipt SHA-256 |
|---|---:|---|
| vehicles | 201 | `86d491cc2121ab85f02eb24f2027a9179359528508fdb317cff19b7b0c21876f` |
| robots | 131 | `6dcc7c4d4049c86863f6ed03025d08d97e83499dd1183fcb77759486a8f0ef48` |
| parallax-interiors | 60 | `1073428540576e4b46421a84fa06b1b5aecab6c1c1d796790a92e13a0d8a8c5f` |

Vehicles add 147 import/image paths, 14 explicit production evidence paths and
the robot/vehicle verifier modules reached through the common packaging validator.
The prior 38 input paths are retained. Robots and Parallax only advance the common
validator hash and add its vehicle verifier dependency; their source hashes,
fingerprints, masters, exports, runtime hooks and raw inventories are unchanged.

Each receipt's `packageVerifierAdvance` retains the previous commit/path/hash,
exact old/new supporting hashes and all added paths. Prior `packageReconciliation`
history is preserved. Historical producer `packageInputHashes` remain untouched;
`packageInputs` is the current packaging snapshot. The reconciliation command
refuses undeclared input drift/removal, verifies input bytes against Git HEAD,
and validates the entire proposed transaction before writing receipts/requirements.
The first conversion correctly refused an omitted explicit robot-verifier
dependency; that dependency was added to the bounded allowlist before conversion.

## Parent review image identities

All paths below are relative to `port/expansion-four/vehicles/production-e/`:

| Image | SHA-256 |
|---|---|
| `inspection/puma-lod0-close.png` | `be17be3951172cdeab30e6c730e89242f89b84ade2ba3f35d7ea4371cb457a82` |
| `inspection/titan-lod0-close.png` | `ce04e4f68c162207324b6e6d62ee3c7ecb0aa0f5d0a4b86c05dc7a9cbe487fc7` |
| `inspection/scout-lod0-close.png` | `33705225c7ee618c72cf728990df6a9580162f640a9ed59ee25294c2e9d557b5` |
| `titan-ui150.png` | `f6eea5cfad9de0561d9f49c1db06c83b606ef63bd0bf8cbe0e37c6403f5fdd3e` |

## Source verification and release prerequisites

Focused tests exercise real missing/tampered vehicle masters, GLBs, PNGs and
sidecars; refreshed receipt hashes cannot bless changed extracted normal/albedo
bytes, source identity, tangent/orientation policy or stale embedded fingerprints.
Material tests reject wrong UV bindings, forced normals and vertex-color
multiplication. Robot tests and historical manifest validation remain in the
targeted suite. Recorded-Git tests verify all three promotions, retained receipt
history and refusal of the remaining four units independently of worktree reads.

Evidence directory: `/home/mojo/.tmp-on-disk/cocs-finish-packaging-evidence-20261002/`;
source log `vehicle-promotion-tests.log`, recorded-object log
`vehicle-promotion-git-tests.log`, audit `vehicle-promotion-audit.json`.

**Three promoted / four pending:** scenery, Vesper Viaduct, Abyssal Pressureworks
and Stormglass Causeway remain null promotions and strict export blockers. Scenery
F is externally owned and active; no scenery runtime, builder, generic asset tool
or final matrix was edited by this lane. Final native freeze/manual/audio, full
HUD accessibility/performance, Windows package verification and export remain
pending. No Godot, Blender, imports, encoding, CI or publication was performed.
