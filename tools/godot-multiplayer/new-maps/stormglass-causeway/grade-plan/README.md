# Stormglass grade plan — analysis tooling

**Source-only. Nothing here writes.** No runtime world data, no generated JSON, no
receipt, no artifact, no engine, no Blender, no network.

This directory is the deterministic backing for
[`port/finish/map-variety/STORMGLASS_GRADE_PLAN_20261005.md`](../../../../../port/finish/map-variety/STORMGLASS_GRADE_PLAN_20261005.md),
which proposes retiring the recorded flat-road concession for Stormglass Causeway
under one versioned grant. The concession itself is untouched and still truthful:
the accepted `recipe.mjs` still reports `roadRelief: 0` and the road is still Y=0.

| file | role |
|---|---|
| `grade-profile.mjs` | the authored elevation profile: 21 knot heights, caps, grade ledger, relief, per-gate windows, the proposed gate predicate, and the break/lag models |
| `grade-analysis.mjs` | builds the proposed graded world **in memory** and measures it with the real `game/terrain.mjs`, `game/vehicles.mjs`, `game/core.mjs` and `game/race.mjs` |
| `report.mjs` | prints the measured report to stdout; `--json` for the raw object |
| `grade-plan.test.mjs` | 30 bounded source tests |

```sh
node tools/godot-multiplayer/new-maps/stormglass-causeway/grade-plan/report.mjs
node tools/godot-multiplayer/new-maps/stormglass-causeway/grade-plan/report.mjs --json
node --test tools/godot-multiplayer/new-maps/stormglass-causeway/grade-plan/grade-plan.test.mjs
```

`grade-analysis.mjs` deliberately reuses production code rather than
re-implementing it: `terrainSupportAt` for authority support, `stepVehicle` for
grip/slope/suspension, `obstructed` for static contact, `crossRaceGates` for the
gate rule. Change the proposal and the report moves; change the proposal without
moving the report and the tests fail.