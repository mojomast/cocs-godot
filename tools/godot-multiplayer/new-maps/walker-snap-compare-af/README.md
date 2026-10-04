# AF — baseline-only same-frame query collection

**Stage0 collection succeeded; no assisted movement or step admission.** Exactly
one Godot invocation ran under `MOTH-BLENDER-20261004-AF`, sealed `grantId: AF`,
phase `snap-query-compare-only-v1`, mode `compare-only`, singleton group
`query-compare`. There was no separate parser/import launch, retry or continuation.

Branch `astra/walker-snap-compare-af` starts at integrated parent `4e4e0588`.
Read-only preservation helper source: `ad5d02b6`; post-exit analysis source:
`d3c17632`. Reviewed supervisor, driver, policy, nine-script closure, query helper,
original Walker and original guard were not changed for execution.

## Actual invocation and outcome

- Fresh write-once project: `godot/tests/walker_snap_compare/snap-compare-af-01/`.
- Explicit binary: `/tmp/opencode/cocs-horde-e353522a-package/toolchain/Godot_v4.5.2-stable_linux.x86_64`.
- Actual engine banner/version: Godot4.5.2 stable official `6ce3de25a`.
- Supervisor acquired the nonwaiting heavy lock at Unix1791081496.5353558 and
  launched PID/PGID **2231222**, kernel startTicks **626464050**. Its raw argv,
  process-group samples, environment and result are preserved in the stage.
- Return code0, `failed:false`, `comparisonCollected:true`,
  `queryAgreementQualified:false`, `nativeStepAdmission:false`.
- Actual **20 settling +8 input responses**, physics frames **2–29**, tick0–27.
  Exactly one eligible proof occurred, at input8 / tick27 / physics frame29.
- All28 records have consecutive actual physics frames, delta1/60,60Hz,
  timeScale1, unchanged before/after-query state and resetCount1. The one ordinary
  response after the eligible queries completed, then the driver stopped.
- Fixed .35 radius / −45° / .15m synthetic fixture. Only unchanged Walker was
  instantiated. **Zero UP applications**, zero parity-candidate responses and
  zero candidate map walks. The log contains only the engine banner.

## Collected request/results

The live actual body remained at
`[.212131947278976, .0166666638106108, -.212131947278976]` while queries ran.
Its live RID was **124554051587**, capsule shape RID **133143986178**, radius
`.349999994039536`, height `1.79999995231628`, local offsetY `.899999976158142`.
Layer/mask were1/1 and margin `.0199999995529652`; exceptions/excludes were empty.

Both DOWN requests used the **same hypothetical edge** transform with origin
`[.141421258449554, .172130957245827, -.141421258449554]`. Forward6 instead used
the hypothetical **raised, not yet advanced** origin
`[.212131947278976, .172130957245827, -.212131947278976]`.

| Measurement | Original short32 | Modeled parent snap4 |
|---|---:|---:|
| Requested DOWN magnitude | .175564289093018 | .300000011920929 |
| Max contacts |32 |4 |
| Safe fraction | .48046875 | .28125 |
| Unsafe fraction | .484375 | .28515625 |
| Raw travelY | −.0843531563878059 | −.0843750014901161 |
| Returned contacts |1 |1 |
| Contact normal angle from UP |34.862615836° |34.910211887° |
| Float32 modeled endpointY | .08777780085802078 | .0877559557557106 |

Both DOWN requests enabled recovery-as-collision and separation rays. Both
returned the same certified target RID **115964116994**, collider shape0/local
shape0, stationary `PositiveTread`, contactY `.150000005960464`. All contact
vectors, depth, fractions, flags, transforms and shape data are retained in the
raw trace. These are hypothetical capsule contacts, not actual uplift support.

Modeled parent forward6 enabled recovery, disabled separation rays, returned
no contacts/hit, safe/unsafe fractions1 and travel equal to motion
`[-.0707106813788414, 0, .0707106813788414]`.

### What the numerical comparison establishes

Float32 full4-minus-short32 travel is `[0, −.000021845102310180664, 0]`:
**−21.845102310180664µm**. Full4 raw travel exceeds margin and is vertical, so the
pinned parent's projection rule retains its Y travel. Adding that projected
travel to the hypothetical edge yields
`[.14142125844955444, .0877559557557106, -.14142125844955444]`.

That modeled endpoint matches AE's historical actual endpoint at float32, while
the short32 reconstruction matches AE's historical predicted endpoint. AF's
actual before-query pose also matches AE's before pose at float32. This provides
same-frame native query evidence consistent with the request-policy mismatch.
Length and contact capacity changed together; this experiment does not isolate
a unique backend cause or independently prove an assisted parent response.

These are **modeled parent-policy PhysicsServer requests**, not observations of
internal `move_and_slide` calls. The configured setting returned `DEFAULT`;
backend implementation remains independently unidentified.

### Actual ordinary baseline response

The ordinary baseline ended at its original actual position, not either modeled
endpoint. Its last response had whole-frame delta `[0,0,0]`, parent positionDelta
`[0,0,0]`, realVelocity `[0,0,0]`, velocity `[0,0,0]`, grounded=true, onWall=true,
slideCount1 and resetCount1. The nonzero lastMotion is retained separately in
the trace; no accounting field was overwritten. Whole-frame and parent deltas
agree throughout the28 baseline records.

This baseline stall cannot serve as an actual hypothetical lifted response.
Below-tread modeled endpoints remain consistent with finite rounded-edge
contact, not a completed tread landing. Actual uplift support is unqualified.
AE's failed endpoint guard remains failed; no epsilon or guard was relaxed.

## Release and preservation

The reviewed supervisor measured its sole owned group empty at:

1. **2026-10-04T02:38:17.387106Z**
2. **2026-10-04T02:38:17.606429Z**
3. **2026-10-04T02:38:17.826038Z**

`releasedCleanly:true`; an additional post-exit census was empty. Heavy lock
availability was verified **02:38:48.288893Z** and AF was explicitly released
**02:38:48.288924Z**. No queued work, retry or further heavy work remains.

Before/after verification preserved AE46, AD45, AB140, Z253, X600, U264, AA141,
AC265 and all15 production dependencies. All **3,302 sidecars** inventoried
across this worktree and the frozen AE root (1,651 each) are unchanged. Preserved
viewer PID2598700 / PGID2598689 / startTicks522477875 and all captured display
process identities are unchanged. No cleanup, sidecar deletion or external
engine import occurred. The minimal stage produced no additional sidecars/cache.

## Seals and review boundary

| Artifact | SHA256 |
|---|---|
| Prepared source receipt | `c9ea66f2a6767b5b58db8f5e0942f1c9686bb21eaf692a04dae03122013d138d` |
| Exact grant | `a3cbae5b9f8e1270cca7f028c8f0d46bf5c8210023b889cd8a4c50eefa57b534` |
| Actual binary | `5803746bbe055bee0f07a3c5b0dd347719bd45599f3d34519a8a0beaf83014ae` |

`evidence/analysis.json` is a derived read-only analysis with raw-trace hash;
`analyze.py` validates every frame's state/clock/accounting, request identities,
source/grant bindings and float32 reconstruction. `evidence/before.json` and
`after.json` preserve process/sidecar/archive snapshots; `release.json` records
AF release. `artifact-inventory.json` seals all delivered AF files except itself.

Parent independent review of the actual evidence precedes any future parity
candidate grant. **No positive admission, production promotion or map acceptance
is claimed. All60 candidate map walks remain unrun.**
