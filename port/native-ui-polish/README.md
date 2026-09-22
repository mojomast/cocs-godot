# Native UI polish: the four inherited UI defects

**PASS on the four owned surfaces, each with measured and rendered before/after
evidence.** Lane ownership: `godot/ui/**`, `godot/horde/scoreboard.gd`, the five
named protocol UI tests and this directory. No gameplay authority, engine
setting, package tool or other lane's file was changed.

**Follow-up (lead request):** the shared (non-Horde) scoreboard also keeps clear
of the vitals/weapon panels now, using the same measured band — see section 5.
**Final item:** the pre-existing GameHUD status-panel inflation reported in
§5.2 is now fixed in `godot/ui/game_hud.gd` (§6); the HUD's settled geometry,
legacy label text/API and `--debug-hud` path are unchanged.

Baseline: detached worktree at `f9f28809` (plus the pre-existing untracked
generated `godot/content/`), pinned Godot
`4.5.2.stable.official.6ce3de25a`. Probe:
`port/native-ui-polish/run.sh` -> `probe.gd` (synthetic state delivery only; no
WebSocket connection, no shared display). Raw JSON/PNG/log evidence is under
`evidence/`.

## 1. Combat setup / strategy popup obstruction

**Reproduced first.** Two independent causes, both visible in
[`setup-960x640-open.png`](evidence/before/setup-960x640-open.png) and
[`setup-1280x800-open.png`](evidence/before/setup-1280x800-open.png):

1. **Layout.** The autowrapping status `Label` (`custom_minimum_size.x = 620`)
   shapes its minimum height at its *current* width, and the first message was
   assigned while that width was 1 px. The resulting 2051 px label min height
   drove the `PanelContainer` to **680x2401** at `(140,16)` on a 960x640
   viewport: the setup slab covered the whole game view and ran past the window
   bottom. The panel never shrank back.
2. **Engine popup windows.** `map_choice`/`mode_choice` were `OptionButton`s:
   **4 popup nodes** (2 OptionButtons + 2 PopupMenus) per surface. This is the
   same proven release popup path the lobby lane replaced in `9a816ff`; the
   lobby report explicitly left "combat setup" as an open copy of it. The
   engine `focus_entered`/`tree_exited` connection errors in the retained
   `port/native-usability-audit/{combat,board}/runtime.log` come from it, and
   the audit's own combat flow got stuck "still setup" after the automation
   could not operate the dropdowns.

**Fix.**

- `godot/ui/lobby_choice.gd` (shared inline choice) gained a window-free
  keyboard browse used by the setup dropdowns: Space/Enter on the row starts a
  browse, Up/Down move the highlighted entry, Enter/Space confirms, Escape
  cancels, and focus loss resets. Left/Right still cycle and select, and the
  lobby behaviour/signal counts are unchanged (63/63 `lobby_popup_free`).
- `godot/ui/match_setup.gd` now uses that control (0 popup nodes), pins the
  status label's width before the first message, re-fits the panel to its real
  content (`settle()`), and is dismissible: Escape or **Close setup** collapses
  it to a one-line hint strip (mouse filter released), and Enter or a click on
  the hint reopens it. Start still requests the match and still hides the
  surface.

**After** (same probe, same sizes): panel **680x524** at `(140,58)`/`(300,138)`,
inside both viewports, 0 popup nodes, dismissible/reopenable by key and mouse,
and after Start the surface is hidden while the live HUD renders
([`setup-960x640-open.png`](evidence/after/setup-960x640-open.png),
[`setup-960x640-dismissed.png`](evidence/after/setup-960x640-dismissed.png),
[`combat-960x640-unobstructed.png`](evidence/after/combat-960x640-unobstructed.png),
[`setup-1280x800-open.png`](evidence/after/setup-1280x800-open.png)).

## 2. Horde compact scoreboard covering health/ammo at 960x640

**Reproduced by measuring the actual control rects** (not by eye) with the real
`res://horde/demo.tscn` composition:

| size | Horde panel (before) | vitals rect | weapon rect | overlaps |
|---|---|---|---|---|
| 960x640 | `(100,280) 760x301` | `(20,474) 238x108` | `(656,474) 284x108` | **vitals + weapon** |
| 1280x800 | `(260,280) 760x481` | `(20,634) 238x108` | `(976,634) 284x108` | **weapon** |

The shared card is 760 px wide and was only clamped to `viewport.y - 214`, so it
reached into both bottom panels at 960 and into the weapon panel at 1280. With
Tab held during live play the health/armor readout sat behind the board
([`horde-960x640-live-tab.png`](evidence/before/horde-960x640-live-tab.png)).

**Fix** (`godot/horde/scoreboard.gd`): the board now measures the shared HUD's
real rects and keeps to the horizontal band the HUD leaves between the vitals
and weapon panels, stops above the help line, paginates inside that measured
band (minimum one row), compacts its numeric columns, and puts the roster count
on its own line so nothing is clipped. `godot/ui/scoreboard.gd` gained the small
overridable layout hooks (`layout_top/bottom/width/band`, `panel_chrome`,
`summary_text`, `help_text`, `row_cell_widths`) with shared defaults that keep
the shared board bit-for-bit identical (verified: `scoreboard_visual.gd` still
reports `(100,224) 760x361` at 960 and `(260,224) 760x541` at 1280).

| size | Horde panel (after) | overlap vitals | overlap weapon | rows shown |
|---|---|---|---|---|
| 960x640 | `(270,280) 374x294` | no | no | 3 of 13 |
| 1280x800 | `(270,280) 694x444` | no | no | 8 of 13 |

Rendered: [`horde-960x640-live-tab.png`](evidence/after/horde-960x640-live-tab.png),
[`horde-1280x800-live-tab.png`](evidence/after/horde-1280x800-live-tab.png),
[`horde-960x640-results.png`](evidence/after/horde-960x640-results.png).
The Horde lane's own `res://tests/horde/layout_test.gd` still passes 2/2 (strip
reservation and viewport bottom), and its `--legacy-layout` control still fails
2/2 as designed.

## 3. Wrong player-count label

**Reproduced:** the summary read `Round 1 · Elapsed 1:23 · 13 players` for a
Horde roster of one human and twelve NPCs (and `3 players` for a human + two
bots in the shared modes).

**Fix** (`godot/ui/scoreboard.gd`): the count is now derived from the wire
roster instead of the actor total. An actor with `isNpc == true` is an
**enemy**, an actor with a `bot` object is a **bot**, and anything else is a
**player**; the summary names exactly what it counted:

| roster | label |
|---|---|
| all humans (any count) | `4 players` (legacy wording preserved when it is true) |
| 1 human + 2 bots | `3 combatants · 1 player · 2 bots` |
| 1 human + 12 Horde NPCs | `13 actors · 1 player · 12 enemies` |
| 1 human | `1 player` (singular) |

The legacy diagnostic label text/API in `world/session.gd` and the shared HUD is
untouched (`game_hud_session.gd` still asserts `HP 100`). The truthful label is
rendered in both Horde captures above.

## 4. Oversized result pickup captions

**Investigation result: the captured defect is already removed from the
production path, and nothing in the owned UI renders pickup text.** The
archived before image is
`port/native-zone-modes/evidence/verdant-reliquary-1de6fe4a-f185-4959-a56a-43fc6df84067/results.png`
(SHA-256 `7682722c53179877c20717c762f6eac3b76100017237b53c528c0a7c1cb89ff4`): an
enormous `ROCKET` caption fills the top of that 1280x800 results screen.

- That caption came from `godot/world/pickup_visual.gd` (`Label3D`,
  `font_size = 32`, `pixel_size = 0.005`, 12 m range), which the zone-modes
  baseline used for pickups.
- Commit `2a431361` replaced the production pickup visual with
  `godot/combat_pickup_assets/pickup_visual.gd` ("zero particles, no labels or
  colliders"). `godot/world/pickups.gd` preloads the caption-free script, and
  the only remaining reference to the legacy file is the comparison fixture
  `godot/tests/combat_pickup_assets/graphics.gd` (`before-legacy` capture).
- This lane re-measured the real compositions with real pickup markers at
  close range (2–4 m, three markers per capture): `pickup_captions = 0` and
  the pickup subtree has **zero `Label3D` nodes** at both sizes, at live and at
  results. The only world `Label3D` text left in the Horde results composition
  is the Horde lane's NPC role badge and the map landmark signs.
  See [`horde-1280x800-results.png`](evidence/after/horde-1280x800-results.png)
  (health marker visible, no caption).

`godot/world/pickup_visual.gd` is lead-owned, so this lane did not edit it. The
precise residual fix for the lead is one of: delete the unreferenced file (only
changes the fixture's comparison capture) or, if a labeled fallback is wanted,
set `font_size = 12`/`pixel_size = 0.003` and `visibility_range_end = 6.0` so a
1.6 m eye at 2 m never sees a screen-filling caption.

## 5. Shared (non-Horde) board clear of the vitals (follow-up)

`ui/scoreboard.gd` now derives its own band from the shared HUD's measured rects
(the `layout_*` hooks added in the first pass), so the shared card behaves like
the Horde specialization: it keeps to the horizontal gap between the vitals and
weapon panels, stops above the help line, stays inside the viewport, and lowers
its page size until the real chrome fits. A narrow band (< 560 px) also switches
to compact numeric columns and a two-line summary so names and the roster count
are not ellipsized. Bare fixtures without a `GameHUD` (zone modes, synthetic
renderers) keep the historic full-width band and three-row floor, so their
geometry is byte-identical.

Measured with a real `world/session.tscn` session and a 12-actor roster
(`evidence/{before,after}/report.json`, `shared-*` cases):

| case | before | after | overlap before -> after |
|---|---|---|---|
| 960x640 live Tab | `(100,224) 760x361` | `(270,224) 374x354` | vitals + weapon -> none |
| 960x640 results | `(100,224) 760x301` | `(270,224) 374x324` | vitals + weapon -> none |
| 1280x800 live Tab | `(260,224) 760x541` | `(270,224) 694x511` | weapon + help line -> none |
| 1280x800 results | `(260,249) 760x301` | `(270,249) 694x301` | none (4-row roster) -> none |

Rendered: [`shared-960x640-live-tab.png`](evidence/after/shared-960x640-live-tab.png),
[`shared-1280x800-live-tab.png`](evidence/after/shared-1280x800-live-tab.png),
[`shared-960x640-results.png`](evidence/after/shared-960x640-results.png) against
[`before`](evidence/before/shared-960x640-live-tab.png) and
[`before 1280`](evidence/before/shared-1280x800-live-tab.png). The Horde board and
the setup surface measurements are unchanged from the first pass (verified case by
case against the previous `report.json`).

### 5.1 Archived images this change invalidates

The shared card's geometry changes only where a `GameHUD` sibling exists: the
combat session (Deathmatch/TDM/Instagib/Rockets, host and guest), the identity
Deathmatch route, arms race and the lobby plays/results. These archived images
show it and are now stale; they are **not** re-rendered here (they belong to
other lanes):

| image | what changed |
|---|---|
| `port/reports/lobby-popup-free/full-flow/09-guest-scoreboard.png` | shared board at 960x640 is now the 374 px measured band, not the 760 px card |
| `port/reports/lobby-popup-free/full-flow/12-host-results-960x640.png`, `13-host-results-1280x800.png`, `11b-spectator-results.png` | same board, plus these also predate the truthful roster wording from the first pass |
| `port/reports/multiplayer-lobby-independent/{ember-crucible,meridian-exchange,verdant-reliquary}/09-host-results.png`, `10-guest-results.png` | same board and the old "N players" wording |
| `port/reports/arms-race-independent/evidence/5170738c-bc25-49c4-b839-17035898df9e/meridian-exchange/results.png` | `arms_race/scoreboard.gd` extends the shared board, so its card is now the measured band |
| `port/native-arms-race/evidence/22d20187-937d-405e-9543-da240344fbc5/meridian-exchange/results.png`, `.../3c656705-8157-42f4-9083-54b35836ec26/meridian-exchange/results.png` | same arms-race card |
| Horde evidence (`port/native-horde/evidence/*`, `port/reports/horde-*/evidence/*`, `port/native-identity-horde/evidence/*`) | **already invalidated by the first pass** (Horde card geometry + roster wording); this follow-up does not change the Horde card again |

Checked and **not** invalidated: the identity-DM action captures
(`port/native-identity-dm/captures/*/*-action-*.png`) show the live HUD without
the Tab board, and the zone-modes/objective captures run scenes without a
`GameHUD`, so their boards keep the historic band. My own first-pass captures
that show no board (`combat-*-unobstructed.png`) and the setup/Horde captures in
this directory were re-rendered at the follow-up baseline with identical
measurements (the only visible difference is the benchmark lane's hint line,
which landed in between).

### 5.2 Pre-existing GameHUD finding — fixed in section 6

The shared HUD's status panel used to inflate from its normal 70 px to 870 px
(phase-0/error message) or 1545 px (long phase-3 message) when a message was
assigned while `status_detail.size.x` was still 1. Section 6 records the fix and
its measurements; `godot/ui/game_hud.gd` now pins the label width before every
message and re-fits once the layout has run.

### 5.3 Lead-owned observation — resolved by the lead

`godot/world/pickup_visual.gd` set `visibility_range_end = 6.0` and then
assigned `visibility_range_end = 12.0` again a few lines later, so the tamed
caption still reached 12 m. Reported here because it is the same asset as the
first pass's defect 4; the lead has since fixed it in `72eec678` ("Honour the
tamed legacy pickup caption range"). Nothing to do in this lane.

## 6. GameHUD status-panel inflation fixed (final item)

**Root cause.** `status_detail` is an autowrapping `Label`, so its minimum
height is shaped at its *current* width. While the HUD `root` is hidden (phase
-2, lobby, `--debug-hud`) the status stack is never laid out and the label keeps
`size.x == 1`; a message assigned in that state was wrapped at 1 px and the
panel grew to its 870/1545 px minimum until the next message change.

**Fix** (`godot/ui/game_hud.gd`, no other file touched):

- `pin_status_width()` sets `status_detail.size.x` to the panel's real content
  width (620 - 32 px, viewport-aware) immediately **before** every message
  assignment and in `resize()`;
- a conservative `refit_status()` (deferred, and only while the message is still
  the one this HUD assigned) re-pins the width and shrinks the panel to its real
  minimum if it is ever larger.

The legacy label text/API (`session.label` replacement, `status_title`/
`status_detail` strings, phase handling) and the `--debug-hud` early-return path
are untouched.

**Measured `setup -> Start` transition**, real session scene (probe cases
`setup-transition-*` and `hud-stress-*`; 960x640 and 1280x800 differ only in the
panel's x position because the panel is 620 wide):

| state | before | after |
|---|---|---|
| Start -> connection error (`A local launcher endpoint is required`, phase -1) | `(170,78) 620x870`, bottom 948, outside the viewport | `(170,78) 620x70`, bottom 148, inside |
| long message assigned before the first layout (`CLICK TO PLAY - Esc releases...`, phase 3) | `(170,78) 620x1545`, bottom 1623, outside | `(170,78) 620x70`, bottom 148, inside |
| settled live state (both sizes) | `620x70` | `620x70` (unchanged) |

Rendered: [`setup-960x640-start-transition.png`](evidence/after/setup-960x640-start-transition.png)
and [`hud-960x640-long-message.png`](evidence/after/hud-960x640-long-message.png)
against the matching `before/` captures (the before images show the dark slab
covering the map preview / the lower view). The same captures exist at
1280x800.

**No archived image is invalidated by this fix:** the settled panel is `620x70`
before and after, and that is what every existing capture shows; the new
transition/stress captures are additions in this directory only.

**It cannot reintroduce the 680x2401 setup-panel class of bug:** the setup
surface owns a separate label and already pins its width plus re-fits through
`settle()`; the same probe run measures the setup panel at `680x524`
(`(140,58)` at 960x640, `(300,138)` at 1280x800) with `fits_viewport: true`, and
the shared/Horde boards at their accepted geometry, so the HUD pin only affects
`status_detail`.

## Assertions changed (and why)

Only the tests this lane owns were touched; no check was removed or weakened.

| file | change | reason |
|---|---|---|
| `tests/protocol/game_hud_session.gd` | `--setup` branch: **+6** assertions (`popup_windows(setup) == 0`, `setup.size.y <= 620`, `dismiss()/dismissed`, reopen, and the surface is hidden with 0 popups after `start_selected_match`) | locks defect 1: the surface must be popup-free, content-sized and dismissible, and must not linger over the match. Existing "setup remains interactive" assertion is kept. |
| `tests/protocol/scoreboard.gd` | **+4** roster-wording assertions, **+8** Horde geometry assertions and **+8** shared-board geometry assertions (panel clear of the vitals/weapon/help rects and inside the viewport at both sizes, measured from the real `ui/game_hud.gd` rects via the real `horde/scoreboard.gd` and `ui/scoreboard.gd`) | locks defects 2 and 3 and the follow-up by measurement instead of eye review. |
| `tests/protocol/match_selection.gd` | **+3** assertions (no popup selector nodes, explicit dismissal exposed, detached panel stays content-sized) | locks the popup-free setup contract on the selection fixture. |
| `tests/protocol/scoreboard_session.gd`, `tests/protocol/team_scores.gd` | unchanged | their assertions still hold; the all-human roster keeps the legacy `N players` wording, and the team-total line is still part of the summary. |
| `godot/ui/game_hud.gd` (§6) | no test assertion changed; the fix keeps every existing `status_panel`/`status_detail` assertion true (visibility, text, containment, `end.y < 224`) and closes the inflation with new probe measurements | the inflation is a transient state no gate measured, so the existing gates already constrain the settled geometry. |

## Verification runs

| command | result |
|---|---|
| `game_hud_session.gd` (default / `--setup` / `--debug-hud`) | PASS (`PORT_GAME_HUD_SESSION_OK`, `PORT_GAME_HUD_DEBUG_OK original_display=true`) |
| `scoreboard.gd` | PASS, checks 25 -> **35** -> **45** (follow-up geometry) |
| `team_scores.gd` | PASS, checks 15 |
| `scoreboard_session.gd` | PASS |
| `match_selection.gd` | PASS, checks 95 -> **98**, failures 0 |
| `lobby_popup_free.gd -- --lobby-menu` (shared control) | PASS 63/0 |
| `lobby_spectator_session.gd -- --lobby-menu` | PASS 31/0 |
| `lobby_followup_geometry.gd` at 960x640 and 1280x800 | PASS 75/0 each |
| `lobby_flow.gd`, `lobby_spectator_context.gd` | PASS 33, 66/0 |
| `tests/horde/layout_test.gd` (Horde lane fixture) | PASS 2/2 (`--legacy-layout` still 2/2 fail by design) |
| `scoreboard_visual.gd` at 960 and 1280 (`--results`) | PASS, shared geometry unchanged |
| `game_hud_visual.gd` at 960/1280 (`--hud-results`) | PASS |
| `port/native-match-selection/run.mjs --menu-only` (graphical keyboard dropdown flow, unowned lane fixture) | PASS `PORT_MATCH_SELECTION_LIVE_OK`, 0 engine errors; Verdant/Instagib selected through the new control |
| `control_safety.gd`, `stall_controls.gd`, `window_focus.gd`, `local_lifecycle.gd`, `round_boundaries.gd`, `entity_visuals.gd`, `pickups.gd` | PASS (unchanged counts) |
| `tests/zone_modes/unit.gd`, `tests/arms_race/independent_fixtures.gd`, `tests/horde/test.gd`, `tests/horde/controls_test.gd`, `tests/horde/layout_test.gd` (follow-up sweep) | PASS 42, 55/0, 15/0, 31+3 samples, 2/2 |
| `game_hud_visual.gd` at 960/1280 (`--hud-results`), `lobby_spectator_session.gd`, `lobby_followup_geometry.gd` x2, `scoreboard_visual.gd` x2, `stall_controls.gd`, `window_focus.gd`, `local_lifecycle.gd`, `round_boundaries.gd`, `entity_visuals.gd`, `pickups.gd`, `control_safety.gd`, `zone_modes/unit.gd`, `arms_race/independent_fixtures.gd`, `horde/test.gd`, `horde/controls_test.gd` (final §6 sweep) | PASS, unchanged counts |
| `port/native-match-selection/run.mjs --menu-only` (graphical setup -> Start flow, final §6 sweep) | PASS `PORT_MATCH_SELECTION_LIVE_OK`, 0 engine errors |

Logs: `evidence/logs/`. The probe run is
`port/native-ui-polish/run.sh` (before/after datasets were produced by the same
probe against the follow-up baseline `6f098448` with and without the two
runtime files; the first-pass datasets for the setup/Horde surfaces are the same
measurements, verified identical case by case).

## Open items the lead should decide

- **Invalidated images** (section 5.1): the lobby and arms-race results images
  named there still show the old shared card; the §6 HUD fix invalidates no
  image (the settled panel is byte-identical). Re-render or annotate as the lead
  prefers; the Horde evidence named there also predates the first pass.
- **F7:** no HUD surface owned by this lane binds or advertises F7; the
  benchmark lane keeps that key.
- No human playtest, hardware review or Windows package run is claimed here.
  The Horde state used by the probe is a documented synthetic fixture; the
  shared-board roster is the stored captured frame plus documented synthetic
  bot rows (so a full card is measured).
