# Campaign numeric-membership correction — source only

Base `8c4ff45b`; branch `astra/walker-numeric-correction`. The independently
approved one-clause source intent is now applied to the actual campaign
`godot/tests/walker_parity_admission/evidence.gd:139`:

```diff
-not integer(up) or not up in [0,1]
+not integer(up) or (up != 0 and up != 1)
```

This is the only runtime-source difference. The **entire corrected Evidence
file** is byte-identical to frozen AJ's `probe/cloned_evidence.gd`, SHA256
`19b7c024e3f15a365cd0289bef45fc069f3908fd9325359dccffc556a3242be8`.
The prior file SHA was
`acbab472c5042bbe5d3d996fe45e9d71f1114dd24bc8f6316ba891bbaacdb96f`.

The preceding `integer(up)` still requires finite INT/FLOAT and integer value.
Only0/1 in either numeric encoding can pass. Bool, string, null, fraction,
negative/out-of-domain numbers and nonfinite values remain rejected. Python's
existing acceptance code already uses this numeric value domain and is unchanged.

Current campaign `review-pins.json` changes only that Evidence hash. The closure
remains16 scripts plus project. Policy, driver finish behavior, census34/4/4,
positive operands, predecessor bindings/errors, timestamp/audit checks, candidate,
controller, planner, guard/epsilon and physics code are unchanged. There is no new
in-memory acceptance call at finish and no change to170/180 supervision.

## Evidence and its review status

Source diagnosis `707e2fe6` and the one-clause source intent were independently
approved (parent integration `609e0ca8`). Frozen AJ archive `bfb32d4e` reports one
receipt-only native invocation: original whole policy=false, one-clause clone=true,
15 controls agreed,7 whole-policy mutants rejected,678/678 original membership
failures. AJ23 manifest SHA is
`dc49cc762bb1eab492e480c429c3528d982154943f32332f9e0d35029d5a030f`.
AJ's **independent actual-archive review is still pending** at this delivery.

The correction does not reinterpret AH/AI failures, identify their first internal
executed branches, or change their unknown physical-call counts. AJ is evidence
for the receipt-validator correction, not movement or fresh campaign acceptance.
The newly edited campaign source remains **unparsed/unrun** in this task despite
matching the previously exercised AJ clone bytes.

## Historical-tool compatibility: intentionally fail closed

The existing receipt-probe preparation pins the **original** canonical Evidence
and the former campaign review-pins hash. It now correctly rejects this corrected
checkout with `original source pins` / `host source pin`. It was not altered to
accept corrected input as historical original input. No probe expected hash,
source-provenance file or historical receipt was rewritten.

The two earlier diagnosis suites likewise assert that canonical Evidence still
equals AH/AI's original. Those assertions describe their historical versions.
All three historical suites were run from the preserved, original-source
`/home/mojo/.tmp-on-disk/cocs-walker-policy-receipt-probe` worktree, whose relevant
source files match the unchanged versions retained here. No monkeypatch or hash
widening was used. Future reproduction/preparation of that historical probe must
use its pinned original-source checkout and separately authorized scope.

The new test explicitly verifies the historical preparer's failure in the
corrected checkout. This preserves the existing toolchain instead of quietly
rebinding its original-policy experiment. A future multi-version probe adaptation
would be separate reviewed work, not part of this one-clause correction.

## Verification

**183 portable checks passed, with locations distinguished:**

| Location | Suites | Passed |
|---|---|---:|
| Corrected worktree | Existing admission49, response24, compare18, parity8, admission7, step-up32 |138 |
| Corrected worktree | New exact-delta/clone/domain/pins/archive/fail-closed checks |5 |
| Preserved original-source worktree | Historical probe26, policy diagnosis5, gate diagnosis9 |40 |

Thus143 checks ran against the corrected checkout;40 validated preserved
historical versions. This is not a claim that all historical suites pass directly
against changed canonical source. Tests use source/finite-domain checks and mock
child lifecycles; no native engine or stage is involved.

AI40, AJ23, AH42, AG29, AF24, AE46, AD45, AB140, Z253, X600, U264, AA141,
AC265 and15 production dependencies were verified. Historical provenance,
correction receipts and diagnosis/probe source directories remain byte-identical.
The additive `walker-parity-admission/numeric-correction-receipt.json` records
current seals without changing previous receipts.

No engine, parser, import, renderer, server, native staging, actual child job or
grant exists for this task. Any future campaign needs a **new sealed source and
grant**, fresh negative then inclined then positive prerequisites under those
same bindings, and explicit authorization for each allowed scope. AI/AH passes
cannot be reused to advance the corrected source. Positive4/8 and all60 map
journeys remain unrun; production accounting remains open.
