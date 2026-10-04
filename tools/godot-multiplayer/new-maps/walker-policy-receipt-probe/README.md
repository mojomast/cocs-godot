# Frozen AI receipt-only numeric-membership probe — source proposal

Branch `astra/walker-policy-receipt-probe`, based on `707e2fe6` as permitted for
the dependent source task. All additions are in this namespace. The reviewed707
diagnosis files are untouched. Parent subsequently approved that diagnosis and
the one-clause source intent and integrated it as `609e0ca8`; this wrapper still
requires its own review and a separate explicit grant before preparation/run.

**No grant, native stage, engine, parser, import, renderer, server or actual child
job was used in this task.** Python tests only build source bytes in memory and
mock the child lifecycle in metadata-only temporary directories.

## Implemented future contract

| Item | Exact scope |
|---|---|
| Phase | `policy-receipt-probe-v1` |
| Mode | `frozen-receipt` |
| Group / allowlist | `numeric-membership` / exactly `["numeric-membership"]` |
| Namespace | lowercase `policy-receipt-probe-<tokens>`, write-once |
| Native invocations | One, no retries/continuation |
| Input | Exact immutable AI negative JSON SHA `708fda878f694b46c0ae1968aca653a206ac7b39e9f3af61e0807154cf2922f4` |
| Binary | Absolute nonsymlink Godot4.5.2, SHA `5803746bbe055bee0f07a3c5b0dd347719bd45599f3d34519a8a0beaf83014ae` |
| Output | One bounded `PROBE_RESULT ` JSON stderr record; supervisor owns output files |
| Acceptance effect | None: campaign/positive/native-step/promotion flags always false |

The **new execution grant** has exactly these eight keys, no extras:
`phase`, `mode`, `allowedGroups`, `grantId`, `authorized`, `expiresUnix`,
`sourceSha256`, `engineSha256`. Both host and native validate the new phase/mode,
exact group allowlist, explicit nonempty grant ID, true boolean authorization,
finite future expiry and exact source/binary hashes. There is no grant creator.

AI's original source/grant/engine hashes are fixed **historical validator inputs**,
not execution authority. Neither a collected probe nor corrected-policy true
changes AI's failed inclined result or qualifies a fresh campaign prerequisite.

## Preparation and closure

`prepare.py` verifies all40 frozen AI inventory entries (hash and byte count),
the manifest itself, original source/grant/receipt/policy/evidence hashes, current
host pins and the existing reviewed source/host/15-production-dependency pins
before writing. An explicit absolute nonsymlink `--ai-root` is required.

The future minimal stage contains exactly **six scripts**, project settings and
one fixed-name copy of the receipt:

1. Original `tests/walker_parity_admission/policy.gd`.
2. Original `tests/walker_parity_admission/evidence.gd`.
3. `probe/cloned_evidence.gd` — exactly one byte replacement:
   `not up in [0,1]` → `(up != 0 and up != 1)`.
4. `probe/cloned_policy.gd` — only its preload basename changes to
   `cloned_evidence.gd`; every method remains byte-identical.
5. The unchanged707 bounded `probe/diagnostic.gd`.
6. `probe/driver.gd`.

Original file hashes must match before cloning. Missing/duplicate needles fail;
no regex, runtime code editing or dynamic evaluation is used. The preceding
`not integer(up)` remains intact, including finite numeric/type checks. The clone
is a probe artifact, not a patch to any production or campaign validator.

The source seal binds exact per-file hashes, namespace, receipt and AI manifest,
and this wrapper's host-pins manifest. Changing the namespace or host code changes
the source seal. The stage is nested under
`godot/tests/walker_policy_receipt_probe/` but has its **own minimal project** and
is always the explicit engine `--path`. There is no main scene, autoload, Walker,
controller, map, body/world creation, or physics-query API in the closure.
The SceneTree entrypoint supplies lifecycle/quit only; this is still an engine
invocation, never described as an engine-free future probe.

## Native observations

The driver parses the frozen receipt once. Original and one-clause-clone whole
Policy.successful calls receive that **same parsed dictionary**, the negative
group, and the original AI hash arguments. The helper remains original-policy
diagnostic only. Its bounded report preserves the distinction between a located
independently failing lifecycle invariant and the unknown first executed branch.

The report includes:

* Original and cloned whole-policy booleans, without forcing expected values.
* Original helper case/profile/record location, Variant types and six checks.
* Fifteen isolated controls: literal INT0/1, JSON FLOAT0/1, -1,2,.5, false/true,
  strings0/1, null, NaN, +Inf and -Inf. Nonfinite values are never serialized;
  only names, type IDs and check booleans leave the process.
* Count of candidate records and original-membership failures across the frozen
  receipt (source-model expectation678, actual future observation reported).
* Seven independent deep-copy mutants checked by the cloned whole policy:
  negative/fractional/boolean applied count, missing record, duplicated case,
  wrong source binding and wrong negative outcome. The original dictionary is
  never mutated; no mutated receipt is written to disk.

`probeCollected` means a structurally valid, hash-bound diagnostic was captured.
`variantAgreementPass` compares observed types, membership and numeric-domain
checks to the precise modeled control expectations. `mutantRejectionsPass`
requires every mutant to reject. `hypothesisConfirmed` requires **original false,
clone true**, both control suites passing,678 candidate records and678 original
membership failures. The host recomputes these summary booleans; inconsistent
reports fail validation.

If original is unexpectedly true, or the clone still rejects, a consistent result
can still be a successfully collected probe with hypothesisConfirmed=false.
No second predicate is patched or retried. Such a result goes back to review.

## Supervision and failure paths

`supervisor.py` is a dedicated diagnostic wrapper, not a relaxed campaign
supervisor. `ownership.py` isolates the reviewed AG ownership/audit pattern with
ESRCH handled as a race requiring measured audits, never proof of release.

* Nonwaiting `/tmp/opencode/cocs-finish-acceptance.lock`; lock held through cleanup
  and final receipt handling.
* Source/grant/engine and AI40 revalidation inside the lock before launch.
* Write-once start marker consumes the stage **before Popen**, even if launch
  fails; exactly one Popen call, no queue or retry.
* Absolute binary, headless/single-threaded scene, LP/OMP threads1, new session.
* Kernel PID/PGID/startTicks identity checked before signaling; no process-name
  kill or shared cleanup. Unknown/reused identity cannot claim clean release.
*170-second **cooperative** native elapsed-time checks at policy/mutant boundaries;
  a blocked synchronous native call is bounded by the180-second external deadline.
  Host waits for child exit with bounded cleanup and independently audits the group.
* Three measured, strictly increasing empty release audits within the recorded
  lock interval; cleanup/restoration failures cannot become success.
* Poll and fast-exit final scan detect SCRIPT ERROR, Parse Error,
  ADMISSION_FAILURE and PROBE_FAILURE. OriginalPolicyResult=false is data and
  does not emit an admission-failure marker.
* JSON result body ≤8KiB; exactly one result line; captured log ≤64KiB; duplicate
  JSON keys, malformed/nonfinite output, contradictory summaries and bad hashes
  fail closed. Raw log survives even when a parsed result file is absent.
* Native writes no files. Supervisor writes `probe-result.json` only for a valid
  diagnostic record, plus its distinct `probe-supervisor.json`. Neither is named
  or shaped as an admission predecessor receipt. A nonzero native exit still
  fails supervision even if a valid observation was collected.

## Manual future commands — not run

After wrapper approval and explicit new authorization, preparation is:

```text
python3 -B tools/godot-multiplayer/new-maps/walker-policy-receipt-probe/prepare.py policy-receipt-probe-<authorized-attempt> --ai-root /home/mojo/.tmp-on-disk/cocs-walker-parity-admission-ai
```

The owner then seals a separately authorized `grant.json` using the reviewed
eight-key schema and the actual newly prepared source hash. There is deliberately
no populated grant example or command that manufactures authorization.

Exactly one subsequent supervisor command uses:

```text
python3 -B tools/godot-multiplayer/new-maps/walker-policy-receipt-probe/supervisor.py --fixture <absolute-new-stage> --ai-root /home/mojo/.tmp-on-disk/cocs-walker-parity-admission-ai --engine /tmp/opencode/cocs-horde-e353522a-package/toolchain/Godot_v4.5.2-stable_linux.x86_64 --group numeric-membership --mode frozen-receipt --grant-id <new-explicit-grant-id> --grant-sha256 <new-sealed-grant-sha256>
```

The owner must stop after that invocation, inspect raw log/receipts and complete
the explicit grant release/lock-availability record. No campaign is automatically
started. Even confirmed numeric diagnosis leaves a reviewed actual validator
change and fresh campaign source/grant/prerequisites as separate work.

## Source-only verification

26 new portable tests plus5 unchanged source-diagnosis and49 unchanged admission
tests passed (**80 total**). Tests cover exact clone reversal, pinned AI40,
minimal closure, virtual stage hash tampering, grant schema/expiry/scope,
consistent confirmed/disproved outcomes, malformed/duplicate markers, write-once
metadata, mocked fast exits/timeouts/launch failure, ESRCH and reused identities.
No test invokes Godot or stages native scripts. All new GDScript remains
**unparsed/unrun**; Python results do not establish native validity.

AI40/AH42 and required historical inventories,15 production dependencies and
historical receipts remain unchanged. Positive4 pairs/8 profiles and all60 map
journeys remain unrun. AI inclined internal counters remain unknown; production
accounting remains open.
