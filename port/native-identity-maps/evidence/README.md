# Identity-map evidence index

Every file here was produced by this lane's own scripts (`tools/godot-identity-maps/`,
`port/native-identity-maps/`, `godot/tests/identity_maps/`). Nothing is a hand-edited result.
Failures are retained, not cleaned up.

## Current (post collision/materials/effects pass)

| Path | What it is |
|---|---|
| `rays-godot-1790087389545863610.json` (current; `rays-godot-1790085973446806397.json` is the pre-slimming run) | Godot-side answer to every exported fixture ray: 6,150 checks, 0 failures, 88 grazing rays counted apart, max hit delta 0.05 mm (4-decimal fixture rounding). |
| `source-rays.json` (in `godot/tests/identity_maps/`) | Exported fixture: 6,150 rays (every cover/wall/floor/sightline ray plus a deterministic 1-in-6 subset of the eye grid). The full 19,976-ray audit stays in `ray-report-*.json`. |
| `render-final-1790085699477045605/{960x640,1280x800,1920x1080}` | Five fixed cameras per map, real PNG dimensions asserted per size (`runner.json` records image count, expected count and dimension match). `report.json` carries per-camera median/p95, draw calls, primitives, video-memory counter and the map's full metrics snapshot. |
| `render-glow-1790085839420647575/960x640/` | Glow A/B at 960×640 (same cameras): enabling glow costs 1.0–3.0 ms per camera; every delivered image is glow-off. |
| `baseline-1790085987346036728/{960x640,1280x800}` | Existing-playable-map baseline: shipped native DM maps under the same 12+40 sampling harness, cameras derived from each map's own generated bounds/spawns. |
| `perf-1790087460080.json` (newest snapshot; earlier `perf-1790085393405.json`) | Cold/warm `createIdentityMatch`, `navigation()` split, obstruction cost, wall/segment counts per map (from `perf.mjs`). |
| `ray-report-1790087459265.json` (newest snapshot; `ray-report-1790086396086.json` and earlier `ray-report-1790084047408/…/1790085690401.json` include the intermediate failures) | Full parity audit: source vs prototype-exact classification, `visible()` parity, reachable-visible-mass probe, per-group counts and every mismatch. |
| `graybox-1790087460952.json` (newest snapshot; earlier `graybox-1790083*` show the prototype's exact-wall cost) | Source movement/nav/route fixtures including the cold-construction gate and per-map speed-up. |
| `lifecycle-1790085973446806397.json` (current) | Three headless build/free cycles with the effect pool, node/resource/orphan accumulation checks. |
| `contract-1790085973446806397.json` (current) | Material count, texture budget, collision-shape ownership, graybox parity, effect Low/High budgets. |
| `normal-rate-1790087066267/lacuna-court.json`, `normal-rate-1790087263321/{vermilion-fold,nacre-engine}.json` (current; `normal-rate-1790081542205/` is the prototype refresh) | Bounded wall-clock source-mode exercise (ordinary controls, no state injection), refresh of the prototype run. |

Retained earlier sets from the prototype milestone (`render-1790081*`, `graybox-1*`, `rays-*`,
`normal-rate-1790081*`) are **historical**: they show the all-1280×800 capture failure and the exact
wall-segment cost this pass fixed. Do not read them as current geometry.

### Failures kept on purpose

* `render-1790081900090569141` — the prototype's only dimension-correct set; earlier sets were all
  1280×800 despite their filenames. Kept as the failure record for the dimension assertion now in
  `capture.py`.
* `ray-report-*.json` snapshots from intermediate steps of this pass contain
  `reachable-visible-mass` and `classification` failures (Nacre vault feet with non-planar fan
  faces, a nested joint band with a z-offset, a 0.3 m decorative fin that was not collision). Each
  is what drove a geometry change; the current report has none.
* `rays-first.json` — the prototype oracle's initial `hit_from_inside` mismatch.
* `normal-rate-1790086195009/` and `normal-rate-1790086486046/` — concurrent refreshes that never
  wrote `lacuna-court.json` inside their wall-clock budget while the other two maps finished. Kept as
  the failure record for the per-map heartbeat and `--maps=` selector now in the runner; the current
  per-map runs are listed above.

### What is NOT in evidence

No hardware GPU, no packaged build, no live-match actors, no audio, no lightmap bake, no visual
acceptance by a human. The PNGs were inspected by this lane's agent for gross defects only; a human
pixel review is still required.
