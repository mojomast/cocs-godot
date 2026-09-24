# Local render-rate translation (Godot)

The shared `world/session.gd` consumes only authoritative snapshots for game state, input acknowledgement, lifecycle and view-angle reseeds. `world/local_motion.gd` produces a **visual camera translation only**: estimated velocity from successive authoritative eye positions, at most 50 ms of forward displacement, and short-lived continuity correction across regular packet arrivals. The camera's yaw/pitch are never smoothed or inferred, so mouse look and outgoing input retain their existing timing. Remote actor motion keeps its separate receive-clock interpolator.

`PortPresentation.render_frame(now)` is the shared frame hook connected by the session at startup; it runs even when a subclass overrides `session._process` (Horde). The hook never transmits input or changes authoritative actors. First snapshot, actor reassignment, loss, spectating, dead/alive transitions, large pose discontinuities, round restart, focus loss, stale snapshots and session teardown break the motion history. While stale/unfocused, the view returns to the last authoritative eye. Some spatially small teleports without a protocol teleport marker cannot be positively identified; this is a visual heuristic, not collision-aware prediction.

Synthetic headless checks (run serially, from this worktree; replace binary path as appropriate):

```sh
/tmp/opencode/cocs-playable-2026-09-23-linux/toolchain/Godot_v4.5.2-stable_linux.x86_64 --headless --path godot --script res://tests/world_motion/unit.gd
/tmp/opencode/cocs-playable-2026-09-23-linux/toolchain/Godot_v4.5.2-stable_linux.x86_64 --headless --path godot --script res://tests/protocol/remote_motion.gd
```

For the lead **after integration**, execute heavier verification **sequentially**, not beside other lanes: import with `--headless --editor --path godot --import --quit`; then run the normal native session/Horde smoke launchers against an isolated authority. Verify live camera framing and high-refresh apparent motion by capture/observation on target GPU separately. Synthetic script checks are not GPU smoothness evidence. Extrapolation cannot eliminate irregular authoritative pose changes or network jitter and deliberately stops after 50 ms without new snapshots.
