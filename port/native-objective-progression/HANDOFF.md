# Native objective progression

## Delivery

Isolated from `d498479` in `/tmp/opencode/objective-progression`, branch `objective-progression`. Changes are restricted to `godot/objectives/`, new `godot/tests/objectives/progression*`, and this new evidence/helper directory. No source simulation, contracts, dependency files, shared session/UI/network/world, original objective tests, original objective tools/evidence, root documentation or verifier changes.

The adapter now composes the shared **combat GameHUD and scoreboard** with a compact panel-backed objective HUD. CTF shows local team, separate Red/Blue capture totals, and each flag's authoritative state/carrier. Payload shows escort/defend role, contest/push/rollback/idle status, source progress/distance and checkpoints. Missing numeric progress stays unknown. `objective_label.text` remains available to the original observer and `--debug-hud`.

Labels are smaller and disappear at close range rather than covering the HUD. A cart overlapping the camera hides only its decorative meshes; its source root, marker ID, position and correlation data remain exact. Ordinary movement away restores the meshes. Results use the shared scoreboard with the objective outcome above it.

## Source workflows

The new helper launches an unchanged normal-rate Node authority on owned loopback port 0 and a pinned graphical Godot client on a private Xvfb (`-nolisten tcp -nolisten unix`). The host uses zero bots and a legal short time limit: **60 seconds CTF, 90 seconds Payload**. The second ordinary WebSocket player joins before start and is assigned the opposing team by source. It only receives its own normal protocol frames and sends input messages; no authority access, repositioning or state writes.

Primary player movement, aiming, E, Enter and fresh mouse capture go through `Input.parse_input_event` using native physical-key and mouse event fields. These are programmatic native input-path observations, not hardware/XTest or human-play acceptance. The primary does not call input handlers or mutate actor/camera poses. The helper follows authored geometry and received source poses, including detours around the two collidable arch posts. See `DISCOVERY.md`.

The first round exercises CTF pickup → drop → opposing defender's return → pickup → capture; Payload escort → sustained opposing-team contest → resumed push → checkpoint → leave/idle. Each runs to an actual source time-limit result, sends ordinary Enter/restart, checks cleared round state, holds capture released for a second, then deliberately clicks again. No forced results or accelerated ticks.

## Reproduce

From the worktree root:

```sh
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
export GUEST_NODE_MODULES=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules
export TMPDIR=/tmp/opencode
node --loader ./port/tools/native_objective_demo/dependencies.mjs tools/godot-export/semantic.mjs
export XDG_DATA_HOME="$PWD/.port-runtime/data"
export XDG_CONFIG_HOME="$PWD/.port-runtime/config"
export XDG_CACHE_HOME="$PWD/.port-runtime/cache"
"$GODOT_BIN" --headless --path godot --editor --import
node --loader ./port/tools/native_objective_demo/dependencies.mjs port/native-objective-progression/run.mjs --map=tidal-citadel
node --loader ./port/tools/native_objective_demo/dependencies.mjs port/native-objective-progression/run.mjs --map=sunscar-convoy --small
```

The new runner is bounded at 150 seconds; every invocation returns a unique evidence directory, source/runtime hashes, verdict and owned-process cleanup. Default interactive standalone launches still work through the original launcher; the new peer wait and short time-limit options are opt-in. No additional dependency install.

Checks:

```sh
"$GODOT_BIN" --headless --path godot --script res://tests/objectives/progression_hud.gd -- --map=tidal-citadel
"$GODOT_BIN" --headless --path godot --script res://tests/objectives/renderer.gd
"$GODOT_BIN" --headless --path godot --script res://tests/objectives/controls.gd -- --map=tidal-citadel
"$GODOT_BIN" --headless --path godot --script res://tests/protocol/control_safety.gd
node --test port/tools/native_objective_demo/test.mjs
node --test port/native-objective-progression/test.mjs
node port/native-objective-progression/validate.mjs port/native-objective-progression/evidence/UUID
```

## Verification semantics

The source lock verifier checks all tracked source/dependency assets against source commit `51289b79c627a26a381ba556b92bab71f93f3732`. Each run records SHA256 of the modified runtime/helper files and inherited core/session/network/source modules. Wire evidence includes connection identity and round number, so two peers or restarted sequence numbers cannot cross-correlate. Every native objective root is checked against its recipient's exact source snapshot by round and sequence.

The gate requires ordered CTF pickup/drop/return source events and corresponding native states; Payload requires sustained frozen contest with both living teams in range, subsequent distance increase and stable idle. Results require `over`, legal elapsed source time, ordinary config and elapsed wall time. Restart requires freed old dynamic marker data, cleared legacy HUD, released capture/no pose, zero source scores and reset flags/checkpoints. Cart distance in the first restart snapshot is bounded by **new-round elapsed time × unchanged source speed**, including the source codec's half-quantum uncertainty for independently three-decimal-rounded scalars, since a normal spawn inside the escort radius can legitimately move it before that snapshot.

New synthetic HUD/lifecycle tests pass **33 assertions**, including both 960×640 and 1280×800 layouts, integer/JSON-float team identity, actor zero, source capture score versus combat frags, contest/rollback roles, progress, source-root-preserving near-eye mesh hiding and round/disconnect cleanup. Original renderer **19**, objective controls **11**, inherited control safety **2,497** (8 parts), and original evidence validator **8** all passed. Logs for the scoped/original objective and validator checks are retained here; inherited control safety emitted `PORT_CONTROL_SAFETY_OK checks=2497 synthetic=true parts=8` in the executed shell check. The combined project verifier was not run or modified.

The new replay/corruption suite passes **10 tests**: genuine final CTF and Payload archives plus rejection of absent source return, forced early result, accelerated elapsed wall time, stale dynamic marker, duplicate completion, wrong source-root height, contest without an opposing occupant, and old cart distance after restart. Tampered copies are offline fixtures, never live authority changes.

## Final accepted evidence and direct visual review

| Map | Evidence directory | Independently correlated result |
| --- | --- | --- |
| Tidal Citadel / CTF | [`evidence/c45137f0-884e-433e-9d22-01f6be647ce6/`](evidence/c45137f0-884e-433e-9d22-01f6be647ce6/) | **1,868 snapshots**; primary pickup 19.55s, drop 19.633s, defender return 20.2s, second pickup 21.167s, capture 40.183s; legal 60-second result; restart and deliberate fresh capture |
| Sunscar Convoy / Payload | [`evidence/38216605-573c-47cf-a23a-18499282579c/`](evidence/38216605-573c-47cf-a23a-18499282579c/) | **2,769 snapshots**, **80 contested snapshots**; contest at 22.867s, resumed push, source checkpoint event at 39.983s, then idle; legal 90-second result; restart and deliberate fresh capture |

Both final summaries record all owned native/display processes reaped and independently absent, server closed, zero sockets and temporary runtime tree removed. Every final gameplay-runtime hash matches the delivery runtime. The CTF archive's validator hash predates only the later Payload-specific quantization-bound correction; current-validator replay passes that CTF archive too. Both final gzip archives were replayed with integrity checks.

**Actual PNGs inspected with the image-capable `read` tool**, not browser thumbnails or dimension checks:

- CTF, 1280×800: `gameplay-capture.png`, `gameplay-results.png`, `gameplay-restart.png`. Compact team/flag/score and combat panels are readable; results show Red's 1:0 capture score and restart resets to 0:0. The inherited WEST CITADEL world landmark is still large when looking back toward home; it is behind the backed objective panel. Objective flag labels no longer dominate the close-up.
- Payload, 960×640: `gameplay-contest.png`, `gameplay-checkpoint.png`, `gameplay-results.png`, `gameplay-restart.png`. Cart is framed outside its mesh rather than covering the top half of the camera. Objective panel clearly shows CONTESTED, then PUSHING / checkpoint 1 of 3, then IDLE and Blue's time-limit win; restart shows zero progress/checkpoints. Results and HUD panels do not overlap. The cart is still an intentionally simple bright block model; these images establish readable presentation, not finished art or human usability acceptance.

The historical failed attempts and earlier accepted CTF capture remain in place with original summaries. No old screenshot is relabeled polished acceptance.

Logs are losslessly gzip-packed. `archive.json` records uncompressed byte counts and SHA256; the replay CLI verifies both. Native completion remains explicitly `false`: helper exit and its completion marker do not prove native recording finalization. ACKs retain their normal high-water semantics.

## Limits

This extends objective progression coverage, not full-mode acceptance. No live flag pass, combat/death while carrying, CTF base contest, payload rollback, full payload delivery, or human/network-adversarial acceptance is claimed. Vehicles remain outside this presentation slice. Source spawns vary normally; the route driver is bounded and can report failure rather than rerolling until a preferred spawn. Shared source/runtime integration should be independently replayed by the lead after cherry-pick, especially with concurrent changes to `session.gd`.

The V-Sync unsupported-driver warning on private llvmpipe/Xvfb is retained. No performance claim. Historical failures are preserved and documented in `ATTEMPTS.md`; they are not relabeled polished or passing evidence.
