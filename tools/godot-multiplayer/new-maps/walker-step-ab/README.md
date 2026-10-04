# AB — negative controls passed; unchanged reference remains FAILED

Grant **MOTH-BLENDER-20261004-AB** ran in new branch `astra/walker-step-ab`
from parent `8251b512`, attempt `walker-step-AB-01`. Source/ownership tooling
is committed separately as **`0dd335b0`**. Only the exact authorized mixed-case
attempt name was added to preparation's namespace validator. No GDScript fix,
movement change, retry, tolerance change or fixture adjustment was necessary.

**34/34 paired negative controls passed. The unchanged accepted-civic .35
reference remains failed: five downhill landings, five uphill stalls.**
There was no candidate map journey or positive step-up admission. All60
experimental map walks remain unrun; incline-rejection and rotated-success
admission controls remain future prerequisites under separate authorization.

## Actual execution

Godot4.5.2 official `6ce3de25a`, headless; `LP_NUM_THREADS=1`, `OMP_NUM_THREADS=1`.
No Xvfb or other display was launched. Native responses used actual60Hz physics
frames and timeScale1. Imports and groups each acquired the shared lifetime lock
nonwaiting for that job, then released it; the parent exclusive grant covered
the gaps. There was no nested outer lock, queue or automatic continuation.

| Job | Limit | Observed supervisor duration | Exit | Owned PGID / startTicks |
|---|---:|---:|---:|---|
| First import | 900s | 13.359s | 0 | 1779130 / 625769113 |
| Precision/LOD reimport | 900s | 3.935s | 0 | 1780793 / 625771559 |
| Controls | 180s | 23.628s | 0 | 1781702 / 625772451 |
| Unchanged reference | 180s | 49.574s | **1** | 1789235 / 625778525 |

All scripts parsed on the first native attempt. There are no suppressed parser
failures or reruns. The reference process's exit1 is expected evidence of the
genuine baseline failure, not a successful traversal exit.

The controls/reference commands used the reviewed `run_group_v2.py` supervisor
with exact grant receipt SHA256
`51c5d0f771c51618cb36b52bb5b9bbc3b644322cb0f8770745341503f6af1ba0`.
The source receipt is
`5421c7369a5bd9ed8e068e17d588190b60faea8bc081db5f817803c80d981068`.
Actual argv, group identities, deadlines, results and empty audits are retained
in attempt supervisor receipts and `evidence/import-*-*.json`.

## Controls: real rejection evidence, not positive stepping evidence

The17 fixtures × two radii produced34 baseline/candidate pairs,68 final input
responses,1,284 settling responses and four jump-launch responses. Every
candidate proposal—including settling—was rejected. There were no accepted
lifts, candidate faults or unexpected resets (each fresh spawn retained
resetCount1). Each profile's response clock was consecutive60Hz. Final paired
position difference was **exactly0**; velocity and ground state agreed as well.

The read-only `check_controls.py` gate ran **before** launching the reference.
It verified the same grant/source receipt, counts, actual shape data, rejection
outcomes, clock continuity, ordinary-response equivalence and overhang envelope.
Its result is `evidence/controls-gate.json`.

### Overhang fixture native readback

Both profiles at both radii rejected exactly `raised_path_blocked`. Native
contact was on `ForwardOverhang` at approximately
`[0,1.78000009059906,.0800000131130219]`, consistent with the reviewed finite box
X[-2,2], Y[1.78,1.88], Z[.08,1].

| Radius | Actual settled foot | Raised query Y | UP hit | FORWARD hit |
|---|---|---:|---|---|
| .35 | `[0,.0166666638106108,-.319999992847443]` | .172130957245827 | false | true |
| .42 | `[0,.0166666638106108,-.361999988555908]` | .172130957245827 | false | true |

Returned UP recovery was approximately.00203094m, within the reviewed range.
The entire native query chain stayed within the source certificate's foot,
raised-height, Z and forward-motion envelope. Continuous source geometry at
these measured poses also verifies up-clear/forward-intersection. It is labelled
analytic corroboration; actual native `hit`/contact results are separately saved.

The rejected .42 ordinary response can still move upward on its own: its
parent response was approximately `[0,.034,.065497]`. Baseline and rejected
candidate agreed exactly. This is **not an applied candidate lift** or proof of
.42 map traversal. Rejection means no assist; it does not mean the ordinary
controller must remain motionless in every fixture.

## Reference: the historical failure reproduced

`failed:true`, `referenceExpected:true`, exit1, attempted10 / passed5 /
failed5 / unrun0. Full trace: **2,686 input responses +200 settling responses**.

- Each ascent had127 responses and120 consecutive stalled responses at
  `[lane,12.0166673660278,24.7000026702881]`, against `civic-stair-0Collider`.
- The five downhill walks landed in410,410,411,410,410 responses.
- Downhill traces contain690 non-grounded responses. Landing success is not
  continuous-grounding proof.
- No experimental controller was instantiated for the reference map walks.

`check_reference.py` verifies the exact expected failures, endpoints, native
frame continuity, reset counts and art readback without editing any receipt.

## Exact art/import evidence

Both exact authority/recipe/GLB pairs were verified using unchanged reviewed
`art_binding.gd`. Genuine import UIDs were retained, compression disabled and
LOD generation disabled before the bounded second import. Runtime readback:

| Variant | GLB SHA256 prefix | Retained UID | Triangles / meshes / materials |
|---|---|---|---|
| Accepted | `6afe34c82d45` | `uid://d1mjht4mpfe0a` | 54,804 /11 /11 |
| X candidate | `f859d49cc1b462` | `uid://dvjcxrca6hvls` | 64,311 /29 /17 |

Only accepted art was instantiated in the reference movement world. Candidate
art's temporary readback instance establishes imported identity, not traversal.
Full hashes, actual cache-resource paths/hashes, sidecar hashes and authority
identities are in `reference-accepted-civic-r035-binding.json`. All96 referenced
cache files are archived with hashes in `attempt-import-cache.tar.gz` and JSON.
Controls use their real synthetic fixtures, not either Vesper map world.

## Trace limitation retained, not repaired retrospectively

The reviewed driver's `KinematicCollision3D.get_collider_shape()` returns an
Object, not a shape index. Its legacy slide `shape` field serializes as
`<Freed Object>` after teardown. Collider names, body RIDs, points, normals,
travel and remainder remain recorded. `PhysicsTestMotionResult3D` proposal
contact **colliderShape/localShape indices remain numeric**. Shape dimensions
were read from PhysicsServer using the live capsule RID, but that shape RID
itself was not separately serialized in the parameter receipt.

No raw evidence is rewritten and no rerun is claimed. These are telemetry
limitations for future instrumentation review. They do not establish positive
postguard correctness: no candidate lift was accepted, so its endpoint/live-
support guard was parsed but not exercised on an applied step.

## Preservation and release

- Verified **Z253, X600, U264, AA141**, all15 original production dependencies,
  and the original `a208613b` source worktree against its committed bytes.
- All other parent-tracked bytes, including Parallax contracts and historical
  source receipts, remained unchanged. No movement epoch, JS/Fighting/network
  source or production Walker parameter changed.
- Archived736 proven-new unrelated sidecars before hash-constrained removal.
  All985 preexisting sidecars remain identical. No wildcard deletion occurred.
  Attempt sidecars and generated textures remain alongside the evidence.
- Preexisting viewer PID2598700 / PGID2598689 / startTicks522477875 and seven
  preexisting display processes remained unchanged.
- Final three empty audits covered **all four owned groups**. Explicit release:
  **2026-10-04T00:45:07.795447Z**. Lock availability confirmed at
  **00:45:07.795521Z**. No queued work or engine invocation after release.
- **32 source tests passed** after execution; no production promotion follows.

The original184 static contacts remain failed separately. Binder was cleaned
for exact art binding; Weather/material lifecycle, whole-map movement,
keyboard/focus/network, positive step admission and production whole-frame
velocity reporting are not accepted by this evidence. Parent review owns any
future grant or selective integration.
