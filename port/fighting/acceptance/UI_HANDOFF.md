# Production UI acceptance producer — source complete, native pending

Canonical `ce084d50` was merged into the original independent acceptance checkout.
Older cherry-picked content add/add conflicts were resolved to canonical content;
previous acceptance work was preserved. This follow-up adds only acceptance
fixtures, tools and documentation. Production `main.gd`, camera, rigs, FX, all nine
GLBs/manifests/import settings, core, combo stats/timing and final matrix are unchanged.

Controller follow-up: canonical `614a8a7f`, including presentation fix `1ca6f39e`,
is now merged. The original checkout and prior work were preserved. This narrow
follow-up changes only `ui_journey.gd` and this handoff; driver/anchor functions,
final-matrix registration, production main/helper/router and other journeys are
left to their respective owners.

**Current resource status:** the exclusive E slot belongs to vehicle production.
This controller follow-up is source-only. No Godot, Blender, imports, rendering,
encoding, audio, authority journeys, X11 focus changes or kernel device injection
ran. `/dev/uinput` access remains unavailable on the current parent environment;
native validation is pending. No nested agents. `gdparse` is grammar proof, not
Godot static-type/runtime proof.

## New executable coverage

`godot/tests/fighting/acceptance/ui_journey.gd` loads the actual
`res://fighting/main.tscn` as `SceneTree.current_scene`. Button focus targeting is
the only GUI test aid; buttons are activated with real Enter InputEvents, not
`pressed.emit`, direct callbacks or production method calls. Choices cycle through
the production selection/Settings/training controls. Human commands use the
current production binding map and `Input.parse_input_event`.

There are no writes to combat positions, HP, meter, state, results, input history
or simulation internals; no direct `step`, `training_reset`, `load_state` or
`start_match` calls. Public training reset/replay are activated by their buttons.
No diagnostic production API was necessary. Existing readable state is sufficient.

### Local versus and training

* Select local versus in the real menu. Walk into throw range normally. For each
  actor, rematch, perform an unteched throw and a defender-teched throw. Require
  real `throw_start`, `throw_hit`, `throw_tech` events, exact authored first throw
  damage / zero teched damage, victim release and zero AI clock advancement.
* Exercise training dummy crouch-guard, speed, authored hitbox display, public
  reset, exactly-one-frame advance, record a real walking/attack/damage route,
  stop and replay. A late-priority read-only observer records `save_state()` after
  each physics tick; every replayed tick must match the corresponding recorded
  state, with exact inventory and terminal equality. Empty/neutral-only replay
  cannot pass the positive attack/contact assertion.
* Measure active AI clock delta against actual fight tick delta; paused and
  inactive-selection AI RNG/history/clock and simulation state must remain exactly
  unchanged. Resume must advance one decision-clock tick per fight tick, without
  accumulated paused work. Selection and rematch must free the old world, camera,
  rigs and FX. Home must actually load `ui/main_menu.tscn` and free the fighting scene.

### Input loss — real application paths

The Python OS bridge only acts on a PID verified as a descendant of its serial
supervisor. It creates an owned X11 focus window and changes actual X11 focus.
Production `NOTIFICATION_APPLICATION_FOCUS_OUT/IN` handlers run naturally;
the fixture never injects a notification. Both actors hold buttons beforehand;
both held/queued states must clear, simulation/AI freeze, stale input must not
reappear on resume, and fresh edges must work.

For controller loss, two Linux **kernel virtual** pads are created sequentially
with uinput. Each is bound to the actual newly enumerated Godot device ID, avoiding
assumptions about mapping-database display names. They are selected through the
Settings device controls in ordinary **P1 first, then P2** order, checking each
actual route and exclusive ownership. Actual `InputEventJoypadButton` objects exercise both
routed actor commands; destroying each owned kernel device in turn must trigger
the production OS disconnect signal, release **both** actors, pause, and prevent
resume while the disconnected device is assigned. Require the exact truthful
`Pad <id> · disconnected` caption and unchanged missing-device route. **One actual
button activation** must select Keyboard while the other player's connected pad
remains assigned. The same focused button must survive refresh; device selection
must leave simulation paused and both actors' held/queued input released. Only
explicit Back/Resume may continue the keyboard-plus-pad match. After checking
fresh ticks and no stale buttons, release the other assignment through public
Settings for the later all-keyboard case. All owned virtual devices/windows are closed.

This is **virtual-controller enumeration/removal and event routing**, not physical
controller unplug or hardware compatibility evidence. `/dev/uinput` must be writable
and its resulting event nodes readable by Godot. Missing access blocks the producer;
there is no forged-signal, stub-controller or conditional-pass fallback.

### Compact camera matrix

Eight stage/layout starts, not an 81-match or hundreds-of-images sweep:

| Stage | Wide fullscreen UI100 | Compact 760×520 UI150 |
|---|---|---|
| Basalt Reach | Meta / Mistral, throws and lifecycle | Meta / Mistral |
| Canopy Divide | ChatGPT / Claude, ordinary projectile | ChatGPT / Claude |
| Crown Array | Grok / Gemini, charged and double jump | Grok / Gemini, jump and reduced mode |
| Helix Conservatory | DeepSeek / Kimi, ordinary max separation/corner | Mistral / Qwen |

All nine real produced rigs are thus represented. Wide is the actual fullscreen
Window mode; compact and UI scaling change only environmental Window properties,
not game state. Reduced motion and low FX are selected through fighting Settings.
Capture neutral plus representative hazards, with actual stage geometry and rigs.

The existing `camera_gate.gd` executes first, unchanged, for mathematical/native
camera behavior. `camera_compare.gd` remains available for a separately labelled
A/B art investigation, but its direct training placements are **not** reused as
proof of this input-only UI journey. No camera/core implementation was copied.

For each presented frame, use production `PoseBounds.envelope()` and native camera
projection, then test real body rectangles against **measured** top HUD/bottom
history exclusions. Every visible HUD control must remain inside the logical
viewport, without top/bottom overlap. Record actual world/pixel bounds, current
camera center/size, authoritative tick, render frame, UTC, native PNG and cadence.
New-match framing must return within 0.5 m of its same-layout initial neutral
height; this is a reset regression tolerance, not a readability/art judgement.

One-time bind-cache construction is measured separately by calling the existing
PoseBounds implementation on each real visual, outside the per-frame sampling
measurement. Per-frame CPU envelope timings and renderer cadence are recorded;
neither is relabelled hardware GPU cost. Human silhouette/contact/crop-seam review,
hardware GPU performance and human fighting feel are not script-oracle passes.

## Driver and strict evidence

`tools/fighting/acceptance/ui_driver.py` reuses the existing finish subreaper,
bounded runner, isolated environment and owned Xvfb launcher. Limits: existing
camera gate 60 s, UI native process 600 s, whole owned display/worker 700 s;
parent job 730 s. `LP_NUM_THREADS=1`, fresh HOME/XDG/stores and a unique output
directory per run. One serial fighting lock; no global runner changes.

The worker's random token is bound to an explicit fighting grant. Robot grants
are refused. Execution must finish before acceptance is evaluated. Zero exit,
exact marker, complete nonempty JSON, exact eight stage/layouts, nine rigs,
two-sided event outcomes, replay frame count and all critical assertion labels
are required. Even **after** a success marker, parser errors, engine errors,
ObjectDB/resource/RID leak messages, killed leaked descendants or survivors fail.
The report retains both supervisor results, OS request/reply records, native
observations, captures and artifact SHA256s. All candidate bytes and the Godot
binary are bound before execution; candidate mutation fails afterward.

Source-only commands (safe while robot production owns the slot):

```sh
python3 tools/fighting/acceptance/ui_driver.py source --output /absolute/evidence/ui-source
python3 -m unittest discover -s tools/fighting/acceptance -p 'test_*.py' -v
/tmp/opencode/fighting-core-grammar/bin/gdparse godot/tests/fighting/acceptance/ui_journey.gd
```

Future **granted** native run, after robot production releases the resource:

```sh
python3 tools/fighting/acceptance/ui_driver.py native \
  --godot /absolute/path/to/Godot_v4.5.2-stable_linux.x86_64 \
  --heavy-grant EXPLICIT-FIGHTING-UI-GRANT \
  --output /absolute/evidence/ui-native \
  --finish-anchor /absolute/current-finish-run/report.json
```

The optional finish anchor must match the current final matrix, environment-bound
input identity and queue **before native launch**. Standalone runs without it still
get exact candidate identities, but cannot later be re-stamped as owner receipts.

## Precise parent final-matrix handoff

`UI_JOB_PROPOSAL.json` contains the complete proposed executable job. Parent alone
should add `fighting-production-ui-journey` before the existing
`fighting-four-stage-training-review` job and add the new job ID to that review's
`after` list. No automatic delegated-plan job was appended here, so the completed
141-job canonical matrix has not changed concurrently. The command starts its
own owned Xvfb; do not add another display wrapper. The driver internally
validates retained native artifacts before printing its final success marker.

The existing receipt-only review remains necessary for art/readability/smoothing
and hardware GPU cost. The new executable supplies its missing concrete UI and
measurement producer, rather than turning subjective criteria into source passes.

`ui_driver.py receipt` reuses the **existing** `owner-closure` schema:

```sh
python3 tools/fighting/acceptance/ui_driver.py receipt \
  --producer /absolute/ui-native/ui-RUN/producer.json \
  --finish-anchor /absolute/current-finish-run/report.json \
  --review /absolute/owner-review.json --output /absolute/receipt-output
```

Owner review must contain `status:passed`, named `reviewer`, substantive `notes`,
the exact `producer_sha256` and `input_identity`, hashed regular-file `artifacts`,
and passing `judgements` for exactly:

* `four-stage-art-and-crop-seams`
* `floor-head-hand-foot-contact-readability`
* `camera-growth-shrink-hitstop-reset`
* `hardware-gpu-frame-cost`

These are explicit owner review assertions backed by retained native/GPU evidence,
not values this producer generates. Receipt export refuses missing review,
modified artifacts, unexecuted reports, changed anchors or changed critical unit
sets. It emits a typed reference consumable by the unchanged
`finish_runner.py --resume ... --receipt ...`. No historical evidence is re-anchored.

## Source results actually obtained

**Earlier presentation findings now fixed in source (`1ca6f39e`):** the pure
`device_choices.gd` model preserves a truthful missing-pad caption, makes its next
choice Keyboard, and skips the other actor's occupied pad. Production refresh
updates the existing button rather than rebuilding the row. The fixture's HBox
caption/button lookup remains compatible with this row shape.

Both acceptance workarounds have been removed: P2 is no longer assigned first,
and the other actor's pad is no longer released before missing-device recovery.
Actual routes, exact caption, one-activation transition, focus preservation,
explicit Resume and both actors' released input are now asserted. These assertions
are prepared native checks, not a claim that kernel hotplug has executed.

No `ui_driver.py` change is needed: its existing required disconnected-caption
label is retained and strengthened, and all emitted checks must pass. New check
labels add measured routing/focus/resume detail. Driver anchor/receipt work remains
with the acceptance owner registering the 142nd job; no changes to those sections
or the final matrix are included here.

Controller follow-up checks on merged `614a8a7f`: `gdparse` passed for the updated
fixture, all **26 acceptance Python tests** passed, and all **12 presentation
source tests** passed (including device choice/recovery and real nine-rig camera
source checks). `git diff --check` is clean. These checks performed no native or
OS-input execution; actual kernel hotplug, focus and single-click recovery remain
pending the later fighting grant and `/dev/uinput` access.

* `gdparse ui_journey.gd`: **passed**; Godot runtime/type validation still pending.
* Independent Python acceptance suite: **26 passed**. New negative checks cover
  late post-marker errors/leaks, signalled descendants, missing lifecycle or
  stage/layout/real-event coverage, fake physical claims, unauthorized robot-grant
  use, unanchored receipt promotion, truncated PNG payloads, and source-only uinput packet layout.
* Real export audit `tools/fighting/animation/check.py --exported`: **passed
  source-only**, 9 operators, 336 state/combat usages, 25 pair timelines,
  225 victim usages, 361 unique authored clips, 561 resolved usages, zero worst IK
  clamp. Existing signature uniqueness, contact task-space and exported-weight/
  rest/bind checks were retained; no schema drift required an acceptance waiver.
* New source contract: all nine real GLB/manifest/content-timing hashes, complete
  state/combat/victim clip resolution, seek maps and lossless import settings pass.
  Current manifests declare self-contained transport; a future shared-library
  transport change requires real resolver coordination rather than weakening coverage.

Evidence:

```
/home/mojo/.tmp-on-disk/cocs-fighting-verification-evidence-20261002/
  ui-source-exported.json
  ui-source/ui-source-03a51f9993c64c1c8421829f3f595aec.json
  20261002T231036Z-4247ffe598/manifest.json
```

The source artifacts identify the bytes checked at their timestamps; final native
producer identity is established only on the final merged candidate. No native UI
receipt exists yet. Fix actual failures with their assigned owner after the grant;
do not retune the already-passing 54 combos or modify immutable rig exports to
make this acceptance script pass.
