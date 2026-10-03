# Parallax tangent AA — actual Blender build; native approval blocked

Grant `MOTH-BLENDER-20261003-AA`, branch `sol/parallax-tangent-native-AA`,
base `d3a4c524`. The approved three-corner source contract is unchanged in
meaning. This is a **failed full native acceptance attempt**, not a package or
runtime promotion. The AA source fixes are separate commits; original X,
Foundry Y, the source-only queue and Vesper histories were not rewritten.

## Actual build identity and qualified scope

| Item | Result |
| --- | --- |
| Exact X input GLB / packed master SHA-256 | `6356cf895c65cec181e1c6c077118b98f3ee80cb567955b37835433971342422` / `9957ca8cc3e4e7f2bca00f7b82a48ed88d031e9e3949259ebf5603f584141051` |
| AA02 new GLB / packed master SHA-256 | `95e9da98a45565ca2aae90858a9e5027d9123e4ffd1347da98d5de8573141cd5` / `2e6617840ec57d08685dd78e64a29bbe7f55db2b1a26da40b6c6a46cd4c0373d` |
| Exact geometry authority | `3a5800e89876ebcc741381802def24415d5050651c0d3b831ea8b9ec3b77b4f9` |
| New GLB / packed master bytes | 19,006,480 / 9,317,468 |
| Bounded delta | Exactly five changed BIN bytes in 48 allowed bytes: accessor 48, face 11823, exclusive corners 24049/24050/24051 -> `[1,0,0,-1]`; all other BIN bytes unchanged |

The pinned Blender **4.5.14**, one-thread build packed a new master. Both its
editable export and a **separate fresh-process reopened-master** export passed
the reviewed audit: 39 flat mesh roots, all **155,553 oriented world-space
faces**, zero position/normal/UV difference, 14 material roles and decoded
pixel/sampler/PBR/emissive equivalence. The reopened canonical GLB is
byte-identical to the AA02 build artifact. `native/AA02/build-report.json`,
`reopen-report.json`, both intermediate editable GLBs and the new master/GLB
are original actual bytes. The canonical compiler is an explicit dependency
of that packed master; a plain Blender glTF export is an audited intermediate.

## Native stage and stopping reason

The isolated Godot **4.5.2** AA03 stage imported exactly the new GLB under a
generated UID `uid://cv2bogce241on`, kept full-precision mesh arrays, disabled
generated LODs, and wrote actual mesh-local arrays and decoded material PNGs.
The exact GLB, 24 extracted original image PNGs and import sidecars, readback
and 39 decoded channel PNGs are under `godot/tests/new_maps/parallax_tangent/`.
The source-geometry+UV-only lookup found the repaired face **once** and proved
all three *actual imported* native corners have a finite +X tangent and
`w=-1`; `native/AA02/targeted-three.json` names their source and native
face/corner records. The actual imported **14 material field sets and 39
decoded channels** passed (`native/AA02/material-proof.json`). Native sampler,
alpha and occlusion state were not measured by that probe; source-side
semantic equivalence was checked by the editable-export audit.

**The strict all-face native gate failed.** First mismatch: `wayfinding-2`,
`ochre`, imported face 963. The actual Godot face has two tangent signs `-1`
where both matching canonical-source choices have `+1` (normal maximum error
on that face `2.3752450942993164e-05`). AA03 used the reviewed
`meshes/ensure_tangents=true` import policy. A fresh AA04 isolated import with
`ensure_tangents=false` reproduced the **same** mismatch. Both imports had
compression disabled and LODs off; no tolerance was widened, and there is no
zero-tangent waiver or all-face native approval. Native readback compares
mesh-local arrays; it does not measure imported node/world transforms.

Attempt receipts are preserved: AA01 Blender failed on a Python module path
before output and Blender misleadingly returned 0; AA02 used
`--python-exit-code 70` and passed build/reopen. The AA02 isolated Godot
readback script first hit a GDScript type parser error (logged); the new AA03
stage succeeded at import/readback but failed strict native verification.
AA04 is the unchanged-art import-policy
countercheck, with its report, sidecar, stream bytes and failure record under
`native/AA04/`. The two `/tmp/opencode/parallax-tangent-AA0{3,4}-stage/`
projects remain intact. Failed receipts are evidence, not approvals.

Since the required strict all-face native gate failed, AA stopped **before**
matched WorldMap/Binder/Weather captures, targeted rays or new traversal
claims. The original X 13,587 Parallax capsule placements remain historical
evidence, not AA reruns. No manual art, hosted mode or performance approval is
claimed. A reviewer must decide how to address the preexisting wayfinding
source/import tangent discrepancy under a **separately reviewed contract**;
expanding the approved three-corner repair or waiving native signs here would
invalidate the exact-change qualification.

## Grant release and file closure

The AA owner held the shared nonwaiting lifetime lock, supervised every Blender
and Godot process under bounded owned PGIDs/start ticks, and set
`LP_NUM_THREADS=1` and `OMP_NUM_THREADS=1`. The grant released with **three
timestamped empty owned-group audits**; the lock was re-acquired nonwaiting
at `2026-10-03T23:22:04.862716+00:00`, then unlocked. The preexisting viewer
and displays were not touched. `native/AA01/release-receipt.json` and
`native/AA01/attempts/` contain the exact release and command history.
`native/AA_MANIFEST.json` hashes every AA-added source, staged resource and
evidence file by original path and byte count; it excludes itself.
