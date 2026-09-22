# Compact native gameplay HUD

Based on `edc222f`; isolated branch `feat/native-game-hud`. The actual session scene now attaches `GameHUD`, a passive layer-3 overlay in the scoreboard's dark/teal style.

## Player presentation

- Compact top strip: authoritative map/mode and local frags/deaths.
- Bottom corners: **HEALTH / ARMOR numbers and bars**, named weapon, ammo including the wire's `∞`, and authoritative reload timing.
- Small controls footer; click-to-play / focus-release prompt. The prompt accurately says that the match continues while controls are paused.
- Snapshot-owned death/respawn countdown, missing-player wait, first-snapshot wait, snapshot stall, connection/content errors, host wait, results, pending restart, and failed-restart retry text.
- The existing combat overlay supplies the reticle, hit marks, and hurt edges. The HUD remains below the layer-8 scoreboard. Setup phase `-2` hides the entire gameplay HUD.
- Every HUD Control has `MOUSE_FILTER_IGNORE` and `FOCUS_NONE`. The module has no input handler, pointer-capture writes, gameplay authority writes, or audio changes.

Health's bar uses authoritative `maxHealth` (100 fallback for old sparse fixtures). Armor has no wire maximum: its gauge is a **100-point reference**, saturating above 100 while the numeric label retains the actual amount. Number labels use integer display; gauge values retain snapshot precision within their bounds. Missing equipment/ammo displays `—`; arbitrary strings/null are not interpreted as unlimited ammo.

`weapon_names.gd` contains the ten display names in `game/data.mjs` order, with no weapon rules. The controls footer adds **1–9 / 0 / wheel: weapons** only when the merged session exposes `weapon_controls_active()`, the parallel weapon-selection lane's hook. This base branch does not implement switching; the checked-in captures therefore omit that hint.

## Integration / hooks

- The only existing file edited is `godot/world/session.tscn` (one resource and child).
- Deferred `bind_parent()` / `bind_session(target)` follows scoreboard ordering: parent handlers process authority before HUD `started`, `snapshot`, `results`, and `connection_error` callbacks.
- `apply_state(state, local_id)` stores only presentation scalars. `refresh_status()` polls phase, legacy error/retry text, focus/capture eligibility context, snapshot age, and local lifecycle every 50 ms. Signal delivery also refreshes immediately.
- Readable controls: `health_label`, `armor_label`, `health_bar`, `armor_bar`, `weapon_label`, `ammo_label`, `weapon_detail`, `score_label`, `map_label`, `status_title`, `status_detail`. The full root is `root`; visible groups are `vitals`, `weapon_panel`, and `status_panel`.
- Default play hides `session.label`, `session.selector`, and `session.combat_label` after rendering their applicable replacement status. Their original text and APIs remain intact for diagnostics/replay tests.
- **`--debug-hud` leaves the original display intact and hides the new HUD.** Direct Godot invocation supports it now. The integrating lead must add `--debug-hud` to `tools/godot-dev/launch.mjs`'s forwarded user flags (outside this lane's ownership).

### Required health-analyzer assertion update

`port/tools/native_health_damage/observe.gd` currently records legacy `label` and `ui_text`. `analyze.mjs:43` tests that the legacy label contains `presentation.hud_text`; lines 52–53 call the diagnostic `TAKING DAMAGE` string a displayed label. **Those strings remain populated but are hidden in normal play, so those assertions cannot establish visible HUD acceptance after this merge.** The same caveat applies to pickup observations using legacy label text.

The lead should record the following **after HUD snapshot handlers have run** (deferred or on the rendered frame), correlate with the same authority snapshot sequence, and assert actual visibility plus values:

```gdscript
var hud: CanvasLayer = session.get_node("GameHUD")
var actor: Dictionary = session.presentation.local_actor
assert(hud.root.is_visible() and hud.vitals.is_visible_in_tree())
assert(hud.health_label.is_visible_in_tree())
assert(hud.armor_label.is_visible_in_tree())
assert(hud.health_label.text == "HEALTH  %s" % int(actor.health))
assert(hud.armor_label.text == "ARMOR  %s" % int(actor.armor))
assert(is_equal_approx(hud.health_bar.value, clampf(actor.health, 0, hud.health_bar.max_value)))
assert(is_equal_approx(hud.armor_bar.value, clampf(actor.armor, 0, 100)))
assert(not session.label.is_visible_in_tree())
```

For hurt feedback, replace the hidden combat-label claim with an independently captured/rendered existing combat overlay assertion (including `session.combat.overlay.is_visible_in_tree()` and its positive hurt feedback state). A diagnostic `--debug-hud` run can still verify original text, but does not establish normal-HUD visibility. This lane's real captures verify healthy visible HUD values and firing; the injured/dead state coverage is explicitly synthetic.

## Focused verification

Pinned Godot: `/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64`.
The worktree used the primary checkout's generated catalog through a read-only symlink; no exporter or source-game writes were needed. Supply existing `godot/content/generated` before the actual-scene checks.

```sh
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
"$GODOT_BIN" --headless --path godot --editor --import
"$GODOT_BIN" --headless --path godot --script res://tests/protocol/game_hud_session.gd
"$GODOT_BIN" --headless --path godot --script res://tests/protocol/game_hud_session.gd -- --setup
"$GODOT_BIN" --headless --path godot --script res://tests/protocol/game_hud_session.gd -- --debug-hud
"$GODOT_BIN" --headless --path godot --script res://tests/protocol/scoreboard_session.gd
GUEST_NODE_MODULES=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules \
  node port/native-game-hud/capture.mjs
```

Passed: actual-scene deferred binding, stored authority state, visible damaged health/armor/ammo/reload/score values, rounded-zero dead timer, respawn, focus pause, receive stall, missing actor, results/restart/retry/guest wait, local errors, `--setup`, `--debug-hud`, recursive pass-through/focus properties, and an actual input dispatch reaching `_unhandled_input`. Existing scoreboard scene integration passes. The new focused scripts should be added to lead-owned verification.

## Rendered and inspected evidence

The capture runner owns a private Xvfb display and normal-rate loopback Node authority, copies game/server modules into an isolated temporary directory, reads the existing dependency tree, disables persistence, and cleans up its children/server/temp directory. Mesa llvmpipe, dummy audio, pinned Godot 4.5.2; the only runtime warning was Xvfb's unsupported VSync mode.

- [Live 960×640](evidence/live-960x640.png): actual session, normal server state, scripted click/capture/fire, no actor injection.
- [Live 1280×800](evidence/live-1280x800.png): same real gameplay path; health 100, armor 5, Pulse Rifle / ∞, frags/deaths, and existing reticle visible.
- [Synthetic respawn 960×640](evidence/synthetic-respawn-960x640.png): stored frame with explicitly injected death state, labeled in the image.
- [Synthetic results 1280×800](evidence/synthetic-results-1280x800.png): injected results state shows the existing layer-8 scoreboard above the HUD.

All four final PNGs were opened and inspected. Visual review caught and fixed an initially collapsed score label; the live capture now also asserts its width and viewport containment. [Capture results](evidence/results.json) and per-image logs record successful exits and live ACK/firing state. This is short focused HUD evidence; combined/full gameplay verification belongs to the integrating lead.
