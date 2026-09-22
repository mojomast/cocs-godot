# Independent CTF / Payload verification

Delivery `91ce0bd39edc6294663b77d069d39d587957cfc5` integrated with attribution as
`d498479`. The original external worktree was unavailable locally; the commit and
all retained evidence were accessible. No pruning/removal was performed.

The lead reviewed the standalone adapter, renderer, launcher and handoff, added
executed revision and launcher/validator hashes to new evidence, then ran:

```sh
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
export PORT=0 TMPDIR=/tmp/opencode
node port/tools/native_objective_demo/run.mjs --map=tidal-citadel --acceptance
node port/tools/native_objective_demo/run.mjs --map=sunscar-convoy --acceptance --small
python3 tools/godot-dev/verify.py
```

## Results

Both normal-rate, real-source graphical sessions **PASS**:

| Scenario | Evidence directory under `port/native-objective-gameplay/evidence/` | Correlations | Inputs received / ACK high-water |
|---|---|---|---|
| Tidal, 1280×800: pickup → carry → drop | `05025180-0ebb-4a26-86f0-751bb9df6d94` | 609 | 641 / 640 |
| Sunscar, 960×640: escort displacement → idle | `0c65b58d-ab60-4b44-b295-01e478c5b71a` | 118 | 92 / 91 |

The validator matches native objective roots/HUD to recipient snapshots and
requires actual source transitions. Native `Input.parse_input_event` mouse/key
dispatch drives the client; this is not OS-device or human-play acceptance.
Input receipts and ACK high-water are not individual application proof. No
authoritative state was injected or gameplay tick timing changed.

Both summaries confirm child/display reaping and absence, server closed, zero
sockets and temporary runtime tree removed. No native recording completion is
claimed. Original failed attempts remain excluded from acceptance.

The combined verifier passes **50 gates**, including new objective renderer
(19 assertions), adapter controls (11) and evidence validator (8), inherited
2,497 control-safety assertions and shared two-client/lifecycle checks. The
exact report is `../verification.json`.

## Direct visual review and follow-up

The lead opened the original accepted CTF approach and Payload screenshots,
then both independent gameplay screenshots using the image reader. Flag/cart
geometry and map identities are visible. The independent CTF image exposes an
oversized close-up label, and the original Payload image has low HUD contrast
against the cart body. The independent Payload image is clearer but does not
resolve that camera condition. These findings are assigned to the objective
progression/polish agent, not relabeled accepted visual quality.

CTF return/capture, Payload contest/checkpoint/delivery, objective results/restart,
vehicles, multiplayer objective UI and broader modes remain open. Launch/demo
APIs are documented in `../../native-objective-gameplay/HANDOFF.md`.
