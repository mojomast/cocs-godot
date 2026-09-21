# Live-reproduced zero-health / zero-timer respawn boundary

Retained genuine run `4b4af664-c092-4a8a-9336-4665ddeddb38` in
`port/native-death-respawn/evidence/` reproduces a real client lifecycle defect.
Snapshot 157, time 5.233, has health 0 / dead 0 at the old position. Native trace
442 classified it alive, capture-eligible and camera-reseeded. Snapshot 158,
time 5.267, restores health 100 at the actual authoritative respawn position;
native trace 444 failed to reseed. The earlier audit's hypothesis is now genuine
recorded evidence. Replaying the original run with its delivered analyzer exits
2 (FAIL); the later successful subagent run does not erase this failure.

`game/quantize.mjs` rounds wire numbers to three decimals. A positive timer close
to expiry can consequently arrive as zero before the authoritative spawn.
The native lifecycle now requires positive health as well as a nonpositive dead
timer to classify an actor alive. Remote visibility and interpolation lifecycle
use that same predicate. No server rules, timer, damage or spawn change is made.
Health absence retains the prior behavior for existing partial replay fixtures;
this change is not a complete nested snapshot schema validator.

The actual-session regression projects the recorded boundary, verifies that
look remains unseeded and controls neutral through health=0/dead=0, then verifies
one reseed at the healthy respawn pose. It failed **10 assertions, exit 1** before
the runtime change. Afterward:

```sh
"$GODOT_BIN" --headless --path godot --script res://tests/protocol/control_safety.gd
"$GODOT_BIN" --headless --path godot --script res://tests/protocol/local_lifecycle.gd
```

Both exited 0: **2,497 control-safety checks**, **15 local-lifecycle checks**.
These new regression inputs are explicitly projected/synthetic, not another
live session. Current-runtime live rerun and combined verifier are recorded
separately after execution. Original failure evidence is unchanged.
