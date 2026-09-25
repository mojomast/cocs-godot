# Native LATTICE command board

The researched [LATTICE Strike flagship direction](FLAGSHIP_VISION.md) proposes
a complete FPS/network-team loop and staged playtest roadmap. It is a design
brief; the current source rules and native acceptance below remain authoritative.

## Current integration

The original command-board delivery below has since gained a clickable
[Map view](../native-lattice-map/README.md) and recipient-authorized
[co-op REINFORCE](../native-lattice-economy/HANDOFF.md). Co-op purchases cost
50 team FLUX, no REQ, during a source-opened between-wave window; initial
deployment is not a purchase window. Both maps independently pass the new
purchase and original input paths. Use the unbounded common launcher:

```sh
PORT=0 node tools/godot-dev/launch.mjs --experience=lattice --map=asterion-relay --mode=cocs-coop
```

The following sections retain the original implementation/evidence scope.

Standalone Godot-native, recipient-only command UI for Asterion Relay and Monsoon Foundry. Source rules and shared port modules are unchanged.

## Launch

From this worktree root, with the existing dependencies read-only:

```sh
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
export GUEST_NODE_MODULES=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules
export TMPDIR=/tmp/opencode
export PORT=0
node tools/godot-export/semantic.mjs
"$GODOT_BIN" --headless --path godot --editor --import
node port/tools/native_lattice_demo/run.mjs --map=asterion-relay --mode=cocs --size=960x640
```

The launcher owns a new OS-assigned loopback server, checks HTTP readiness, and prints its port. It uses the pinned Godot version and isolated temporary XDG directories. No package install, shared-service restart, or persistent deployment. Each attempt is bounded to 120 seconds. The scene starts disconnected: click Connect / start. Use Monsoon Foundry or cocs-coop through the native selectors before connecting. An optional room ID joins instead of creating; the host must have chosen the same map/mode. Join UI exists but multi-client join acceptance is not claimed.

To use an independently running server, launch the scene directly:

```sh
"$GODOT_BIN" --path godot res://lattice/board.tscn -- --endpoint=ws://127.0.0.1:PORT --map=monsoon-foundry --mode=cocs
```

## Manual flow

1. Choose map/mode, connect, and wait for live round/actor identity.
2. Inspect team FLUX, cumulative FLUX spent, income/upkeep, personal REQ, and public objective rows. Missing values say unknown / hidden.
3. Select a target and issue HOLD / GO. Both locked maps link the team's HQ directly to front-N, so the live team frontier is a legitimate initial target even when neutral. Final legality always belongs to the server.
4. In cocs, authorize one 12 FLUX purchase, then Recruit Fighter. The checkbox resets on activation, round reset, or disconnect; it is not standing permission to spend.
5. Read action receipts: queued is local transport only; pending (server accepted) is an authoritative running card; confirmed is a done card. A completed HOLD may say replaced, which does NOT establish a capture.
6. Disconnect clears targets, resources, pending actions, and purchase authorization. Connect again explicitly for a fresh room/session. There is no automatic spending retry.

Co-op HOLD is enabled only with observed ordinary human slice membership. Co-op economy is disabled because its between-wave window, slice, and executor rules differ. No movement, teleportation, privileged actor, hidden-wallet inference, or gameplay changes.

## Verification

```sh
python3 port/tools/native_lattice_demo/verify.py --source --live --graphical
```

Requires Xvfb for graphical cases. `xvfb-run -a` owns a separate private display; it never uses the shared desktop. The verifier saves actual output under a unique evidence directory and treats engine errors as failures even with exit zero. Tests drive real native button signal handlers and actual network transport; they are not physical mouse/keyboard acceptance. The adapter regression uses explicitly synthetic frames/recording transport, kept separate from live runs.

For just synthetic adapter/UI checks, omit flags. For graphical capture on one map:

```sh
xvfb-run -a -s '-screen 0 1400x1000x24 -nolisten tcp' node port/tools/native_lattice_demo/run.mjs --smoke --map=asterion-relay --size=960x640 --capture=/absolute/path/capture.png
```

See HANDOFF.md for evidence, limits, integration, and failed attempts. Captured images have not passed direct visual review: the available browser inspection service returned HTTP 500.
