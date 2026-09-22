# Optional native LATTICE world slice

Standalone `res://lattice/world_demo.tscn`, based on `642c615`. Own scene/helper/test files only; ordinary authoritative **cocs / cocs-coop** rules on **Asterion Relay / Monsoon Foundry**. [Discovery](DISCOVERY.md) was written before implementation and identifies the input routing, recipient visibility, projection-shape assumptions and capture conditions.

## Play

From this isolated worktree (existing primary dependencies are read-only):

```sh
ln -s /home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules node_modules
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
export TMPDIR=/tmp/opencode
node tools/godot-export/semantic.mjs
"$GODOT_BIN" --headless --path godot --editor --import
node port/native-lattice-world/run.mjs --play --map=asterion-relay --mode=cocs
node port/native-lattice-world/run.mjs --play --map=monsoon-foundry --mode=cocs-coop
```

Create the symlink only if absent. `--play` opens a visible native window on your current display. Closing it shuts down its owned ordinary server, ephemeral loopback listener and temporary XDG directories. The owned runner pins Godot, verifies the source lock, starts `createGameServer({historyPath:null,progressionPath:null})` on `127.0.0.1:0`, and launches the standalone scene. Tick rate, rules and snapshot defaults are unmodified. The host requests two bots through the normal configure/start socket flow. Audit recording caps at 10,000 records; it does not affect play.

Direct scene command, with an already running ordinary compatible authority:

```sh
"$GODOT_BIN" --path godot res://lattice/world_demo.tscn -- \
  --endpoint=ws://127.0.0.1:PORT --map=asterion-relay --mode=cocs
```

Controls: click to engage/fire, mouse look, WASD movement, Shift sprint, Space jump, Ctrl crouch, R reload, E interact, F mobility; inherited weapon keys/wheel also remain available. Escape releases the pointer. Release movement/action keys before clicking again. Focus loss, stale state, missing projection, revoked owner, death, results and disconnect release controls. Enter at results requests an ordinary new round. No free-flight or local movement prediction is used.

## Composition and visibility

- `world_demo.gd` subclasses the shared session, installs `world_transport.gd` before attaching its client, and initializes its own scene. All ordinary control generation, input cadence, camera look and lifecycle callbacks reuse shared behavior.
- It calls the existing nine-map viewer's `load_map`, retaining all semantic blocks, terrain and authored landmark geometry. Actors and first-person camera use exact received coordinates (feet + 0.9 visual anchor; feet + source eyeHeight camera). Remote extrapolation/interpolation is disabled for this slice.
- `world_transport.gd` retains the complete current base envelope validator and LATTICE transport, adding finite typed actor/pickup/objective/wallet checks before signals reach typed world consumers. Missing COCS or owned actor means unavailable control, not a guessed pose.
- `world_hud.gd` displays only local REQ, recipient-team FLUX and public nearby objectives. Node labels use received x/z and co-op y when supplied; PvP lacks y/r, so label height uses the locked static support surface. No capture radius is guessed. Close labels yield to the compact HUD.
- Actor visuals are created only from the recipient socket's actor list and removed when absent. The pinned source currently sends enemy positions, an explicitly documented source limitation; this slice never reads omniscient simulation state or reconstructs withheld actors/wallets.
- This scene has no command widget. The installed transport supports the same-socket HOLD API, but ordinary movement needs no HOLD. Public owner/progress is authoritative; ACK means input consumption, not movement/capture completion.

## Reproduce bounded acceptance

```sh
GODOT_BIN="$GODOT_BIN" TMPDIR=/tmp/opencode python3 port/native-lattice-world/verify.py
python3 port/native-lattice-world/cleanup_check.py
```

The own verifier runs semantic source validation, Godot import, targeted detached control/projection contracts and two normal-rate graphical cases: Asterion/cocs and Monsoon/cocs-coop. Each graphical child has a 90-second deadline (120-second wrapper), a private Xvfb with `-nolisten tcp -nolisten unix`, and its own ephemeral server. Exact commands/hashes/display/port are saved in manifests. These are real Godot engine input events, **not OS-device automation or a human playtest**: the observer reads recipient poses and sends physical-keycode and mouse events through `Input.parse_input_event`, never writes the simulation or scene camera/actor coordinates.

Evidence separates incoming socket input receipts, actor ACK, source recipient coordinates, actual rendered camera/actor coordinates, public node observations and screenshots. Every accepted sampled render must match the same wire snapshot sequence within float32 conversion tolerance. Route checks require source displacement, neutral stop after Escape, rejection of recapture with W held, fresh release/click resume and authored landmark correspondence. Capture is an optional public observation, never an ACK-derived success criterion.

See [acceptance report](ACCEPTANCE.md) for results and direct screenshot review. Failed attempts are retained under `evidence/`.

## Unapplied common launcher suggestion

Reserve `--experience=lattice-world` to select `res://lattice/world_demo.tscn`, with the same two-map/two-mode allowlist and ordinary server lifecycle used here. Existing `--experience=lattice` must continue selecting the command board. No shared launcher or combat-menu changes are included. No shared session hook is needed: the scene follows the existing standalone subclass initialization pattern.

Limits: fixed single-host vertical slice, native generic actor visuals and existing semantic world presentation, no new lobby/guest experience, no strategy win or complete co-op campaign claim. Brief public-node approach/capture evidence does not establish long-match balance, every class verb, multiplayer reliability, or all authored routes.
