# AI bounded native admission diagnostic

Base `8478cd8c`; helper commit `cc2b72fd`; branch `astra/walker-parity-admission-ai`.
Authority: `MOTH-BLENDER-20261004-AI`, now **released**. Exactly two separately
supervised engine invocations occurred, without retries or native source changes.

## Actual results

| Group | Invocation | Native evidence |
|---|---|---|
| negative-controls | Godot0 / supervisor0 | PASS34/34 pairs,68/68 profiles; no failed/interrupted/unrun records |
| inclined-landing-rejections | Godot2 / supervisor1 | FAIL at `predecessor.native_policy`; no native result file |
| positive-step-admission | Never authorized or invoked | UNRUN4 pairs/8 profiles |

The single actual stderr diagnostic names predecessor `negative-controls` and
predicate `Policy.successful`. The original line is preserved verbatim in
`godot/tests/walker_parity_admission/parity-admission-ai-01/inclined-landing-rejections.log`
and in `evidence/analysis.json`. Its source/grant/engine/dependency/native/supervisor
hashes match the actual AI files. The supervisor final scan classified it as
`admission_failure`; its failed flag remains true despite clean release.

**This identifies the driver gate, not an internal Policy/Evidence subpredicate.**
Host strict replay passed before launch, whereas this native predecessor check
rejected. No timestamp, numeric or other internal cause is established. This AI
observation does not retrospectively trace AH's silent failure.

The staged driver line105 emits this code on `Policy.successful` rejection;
line119 returns before `ready = true`, receipt census initialization, and the
campaign dispatch at lines130–131. This bounds the labeled driver admission
phase before campaign world construction. It does not instrument every physical
call. The actual diagnostic explicitly says `nativeCountersKnown:false` and
`physicalCallCounts:null`. Inclined internal attempted/completed/failed/
interrupted/unrun counts remain **unknown**. Zero instrumented completions and
an absent result file are not zero internal work or an empty native receipt.

## Negative checkpoint

`evidence/negative-controls-checkpoint.json` and the subsequent additive
`negative-controls-owner-review.json` were saved after negative release and before
inclined launch. Strict current host native/supervisor predicates and next-group
dependency replay passed. Independent raw-record inspection confirmed:

* Exact34-pair/68-profile ordered census and expected fixture mechanisms.
* 1,284 settling records,72 input records including jump launches,678 candidate
  ordinary responses; zero applied assists and zero verified lifts.
* Exact paired position, velocity and grounded agreement; consecutive60Hz clocks,
  timeScale1 and one reset per profile. Radius.42 positive ordinary Y remains
  baseline motion, not an assist.
* Exact AI hash bindings, exit0, no errors or admission marker, and three distinct
  measured empty release audits within the lock interval.

## Source, commands and preservation

The minimal stage contains the same16 reviewed scripts plus project settings;
all15 production dependencies and host pins were checked. Its sealed grant has
exactly the negative/inclined allowlist, the reviewed phase/mode and no extra keys.
The absolute hash-bound Godot4.5.2 binary was used without a PATH fallback.
Actual argv/environment/owned kernel identities are in each supervisor receipt;
`evidence/execution-record.json` records the preparation and supervisor commands.
The first parse happened inside the first supervised group. The source retains
the170-second internal timer and180-second supervisor timeout, nonwaiting lock,
single-threaded scene and LP/OMP thread limits of1.

Both owned groups were empty in three final measured audits. Lock availability
was measured at `2026-10-04T06:14:39.405465Z`; explicit AI release was recorded at
`2026-10-04T06:14:39.405496Z`. No engine ran after release and no work is queued.

Before/after preservation verified AH42, AG29, AF24, AE46, AD45, AB140, Z253,
X600, U264, AA141, AC265, historical receipts and15 production dependencies.
All25,544 preexisting sidecars were unchanged; no new sidecars or cleanup.
Viewer PID2598700/PGID2598689/startTicks522477875 and seven displays were preserved.

147 portable Python tests passed after release (9+49+24+18+8+7+32). These tests
are not native validity evidence. No positive admission, map admission or
production accounting claim follows. All60 candidate map journeys remain unrun.
Any further investigation/execution requires separate parent review/authority.
The exact-byte artifact inventory self-excludes only its own manifest.
