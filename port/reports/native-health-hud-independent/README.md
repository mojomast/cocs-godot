# Independent rendered-HUD health/damage acceptance

At integrated runtime `9a8d59e`, the lead ran:

```sh
TMPDIR=/tmp/opencode \
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
GUEST_NODE_MODULES=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules \
node port/tools/native_health_damage/run.mjs
```

**PASS**, normal-rate source authority, real native guest physical movement,
owned private Xvfb. Full sanitized evidence and hashes remain at
[`ea3292e2-ba92-4b8a-a881-4f8074635ee9`](../../native-hud-acceptance/evidence/ea3292e2-ba92-4b8a-a881-4f8074635ee9/summary.json).

- **1,065** exact authority/native snapshot correlations.
- **316** post-render observations verify visible compact HUD labels/bars with
  the correct latest snapshot association and bounded 0.01 gauge rounding.
- Five damage events reconcile **49.419 HP + 5 armor** lost.
- `hurt.png` shows the authority-event damage edge pulse, with an observed draw
  in the captured frame, HEALTH 94 (source 94.256) and ARMOR 0.
- Health pickup raises source HP **50.581 → 85.581**, exactly **+35**. The
  rendered label/gauge show 85 / 85.58, with the health marker hidden.
- The same source pickup and native marker return after **12.000 simulation
  seconds**; 344 samples establish remaining outside the pickup radius.
- **1,854 input receipts** match queued native controls; ACK high-water 1,852
  does not establish individual application of every input.

The lead opened all three baseline/hurt/collected PNGs. These are genuine live
frames, not fixtures. Human sound/usability, OS focus and heal-to-cap remain
separate. Normal exit is a harness boundary, not proof of native recording
completion (`completionProven=false`). Owned children/server/private files were
cleaned up. The earlier agent's inconclusive route/output-cap attempt is retained
in its original evidence directory, not relabeled as acceptance.

Both old and new offline suites also passed **29 tests** after lead integration:
historical recordings explicitly select legacy text-only analysis, while
current evidence must prove visible widgets and same-frame overlay drawing.
