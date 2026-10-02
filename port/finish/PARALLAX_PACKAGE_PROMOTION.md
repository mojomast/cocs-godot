# Parallax production-C: bounded package asset promotion

Later auxiliary receipt reconciliation is recorded in
[ROBOT_PACKAGE_PROMOTION.md](ROBOT_PACKAGE_PROMOTION.md). The original receipt
hash below is retained as history; Parallax assets and acceptance scope are unchanged.

Parent explicitly authorized source-only promotion of **Parallax interiors only**
in this packaging session on 2026-10-02, after personally reviewing the full-size
overview, archive interior/storage, pump interior/hydraulics and corrected Foundry
cooling images. Parent accepted the bounded Parallax art improvement and existing
production-C native geometry, mount and DM results. This records that review;
the packaging worker did not rerun native checks or perform a new visual review.

Committed parent `b66f4ab3` was merged as `005916fc`. Production inputs originate
from `fd1aeefb`, `be16f060`, `bf0aaac9`. The authoritative evidence receipt remains
`port/new-maps/parallax-observatory/production-c.json` (SHA-256
`f369bc9d595dd84c08c791cb6a443aa7bbd06e37b65d080d85c7095a92050ec1`).
Its old pending-human-review text and the asset manifest's build-time pending
label are preserved; this later explicit authorization supplies asset promotion.

## Exact assets and package receipt

- GLB: `godot/multiplayer_worlds/art/parallax-observatory/parallax-observatory.glb`
  — `c1dffd357545206d3f70870f850e441c5be148e652830a4a69835185a75610bd`;
  8,621,072 bytes, 147,103 triangles, seven material batches.
- Revised master: `tools/godot-multiplayer/new-maps/parallax-observatory/revisions/interiors-v2/output/parallax-observatory.blend`
  — `59946f15dd530ecc3f38d38aea41089e2e113b812060483e8ff92138c0d686b8`.
- Original master remains bound separately:
  `fcd7f284443c45d08177837a23af530b1667deb106bddb8822d507f5655ca090`.
- Fixed receipt: `tools/godot-package/production_receipts/parallax-interiors.json`
  — `f0d2b15ddb6c1d1609a2be5f1bc37cbf486b4b7034bf7fa6973577af9e79e6d0`.

The receipt binds 58 exact package inputs, committed production-C input hashes,
profile/binder/presentation/map/demo/native registry hooks, source registry,
import sidecar, original/revised masters and the export. The source-only preparer
compares every hashed input with `HEAD` bytes before emitting a receipt. External
Parallax has no embedded textures or common-helper mesh fingerprint; its source
fingerprint is only a package input identity, not an invented production claim.

`map.gd` uses an imported resource. The physics, inspection and journey probes in
`godot/tests/new_maps/parallax_observatory/` use `FileAccess.get_sha256` on the
original GLB. Therefore `rawFiles` explicitly includes that GLB for native audit
byte access. The existing raw export plugin and extracted hash probe consume it.
The `.glb.import` sidecar is source provenance, not a loadable runtime resource.

## Review and native evidence anchors

Evidence root: `/home/mojo/.tmp-on-disk/cocs-new-map-observatory-evidence-20261002/production-c/`.
Parent-reviewed Parallax images under `native-review/`:

| File | SHA-256 |
|---|---|
| `overview-full.png` | `d696c27e0a567c449cd7e6ad828c6dd10f18f7758eeecfda863c3e9438183716` |
| `archive-interior-full.png` | `c04ecf684c980fb81ac01e34c4d8605a1648713bdbb7561e29f8402f92a376ca` |
| `archive-storage-full.png` | `5db64400b75ed549c09c28fde8121d49db153ee00fe9391832a705e8da07adcb` |
| `pump-interior-full.png` | `e9aaeb7ebc0a369d27db030522df477bc27fa3bb274563d925c6809c53b7d7e6` |
| `pump-hydraulics-full.png` | `48709dca5bf11af73624482491e29b9b0e4505285095bde0b37a83c648f368a5` |

The committed production receipt binds `native-physics.json`
(`72f89dce8ce31e6027685f3b2b0c3af1449f879c842a141fd8002bff14498bea`),
with 859 support rays / 859 capsule checks, 60 source blocks, five ceilings and
no failures. Dressing records 900 mount samples without failures. Its separate
master reopen records a byte-identical GLB re-export. Current native journeys:

- `native-walkthrough/native-journey.json`:
  `ff619e027d9fedf477c066674f80f5c2bf93a6368f957aa509560fe30e772bfb`
  — archive, polar, arcade, pump and lens visits.
- `current-dm/native-journey.json`:
  `b74953260868826b519d2d4a97aca3639976f7ea1f4dd7b3ffcbed42824e9139`.

The six historical native-proven mode pairs retain anchors `9a6372b4` and
`277f379e` and unchanged source geometry. Only current DM and the five-district
walkthrough were rerun under C. **This is not six fresh canonical attestations.**
The catalog now contains ten worlds / 60 pairs. Existing performance limitations,
import-crash history and partial proof statuses remain in the producer record.

## Source verification and remaining prerequisites

- Verified all **61** existing image/physics/journey/source-outcome/teardown file
  hashes cited by production-C; no evidence files were generated or rewritten.
- **62/62** targeted package tests passed, including historical manifest checks,
  actual Parallax tamper/raw-inventory failures, missing registry refusal and
  updated 60-pair coverage. Log: packaging evidence directory,
  `parallax-promotion-tests.log`; audit: `parallax-promotion-audit.json`.
- Only Parallax's requirement now carries a promotion. **Six remain null**:
  robots, vehicles, scenery, Vesper Viaduct, Abyssal Pressureworks and Stormglass
  Causeway. Their actual masters/exports, complete receipts, runtime hooks and
  accepted registration where applicable remain mandatory export prerequisites.
- Selective-normal reconciliation `935e24a0` and exact robot recipe output
  `dff733c0` are integrated source changes; neither promotes the six pending units.

Native closure, final manual review and audio remain pending in the acceptance
runner. No engine, Blender, import, rendering, export, CI or publication was run.
This bounded asset promotion does not grant release acceptance or publication.
