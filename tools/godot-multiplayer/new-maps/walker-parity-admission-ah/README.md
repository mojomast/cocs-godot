# AH — negative controls pass; inclined invocation fails before receipt

**AH released2026-10-04T05:34:16.414998Z. No remaining authorization or queued
work.** Two separately supervised engine invocations were made; no retry,
source correction, separate parser/import, positive-group invocation or map run.

Fresh branch `astra/walker-parity-admission-ah` from parent-integrated `f860e426`.
Read-only helper commits: `560fff1e` (preservation/checkpoints) and `c3c922f9`
(post-release analysis). Reviewed runtime sources were unchanged.

## Results

| Group | Planned matrix | Native invocations | Result |
|---|---:|---:|---|
| negative-controls |34 pairs /68 profiles |1 |34/34 pairs,68/68 profiles completed and passed; no failed/interrupted/unrun entries |
| inclined-landing-rejections |4 pairs /8 profiles |1 |Engine exit2; wrapper exit1; no native receipt; group failed |
| positive-step-admission |4 pairs /8 profiles |0 |All4 pairs /8 profiles unrun after failure |

The inclined invocation has **zero instrumented completed** pairs/profiles. Its
internal attempted/failed/interrupted/unrun counts and physical-call counts are
unknown, not inferred zero. Do not invent one failed trial from the group-level
failure or treat an absent result as proof no physical calls occurred.

### Group1 checkpoint

The strict Python native-success predicate, supervisor predicate and next-group
dependency reader all passed against the actual AH files. Owner inspection
confirmed all17 frozen IDs ×2 radii in exact order,1284 settling records and72
input records including four explicit jump-launch records. Candidate responses
were678 ordinary Walker responses, with zero physical assist-UP applications or
verified lifts. Paired position differences were exactly0; velocity and grounded
flags also agreed exactly. Every recorded frame returned, clocks were consecutive
60Hz/timeScale1, and resetCount remained1 per profile.

Observed mechanisms matched the frozen fixtures: ceiling UP blocked; overhang
UP clear and forward blocked (actual frontZ≈.0800000131); height controls rejected
the riser band; narrow controls rejected landing footprint; hole rejected flat
continuity; pit had no bounded riser; lateral rejected head-on alignment; remaining
input/airborne/jump/transform/platform controls returned their exact reasons.

Radius.42 ordinary responses can rise after original rejection. For example,
both baseline and candidate ceiling/overhang responses had deltaY≈+.03399998m
with zero assist applications. These are paired ordinary responses, not admitted
lifts. The complete native trace retains all queries, contacts and body states.

The group1 log contained only the official4.5.2 banner. ReturnCode0, failed=false,
consistent hashes and three distinct measured empty release audits were checked.
`negative-controls-checkpoint.json` and `negative-controls-owner-review.json`
were saved **before** the separate inclined invocation.

### First failure and stop

Inclined invocation started under the same sealed source/grant/binary hashes and
passed the host predecessor dependency check. Godot returned2 about.7s later;
the supervisor returned1, failed=true, releasedCleanly=true, and
partialCountersMayBeUnknown=true. There is no inclined native result file. Its
log contains only the official4.5.2 banner, without script/parser/error lines.

The staged driver's initialization/run path contains silent `quit(2)` preflight
branches before `ready=true`, including native predecessor validation. The
observed exit is consistent with early initialization/admission rejection, but
the exact branch is not instrumented. Host strict replay of group1 and the
predecessor dependency chain still pass after failure. **No unique native cause
is asserted, and no diagnostic engine rerun or source correction was made.**

The failed checkpoint and owner decision are archived. AH stopped here; the
positive group was never invoked. All native/global/production admission flags
remain false. There is no new assisted/full-tread positive evidence, sustained
traversal or candidate map acceptance. The existing production pre-lift/parent
accounting limitation remains open. AG's prior one-response qualification is
preserved, not upgraded by AH.

## Binding and lifecycle

* Grant: `MOTH-BLENDER-20261004-AH`, new sealed file, exact three-group allowlist.
* Phase: `parity-admission-synthetic-v1`; mode: `synthetic-controls`.
* Attempt: `godot/tests/walker_parity_admission/parity-admission-ah-01/`.
* Source SHA256: `2bf47230230d4804507dd00257ce66b43adb72c30425af7872e6c5a5394ecbc0`.
* Grant SHA256: `26b8d535721f8cf2a5513edf020a50aaedc50681a545e7f90ebf56e48bd25323`.
* Binary SHA256: `5803746bbe055bee0f07a3c5b0dd347719bd45599f3d34519a8a0beaf83014ae`.
* Binary: `/tmp/opencode/cocs-horde-e353522a-package/toolchain/Godot_v4.5.2-stable_linux.x86_64`.

First engine parsing occurred inside group1's supervised headless invocation.
Both invocations used the reviewed single-threaded scene option, LP_NUM_THREADS1,
OMP_NUM_THREADS1, nonwaiting shared lock and170/180s internal/external bounds.
No import/editor/render/server invocation was added. The sealed grant remains
archived unchanged; its future expiry does not authorize continuation after the
terminal failure and explicit release.

| Group | Owned PID=PGID | startTicks | Supervisor's three empty audit UTCs |
|---|---:|---:|---|
| Negative |2800082 |627501641 |05:31:35.735655,05:31:35.952341,05:31:36.171950 |
| Inclined |2806016 |627513257 |05:33:09.344994,05:33:09.558297,05:33:09.773865 |

Final fresh audits of **both** owned groups were measured empty at
05:34:15.726409Z,05:34:15.954620Z,05:34:16.182596Z. Lock available at
05:34:16.414945Z; explicit release05:34:16.414998Z. Clean release does not override
the inclined native failure. No engine execution followed release.

## Preservation, validation and delivery

Before/after preservation verifies AG29, AF24, AE46, AD45, AB140, Z253, X600,
U264, AA141, AC265, all15 production dependencies, the reviewed16-script stage,
host pins and historical provenance. All22242 snapshotted preexisting sidecars
were unchanged; no new sidecars were observed. Viewer PID2598700 / PGID2598689 /
startTicks522477875 and all seven snapshotted display processes were unchanged.
No cleanup or unowned process-group signaling was performed.

138 Python source tests passed after release (49+24+18+8+7+32); subprocess tests
were mocked. These tests do not override native failure. Parent's prior13 package
checks were not rerun or counted as new AH verification.

`evidence/artifact-inventory.json` records exact hashes and sizes for this report,
both read-only helpers, preservation/authorization/checkpoint/review/analysis/
validation/release records, the actual16-script minimal stage plus project,
sealed source/grant, both start/dependency/supervisor receipts, both logs and the
complete successful negative native result. The inventory excludes only itself.
The missing inclined native result and absent positive artifacts are retained as
absence; no synthetic native receipt has been manufactured.

Parent independent evidence review is required before any future phase or newly
scoped diagnostic grant.
