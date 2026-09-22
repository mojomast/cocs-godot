# Native UI polish: the four inherited UI defects

**PASS on the four owned surfaces, each with measured and rendered before/after
evidence.** Lane ownership: `godot/ui/**`, `godot/horde/scoreboard.gd`, the five
named protocol UI tests and this directory. No gameplay authority, engine
setting, package tool or other lane's file was changed.

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

## Assertions changed (and why)

Only the tests this lane owns were touched; no check was removed or weakened.

| file | change | reason |
|---|---|---|
| `tests/protocol/game_hud_session.gd` | `--setup` branch: **+6** assertions (`popup_windows(setup) == 0`, `setup.size.y <= 620`, `dismiss()/dismissed`, reopen, and the surface is hidden with 0 popups after `start_selected_match`) | locks defect 1: the surface must be popup-free, content-sized and dismissible, and must not linger over the match. Existing "setup remains interactive" assertion is kept. |
| `tests/protocol/scoreboard.gd` | **+4** roster-wording assertions (bot roster, NPC roster, singular, all-human legacy wording) and **+6** Horde geometry assertions (panel clear of the vitals/weapon panels and inside the viewport at both sizes, measured from the real `ui/game_hud.gd` rects via a real `horde/scoreboard.gd`) | locks defects 2 and 3 by measurement instead of eye review. |
| `tests/protocol/match_selection.gd` | **+3** assertions (no popup selector nodes, explicit dismissal exposed, detached panel stays content-sized) | locks the popup-free setup contract on the selection fixture. |
| `tests/protocol/scoreboard_session.gd`, `tests/protocol/team_scores.gd` | unchanged | their assertions still hold; the all-human roster keeps the legacy `N players` wording, and the team-total line is still part of the summary. |

## Verification runs

| command | result |
|---|---|
| `game_hud_session.gd` (default / `--setup` / `--debug-hud`) | PASS (`PORT_GAME_HUD_SESSION_OK`, `PORT_GAME_HUD_DEBUG_OK original_display=true`) |
| `scoreboard.gd` | PASS, checks 25 -> **35** |
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

Logs: `evidence/logs/`. The probe run is
`port/native-ui-polish/run.sh` (before/after datasets were produced by the same
probe against `f9f28809` with and without the four runtime files).

## Open items the lead should decide

- **Shared (non-Horde) board at 960x640:** the unchanged shared card still
  reaches `y=585` while the live vitals start at `y=474`. This lane deliberately
  did not change it because it would alter every non-Horde results/live board
  image that other lanes already inspected; the hook to fix it exists
  (`layout_*`) and would mirror the Horde band.
- **F7:** no HUD surface owned by this lane binds or advertises F7; the
  benchmark lane keeps that key.
- No human playtest, hardware review or Windows package run is claimed here.
  The Horde state used by the probe is a documented synthetic fixture; the
  pickup-caption finding is evidence of the composition, not of a live match.
