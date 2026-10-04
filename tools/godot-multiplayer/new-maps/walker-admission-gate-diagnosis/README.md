# AH admission-gate diagnosis — source only

Branch `astra/walker-admission-gate-diagnosis`, based on parent `5b01702e`.
AH is read **only** from `/home/mojo/.tmp-on-disk/cocs-walker-parity-admission-ah`.
Its42 inventory entries were verified, and none of its sources, receipts or logs
were modified. Parent approval/integration of AH (`58138256`, `d1aa4b63`,
`dcda8780`) is retained as archive approval, not new execution authority.

## Finding

**No concrete cross-language rejecting predicate was established.** The actual
native branch remains untraced. The proposed fractional-time-collapse cause is
not supported by the staged source or actual audit data:

* The staged `evidence.gd:332–338` parses the first19 characters as whole seconds,
  verifies the calendar round-trip, then explicitly adds
  `float("0." + text.substr(20,6))` before strict ordering/interval checks.
* Godot4.5.2 `core/os/time.cpp` returns whole seconds and defaults the round-trip
  separator to `T`; `core/variant/variant.h` stores FLOAT as a double. Source URLs,
  hashes and line references are in `references.json`.
* AH's first two negative release audits share a second; its third is in the
  **next** second. The actual values and binary64/calendar source-model results:

| Audit UTC | Exact epoch microseconds | Gap from prior audit |
|---|---:|---:|
|05:31:35.735655Z |1791091895735655 |— |
|05:31:35.952341Z |1791091895952341 |216686µs |
|05:31:36.171950Z |1791091896171950 |219609µs |

All lie strictly after lock acquisition and no later than release-pending time.
Binary64 spacing here is about.238419µs, far below those gaps. This is source
reasoning plus a Python binary64/calendar model, **not a measured GDScript result**.
No speculative timestamp/parser replacement or ordering relaxation was made.

The offline integer-microsecond reference tests the existing exact six-fractional-
digit `+00:00` emitter schema. It includes three audits within one second, duplicate
and reversed audits, one-microsecond midnight carry, leap day and malformed
calendar/fraction/timezone forms. Existing runtime format remains unchanged:
`Z`, `-00:00` and nonzero offsets are not silently accepted as new alternatives.

## Gate comparison against actual AH bytes

Full machine-readable output is `diagnosis.json`; it includes all68 profile
checks and exact source/grant/engine/native/supervisor/dependency hashes.

| Gate / predicate | Established offline result | Native qualification |
|---|---|---|
| `_initialize`: CLI keys/count/group/mode |Five unique reviewed args, correct group/mode |Actual argv archived; branch not traced |
| `_initialize`: output existence |Inclined result absent in frozen archive |No retrospective assertion about an unrecorded native check |
| `run`: grant hash/schema/phase/allowlist/engine/expiry |Strict host validation passes at both historical invocation endpoints |Godot clock value at the predicate was not recorded |
| `run`: source order/schema/input hashes |Actual16 scripts + project match sealed file hashes |Hashes concern file bytes, not JSON dictionary reserialization |
| `predecessors`: dependency hash/bindings/count/member/result/supervisor hashes |Exact strict host dependency reconstruction matches archived dependency JSON |Native path not traced |
| `Policy.successful`: counters, flags, roles and census |Actual negative receipt passes; also passes a Python model parsing every JSON number as double |Not a Godot JSON/parser/type-equality execution |
| `Evidence.campaign/profile`: parameters, clocks, ordinary lifecycle, reasons/stages, paired states |All34 pairs/68 profiles pass strict current host predicates |No claim of native expression-by-expression equivalence |
| `Evidence.supervisor_ok`: bindings, flags, errors, owned identity, return code |Actual negative supervisor passes |Native predicate outcome unknown |
| `Evidence.supervisor_ok`: timestamp format, round-trip, fraction/order/interval |Source model passes with distinct reconstructed epochs |Actual native Time/RegEx calls unobserved |
| Actual rejecting native branch |Not localized |Exit2, banner-only log, no native receipt remain the evidence |

The inclined invocation was within the sealed expiry by more than57 minutes.
Common initialization had succeeded for the earlier negative invocation with
the same source/grant/engine. These observations narrow the investigation but
do not convert an inferred predecessor rejection into a measured cause.

AH's accepted accounting is unchanged: negative34/68 PASS; inclined invocation
FAIL with internal attempted/completed/failed/interrupted/call counts unknown;
positive4/8 UNRUN. Zero **instrumented** completion is not an internal zero count.
Radius.42 positive ordinary Y displacements remain ordinary motion, not assists.

## Minimal future-source diagnostic

The only native-source edit is admission diagnostics in the current proposed
`godot/tests/walker_parity_admission/driver.gd`; frozen AH's copy is untouched.
Twenty stable labels cover the formerly silent argument, output, grant, source
and predecessor gates. In particular, the previously indistinguishable calls
now identify `predecessor.native_policy` (`Policy.successful`) versus
`predecessor.supervisor_policy` (`Evidence.supervisor_ok`). These identify the
exact **driver gate**, not an invented internal subpredicate cause.

`fail_admission(code, details)` emits at most one bounded `ADMISSION_FAILURE `
JSON record on **stderr**, then preserves exit2. It contains fixed phase/mode,
allowlisted group or null, a stable code, available file hashes, fixed predecessor/
predicate labels, failed=true, nativeCountersKnown=false and physicalCallCounts=null.
It does not echo raw CLI arguments, grant IDs, paths, secrets, textures or complete
receipts. The worst-case fixed metadata schema is below2KiB. No output path is
constructed or file written, even before grant validation. The reviewed supervisor
already captures stderr in its owned write-once log.

The supervisor's final log scan now recognizes this marker as `admission_failure`
without killing on it during the poll loop, preserving the engine's intended
exit2. A mocked regression rejects the marker even if a contradictory mocked
child returns0 and supplies a passing native summary. Clean release still cannot
override failure. A malformed predecessor entry now receives a schema label
instead of relying on a dictionary cast error.

All grant/campaign/support/supervisor acceptance predicates and timestamp
implementations remain byte-identical to the reviewed source. So do the candidate,
guard/epsilon, planner, fixtures and movement code. No threshold, count, canonical
matrix, audit order, query binding or positive operand check was relaxed.

## Verification and next boundary

Nine new tests plus all138 existing Python tests passed (**147 total**). New tests
cover actual frozen-AH replay/hash preservation, timestamp source models and
strict invalid cases, diagnostic-label coverage, bounded stderr-only emission,
unchanged validator bytes and mocked final-log rejection. GDScript tests are
explicitly structural; the changed driver is **unparsed/unrun**.

`review-pins.json` seals the updated driver/supervisor; the minimal closure still
contains16 scripts. Earlier provenance/correction receipts remain historical and
unchanged; `source-receipt.json` records current seals and preservation.

No engine, import, render, server, native attempt staging, actual child job or
grant was used. There is no new native mode or diagnostic campaign framework.
Independent source review is required. Any authorized future execution must use
a new sealed source/grant and rerun negative prerequisites under those bindings;
AH receipts cannot authorize continuation under the new hashes. All60 candidate
map journeys remain unrun, and production pre-lift accounting remains open.
