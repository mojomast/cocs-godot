# First-person articulated accepted-kick chains

## Implemented

- Replaces the rigid four-piece foot with a Hip → Knee → Ankle → Toe hierarchy: shaped thigh and calf, thigh plate, trouser seams, kneepad/inset, shin armor and vents, calf straps/buckles, boot cuff/bellows, heel counter, laces, welt, outsole, individual angled tread lugs, toe cap and scuff plate. Rounded elliptical section meshes are generated once, not per frame.
- Nine explicitly named operator profiles use the existing source catalog's linear palette converted to display colors; proportion differences preserve a recognizable shared armored operator silhouette. No external generated assets or new import pipeline.
- Lead push, opposite-leg cross snap, heel drive have distinct hip rotation, side, knee extension and weapon counterbalance. Six eased phases finish in **0.290 s**, before the **0.300 s** authority cooldown. Visual contact is **0.095 s after event receipt**; damage and contact sound/ring already happen at authoritative acceptance. This deliberate presentation offset is not a second hit.
- Ordinary accepted melee events advance the sequence if the previous action confirmed a hit and the source-time gap is 0.299–0.850 s. A miss/blocked result animates the current strike but breaks the next continuation. The third strike wraps to lead. Timeout and interruption reset to lead.
- Existing rig event deduplication (4096 bounded entries), hidden consumption, and hit feedback remain authoritative. The new model also rejects non-monotonic/replayed IDs/timestamps. No input buffering, synthetic presses, delayed retry, damage multiplier, extra damage event, target lock or combat protocol change.
- ADS yields during the kick and can resume from held aim after recovery. Existing reload/sprint/switch snapshot gates interrupt the pose; weapon selection, death, actor change, focus/session hide, round/reset clear it. Reduced motion decreases weapon weight shift; essential leg articulation stays readable. Mesh surfaces are detached by the existing rig teardown before resources are released.
- Leg stays in the existing isolated first-person viewport, inheriting its FOV/aspect/projection synchronization and near plane. World hit feedback was intentionally left at its existing one-confirmation behavior.

## Public contracts for other lanes

`rig.interrupt_kick()` clears presentation and continuation while retaining replay watermark. Call it for any additional locomotion interruption the movement lane introduces. No `inertia.gd` or `session_binding.gd` changes are required here.

`rig.get_kick_state()` returns `step` (1–3), `strike`, `age`, `active`, `confirmed`, `accepted`, `contact_seconds`, `duration`, `chain_window`. Third-person consumers can explicitly preload `res://first_person/kick_motion.gd`, feed **accepted authoritative melee events only**, and use its `sample()` hip/knee/ankle/toe rotations. Camera-space `root` and weapon offsets are FPS-specific and must not be applied to world actors. This lane does not edit operator files.

These are **sequenced accepted kicks**, not a new bonus-damage combat combo system. A buffered or damage-changing system would need a separately approved port-owned action adapter and protocol agreement; none is proposed as necessary for this accepted-press sequence.

## Verification completed (source-only grant)

- `node --test game/melee.test.mjs`: **9/9 pass**, including real authority rising-edge input, discarded early presses, held input beyond cooldown, exactly three fresh accepted events, damage/cooldown, misses, protected targets, occlusion, team and lifecycle rejection.
- `uv tool run --from gdtoolkit gdparse ...`: parser checks on changed rig/helper scripts and prepared native tests. Parser checks are not Godot static-type/import validation.
- Native regression prepared: `godot --headless --path godot --script res://tests/first_person/kick_chains.gd`. It exercises timeout, miss reset, replay suppression, interruption, frame-rate-independent settle, three contact poses, reduced motion, all nine profiles and joint hierarchy. **Not executed: exclusive native grant pending.**

## Native evidence pending

After exclusive grant, run the regression above plus existing `tests/protocol/melee_feedback.gd` and first-person lifecycle/ADS suites. Import/type-check all explicit preloads. Then run:

`godot --path godot --script res://tests/first_person/kick_capture.gd`

This prepares 1280×720 images in `user://kick-capture/`, all nine profiles × three strikes × 35/65/95/185/290 ms, with the actual first-person weapon viewport. Inspect near-plane clipping, toe/sole silhouette, leg/receiver overlap and exact recovery. These offline pose captures are **not authoritative-input evidence**.

For live acceptance, record normal F press/release at ≥0.30 s intervals against a surviving target, plus early press held through cooldown, miss, blocked contact, timeout, ADS, reload, swap, sprint, death/respawn and Home. Log authoritative melee IDs/outcomes beside `get_kick_state().accepted`; each accepted ID must increment once and feedback must remain one whoosh plus at most one confirmed impact. Preserve counts and screenshots for kick1/2/3. No screenshots, runtime type-check, live event trace or native visual-quality claim exists yet.

## Sources

- Authority audit: `game/core.mjs` `MELEE`, `melee()`, rising-edge `meleeHeld` handling; `game/melee.test.mjs`.
- Existing adapter: `godot/first_person/session_binding.gd` routes session accepted events; rig has no action send path.
- Anticipation: https://education.siggraph.org/static/Drupal_2025/education.siggraph.org/static/HyperGraph/animation/character_animation/principles/anticipation.html
- Weight shift: https://studio.blender.org/training/animation-fundamentals/5d69b398c4769bb8cceb0709
- Animation principles: https://www.dgp.toronto.edu/~patrick/csc418/notes/tutorial11.pdf

## Executable ordinary-input live producer (source-only prepared)

`tools/godot-weapons/kick-live.py` now runs the complete bounded evidence group after the exclusive grant:

```sh
python3 tools/godot-weapons/kick-live.py \
  --execute-native --grant PARENT_ISSUED_GRANT_ID --godot "$GODOT_BIN" \
  --output /tmp/opencode/kick-live-UNIQUE
```

Prerequisites: clean committed worktree, existing Node `ws` dependency, Godot 4.5.x and Xvfb. The runner refuses execution without the explicit native flag; **the flag is not a grant**. No engine, renderer, server, importer or live producer was executed during source-only preparation.

The parent-issued `--grant` identifier is required authorization **metadata**, not self-authorization. Before staging or launching anything, the runner acquires `/tmp/opencode/cocs-finish-acceptance.lock` using `fcntl.LOCK_EX | LOCK_NB`. A busy slot fails immediately; there is no lock wait or retry. The lock stays held through copy, import, authority, render, all cleanup audits and summary writing.

`LP_NUM_THREADS` is fixed to **1**, overrides inherited environment settings, and is recorded in summary metadata. This is the actual configured llvmpipe worker count, not a measurement of total engine threads and not a benchmark/rebench. There is no multi-thread override. Staging copies **only Git-tracked project files**, excluding ignored/untracked injections even when `git status` would omit them. Revision/clean status are checked again after staging; SHA-256 of the runner, authority fixture and native observer is recorded beside the clean executing revision.

The runner records the exact executing `git rev-parse HEAD`, clean `git status`, commands, exit status and cleanup in `summary.json`. It creates a private project copy excluding `.godot`, private HOME/XDG directories and display. Process groups are owned with `start_new_session`, terminated then killed/reaped on success, error, timeout, SIGINT or SIGTERM. Overall deadline is 900 seconds including staging/import; import 600 seconds, semantic probes 30 seconds each, live client 45 seconds each (native self-deadline 40), authority self-deadline 60. There is no detached/background daemon. All logs remain in the requested evidence directory.

Cleanup records actual `/proc/*/stat` process-group membership, including descendants and zombies, rather than trusting the leader's return code. SIGTERM gets a bounded grace period; SIGKILL is sent **only if group members remain**, with escalation recorded. Every owned group receives a fresh final bounded membership audit. `cleanup_audit` records owned/audited group counts, survivor count and `all_groups_empty`; missing audits or any survivor fail acceptance. Authority shutdown requires exit 0, no forced escalation and an empty group. A forced-killed server can never make a journey clean even when the subsequent audit is empty. Xvfb's expected service teardown is labelled separately as `role: display`; it still requires zero survivors but does not masquerade as a clean game/server exit.

### Authority and input provenance

- Real production `createGameServer` / Room / Match / WebSocket protocol, normal 60 Hz source time, shipped `meridian-exchange` geometry. A test-only wrapper on registry ticking sets **one initial placement before the first simulation step** around the clear western spawn, local `(-44,0,-34)` and target `(-44,0,-35.2)`. Both start with normal 100 health and zero armor; the target is a stationary practice participant (`bot:false`). The local initially faces away so the ordinary pointer-capture click cannot damage the target. Construction-only setup is explicitly logged.
- No post-setup actor position, health, cooldown or authority-action writes. `godot/tests/first_person/kick_live.gd` instantiates the shipped session and uses `Input.parse_input_event` for F, W, number 2, Escape, right/left mouse and look. It never calls `apply_events`, `apply_actor`, `apply_pose`, `advance`, `send_frame`, or kick-model methods. Snapshots/events/rig state are observed only.
- **Chain scenario:** ADS → first F hit → early F held beyond cooldown (no new event) → normal W follows actual knockback → second/third fresh F hits. Source health must be exactly **55, 10, 0**. Ordinary look-away creates a miss; the next press must return to step 1. Number 2 interrupts a later kick, then a fresh F and Escape test pointer-release interruption.
- **Blocked scenario:** separate match, explicitly labelled construction-time `protection:25`. Two ordinary accepted F presses must be blocked with health unchanged and step 1, then the same look-away/miss/swap/release checks. This is a controlled protection fixture, not a claim that protection was earned through gameplay.
- `authority.jsonl` logs original input envelopes, setup, accepted IDs/outcomes/source times and actual target health; `native-report.json` logs received IDs, input events, observational per-frame kick states, checks and captures. The runner requires identical ordered unique authority/native IDs, legal cooldown gaps, expected action counts (**6 chain / 5 blocked**) and correct health results. Native early-press assertion is additionally backed by source-only held-edge tests.

### Render evidence and honesty gates

Contact PNGs come from the **normal rendered session after real accepted F input**, not a posed leg fixture. Each capture stores event ID, strike/step, actual rig age, event-receipt timestamp and rendered-frame timestamp (taken before PNG encoding). Model contact remains 95 ms after receipt; `receipt_to_render_ms` reports the real observed frame delay. Damage is already authoritative at acceptance. The runner requires actual 1280×720 PNG files and active first-three chain poses 1/2/3 in the bounded 95–160 ms sampling window. Slow rendering that misses this window fails evidence rather than silently substituting staged imagery.

The existing offline `kick_capture.gd` remains the separate full nine-profile × three-strike × five-phase gallery. Replay/hidden-drain semantics are deliberately checked by the existing `first_person/lifecycle.gd` and `protocol/melee_feedback.gd`, plus `kick_chains.gd`, which the group runs before live journeys. Live protocol replay injection is not used. Death/respawn/Home and full reload/sprint behavior remain in separate semantic/manual lifecycle coverage; the live producer specifically proves ADS, swap and Escape interruption and target death.

Source-only verification of the producer:

- `node --test tools/godot-weapons/kick-live.test.mjs`: **3/3 passed**. Executes shipped-map placement/occlusion and ordinary source-input knockback-following chain (55/10/0), blocked/early held-edge/miss behavior, and a live-observer no-injection source contract. No socket is opened.
- `python3 -B tools/godot-weapons/kick_live_contract_test.py`: **3/3 passed**, including rejection of missing images, duplicate/reordered IDs, unearned damage and extra actions. Does not execute the runner.
- New native observer parses with `gdparse`; Python AST and Node syntax checks pass. **Godot type-check and actual live execution remain pending the exclusive grant.**
- Follow-up policy checks: `python3 -B tools/godot-weapons/kick_live_policy_test.py`: **6/6 passed**. Covers nonwaiting lock refusal/release, absent-leader descendant and zombie detection, real tiny Python parent/child group shutdown, forced-stop rejection for authority despite zero survivors, mandatory grant/one-thread source policy, and exclusion of ignored/untracked injected files during staging. Only short synthetic Python processes were spawned; no server or engine. Original source contracts remain **3 Node + 3 Python**; native still pending.
