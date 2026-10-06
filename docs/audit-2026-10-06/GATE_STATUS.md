# Gate status — audit implementation 2026-10-06

Exact candidate: branch `audit/2026-10-06-implementation` from the audited
baseline `9b497d53c95b36198d5a0239ce578469b1acf358` (no source changes existed
between the audit and this implementation start). Engine: pinned Godot
`4.5.2.stable.official.6ce3de25a`.

## Known baseline failures (present at the audited SHA, now resolved or scoped)

| Baseline failure | Status |
|---|---|
| `port/native-campaign/core-provenance.test.mjs` compared the movement-only historical inventory against a later racing source (audit §21: 21 pass / 1 fail) | **Repaired by T1/F01**: the movement claim is scoped to its frozen commits; a new active-source test verifies current bytes through the reviewed chain. 4/4 pass. |
| `port/reports/verification.json` is a historical failed report from older dirty source `e530c1c9` (318 gates, 7 fail) | **Not a current regression.** Left untouched as historical evidence; the current aggregate was not rerun in the audit and is not claimed here. |
| README/CI selected the stale lattice derivative; a fresh documented launch failed source verification | **Repaired by T1/F01**: one active-source descriptor consumed by dev/package/CI/verify; semantic export and both suites resolve it. |

## Checks executed for this implementation

| Task | Command (summary) | Result |
|---|---|---|
| T1 F01 | `node --test port/native-campaign/core-provenance.test.mjs` | 4 pass / 0 fail |
| T1 F01 | modified-byte negative control through `verifySource(activeSource())` | rejected: `Derivative source byte mismatch: game/race.mjs` |
| T1 F01 | `node tools/godot-export/semantic.mjs <tmp>` (no env, descriptor default) | exit 0, 9 maps exported |
| T4 F12 | `godot --headless --script res://tests/main_menu/contracts.gd` | **1153 checks / 0 failures** |
| T4 F12 | `node --test tools/godot-package/route_parity.test.mjs` + `gen_routes --check` | 13/0 + parity green |
| T5 F11 | `node --test campaign.test.mjs interludes.test.mjs` then full native-campaign suite | 20/0 then 33/0 |
| T6 F08 | `godot --headless --audio-driver Dummy --script res://tests/protocol/audio_feedback.gd` | **412 checks / 0 failures** |
| T7 F07 | `node --test game/cadence.test.mjs` (new `cadence-source` gate) | 2/0; audit counterexamples reproduced |
| T8 F17 | `world_weather/unit.gd` (headless) and `world_weather/spatial.gd` (xvfb) | `WORLD_WEATHER_NATIVE_OK`, `WORLD_WEATHER_SPATIAL_OK` |
| T2/T3 | Flash decode-once + Space Bunny weapon profile worker branches | pending integration (see ledger) |

## Real process journeys executed

| Journey | Command | Result |
|---|---|---|
| Dev supervisor → menu → self-quit | `node tools/godot-dev/launch.mjs --experience=menu --smoke` | exit 0; `MENU_READY {"routes":26,"categories":5,"visible":16,"developer":false}` |
| Dev supervisor → menu with developer navigation | `COCS_DEV_MENU=1 node tools/godot-dev/launch.mjs --experience=menu --smoke` | exit 0; `MENU_READY {"visible":26,"developer":true}` |

## Explicitly unrun / not claimed

- The full `tools/godot-dev/verify.py` aggregate (384 registered gates) was not
  executed in this pass; individual affected gates were run instead.
- GPU/rendered captures, color-vision review, audio-hardware listening, human
  playtests, target-hardware latency/performance and the 4.7.2 engine trial are
  **unrun**. No hardware/visual/audio/human acceptance is claimed.
- Package builds/CI were not rerun for this candidate.
- The source-side blocked-muzzle contact classification (F08) and the weapon GLB
  material-role export (F17) remain gated source/asset phases.

## New regressions observed

None so far: every gate touched by T1/T4/T5/T6/T7/T8 passes, and the previously
red provenance test is green. Worker-branch validation is recorded on merge.
