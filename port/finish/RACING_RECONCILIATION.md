# Racing reconciliation (2026-10-04)

## Scope
Source-candidate advancement of the racing gameplay and presentation lanes. This
is a supporting-input reconciliation, not a native acceptance: race feel and
native checks remain pending human play.

## Content advanced
- `game/race.mjs` — slipstream/draft, anti-ram contact, full-throttle/braking
  bots with line variation and mistakes, leader pace penalty removed, `finalLap`
  snapshot flag (tests in `game/race.test.mjs`).
- `godot/sports/chase.gd` — speed-scaled field of view and boost pull-back
  exposed as `pose.fov`.
- `godot/sports/demo.gd`, `godot/multiplayer_worlds/sports_demo.gd` — wire
  `world.camera.fov = pose.fov`.
- `godot/sports/hud.gd` — gap deltas, final-lap banner, speed vignette/speed
  streaks.
- `godot/audio/vehicle_service.gd` — per-kind engine pitch normalization.
- `tools/godot-package/movement_dependencies.mjs`, `polish_dependencies.mjs`,
  `stormglass_imports.mjs` — chain latest-lane supporting hashes through the
  racing advance.
- `tools/godot-package/racing_dependencies.mjs` — validates and reverses the
  racing layer so the frozen pre-movement predecessor hashes still reconstruct.

## Derivative chain
- `port/contracts/racing-candidate-derivative.json` — additive overlay whose
  parent is the frozen `movement-candidate-derivative.json`; derivative commit
  `9812edfa`; source lock unchanged.
- `tools/godot-package/racing_derivative.mjs` — resolves the racing chain on top
  of the byte-identical movement resolver.
- `tools/godot-export/semantic.mjs`, `manifest_validation.mjs`,
  `windows_source_preflight.mjs`, `build.py` — call sites resolve the newest
  reviewed contract and fall back to movement for historical artifacts.

## Receipts
All seven production receipts gained a `racingAdvance` layer with before/after
values for every advanced file, package fingerprints, and a review boundary
pointing at this document. `production_requirements.json` pins the new receipt
bytes. Historical fields, evidence, and the `PREVIOUS` pre-movement receipt
hashes are preserved; `verifyRacingAdvance`/`reverseRacing` are exercised by
`movement_dependencies.test.mjs` and `promoted_assets_git.test.mjs`.

Pending: none of the seven units is re-accepted natively; native race acceptance
and the outstanding Vesper stair / motion-accounting work are unchanged.
