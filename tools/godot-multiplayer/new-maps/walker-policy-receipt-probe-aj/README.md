# AJ receipt-only native probe — collected and confirmed, released

Base `b424af67`; helper commit `bb403edf`; branch
`astra/walker-policy-receipt-probe-aj`. Explicit grant
`MOTH-BLENDER-20261004-AJ` is **released**. Exactly one supervised headless native
invocation occurred, including its first parse. No retry or source correction.

## Actual native observations

| Observation | Result |
|---|---|
| Native / supervisor exit |0 /0 |
| probeCollected |true |
| originalPolicyResult |false |
| correctedPolicyResult |true |
| variantAgreementPass |true;15 controls |
| mutantRejectionsPass |true; all7 mutants rejected |
| candidateRecords / membershipFailures |678 /678 |
| hypothesisConfirmed |true; independently recomputed by host |

The original and one-clause clone evaluated the same parsed frozen AI negative
receipt under its original AI validator-input hashes. AJ's execution grant was
separate. The unchanged diagnostic located case0/profile1/settle0 at
`Evidence.profile.lifecycle_invariant`, original source line139. Its checks were
`[true,true,true,false,true,true]` in the order returned, frame, integer_up,
up_membership, parent_calls, accepted_type. The actual operand was FLOAT0.0
(Variant type3); the allowed array contained INT0/INT1 (type2). The explicit
numeric alternative returned true.

This is a measured independently failing invariant, **not an instrumented trace
of the first executed internal branch**. It does not retroactively trace AH.
Original AI/AH failed results and unknown internal counters remain unchanged.
Shared parsed-object immutability is assured by reviewed source structure only;
no pre/post serialization observation is claimed.

### All15 controls

| Values | Types | Integer guard | Original membership | Numeric domain |
|---|---|---|---|---|
|literal0, literal1 |INT |true |true |true |
|JSON0, JSON1 |FLOAT |true |false |true |
|-1,2 |INT |true |false |false |
|.5 |FLOAT |false |false |false |
|false,true |BOOL |false |false |false |
|"0","1" |STRING |false |false |false |
|null |NIL |false |false |false |
|NaN,+Inf,-Inf |FLOAT |false |false |false |

All seven whole-policy mutants returned correctedPolicyResult=false: negative
count, fractional count, boolean count, missing record, duplicated case, wrong
source hash and wrong negative outcome. No mutant was saved as a campaign receipt.

## Exact evidence and execution

Stage: `godot/tests/walker_policy_receipt_probe/policy-receipt-probe-aj-01/`.
The stage archives six scripts, minimal project, exact frozen input copy, sealed
source/grant, start/owned supervisor metadata, native result and raw log. Original
Policy/Evidence, unchanged707 helper and reviewed driver match their pins. The
evidence clone changes exactly one membership clause, preserving `not integer(up)`;
the policy clone changes only its evidence preload. No campaign source changed.

* Source SHA256: `7bad2204e82a553be344756758aee97f876a976dcd25c7a335cea948eb22c3c5`
* Grant SHA256: `fc3c3a85fe17b208599526f7e946893ea88d638f8d4df71964df6d57c237cfb0`
* Native result SHA256: `d923e1dda20e2492ff413138dfc20a49434cb3792927f7d6f394b475c239c588`
* Supervisor SHA256: `6a20af8d1657e3f8d8b7bac5d37f044e823dbf896445845ee065d76d61484efd`
* Raw log SHA256: `ca7f9585f3936d3db0a49671eb2772e28435313d64915d51b1939981336c6518`

The raw log contains the official4.5.2 banner and exactly one PROBE_RESULT marker,
no script/admission/probe error markers. JSON body3,605 bytes; raw log3,692 bytes.
The reviewed wrapper captured stderr and wrote the parsed diagnostic result;
native code wrote no files. `evidence/execution-record.json` records exact
preparation/supervisor commands, engine argv, parameter bounds and result hashes.

## Release and preservation

Owned PID/PGID3162248, startTicks628075682. Supervisor release audits were clean
and strictly ordered inside the recorded lock interval. Three further final
measured audits found the group empty. Lock available at
`2026-10-04T07:07:14.880108Z`; explicit AJ release at
`2026-10-04T07:07:14.880139Z`. No queued work or engine invocation after release.

Before/after preservation verified AI40, AH42, AG29, AF24, AE46, AD45, AB140,
Z253, X600, U264, AA141, AC265,15 production dependencies, historical receipts and
reviewed probe sources. Viewer PID2598700/PGID2598689/startTicks522477875 and seven
displays were preserved. All28,846 preexisting sidecars were unchanged; no new
sidecars and no cleanup. The exact-byte inventory self-excludes only its manifest.

80 portable Python tests passed after release (26 probe +5 diagnosis +49
admission). These are separate from the actual native observations above.

## Qualification boundary

This confirms the receipt-only numeric-membership hypothesis for this frozen
input and exact one-clause clone. It is not movement, campaign or positive
admission, and does not authorize reuse of AI as a fresh prerequisite. No
Walker/body/world creation or physics-query code is present in the reviewed
probe closure; that is a source-scope assurance, not engine-internal tracing.
Production validator changes and any fresh campaign require separate review and
authority. Positive4 pairs/8 profiles and all60 map journeys remain unrun;
production accounting remains open.
