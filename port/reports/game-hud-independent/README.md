# Independent combined native HUD captures

Executed at `3a049d5`, including the merged weapon-selection hook:

```sh
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
GUEST_NODE_MODULES=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules \
node port/native-game-hud/capture.mjs --output=/tmp/opencode/game-hud-independent
```

Exit 0, all four capture cases pass. The lead opened all four PNGs. Live 960×640
and 1280×800 runs show authoritative health/armor, Pulse/∞, frags/deaths, reticle,
shot feedback, map/mode and the newly available number-key/wheel hint. HUD panels
and controls are contained at both target resolutions.

The respawn and results captures are explicitly **synthetic lifecycle fixtures**;
they show readable respawn text and the scoreboard above the HUD. The two live
captures use normal-rate owned source servers and actual native input; they do
not inject state. All rendering used an owned private Xvfb with software Mesa.

Legacy debug label strings are now hidden during normal play. Historical health
acceptance remains tied to its earlier runtime; the live health/pickup observer
is being updated separately to verify the new visible widgets and damage overlay.
