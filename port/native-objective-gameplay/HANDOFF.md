# Native objective gameplay — integration handoff

## Delivery / isolation

Base: `8e91969ca0d55938c25198c34ff158dd7195be20`.
Branch: `subagent/native-objective-gameplay`.
Worktree: `/tmp/opencode/cocs-native-objective-gameplay`.

Standalone Tidal Citadel/CTF and Sunscar Convoy/Payload scenes. Source simulation, network module, shared session/menu, contracts, dependencies and other worktrees were not edited. All files are new under the four assigned directories. No global capability is enabled. No essential shared patch is required. Lead should review/cherry-pick the delivery commit, then independently rerun against the newer integrated runtime before wiring it into the main menu.

This is a bounded objective interaction slice, NOT full mode acceptance. **Flag return, pass to a teammate, capture/victory, payload contest/rollback/checkpoint/delivery, results/restart and human visual/usability acceptance remain open.** The live CTF run has no defender to return the dropped flag; it ends after pickup/carry/drop. Return was not attempted and is not claimed blocked by a source defect. The payload run intentionally tests only escort displacement followed by idle.

## Discovery

Read `DISCOVERY.md` for source references, rules, routes and implementation plan. Key contracts: mode selects CTF (its objectives subtree has no required kind); team IDs are 0/1 and JSON may decode them as floats; carrier ID zero is valid. Flags' exact source x/y/z drive their roots. Payload is `state.objectives.payload`; checkpoint state is `state.objectives.zones`. Root heights are never resampled. Team 0 attacks, team 1 defends. Pickup/return/escort are automatic proximity actions; E's interact edge passes/drops carried flags.

## Reproduce / launch

Run from this worktree root, using the existing pinned toolchain and dependencies read-only:

```sh
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
export GUEST_NODE_MODULES=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules
export TMPDIR=/tmp/opencode
node --loader ./port/tools/native_objective_demo/dependencies.mjs tools/godot-export/semantic.mjs
export XDG_DATA_HOME="$PWD/.port-runtime/data"
export XDG_CONFIG_HOME="$PWD/.port-runtime/config"
export XDG_CACHE_HOME="$PWD/.port-runtime/cache"
"$GODOT_BIN" --headless --path godot --editor --import
```

Interactive launches use your deliberately chosen DISPLAY (do not use somebody else's desktop):

```sh
node --loader ./port/tools/native_objective_demo/dependencies.mjs port/tools/native_objective_demo/run.mjs --map=tidal-citadel
node --loader ./port/tools/native_objective_demo/dependencies.mjs port/tools/native_objective_demo/run.mjs --map=sunscar-convoy
```

Each map fixes its explicitly catalog-validated mode: CTF or Payload. Host create/configure/start is ordinary protocol. Default configuration uses zero bots, unchanged normal gameplay settings and server tick timing. The outer launcher lifetime is 180 seconds, not a modified match time limit; `--timeout-ms=100..180000` changes only that outer deadline. A deadline ends observation unsuccessfully, not an authoritative game result. Guest support is not implemented. `--small` requests 960x640; default is 1280x800.

Controls: left click engages pointer (also normal fire); mouse aims; WASD moves; Space jumps; Shift sprints; Ctrl crouches; R reloads; E interacts/pass/drops; F mobility; 1–9/0 or wheel uses inherited weapon selection; Escape releases. Release movement/action keys before a fresh click. Focus loss, death, stalls and new rounds release capture. Results stop controls; Enter uses the inherited ordinary restart request, but objective results/restart has not been exercised live.

CTF manual smoke: follow the gate road toward the opposing flag; approach until source pickup and the carried HUD state appear. Press/release E with no teammate nearby to drop; move out before the one-second pickup lock expires. A separate ordinary friendly-to-that-flag actor is needed for return. Bring the enemy flag home to an uncontested at-base friendly flag for capture.

Payload manual smoke: team 0 moves within the cart radius, follows it, then leaves; compare PUSHING and IDLE with cart displacement. E is unnecessary. A team-1 peer in range can contest, but the supplied acceptance driver does not exercise this.

Vehicles are outside this presentation slice even though the unchanged source maps contain them. Do not interpret this demo as vehicle acceptance or use invisible vehicle bays as an objective test shortcut.

## Renderer / integration API

`godot/objectives/renderer.gd` extends Node3D:

- `configure_map(source_map, mode)` clears previous state and creates visual-only home-base/authored road markers. Invoke at accepted round start after the world map is resolved. Tidal bases and Sunscar freight-road guide points are authored zero-height ground positions. The road guides explicitly are not the exact navigation-derived runtime payload path, which is not transmitted.
- `apply_state(state, local_actor_id)` consumes a validated recipient snapshot or authoritative results, updates stable flag-team/cart/checkpoint nodes and `hud_text`, and deletes missing dynamic nodes. Source coordinates are used even when a flag carrier is absent from the actor list. No fabricated carrier motion or locally inferred outcome.
- `clear_round()` frees nodes and state. Invoke on mode change, round start, disconnect and error. Apply after the shared session handler accepts ordering/lifecycle, not before validation.
- `rendered` contains compact dynamic node positions/text for external observation, not simulation state. Stable node IDs survive ordinary snapshots. Limits: two flags, six checkpoints, at most 32 authored guidance points. No transient effects or authoritative collisions.

`godot/objectives/demo.gd` inherits session methods for networking, input, freshness, ownership, lifecycle, presentation, pickup and combat handling; it supplies its own small initialization/host coordinator instead of copying the infantry client. The shared menu is neither changed nor bypassed for ordinary launches. The standalone fixed-pair capability check is explicit. Objective HUD is a pass-through Label; no objective UI button intercepts input. Future integration should retain the shared HUD and insert the renderer's text in an appropriate region rather than copy this standalone initialization into production.

## Executed tests

```sh
node --loader ./port/tools/native_objective_demo/dependencies.mjs --test game/destination-maps.test.mjs game/objective-occlusion.test.mjs game/payload.test.mjs game/payload-layout.test.mjs
"$GODOT_BIN" --headless --path godot --script res://tests/objectives/renderer.gd
"$GODOT_BIN" --headless --path godot --script res://tests/objectives/controls.gd -- --map=tidal-citadel
"$GODOT_BIN" --headless --path godot --script res://tests/protocol/control_safety.gd
node --test port/tools/native_objective_demo/test.mjs
```

Results: 58 source tests, 19 renderer assertions, 11 objective adapter control assertions, all 2,497 inherited control-safety assertions, and eight validator tests passed. Synthetic renderer cases cover JSON number types, actor zero, carrier changes, source height, stable IDs, missing/removal/reappearance, malformed data, mode/reset and no inferred victory. Control tests explicitly inject events/lifecycle/focus and use a transport double; they are not OS-focus evidence. Godot import and scene load executed without engine errors. Full combined verifier was not run and existing gates were not modified.

## Final live evidence

Both scenarios use a real Node server and actual graphical Godot client on a newly owned private Xvfb, ordinary runtime `InputEventKey` physical-key fields and `InputEventMouseMotion` through Input.parse_input_event, and unchanged normal simulation timing. No teleporting or authority writes. The driver reads received source poses to aim/follow authored routes. This is programmatic native input-path evidence, not XTest/hardware/human acceptance.

```sh
node --loader ./port/tools/native_objective_demo/dependencies.mjs port/tools/native_objective_demo/run.mjs --map=tidal-citadel --acceptance
node --loader ./port/tools/native_objective_demo/dependencies.mjs port/tools/native_objective_demo/run.mjs --map=sunscar-convoy --acceptance --small
```

Final CTF directory: `evidence/40e1b463-a857-44ab-bf1a-d8ebee783178/`.
582 correlated native/server snapshots; pickup/carry/drop plus matching flag roots/HUD; 1,087 received inputs and ACK high-water 1,087. Exact sequence association uses the one owned connection and snapshot_seq emitted after the real session handler. Source flag-drop event and E input receipt are required. No flag return/capture is claimed.

Final Payload directory: `evidence/5ff72691-48e6-462b-9d0e-54095e807c7e/`.
54 correlated snapshots; source displacement/pushing then idle with corresponding cart/HUD; 68 received inputs, ACK high-water 66. Last receipts are not claimed acknowledged/applied. No contest/checkpoint/delivery is claimed.

The server observer wraps only socket send/read observation; it does not alter payloads or simulation. Evidence includes compact selected authoritative state/events, native renderer/actor state and incoming input receipts. Native input queue outcomes are not independently logged in this slice. ACK is a high-water mark, not proof every lower input independently applied. Observed objective state changes establish those transitions. `nativeCompletionProven=false` always: normal exit and harness markers are NOT native recording completion.

Each final summary includes base/source identifiers, source/runtime SHA256 values, cleanup and native/server counts. Each run is below the 180-second bound. The launcher now rejects a success marker unless independent source/native correlation also passes.

Replay genuine archived evidence:

```sh
node port/tools/native_objective_demo/validate.mjs port/native-objective-gameplay/evidence/40e1b463-a857-44ab-bf1a-d8ebee783178
node port/tools/native_objective_demo/validate.mjs port/native-objective-gameplay/evidence/5ff72691-48e6-462b-9d0e-54095e807c7e
python3 -B port/tools/native_objective_demo/pack.py
```

Logs are losslessly gzip-packed. `archive.json` records original byte counts and SHA256; pack.py verified decompression byte-for-byte. Replay accepts raw or packed logs. Do not relabel historical failed runs successful.

## Screenshots and review

Final CTF: `evidence/40e1b463-a857-44ab-bf1a-d8ebee783178/gameplay-approach.png` and `gameplay.png`, both 1280x800.
Final Payload: `evidence/5ff72691-48e6-462b-9d0e-54095e807c7e/gameplay.png`, 960x640.

These are actual live gameplay renders, not synthetic fixtures. Private-Xvfb runs retained the driver warning that V-Sync mode could not be changed; no performance claim is made. PNG dimensions were checked. **Direct visual review is pending:** browser navigation failed with HTTP 500 from the browser service's /tabs endpoint. A private loopback image server was stopped afterward; the reference screenshot gallery was untouched. Do not infer readability, absence of clipping or camera usability solely from recorded HUD strings or file dimensions. The lead should inspect these images and play manually before promotion.

## Failure history / cleanup

See ATTEMPTS.md. An initial dependency resolver used CommonJS resolution for ws; corrected to preserve ESM conditions. Initial CTF live interaction succeeded but renderer omitted flags because Array membership rejected float team IDs; independent correlation caught it. The JSON regression and renderer were fixed, and both modes rerun. The old misleading success summary is retained and explicitly excluded. A control test initially examined buffered events before flushing and reused an event object; corrected the fixture, not runtime behavior.

An explicit `--timeout-ms=100` live launcher attempt exited 1 as intended and reaped both owned processes; it is failure-path cleanup evidence only. Successful final summaries confirm all native/display PIDs reaped and independently absent, zero sockets, server no longer listening, and temporary runtime trees removed. Only this worktree's ignored generated content/import caches remain for local reproduction. No shared service restarted, no shared display used, no dependency installed, no push/deployment/merge performed.
