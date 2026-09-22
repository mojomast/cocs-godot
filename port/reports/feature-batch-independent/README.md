# Feature-batch independent verification

Initial complete verifier attempt at `edc222f`:

```sh
PORT=0 TMPDIR=/tmp/opencode \
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
python3 tools/godot-dev/verify.py
```

The runner stopped on `round-boundaries`: all 12 synthetic assertions passed,
but a leaked render RID/ObjectDB instance correctly fails the gate. The original
report and output are copied here as `initial-verification.json` and
`initial-round-boundaries.log`.

After integrating the standalone Puma component (`e2fd1d3`), the lead separately
executed all **20** configured commands following that gate. Commands were read
from the verifier's `commands` assignment using Python AST and executed through
the unchanged `gate_runner.run_gate`; exact commands and outcomes are recorded
in `remaining.json`. This continuation runs every remaining command to inventory
failures; it does not change the full verifier's fail-fast behavior or constitute
a complete verifier pass. Release-refusal is outside this continuation.

- **13 pass**, including native lifecycle/results/restart, native session,
  two native clients, audio, combat, pickup/entity presentation, scoreboard,
  snapshot freshness and motion checks.
- **7 fail**: native-trace, guest-session, match-selection, control-safety,
  window-focus, session-recovery and stall-controls print passing assertions but
  leak render instances.

Each individual gate result is authoritative. Setup also emits a script error
accessing a null viewport's `size_changed` signal. That separate UI lifecycle bug
has been routed to the mode agent. The resource-leak investigation is assigned
through `port/handoffs/external-native-lifecycle-cleanup.md`.

No failed gate was accepted based on process exit or its own printed success
marker. Native trace completion remains unproven. All live gates use owned local
servers at normal source rate; synthetic gates remain explicitly synthetic.

## Corrected combined run

The external diagnosis/fix was integrated at `9dc82c8`: detached fixtures bypass
normal `_ready()` and did not adopt the viewer's new `environment` and `sun`
nodes. `session.free()` could not free unparented nodes. The round-boundary test
now verifies actual descendant destruction and repeated reset/repopulation in
34 assertions. The lead applied the same ownership correction to the six other
fixture files. The mode expansion at `5ce0ae0` corrects match-selection ownership
and the separate premature viewport-signal connection.

The exact full-verifier command above was rerun with these changes and the new
HUD, team-score and Puma gates: **all 40 gates passed**, including toolchain and
release-refusal. `corrected-verification.json` preserves the complete report.
The executed tree is `5ce0ae0` plus the fixture-ownership/gate/launcher changes
committed with this report. Live lifecycle/restart, movement/fire and two-client
checks pass with the compact HUD and weapon-selection code integrated.
