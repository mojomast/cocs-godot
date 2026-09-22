# Native LATTICE physical-event acceptance

Isolated worktree `/tmp/opencode/lattice-physical-658b4e7`, branch `lane/lattice-physical`, based on `658b4e76a65e7ca37489a948ed466cd8a2872d98`. Source pin: `51289b79c627a26a381ba556b92bab71f93f3732`.

## Changes

- `godot/lattice/board.gd`: objective list 185 → 132 px, margin 22 → 18 px, spacing 12 → 8 px, hide empty notice, wrap status. This brings the first two action receipts into the initial 960×640 viewport. Existing outer/list scrolling remains available. Numeric labels use up to two decimal places without trailing zeros; owner labels say Team 0 / Team 1.
- `godot/tests/lattice/physical.gd`: separate SceneTree observer driving the command-line `res://lattice/board.tscn` through `Input.parse_input_event` mouse motion/buttons and key press/release events. No Board replacement, signal emissions, direct command-handler calls, authoritative-state injection, focus grabbing, or built-in `--smoke` activation.
- `run.mjs`: ephemeral normal-rate real server and native process, with passive server socket send/message observation. It records only allow-listed recipient/card/action fields, never tokens, full raw frames, or enemy actor data. It verifies actor/peer/round/card correlation, incoming action counts, source done cards and cumulative spending.

These are **engine-input-path** checks, including physical keycode events. They are not OS-device automation or a human playtest. The observer reads widget geometry and recipient projection to choose coordinates and check outcomes; actual Godot GUI dispatch performs each action.

## Reproduce

From this worktree root, use the existing dependency directory read-only through a symlink (already created in this worktree; ignored by git):

```sh
ln -s /home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules node_modules
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
export TMPDIR=/tmp/opencode
python3 port/native-lattice-physical/verify.py
python3 port/native-lattice-physical/cleanup_check.py
```

The verifier runs semantic export/source verification, Godot import, existing adapter/UI tests and three real graphical cases. Every case has a fresh evidence directory. `results.json` records exact wrapper commands; each live `manifest.json` records the exact native command, endpoint/display, source SHA-256 hashes, pinned Godot version and default server options. Private displays use `xvfb-run -a -s '-screen 0 1400x1000x24 -nolisten tcp -nolisten unix'`. The launcher removes its temporary XDG directories in `finally`; xvfb-run owns and shuts down each display. No persistent server or desktop is used.

## Accepted run

Evidence: [`evidence/1790040404615162023/results.json`](evidence/1790040404615162023/results.json).

| Case | Native checks | Observed result |
|---|---:|---|
| Asterion Relay / cocs / 960×640 | 28, zero failures | HOLD running; Fighter done; exactly 12 spent and one spawn |
| Monsoon Foundry / cocs / 1280×800 | 28, zero failures | HOLD running; Fighter done; exactly 12 spent and one spawn |
| Asterion Relay / cocs-coop / 960×640 | 20, zero failures | HOLD running; economy disabled |

The existing **38 adapter checks and 10 UI checks pass**. Semantic export validates all nine locked maps and exact pinned source; Godot 4.5.2 import passes. No source suite rerun was needed for this presentation/observer-only change; the primary lead independently owns the source/live regression lane.

In each case a physical-event mouse click connects, a real ItemList row click selects the recipient team's `front-0`, and Up/Down keyboard navigation leaves that row selected. A HOLD mouse click and rapid second click produce just `native-r1-p1-s1`, witnessed as `running/accepted=true` for ordinary peer 1, actor 0, round 1.

In PvP, a fresh checkbox mouse click explicitly authorizes the purchase. Tab focuses Recruit Fighter; Enter activates it. Two further mouse clicks do not duplicate it. The server sees one economy spawn request, `native-r1-p1-s2`. Recipient cards then report `done/ok=true`, cumulative `fluxSpent` **0 → 12**, spawned **0 → 1**. Wallet values are retained in native observations but not used as cost proof. The two receipt rows are visible without scrolling. Clicking Disconnect clears state and disables the real controls; clicking those disabled controls sends no further actions. Each server witness has exactly two incoming command frames (one in co-op).

## Direct visual inspection

The original Asterion screenshot was read directly with the image-capable `read` tool: receipt heading was at the bottom and receipt rows were offscreen. The following genuine new viewport captures were also read directly:

- [Asterion 960×640 receipts](evidence/1790040404615162023/asterion-relay-cocs-960x640/receipts.png): resources, selected front, checkbox, actions and both receipt rows fit; last receipt around y=550, footer around y=580. Owner IDs have readable integer team labels.
- [Monsoon 1280×800 receipts](evidence/1790040404615162023/monsoon-foundry-cocs-1280x800/receipts.png): full objective labels and both receipts fit, ample lower space.
- [Asterion co-op 960×640](evidence/1790040404615162023/asterion-relay-cocs-coop-960x640/receipts.png): running HOLD receipt visible, economy controls gray/disabled.
- [Asterion disconnected 960×640](evidence/1790040404615162023/asterion-relay-cocs-960x640/disconnected.png): idle/disconnected status, wrapped unknown resources, empty list/history and disabled actions all fit.

Each live folder also contains `native.log`, compact `wire.jsonl`, `result.json`, `manifest.json`, and `cleanup.json`. Screenshots are actual Godot rendered viewports, not reconstructed mockups.

## Failed attempt retained

[`evidence/1790040340529593473`](evidence/1790040340529593473) preserves the first attempt and all commands, logs, wire evidence, source hashes and cleanup. The observer initially assumed ItemList Home would move to the first item. It did not; two subsequent Down events selected `econ-n`. The failed assertion and real server `wrong-team` rejection remain recorded. The run timed out waiting for acceptance and exited 1. It is **not** an accepted negative/UI workflow and does not replace the original unsupported-fortify proof. The correction uses one Up and one Down, checks each transition, and aborts before submitting if the target is wrong.

The accepted run has no script errors. The software Xvfb driver emits a V-Sync capability warning, retained in logs.

## Cleanup and limits

`evidence/cleanup.json` checks the four recorded loopback ports and finds no native/server/Xvfb runtime children belonging to this worktree. Per-case reports confirm closed HTTP endpoints, exited native children and removed temporary XDG directories. Generated untracked `physical.gd.uid` was removed; only the owned `.gd` test is committed.

Acceptance is limited to these short single-client command-board sessions. HOLD was accepted/running, not claimed captured/completed. Disconnect is the real disabled-control path tested; no network-stall/stale timeout was induced. Monsoon co-op, multi-client behavior, OS keyboard/mouse injection, full keyboard-only traversal, larger history scrolling, long rejection-text visual review and native gameplay completion traces are not claimed. The original signal-based unsupported-fortify evidence remains in its original directory. Transport, scene API, source, contracts, dependencies and shared files retain their original contents.
