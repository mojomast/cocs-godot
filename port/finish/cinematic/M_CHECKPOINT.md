# Cinematic M — in-progress checkpoint

**Superseded:** M completed and released at `2026-10-03T08:08:16.973785Z`, documented
in `M_PRODUCTION.md`. Parent discovered the completed handoff while answering the
user's missing-in-flight question, verified release/MP4 identity and integrated
the delivered branch as `701d4caf`. Eleven parent pipeline tests pass. The earlier
capturing status below is historical; it must not be used as current activity.

Grant **`CINEMATIC-NATIVE-20261003-M`** remains exclusively owned by
`ses_f03411df4ffeEk7157dyOo57NZ`. The worker's checkpoint response is not a
production completion or a grant release.

The producer reports fresh **attempt-02 capturing** from adopted parent
`623127c5` plus the fixture corrections below. Evidence root:
`/home/mojo/.tmp-on-disk/cocs-cinematic-M-evidence-20261003`.
Attempt-01's interrupted capture and actual frames are retained. Existing v1/v2
movie hashes and original menu bytes were recorded/preserved. Native import
preserved all 116 committed operator texture sidecar hashes.

## Reviewed fixture corrections

| Worker | Parent | Correction |
|---|---|---|
| `f57576ba` | `1912a2bd` | Explicit `WeakRef` type for native menu teardown fixture |
| `966d6d86` | `0646c936` | Hide the interactive cheat/debug launcher in offline capture, keeping gameplay HUD |

Parent reviewed both diffs, parsed both GDScripts and passed all **10 cinematic
pipeline source tests**, including real ordinary-source input effects, frame
completeness, explicit-grant refusal, asset-fallback refusal, menu rollback and
execution-artifact validation. Diff checks pass. These source checks do not prove
capture completion or installed-Home acceptance. Parent integration does not
change the worker's active source identity or reattribute its earlier frames.

## Pending production work

Capture completion, encoding, technical visual/audio review, candidate and
installed-Home acceptance, and three empty ownership audits remain pending.
The independent human-listening gate and frozen-candidate final acceptance cannot
be inferred from an encoded movie. Do not start another engine/encoder owner or
reuse grant M until the producer explicitly releases it with cleanup evidence.
