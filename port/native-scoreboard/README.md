# Native scoreboard

Implemented on `d06b681` in `feat/native-scoreboard`, using pinned Godot 4.5.2.

## Controls and integration

- Hold **Tab** during an active round; release to hide. Key-repeat is ignored and focus loss clears the hold.
- Results open automatically. Existing **Enter** restart handling stays with the session; guests see “Waiting for host to restart.” Pending host restart gets its own status.
- **PgUp / PgDn** page larger rosters while the panel is visible.
- The scene adds one `CanvasLayer` child, `Scoreboard`, with `res://ui/scoreboard.gd`. Deferred binding connects after the parent has set up `client.started`, `snapshot`, `results`, and `connection_error` handlers. No additional session script hook is needed.
- The module also exposes `bind_session(target)`, `apply_state(state, local_id, is_results = false)`, and `clear_round()` for direct use. `round_number` and `guest` are presentation context for standalone use. Normal integration reads round count and host/guest status from its parent.

Names, frags, deaths, team, map/mode, and **elapsed** time come from authoritative state. Round number counts received authoritative starts through `session.round_starts`; it is not a fabricated server round field. Missing teams/stats display `—`. Team identifiers are shown as supplied, without inventing team colors/names or objective rankings. Rows sort by frags descending, deaths ascending, case-insensitive name, then original roster order. Local identity is highlighted with **YOU**.

The first 64 roster entries are retained, with a visible cap notice for larger rosters. There are 12 reusable row controls; 960×640 shows six per page and 1280×800 shows twelve. Identical score/time presentations skip label updates. Long names are bounded and ellipsized; plain `Label` widgets display BBCode literally. Every control ignores mouse input and keyboard focus. The module never consumes gameplay input or changes pointer capture.

Layout reserves the top 224 px for existing HUD/status labels. Network errors and local session errors clear/hide the panel, including errors that do not emit a client signal. Round starts clear prior scores and results. The scoreboard uses canvas layer 8.

## Verification

```sh
GODOT=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
"$GODOT" --headless --path godot --script res://tests/protocol/scoreboard.gd
"$GODOT" --headless --path godot --script res://tests/protocol/scoreboard_session.gd
```

Passed:

```text
PORT_SCOREBOARD_OK checks=25 recorded_frames=6 synthetic_cases=true
PORT_SCOREBOARD_SESSION_OK actual_scene=true synthetic_signal_delivery=true captured_state=true
```

The focused checks cover sort/update, fixed row reuse under 100 score changes, sparse/malformed fields, literal names, elapsed time, local identity, cap/pagination, unchanged-snapshot sparsity, Tab/echo/release/focus loss, host/guest/results/restart states, and error/reset behavior. Six stored authority frames are replayed separately from synthetic cases.

The integration test instantiates **the actual `session.tscn`**, verifies deferred handler order, delivers captured state via synthetic client signals, and checks existing results/error labels. It requires generated map content; this worktree used the primary checkout's generated directory read-only. No server is opened by this test. Headless editor import also passed. Combined full verification belongs to the integrating lead.

## Visual review — explicitly synthetic

Screenshots were rendered by Godot on private `xvfb-run -a` displays with Mesa llvmpipe and dummy audio. They contain synthetic score fixtures, **not live gameplay evidence**. Both assert viewport containment and HUD reservation before saving:

- [960×640 automatic results](screenshots/synthetic-results-960x640.png): panel `(100, 224, 760, 361)`.
- [1280×800 Tab-held scores](screenshots/synthetic-tab-1280x800.png): panel `(260, 224, 760, 541)`.

Reproduce from the repository root, substituting an absolute output path:

```sh
xvfb-run -a -s '-screen 0 1280x800x24' "$GODOT" --audio-driver Dummy \
  --path godot --resolution 960x640 --script res://tests/protocol/scoreboard_visual.gd \
  -- --results --capture=/absolute/path/synthetic-results-960x640.png
xvfb-run -a -s '-screen 0 1280x800x24' "$GODOT" --audio-driver Dummy \
  --path godot --resolution 1280x800 --script res://tests/protocol/scoreboard_visual.gd \
  -- --capture=/absolute/path/synthetic-tab-1280x800.png
```

Final render runs passed with only Xvfb's unsupported VSync warning.
