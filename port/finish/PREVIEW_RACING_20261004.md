# Racing excitement preview — 2026-10-04

The racing gameplay and presentation package is playable in a fresh preview.
This is a source-candidate supporting advance, not a native acceptance, and the
preview channel remains non-final.

## Source change

Candidate **`c669e8f89cc80e3bc76ed95654fdb5199d396e9b`** on
`feature/relay-campaign`:

- `game/race.mjs` — slipstream/draft with build-up and cooldown, anti-ram
  contact (the car ahead no longer gains speed), full-throttle/braking bots with
  line variation, skill spread and rare mistakes, leader pace penalty removed,
  `finalLap` snapshot flag (`game/race.test.mjs` covers each behavior).
- `godot/sports/chase.gd` — speed-scaled FOV and boost pull-back via `pose.fov`.
- `godot/sports/demo.gd`, `godot/multiplayer_worlds/sports_demo.gd` — camera FOV
  wiring.
- `godot/sports/hud.gd` — gap deltas, FINAL LAP banner, speed vignette/streaks.
- `godot/audio/vehicle_service.gd` — per-kind engine pitch normalization.
- Sirocco Circuit furniture from `cb2fe663` — boost pads 5 → 10, item boxes
  7 → 12, coin arcs reworked; gates/geometry byte-identical.

The locked-source overlay, the seven production receipt advances, and the
support-test chaining are recorded in `port/finish/RACING_RECONCILIATION.md`.
Derivative commit `9812edfa`; movement contract and source lock unchanged.

## Builds

Preview invocation with `--preview --source-derivative` at candidate `c669e8f8`:

| Target | Archive | Bytes | SHA-256 |
|---|---|---:|---|
| Windows | `cocs-native-windows.zip` | 153,080,982 | `4f321a07e3103b249d270b6afe69914ddb95edd31ee7641953720d4b76c625ed` |
| Linux | `cocs-native-linux.tar.gz` | 112,812,967 | `b93c8c483eb9b8308a5afd4c6a08feb77cdc0ae83e38e17755b45e71888774a8` |

Build roots:
`.../cocs-racing-preview-20261004/windows-state/builds/1791142474169053161` and
`.../cocs-racing-preview-20261004/linux-state/builds/1791142474165677543`.

Published pre-release: `quiet-relay-racing-preview-2026-10-04`
(<https://github.com/mojomast/cocs-godot/releases/tag/quiet-relay-racing-preview-2026-10-04>)
with `cocs-native-windows.zip.sha256` and `cocs-native-linux.tar.gz.sha256`.

## Verification

- Fresh extraction + `manifest_validation.mjs` passed on both archives at
  candidate `c669e8f8`: Linux 194 files / 86 source modules / 40 adapters,
  Windows 202 files.
- Full `verify_linux.mjs` run passed: **23 cases**, `expansion` **73 pairs**
  including `stormglass-causeway/puma-race` (hash `6afb8a36…`, `sports_demo.tscn`)
  and `sirocco-circuit/puma-race` (hash `57b9e5a9…`, `sports_demo.tscn`), plus
  features and final content. Report: `.../verify-linux-report/result.json`
  (`status: passed`, `port_commit: c669e8f8`, `derivative_commit: 9812edfa`).
- Bounded packaged-launcher smokes on the Linux extraction (Xvfb `:77`,
  terminated by timeout as expected): both racing maps reached
  `PACKAGE_NATIVE_STARTED res://multiplayer_worlds/sports_demo.tscn` with zero
  script/parse errors; the only error lines are the headless ALSA dummy fallback.
- Public asset URLs return HTTP 200 with the exact sizes above.
- **Windows CI run [37229519706](https://github.com/mojomast/cocs-godot/actions/runs/37229519706)
  completed successfully** against the published tag and candidate `c669e8f8`
  (2026-10-04T19:45:59Z → 20:05:54Z): bundled runtimes, expansion pairs, native
  cases with cleanup, and resource checks passed.

## Caveats

- **Vesper Viaduct stairs:** native step-up remains unresolved; exposed for
  testing only.
- **Stormglass Causeway** still has no race furniture (boost pads/item boxes so
  far are Sirocco only).
- Race feel and native race acceptance are pending human play; final manual,
  audio, HUD accessibility/performance and Windows acceptance are not implied.
- Production motion accounting and the remaining map/manual checks are unchanged.

Please report race feel, camera, HUD and AI observations with the map, mode and
reproduction steps.
