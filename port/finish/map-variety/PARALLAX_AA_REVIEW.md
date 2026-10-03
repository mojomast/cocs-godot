# Parallax AA — source and failed-attempt archive approved

Independent Astra `ses_efd0e4deaffeke8j2rdXdxtbbn` approved producer source
`ed3582c6` / `bd0aa9c2` / `38106ce2` and evidence `b9c53e82` for integration
as a **failed full native acceptance attempt**. Parent selected them as
**`1b7dff8a` / `673d0a0f` / `badfedc3` / `dec159d4`**.

The three targeted saltstone corners are corrected in actual GLB and native
readback. The all-face native basis gate still fails. **AA is not an approved
successor artifact.** No broader patch or handedness waiver is authorized.

## Correction to original diagnosis — preserve original receipts

The immutable producer `AA_REVIEW.md:44–47` incorrectly describes two native −1
signs against canonical +1 signs. Independent inspection gives canonical corner
order:

| Data | Tangent handedness |
|---|---|
| Native `wayfinding-2`, face 963 | `[+1, -1, -1]` |
| Both matching canonical choices | `[-1, -1, -1]` |

**One corner differs.** Source face 965 has all −1 signs in both X and AA.
The two choices come from identical mesh-local geometry in `wayfinding-2` and
`wayfinding-3`. This corrects the narrative without changing the valid strict
failure, rebuilding artifacts or modifying hash-pinned receipts. The root-cause
investigator has received this correction.

## Verified artifact and master scope

- GLB: `95e9da98a45565ca2aae90858a9e5027d9123e4ffd1347da98d5de8573141cd5`.
- Master: `2e6617840ec57d08685dd78e64a29bbe7f55db2b1a26da40b6c6a46cd4c0373d`.
- Exactly five changed BIN bytes within 48 permitted positions; all other BIN
  bytes are preserved from the pinned X input.
- Both actual build/reopen editable exports pass all 155,553 oriented faces,
  39 flat mesh roots, zero position/normal/UV error and semantic material checks.
- Canonical output is deterministic and byte-identical after fresh reopen.
  Build/reopen source hashes and packed-recipe dependencies match delivered source.

The reviewer uniquely matched the repaired face by complete oriented geometry
and UVs, without tangent/handedness selection. All three native corners read
`(1, 0, -0.0000457784626633, -1)`, closing the bounded mesh-local defect at
vertices 24049–24051.

## Native proof and failed gate

Fourteen material-field sets and 39 decoded image-channel comparisons pass.
The staged GLB matches AA02, retains UID `uid://cv2bogce241on`, disables compression
and generated LODs. Strict all-face verification fails at the same wayfinding
face for both AA03 and AA04:

- Position and UV errors: zero.
- Normal error: `2.3752450943e-5`.
- Tangent/handedness component error: `2.0`.

Changing `ensure_tangents` from true to false does not resolve it. Unchanged
source bytes establish preservation, not source-basis correctness, importer
correctness or identical behavior in X's historical runtime. Root-cause disposition
is separate and source/static only.

AA01's module-path failure despite Blender exit 0 remains preserved. AA02's
successful commands use `--python-exit-code 70`. The GDScript parser failure and
subsequent strict failures remain separately recorded. Source changes fix module
loading, typed path and diagnostic output without weakening the contract.

## Parent verification and remaining work

Parent verified all **141 manifest hashes/sizes after integration** and passed
**19 checks**: six Python contract tests and thirteen Node staging/committed-Git
shipping tests. Original receipts remain byte-identical. All candidate resources
are confined to test/tool namespaces; artifact approval and public promotion are
withheld. Existing shipping exclusions and accepted histories remain enforced.

Release is verified: three empty audits/ten groups, supervisor receipt hash,
no current survivors and available lock at 23:32:12.751660Z. No heavy grant is active.

Matched lifecycle captures, fresh rays, traversal, performance and hosted acceptance
were not run. X's 13,587 capsules remain historical. A separately reviewed contract
must resolve the discrepancy before a new authorized attempt and full native gate.
Vesper's disposition is unchanged.
