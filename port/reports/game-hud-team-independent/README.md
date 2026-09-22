# Live team scoreboard / compact HUD review

At `9a8d59e` plus the capture extension, the lead ran:

```sh
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
GUEST_NODE_MODULES=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules \
node port/native-game-hud/capture.mjs --output=/tmp/opencode/game-hud-team-independent
```

All five captures pass. The new **actual Team Deathmatch** 960×640 case sends a
physical Tab event through native input, retains pointer capture, and verifies
that the visible scoreboard's Red/Blue totals equal the latest accepted source
snapshot. The full panel is inside the viewport. The lead opened its PNG:
three readable rows, Red/Blue labels, local YOU marker, team totals and compact
HUD are visible. The held-Tab panel intentionally overlays part of the vitals.

This brief fresh round ends 0 / 0 at capture, so score changes are established by
the separate longer `native-modes-independent` runs, not this screenshot.
Other files retain their live/synthetic classification in `results.json`.
