# Native objective completion

## Payload: completed on the first bounded attempt

Archive: [`evidence/2d6b7e66-6adc-43f2-b29e-9d26fed86387/`](evidence/2d6b7e66-6adc-43f2-b29e-9d26fed86387/). The exact original live driver/helper/validator version is preserved by commit **`460674e`**, based on **`ffa6aac0bc4a61a0b5e1721dbb4000066c22a474`**. This work owns only new completion helpers, tests, documentation and evidence. No source simulation, dependencies, contracts, accepted HUD/lifecycle, previous helpers/evidence, root documentation or verifier changes.

The ordinary native primary player walks the accepted arch detour, escorts the actual received cart, leaves after checkpoint 1, allows an ordinary opposing protocol peer to roll the cart back, then resumes and completes the full route. Close 1.2 m following negotiates the source cart's navigation-derived refinery bends. This is a native engine input-path test driver using physical-key/mouse event objects, not hardware/human acceptance or product autopilot. No clock changes, direct handler calls, authority access, position writes or preferred-seed rerolls.

| Source milestone | Observation |
| --- | --- |
| Checkpoint 1 | 39.050 s; bank distance 55.210 m |
| Decreasing defender rollback | 148 native/source-correlated snapshots |
| Defender remains at checkpoint floor | 79 snapshots; 46.600–49.200 s; never crosses bank |
| Native primary resumes escort | Verified source attacker occupancy and increasing progress |
| Checkpoint 2 | 87.317 s |
| Checkpoint 3 and `payload-delivered` | 124.117 s |
| Genuine delivery-ended result | `over=true`, `delivered=true`, source winner 0, distance=total, all 3 checkpoints; before configured 180 s limit |
| Results and restart | Actual results release capture/stop input transmission; native Enter requests restart; cleared objective roots, zero old checkpoint/score state; deliberate fresh mouse capture |

**3,792 exact native/source snapshot matches**, including cart and every checkpoint root x/y/z by recipient, round and snapshot sequence. Payload source is unchanged at 1.5 m/s push / 0.75 m/s rollback, total 165.631 m. Normal wall time is checked independently of source time. There is no `payload-hold` event in this delivery run. Completion marker and helper exit remain explicitly **not proof of native recording finalization**.

The strengthened replay additionally reports primary **7,090 input receipts**, **3,717 applied-ACK samples**, high-water **7,089**; defender **3,723 receipts**, **3,722 applied-ACK samples**, high-water **3,722**. ACK high-water establishes application through a sequence, not application of every superseded input. Source events/states establish gameplay outcomes separately.

## Reproduce

From this worktree root:

```sh
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
export GUEST_NODE_MODULES=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules
export TMPDIR=/tmp/opencode
node --loader ./port/tools/native_objective_demo/dependencies.mjs tools/godot-export/semantic.mjs
export XDG_DATA_HOME="$PWD/.port-runtime/data"
export XDG_CONFIG_HOME="$PWD/.port-runtime/config"
export XDG_CACHE_HOME="$PWD/.port-runtime/cache"
"$GODOT_BIN" --headless --path godot --editor --import
"$GODOT_BIN" --headless --path godot --script res://tests/objectives/completion_live.gd --check-only
node --loader ./port/tools/native_objective_demo/dependencies.mjs port/native-objective-completion/run.mjs --small
node port/native-objective-completion/validate.mjs port/native-objective-completion/evidence/2d6b7e66-6adc-43f2-b29e-9d26fed86387
node --test port/native-objective-completion/test.mjs
```

Each launch checks the pinned **Godot 4.5.2** version and unchanged source lock, records binary SHA256 plus exact process arguments in `launch.json`, and hashes runtime/helper/source files in `summary.json`. Gzip archives have original byte-count and SHA256 checks in `archive.json`; replay verifies them before validation. The first Payload archive predates only subsequent stricter replay checks and the CTF driver extension; its original passing summary remains untouched. Current validator replay passes it.

The runner owns a normal-rate Node authority on loopback port 0 and a private `Xvfb -nolisten tcp -nolisten unix`; Payload outer deadline is **235 s**, match limit **180 s**. Summary confirms both owned PIDs reaped and absent, server closed, sockets zero, temporary runtime tree removed. The accepted native driver also terminates with coordinates and screenshot after 12 seconds of stationary route failure. All gameplay attempts must be retained; there was no failed Payload live attempt.

## Actual PNG review

All six Payload PNGs were opened directly with the image-capable `read` tool at their original 960×640 size:

- `gameplay-checkpoint1.png`: 35.2%, 58.2 / 165.6 m, checkpoint 1/3, Red pushing.
- `gameplay-rollback.png`: 35.5%, 58.9 m, **ROLLING BACK**, checkpoint remains 1/3. Camera is still facing the ordinary retreat direction here.
- `gameplay-banked.png`: cart framed from outside radius, **ROLLING BACK**, **33.3%, 55.2 m, checkpoint 1/3** while defender remains at the floor.
- `gameplay-checkpoint2.png`: 66.7%, 110.5 m, checkpoint 2/3, source push restored. Close-follow cart mesh is at the bottom of view; panels are readable.
- `gameplay-results.png`: **DELIVERED**, **100.0%, 165.6/165.6 m, 3/3**, **Winner RED [1]**, genuine round-complete scoreboard at 2:04.
- `gameplay-restart.png`: fresh round, checkpoint 0/3. The naturally chosen attacker spawn is within escort radius, so source advances to 3.2 m by this two-second screenshot; the first new-round snapshot is separately bounded by fresh elapsed time × unchanged speed (including codec rounding).

The HUD distinguishes source rollback/delivery correctly without product changes. There is no inferred route drawn as authoritative. Art quality and human route usability are not claimed. Source profile/wallet data does not establish any of these results.

## CTF: genuine pass/capture proven; original full gate retained as failed

Single allowed attempt: [`evidence/cfb8c298-c0e0-4337-9951-75b7bcc734a3/`](evidence/cfb8c298-c0e0-4337-9951-75b7bcc734a3/). Exact live files are preserved at **`12e0707`**. Three ordinary source-assigned actors are 0/1/2, teams 0/1/0. Native primary picks up at **19.483 s**, presses E near its teammate, and receives exact source **`flag-pass {actor:0,to:2,time:20.867}`**. The enemy flag stays carried and switches directly to actor 2; there is **no drop and no second pickup**. Recipient actor 2 captures at **38.367 s**. Results arrive naturally at 60 s with Red 1:0, followed by Enter/restart and deliberate fresh capture.

The narrowed gameplay replay passes **1,869 source-root-correlated native snapshots**, source pass event recipient, ordinary E receipt/application high-water, source capture, actual results input suppression, all-neutral new-round inputs and cleared flags/scores. Primary receipts **3,324**, applied-ACK samples **1,799**, high-water **3,323**; each secondary peer has **1,800** receipts and **1,799** applied-ACK samples/high-water.

**Original run exit remains 1.** Its strict assertion observed `controls_released=false` immediately after queuing native key-up events at results. Capture was false and input eligibility false. A pinned native synthetic probe (`completion_inputs.gd`) confirms physical E remains held in the same callback after `Input.parse_input_event(key_up)` and is released after two process frames. The pass driver's stage-dependent E release also let a fast successful pass leave E held until results neutralization. Source rising-edge handling prevented repeated passes.

The final helper corrects the E pulse independently of stage and adds a two-process-frame `COMPLETION_SETTLED` observer. It passes the script check; **these final helper changes were not followed by another live CTF run**. The archived run has no settled result-frame physical-key witness, and full acceptance still rejects it. `--gameplay` explicitly reports `fullLiveAcceptance:false`, `immediatePhysicalRelease:false`, `settledResultPhysicalReleaseObserved:false`; it does not relabel the original failed summary. Input suppression during results and neutral input after restart are independently checked from the wire. See [`ATTEMPTS.md`](ATTEMPTS.md).

All four 1280×800 CTF PNGs were read directly with the image-capable tool: `gameplay-pass.png` visibly shows the teammate carrying Blue's flag and the HUD **carried / actor 2**; `gameplay-capture.png` shows **1:0**, both flags at base; `gameplay-results.png` shows the actual 1:00 three-player scoreboard and Red winner; `gameplay-restart.png` shows **0:0** and reset flags. The large inherited WEST CITADEL landmark is visible behind the results, with objective and scoreboard panels readable.

Executed once, after the source plan:

```sh
"$GODOT_BIN" --headless --path godot --script res://tests/objectives/completion_pass.gd --check-only
node --loader ./port/tools/native_objective_demo/dependencies.mjs port/native-objective-completion/run.mjs --pass
```

Replay the actual archived outcome without another gameplay run:

```sh
node port/native-objective-completion/pass-validate.mjs port/native-objective-completion/evidence/cfb8c298-c0e0-4337-9951-75b7bcc734a3 --gameplay
# Omitting --gameplay intentionally rejects this archive's missing settled release witness.
```

## Final verification and provenance

All changes stay in `port/native-objective-completion/` and `godot/tests/objectives/completion*`. The inherited HUD/lifecycle/source required no changes to support full delivery or flag pass. The aggregate verifier/57-gate suite was not run or modified in this isolated lane.

| Check | Result / retained log |
| --- | --- |
| Completion replay/corruption tests | **22 passed**, `validator-tests.tap` |
| Original progression replay suite | **10 passed**, `progression-validator-tests.tap` |
| Accepted objective HUD | **33 assertions**, `hud-tests.log` |
| Original objective controls | **11 assertions**, `controls-tests.log` |
| Original objective renderer | **19 assertions**, `renderer-tests.log` |
| Pinned synthetic parsed-key release timing | Passed, `input-timing.log` |
| Final completion/pass driver parse check | Passed, `driver-check.log` |
| Current strengthened Payload replay | PASS, `payload-replay.json` |
| CTF scoped gameplay replay | PASS with full-live-acceptance=false, `ctf-gameplay-replay.json` |
| Exact live code/image/binary provenance and independent PID absence | Passed, `evidence-index.json` |

The corruption suite rejects missing delivery, time-limit hold mislabeled delivery, wrong winner, accelerated clock, rollback crossing bank, missing defender, excessive rollback speed, wrong source-root height, missing rollback HUD, retained capture, stale marker, duplicate completion marker, ACK without receipt, missing/wrong pass event, drop mislabeled pass, erased actor zero, absent E input, post-results movement and held interaction after restart. It also requires the original CTF full acceptance to remain rejected. The first expanded test run caught a test-fixture mistake (a deliberately injected late receipt reused an existing sequence and therefore correctly failed ACK validation before the intended result-input assertion); the fixture now uses a unique sequence. Original failed TAP is preserved in `validator-tests-initial-expanded.tap`.

Additional exact commands, using the environment above:

```sh
"$GODOT_BIN" --headless --path godot --script res://tests/objectives/completion_inputs.gd
"$GODOT_BIN" --headless --path godot --script res://tests/objectives/progression_hud.gd -- --map=tidal-citadel
"$GODOT_BIN" --headless --path godot --script res://tests/objectives/controls.gd -- --map=tidal-citadel
"$GODOT_BIN" --headless --path godot --script res://tests/objectives/renderer.gd
node --test port/native-objective-progression/test.mjs
node --test port/native-objective-completion/test.mjs
node port/native-objective-completion/provenance.mjs
git diff --check
```

Source lock: **`51289b79c627a26a381ba556b92bab71f93f3732`**. Pinned engine binary SHA256: **`5803746bbe055bee0f07a3c5b0dd347719bd45599f3d34519a8a0beaf83014ae`**. `provenance.mjs` verifies every recorded runtime/helper hash against its exact live commit (**15 Payload files / 19 CTF files**), verifies unchanged product/source modules against current files, verifies the pinned binary hash and all archived log checksums, and independently checks every owned PID is absent. It outputs hashes and byte sizes for every screenshot, log and metadata file. The current final helper's delayed release observer is compile/synthetic-checked only; archived live behavior is tied to the two explicit historical helper commits.

No push, merge or deployment. No recording-finalization, finished-art, human-input or adversarial-network acceptance claim. The source-rate full Payload completion objective is closed; the CTF source pass/capture objective is demonstrated with its explicit full-run witness limitation preserved.
