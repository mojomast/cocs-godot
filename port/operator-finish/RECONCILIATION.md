# Actual-content runtime reconciliation

Content dependency: `8d84b3ff` (cherry-picked locally as `b0cd913c`). Runtime
corrections are separate from the existing FPS/FIGHT/package commits; apply them
on the parent's already-combined content/runtime tree without re-picking content.

## Preserved original failure

The pre-reconciliation command was rerun against the actual delivered assets and
failed exactly as reported by the parent:

```
python3 tools/operator-finish/runtime/validate.py --output /tmp/opencode/operator-finish-pre-reconcile-coverage.json
AssertionError: texture lacks hash/dimension record: res://source_operators/moth_finish/assets/shared-rubber-albedo.png
```

Traceback: `check_provenance`, original validator line 82. The full local stderr is
retained at `/tmp/opencode/operator-finish-pre-reconcile.log`. The old validator
expected nested `path`/`sha256` records. Delivered texture records are keyed by
resource path and use `png_sha256` and `dimensions`. The correction reads that
actual schema and retains hash, dimensions, encoding, registry input and frozen
source checks.

## Runtime material correction

Delivered L8 roughness maps encode physical perceptual roughness, with scalar
gain 1. Material installation now sets `roughness=roughness_gain` when a map is
present; multiplying the original scalar would have made them excessively smooth.
Albedo remains neutral modulation of the original palette/team tint, precision
vertex-color multiplication survives, and existing source optics/emission remain
preserved. The nine rubber finishes' normal omissions remain explicit and untouched.

All nine source import configurations set `meshes/ensure_tangents=true`. This is
configuration evidence, not a claim that their imported arrays contain correct
tangents. Normal-bearing surfaces still fail the entire atomic install if their
actual imported tangents are absent. Native lifecycle checks additionally assert
real map/scalar assignments and retained render traits. No blanket normal-map
removal or geometry replacement was introduced.

## Completed source checks

- Runtime real-manifest validator: **PASS** — 63 finish IDs, 116 actual PNGs,
  1,014 source primitives: 538 matched, 476 intentionally excluded, 0 unmatched.
- Runtime tests: **14 passed**, including real resource/provenance graph, all
  actual finish tokens, explicit rubber normal omission, and hash/dimension/channel/
  Moth-key tampering rejection.
- Content validator: **PASS** — decoded pixel hashes, actual UV/material coverage,
  protected ancestry, neutral albedo, normal vectors and roughness variation.
- Content `build.py --check`: **PASS** — deterministic byte-for-byte reproduction.

Outputs: `/tmp/opencode/operator-finish-merged-coverage.json`,
`/tmp/opencode/operator-finish-content-validation.json`, and
`/tmp/opencode/operator-finish-content-reproduction.log`.

Native import/render, lighting/readability, simultaneous team switching, moving
attachments and fighting pair/LOD checks remain with Astra under the exclusive
heavy grant. No native tools were run by this worker.
