# External task: fix native round-boundary resource leak

## Project and goal

You are assisting the Godot port of `github.com/mojomast/cocs`.
Primary checkout: `/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port`.
Primary branch: `port/godot-destinations`; integration reference: `edc222f`.

Create your own branch/worktree under `/tmp/opencode/` from that reference.
Inspect local instructions and relevant code before changing anything.

Fix the actual resource ownership/teardown issue that fails the combined
verifier at `round-boundaries`. The latest run passed all preceding gates,
including native-live and presentation-replay, then printed:

```text
PORT_ROUND_BOUNDARIES_OK synthetic_checks=12
ERROR: 1 RID allocations of type 'N17RendererSceneCull8InstanceE' were leaked at exit.
WARNING: ObjectDB instances leaked at exit (run with --verbose for details).
```

Assertions passing and exit code zero are not sufficient. Expected behavior:
correct round/error cleanup and clean shutdown without leaked objects or RIDs.
The source of the leak is not established; distinguish fixture ownership from
production lifecycle behavior before fixing it.

## Ownership and constraints

- Own `godot/tests/protocol/round_boundaries.gd`, narrowly necessary cleanup in
  `godot/world/viewer.gd` (world presentation work has completed),
  `godot/world/presentation.gd`, `pickups.gd`, `actor_visual.gd`, or
  `pickup_visual.gd`, and new `port/native-lifecycle-cleanup/` evidence/docs.
- You may adjust fixture ownership in `native_trace.gd`, `guest_session.gd`,
  `control_safety.gd`, `window_focus.gd`, `session_recovery.gd` and
  `stall_controls.gd` under `godot/tests/protocol/` if that is the proven layer.
  Prefer the actual ownership fix over duplicating cleanup across many fixtures.
- Read other modules freely. If the fix needs another file, provide the exact
  proposed patch and integration rationale instead of editing an occupied file.
- Other active agents own `session.gd`, `client.gd`, weapon selection, the compact
  HUD, `session.tscn`, `match_setup.gd`, scoreboard and their tests. External Puma
  work owns vehicle/sports code. Leave all these and pulse-rifle work untouched.
- Do not weaken `tools/godot-dev/gate_runner.py` or `verify.py`, suppress warnings,
  hide stderr, remove assertions, or add arbitrary sleeps to mask the leak.
- Preserve source authority, input safety, healthy-alive visibility, all nine
  locked maps/modes and existing presentation APIs. No source-game rule changes.
- Leave unrelated tracked/untracked changes and worktrees intact. No installs,
  destructive git commands, pushes, deployments or shared-service restarts.

## Phase 1 — parallel discovery, no edits

Use two read-only subagents if available:

1. Reproduce the exact failing test with `--verbose`; inspect fixture lifetime,
   unparented nodes, deferred deletion and SceneTree shutdown. Return file/line
   evidence identifying leaked objects and the smallest justified fix.
2. Inspect runtime presentation/pickup/model construction and cleanup across
   error, round reset and restart. Compare recent entity/world changes with the
   prior behavior. Return whether the issue affects real sessions or only the
   fixture, plus a focused regression recommendation.

Do not implement until both investigations return. Without subagent support,
perform both investigations yourself before editing.

## Phase 2 — synthesis and sequential implementation

Summarize the root cause, evidence and intended changed files first. Then use
one implementation agent for the minimal fix, followed by a separate review/test
agent after the fix returns. Keep implementation sequential.

Fix ownership at the appropriate layer. Update the existing test or add a small
meaningful repeated cleanup regression if necessary. Retain the original failed
output and new passing output under `port/native-lifecycle-cleanup/`; explain
what the test does and does not prove in a short README.

## Phase 3 — verification

Use the pinned engine:

```sh
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
export TMPDIR=/tmp/opencode
export PORT=0
```

The environment otherwise inherits an occupied port; leave that service alone.
Use existing primary dependencies read-only if your worktree needs them.

Rebuild generated semantic inputs and import in your worktree as needed:

```sh
node tools/godot-export/semantic.mjs
"$GODOT_BIN" --headless --path godot --editor --import
"$GODOT_BIN" --headless --verbose --path godot --script res://tests/protocol/round_boundaries.gd
"$GODOT_BIN" --headless --path godot --script res://tests/protocol/presentation.gd
"$GODOT_BIN" --headless --path godot --script res://tests/protocol/pickups.gd
"$GODOT_BIN" --headless --path godot --script res://tests/protocol/entity_visuals.gd
python3 tools/godot-dev/verify.py
git diff --check
git status --short
```

The full verifier starts bounded owned local processes; stop only resources you
created. No persistent restart or deployment is needed. Preserve any new failure
and report it honestly; fix directly related failures within your ownership.
Do not commit the verifier's wholesale rewrites of historical report files.

Manual/runtime smoke: exercise round reset/error teardown and confirm actor and
pickup collections clear, stale controls remain disabled, and subsequent round
state repopulates correctly. Prefer existing native lifecycle gates. If visual
inspection becomes necessary, use a private Xvfb display only. Synthetic tests
are not live gameplay or complete native recording acceptance.

## Delivery

Commit only intended code, regression and concise evidence/docs. Suggested title:
`Fix native round-boundary resource cleanup`. Do not merge into primary or push.
Return commit hash/base/worktree, proven root cause, changed files, exact checks
and results, unrelated remaining failures, and any shared-file integration patch.

Existing screenshot gallery: `http://100.125.104.79:43595/` over Tailscale.
It is a reference gallery, not your new test deployment; leave it untouched.
List residual manual checks and avoid claiming broader feature acceptance.

## Additional independent findings after this handoff was written

The lead executed every remaining configured gate after round-boundaries,
using the existing strict gate runner; see primary
`port/reports/feature-batch-independent/remaining.json` and per-gate logs.
Assertions pass but rendering RIDs leak in native-trace (2), guest-session (1),
control-safety (2), window-focus (1), session-recovery (10), stall-controls (1),
and match-selection (1), as well as the initial round-boundaries (1).
Actual native lifecycle/results/restart, native session movement/fire and two
native clients pass without these errors. This is evidence to guide diagnosis,
not a conclusion that production ownership is correct.

Match-selection also reports a separate null viewport `size_changed` access at
`match_setup.gd:98` when configured from the test's `_initialize`. The active
team/rocket-mode agent has been assigned that UI lifecycle bug. Do not edit
match_setup.gd or match_selection.gd; report any remaining fixture change needed
there as a proposed patch for the lead.
