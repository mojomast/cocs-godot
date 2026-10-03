# Scenery F source-only package promotion

Parent explicitly accepted the four chapter inspection-after views and Root
archive, wheelhouse, ceramic exhaust and folio architecture views for integration.
Canonical `27f3afc3` was merged before this work. F production identities remain
anchored to **`b320c270`**, with evidence/release in `b8ba1de8` (canonical picks
`436c30fb`, `ad52003d`, `27f3afc3`). No native evidence is restamped as this merge.

## Exact closure

The received `port/expansion-four/scenery/production-f/final-assets.json` has SHA-256
`f5e7b53a536c7198128f9ff6ce6a9b6fbd41470d57ace08e7ce753398b5daf7f`.
The verifier pins these immutable bytes and requires the exact inventory:

- 12 Blender masters and 24 GLBs retain original receipt identities.
- **118 PNGs**, byte-equal to the corresponding embedded GLB PNGs.
- **118 PNG import sidecars**, with lossless mode, unchanged normal orientation
  and no size reduction.
- **24 GLB import sidecars**, with mesh compression disabled, tangents enabled,
  authored LODs retained and extracted-image policy enabled.
- All 284 art files match received hashes and sizes; PNG signature/IHDR and
  exact embedded/extracted image names are checked. No filesystem wildcard
  discovery admits additional files.

Scenery package inputs increase **107 → 390**: 260 import/image paths, 21 immutable
F evidence records, and two verifier dependencies (the vehicle verifier already
present on canonical plus the new scenery verifier). The sole changed existing
input is `tools/godot-package/production_resources.mjs`.

PNG bytes are package resources; `.import` sidecars are provenance inputs used to
reproduce imports. No artificial runtime raw-file requirement is introduced.

## Receipt history and parent acceptance

`reconcile_scenery_promotion.mjs` reads the previous receipts directly from
`27f3afc3`, verifies unchanged source hashes, runtime hooks, masters and exports,
and writes the proposed four-receipt transaction only after closure validation.
Each receipt records its exact previous receipt hash, previous/new supporting
package fingerprints, added path hashes and changed before/after hashes under
`sceneryPackageVerifierAdvance`. All previous fields except `packageInputs` are
preserved, including previous reconciliation history and `accepted:false`.
The requirements promotion and explicit parent review are separate from the
original production attestation.

The three existing promoted receipts require only the changed shared verifier
hash and the new verifier dependency: Parallax **60 → 61**, robots **131 → 132**,
vehicles **201 → 202** inputs. Their production/native identities do not change.

New receipt SHA-256 values:

| Unit | SHA-256 |
|---|---|
| Scenery | `ee945cd0574184ffccaec3d974f100f2a86f3446b56c1d1a3c8cacc9ce964b09` |
| Parallax | `1c768e8bf75f937060301725802aebc899db228eb575f564b484e943caddbf69` |
| Robots | `6d2ce07555b2f0848876f3e1b1e2a1075372bfbb03ba3c21bd85aef210bbd8b2` |
| Vehicles | `5e3dcb74f8cf031e34e909e7ae788ced7627617eb458938d918909ad371aef50` |

## Verification and limits

Source-only Node tests exercise four promoted units, missing PNG/PNG-sidecar/
GLB-sidecar refusal, wrong bytes, mesh compression/normal/source policy changes,
unchanged production fields, preview intent and strict-final refusal. Commands:

```sh
node --test tools/godot-package/scenery_imports.test.mjs tools/godot-package/production_resources.test.mjs tools/godot-package/build_channel.test.mjs
node --test tools/godot-package/promoted_assets_git.test.mjs
```

The first command passed **10/10**. The second independently checks committed
bytes via Git, including retained receipt history. Final mode still requires all
seven units and rejects **Vesper, Abyssal and Stormglass** as pending. Future
preview closure has **four promoted / three pending** units.

Published preview `cb6e4c9f` remains immutable and excludes F. No release/download
files were edited and no new build was produced. No Blender, Godot, import,
server, render or encoding ran during this promotion. Heavy H remains exclusively
owned by Vesper; F remains released.

Accepted native evidence retains its **capture-paced llvmpipe** limitation.
Continuous rendered playability, hardware-GPU performance and human feel were
not established by F. Parent visual acceptance does not rewrite that limitation.
