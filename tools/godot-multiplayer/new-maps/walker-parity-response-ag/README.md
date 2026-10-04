# AG — one guarded parity response passed

**Exactly one parity attempt completed and passed the unchanged response guard
and candidate postconditions. This is not positive admission or a completed
tread landing.** `positiveAdmission:false`, `nativeStepAdmission:false`, all60
candidate map journeys remain unrun. Parent independent evidence review precedes
any further execution.

Branch `astra/walker-parity-response-ag` starts at approved parent `829aa08b`.
Preservation helper source `c30c0e13`; post-exit analysis source `139f5618`.
Reviewed runtime scripts, supervisor, guard, epsilon and production code were
unchanged for execution. All execution/tooling additions occupy new namespaces.

## Authorized invocation

Sole grant `MOTH-BLENDER-20261004-AG`, sealed `grantId:AG`, phase
`parity-response-only-v1`, mode `single-response`, group `parity-response`.
Fresh lowercase project `godot/tests/walker_parity_response/parity-response-ag-01/`
contains the exact approved13 scripts and minimal project settings. Preparation
verified explicit frozen AF root against `b80273a7`/24 files and all15 production
dependencies. No AF grant was reused.

Exactly **one** supervised engine invocation included first parsing. No separate
parser/import, retry, correction or continuation occurred. Engine was explicitly
`/tmp/opencode/cocs-horde-e353522a-package/toolchain/Godot_v4.5.2-stable_linux.x86_64`;
banner/runtime reported4.5.2 stable official `6ce3de25a`. Log contains only the
banner and trailing blank line, preserved verbatim. Supervisor return code0,
`failed:false`, native outcome `single_response_guard_passed_not_positive_admission`.

The supervisor used the nonwaiting heavy lock, thread1 settings,170s internal /
180s external bounds, single-threaded scene option and owned PID/PGID tracking.
Actual command, hashes, environment and process samples are in supervisor receipts.

## Actual lifecycle and clock

Fixed .35 radius / −45° yaw / .15m synthetic fixture, unchanged geometry/control
sources. One continuous candidate-derived Walker body performed **27 ordinary
approach responses**:20 settles and7 input responses. The first original eligible
proof occurred on **input8, tick27, physics frame29**; its live parity proof was
also accepted. It then executed one physical UP and one original Walker parent
response, ran the original guard and all postconditions, and stopped immediately.

All28 records cover consecutive physics frames2–29, actual delta1/60,60Hz,
timeScale1, no sprint/jump and resetCount1. Actual body state was unchanged across
each original proof, the parity planning queries, and the final guard query.

| Completed-path counter/flag | Result |
|---|---:|
| candidateAttempts |1 |
| appliedUpCount |1 |
| parentResponseCount (candidate attempt only) |1 |
| candidateResponseCollected |true |
| responseGuardPassed |true |
| candidateFault |empty |

These post-return counters are valid for this completed, error-free instrumented
path. They must not be generalized to interrupted attempts: a default zero after
a script fatality would not establish absence of a physical call.

## Physical UP, modeled requests and actual endpoint

Actual before position:
`[.212131947278976, .0166666638106108, -.212131947278976]`.
UP requestedY `.153433352708817`, actual travelY `.155464291572571`, with no
returned collision. Actual raisedY `.172130957245827` matched the modeled raised
pose at float32: **zero raised-pose discrepancy**, tolerance **1µm unchanged**.

Read-only DOWN requests shared the predicted edge origin
`[.141421258449554, .172130957245827, -.141421258449554]`; modeled forward6 started
at the predicted raised pose, not the already-advanced edge.

| Measurement | Original short32 | Modeled full4 |
|---|---:|---:|
| DOWN magnitude | .175564289093018 | .300000011920929 |
| Max contacts |32 |4 |
| Safe fraction | .48046875 | .28125 |
| Unsafe fraction | .484375 | .28515625 |
| Raw travelY | −.0843531563878059 | −.0843750014901161 |
| Modeled endpointY | .0877778008580208 | .0877559557557106 |

Both were recovery/rays enabled and reported one target contact. Full4 travel
exceeded margin and was vertical; the parent's modeled UP projection retained
that travel. Forward6 enabled recovery, disabled rays, and returned no hit or
contacts with travel exactly equal to requested motion.

**Actual final = selected parity expected final**:
`[.141421258449554, .0877559557557106, -.141421258449554]`.
Float32 endpoint error vector `[0,0,0]`, length0, against unchanged epsilon
`.000001`. Original short32 expectedY remains21.845102310180664µm higher. Thus
AE's original failed endpoint check is not retroactively converted into a pass.

Actual parent lastMotion was
`[-.070710688829422, 0, .070710688829422]`, differing from modeled forward by
approximately `[-7.450580597e-9, 0, +7.450580597e-9]` (length≈10.537nm), within
the unchanged guard budget. The modeled query did **not** execute the cancellation
wrapper. No internal parent call was traced; numeric agreement does not identify
a unique backend cause. The configured setting returned `DEFAULT`, not an
independent backend implementation identification.

## Guard and actual final-support evidence

Guard passed with reason
`endpoint_and_pinned_clear_branch_and_live_support_agree`. **Every guard check
was reached; none was skipped by early rejection.** Parent slideCount0 and
observedSlides empty; platform velocities zero; valid grounded state; candidate
postconditions passed. This retains the guard's pinned static/no-slide branch
qualification, not a general internal-path reconstruction.

The fresh final-support query ran from the **actual final pose**, using DOWN
`.0200999993830919`, margin `.0199999995529652`, max32, recovery/rays enabled.
It returned one stationary contact on `PositiveTread`:

- Certified and resolved actual target RID **115964116994**, shape0/local shape0.
- Collider instance ID29645342078; ID-to-RID resolution succeeded.
- Contact point `[-.000000119209289550781, .150000005960464, -.000000119209289550781]`.
- Plane error0 against the certified landingY.
- Normal `[.422360450029373, .802012085914612, -.422360450029373]`, approximately
  **36.677329° from UP**, within the unchanged46° rule.
- Depth `.0197234023362398`, safe/unsafe fractions1/1, hit=true, valid=true.

Its raw query travel was
`[.00652162730693817, -.00682989694178104, -.00652182102203369]`.
**That support-probe travel was not applied.** Before/after-guard state was
identical. The actual floor normal reported by the parent was separately
`[.40467157959938, .82004988193512, -.40467157959938]`, approximately34.9102°.
The live support query passed the existing support criteria; neither normal nor
the query travel is substituted for actual movement.

This qualifies the existing guard's actual-final-support check for this one
response. FootY remains below treadY, consistent with rounded-edge support—not
full footprint placement, completed tread crossing or sustained traversal.
RIDs are scoped to this invocation; coincident numeric RIDs across runs do not
establish cross-process object identity.

## Motion accounting remains a production limitation

- Whole-frame delta:
  `[-.070710688829422, +.0710892900824547, +.070710688829422]`.
- Parent positionDelta:
  `[-.070710688829422, −.0843750014901161, +.070710688829422]`.
- Difference is exactly the actual UP travel at float32: `[0,.155464291572571,0]`.
- Parent realVelocity `[-4.24264097213745, −5.0625, +4.24264097213745]`;
  actual grounded velocityY0.

No accounting field was overwritten. Immediate post-UP getter snapshots are
also retained: they can still reference the preceding parent step and are not
presented as a fresh isolated UP velocity. The later parent accounting omits
the pre-lift despite net upward whole-frame displacement; production reporting
therefore remains blocked.

## Release and preservation

Owned PID/PGID **2400970**, startTicks **626752150**. Three fresh measured audits
found the sole owned group empty at:

1. **2026-10-04T03:26:18.400912Z**
2. **2026-10-04T03:26:18.617991Z**
3. **2026-10-04T03:26:18.836334Z**

An additional post-exit census was empty. Heavy lock availability was verified
**03:26:30.169335Z**; explicit AG release recorded **03:26:30.169363Z**.
`releasedCleanly:true`; success is independently supported by the completed
native result, not inferred merely from cleanup. No queued or further heavy work.

Before/after preservation verified AF24, AE46, AD45, AB140, Z253, X600, U264,
AA141, AC265 and all15 production dependencies. All **4,953 sidecars** across
AG, frozen AF and frozen AE roots (1,651 each) were unchanged. Viewer PID2598700 /
PGID2598689 / startTicks522477875 and captured display identities were preserved.
No cleanup, deletion, extra sidecars/cache, external import, render capture or
performance measurement occurred. All prior worktrees and failed evidence remain.

## Seals and artifacts

| Artifact | SHA256 |
|---|---|
| Prepared source receipt | `11932ce5036a4ccd352ed0d68f881e5b8917de01279f08e763382be54711e45f` |
| Exact AG grant | `193374d8085792857b15806ec0877c9fa499fb970c5af8bc7d61c9afb763819a` |
| Actual engine binary | `5803746bbe055bee0f07a3c5b0dd347719bd45599f3d34519a8a0beaf83014ae` |

The stage preserves all13 script bytes, project/source/grant, complete28-record
trace, exact command, banner log and supervisor receipts. `evidence/analysis.json`
holds derived measurements and raw-trace hash; `analyze.py` checks each record,
hash binding, physical/query pose separation, completed counts, guard/support
criteria and float32 accounting. Preservation snapshots and explicit release are
under `evidence/`. The exact inventory lists hashes/sizes and excludes itself.

After engine exit, all89 Python source tests passed (24+18+8+7+32), including
the supervisor's mocked lifecycle regressions. No additional engine ran.
`evidence/validation.json` records those checks and parent-byte preservation.

Any broader controls, another candidate response, mirrored/radius profiles or map
journey require independent review and a new explicit grant. No automatic next
step is authorized by this result.
