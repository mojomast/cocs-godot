# Parallax tangent classification — parent integration note (2026-10-05)

**Delivery:** `ec50ae95` on `spacebunny/parallax-tangent-classifier-20261005`
(worktree `/home/mojo/.tmp-on-disk/cocs-walker-snap-compare-af`); merged as
**`fd0d8175`**. Seven new files only; no existing tracked file modified.

## Parent verification

- Re-ran the classifier suite: **35/35 pass** (78.9 s); appearance contract:
  **40/40 pass** (32.7 s). Existing `test_provenance.py` and
  `test_diagnosis.py` remain passing.
- Artifacts are driven from committed evidence and hash-matched to the pinned
  X / AA / AC GLBs; the AC path is re-derived from committed X, so the result is
  reproducible without the external worktree.

## Classification outcome (the "4,729" question)

319,065 supplied records, 155,553 faces each:

| category | X | AA | AC |
|---|---:|---:|---:|
| (a) spec-invalid | 17 | 16 | **0** |
| (b) spec-valid, derivative-disagreeing | 314,180 | 314,178 | 314,178 |
| (c) unaffected/other | 4,868 | 4,871 | 4,887 |

So the 4,729/4,745 figure is **entirely (b)/(c)**, and the artifact under
review (AC) has **zero spec-invalid records**. This matches the classification
proposal in `BLOCKERS_EFFICIENCY_20261005.md` §2. It is not itself an
appearance acceptance.

## Measured findings that remain review-pending

- **Saltstone face 11823:** AA's sign change does **not** preserve X appearance
  — 2/2 comparable corners reverse green 180° (world normal 4.90°/5.59°). This
  answers the provenance report's open question in the negative. The approved
  three-corner AC edit is **not revoked** by this note; a reviewer/render or
  authored-intent decision is required before any revert.
- **Five U-reversed corners** cannot be qualified source-only (narrowest UV edge
  is ~5.96e-5 float32 ULPs; `dP/du` is cancellation noise).
- **Sixteen glyph records** changed appearance necessarily (degenerate frame had
  zero green contribution).
- The two pinned shader paths diverge up to **15.06°** at reviewed strengths,
  identically in X/AA/AC — no reviewed edit caused it.
- **452,022 / 452,022** spec-valid full-rank corners select the identical
  bilinear REPEAT sample under the exporter V-flip + bottom-up image buffer;
  **319,046 / 319,065** records keep exact X bytes, so their perturbation is
  identity rather than a sign derivation.

## Scope

No artifact, GLB, registry, receipt or promotion change; no render proof. The
withdrawn shading-defect inference of `8c43b112` is not revived, and no
qualification statement is adopted by this integration. The next decision point
is whether the face-11823 corners warrant a bounded revert proposal — that
requires a reviewer or authored-intent/render input, not this analysis alone.
