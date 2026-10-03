# Released L — bounded package advance

## Parent verification

Worker `d5335f8b` integrated as **`623127c5`**. Parent independently passed all
**52 source tests**, including committed-Git validation of the seven strict
inventories, exact L history, unchanged 116 sidecars and rejection of forged or
future input/evidence. Whitespace checks passed. No engine or build ran here.

This closes package reconciliation for the reviewed L runtime correction. It does
not discharge final-matrix, live-kick, remaining vehicle-input or release gates.

Foundation: **`9cd1ac7201e6c96a4911659cb1e5e3deb46a4bd9`**. Parent's
`6266702d` correction is the sole runtime change admitted here:
`godot/ui/lobby_choice.gd` now always consumes Cancel on the focused row, even
outside browse mode, preventing Escape from opening global Settings and losing
chooser focus. The implementation was adopted from parent, not rewritten.

Exact source chain:

- `8921ed41`: `2f2b0264984c1f959f497877e63936f79765219d8d808cc2fb10d3c724f2d19a`
- `9cd1ac72`: `9eba4c8067e4b769a3486cf0949680a5e145c1620d00608f9ece1fad8b9d7e95`

Every receipt appends `lReviewAdvance`, binding its exact previous receipt at the
foundation. Existing `polishAdvance` records remain unchanged, including their
historical native-pending state. Original producer/native identities, masters,
exports, `accepted:false`, pending lists and every preceding history are preserved.
No declared activation hook changes. Each unit changes two existing inputs (the
chooser and supporting verifier), and adds exactly three retained evidence JSONs.

## Retained L evidence and limits

`package-evidence-l/` contains exact copies from the released L archive:

| Record | SHA-256 |
|---|---|
| `release-L.json` | `819946192b5425341e3759d0f1ea0e00b03e6ee287b06ff6651eed6d3dc44675` |
| `NATIVE_RESULTS_L.json` | `2365f98ddf01a038503982febebc686c35812436ff37f9acdf6ac5619a6feae2` |
| `sidecars-post-import.json` | `6dd729453631d929094fb28ee1c027e740e180508a59958f6a2e78f0d53bdf5f` |

L released at **2026-10-03T07:30:42.252132Z**, with 49 retained groups and three
empty ownership audits. Its nine primary fixtures and 30 latest after-candidate
gate IDs passed, including 84 lobby QoL checks, 63 popup/focus checks and unchanged
strict 81-pixel depth tests. All 116 committed operator sidecars match L's
post-import hashes; no sidecar or asset is changed in this transaction.

These are retained supplemental native results, not a new run here or final
142-case acceptance. Stage HEADs and exact dirty-source fingerprints remain in the
original evidence. The 27 comparison pairs/54 PNGs remain with the parent's gallery;
they are not duplicated in package provenance. Staged effects/identity captures
are not network gameplay proof. K live-kick timing remains **not accepted**; L did
not retry it. General-world/combined-arms ordinary-input mounted journeys, human
feel, GPU performance and package export remain outside these results.

## Inventory and receipt hashes

| Unit | Inputs | New receipt SHA-256 |
|---|---:|---|
| Parallax | 551 → 554 | `d6012654bb2236af66eef7ef36e7dd2c5a1ab6ea7aca8c081eb1a0524f65a86d` |
| Robots | 629 → 632 | `9fcef298dfe4b141a33d36cf11aa40fc921a3fcb304dcc426884afb2c981927a` |
| Vehicles | 699 → 702 | `d3c5b37919b0119d3c51076b7d985ffc5b6c71af1a521dffb6d840580e36380f` |
| Scenery | 880 → 883 | `429fae356e7b2a788dcc21083f07f0f13e32136d07cd13878cff4ebcfedf482b` |
| Vesper | 644 → 647 | `710f2742a7a94f7828cdb8ca4e4d8d3bbb27ad5f0df9b3bc3973ad101e5f9706` |
| Abyssal | 628 → 631 | `20c15bdf99cea56edb95daf1a6c8724ec9bf5e23838b9235bf2af11fd3b5904e` |
| Stormglass | 569 → 572 | `4736b2d686ae9c4a39d05a77f2f238cc6e0b23d76a3e0571230c80e2b6ae5602` |

`l-package-audit.json` records counts and hashes. The source-only reconciler
validates all seven proposed receipts together before writing. Exact old/new
policy rejects skipped L history, forged predecessors, stale current source,
changed evidence, invented live-kick acceptance and future runtime drift.

**51 targeted source tests passed** before commit. The independent
`node --test tools/godot-package/promoted_assets_git.test.mjs` verifies all seven
strict inventories, original receipt fields and exact deltas from committed Git.
The existing polish test still verifies every original `8921ed41` source identity,
then applies only this explicitly pinned chooser advance to current bytes.

No engine/import/server/build/benchmark or child agent ran. Published releases,
final matrix, build commands and the final 142-case obligation are untouched.
