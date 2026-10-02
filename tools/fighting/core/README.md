# Core gates

Source-only (no engine/import):

```sh
node --test tools/fighting/core/source.test.mjs godot/tests/fighting/content/content.test.mjs
gdparse godot/fighting/core/*.gd godot/tests/fighting/core/*.gd
```

After the parent grants the native slot, execute with the pinned stock Godot 4.5.2:

```sh
LP_NUM_THREADS=1 "$GODOT" --headless --path godot --script res://tests/fighting/core/run.gd
LP_NUM_THREADS=1 "$GODOT" --headless --path godot --script res://tests/fighting/core/invariants.gd
LP_NUM_THREADS=1 "$GODOT" --headless --path godot --script res://tests/fighting/core/actual_content.gd -- --report=/absolute/evidence/actual-combos.json
```

`run.gd` tests functional synthetic encounters, guards, tech frame ten, command
escape, unique mechanics, JSON replay, seeded AI damage and match lifecycle.
`invariants.gd` generates nine mirrors and 36 distinct pairings, mirrored input
logs, bounds, monotonic IDs and replay. `actual_content.gd` executes all 27 authored
traces in both facings and writes full failing/passing traces. It requires actual
contacts and uninterrupted combo counters; timing estimates are not a pass.
The fixtures run RefCounted authority without scenes or render assets. They still
require a native grant; grammar parsing is not a Godot type/runtime check.
