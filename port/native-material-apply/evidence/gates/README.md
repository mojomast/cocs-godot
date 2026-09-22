# Gate logs

Each `<gate>-after.log` is the raw stdout of one gate re-run after the material
application pass, on this working tree:

| log | gate |
|---|---|
| `aurora-after.log` | `res://tests/aurora_basin/validate.gd` (aurora-traversal) |
| `cinder-after.log` | `res://tests/cinder_array/verify.gd` (cinder-traversal) |
| `scenery-after.log` | `res://tests/moth_scenery/verify.gd` (moth-scenery) |
| `shader-after.log` | `res://tests/shader_lab/validate.gd` (shader-lab) |
| `identity-baseline-after.log` | `res://tests/identity_maps/baseline.gd` under a private Xvfb (identity lane's own DM-arena harness) |
| `identity-lifecycle-after.log`, `identity-rays-after.log` | identity map lifecycle and ray oracles |
| `exploration-walker-after.log` | `res://tests/graphics_batch/walker.gd` |
| `particle-lab-after.log` | `res://tests/particle_lab/verify.gd` |
| `zone-unit-after.log` | `res://tests/zone_modes/unit.gd` |
| `horde-model-after.log` | `res://tests/horde/test.gd` |
| `combined-arms-graphics-after.log` | `res://tests/combined_arms/graphics.gd` |
| `showcase-startup-after.log` | `node tools/godot-dev/launch.mjs --experience=showcase --smoke` (GODOT_BIN set) |
| `actual-maps-after.log` | `node --test port/native-arenas/tests/actual-maps.mjs` |
| `geometry-hashes.json` | the three arena geometry hashes, before vs after (identical) |

The graphics-terrain / graphics-atmosphere / graphics-fx / moth-resources runs
are recorded in `port/native-material-apply/evidence/logs/` and in the report
tables; harness-driven gates that need an external server or extra CLI args
(`graphics-live`, `native_modes_live`, `graphics-batch gallery`, `horde-controls`)
are not run from here.
