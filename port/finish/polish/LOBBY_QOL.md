# Lobby QoL — Flash polish lane (`feature/polish-flash-lobby`)

Source-only lobby quality-of-life fixes for the audited defects plus the
parent-review follow-ups. The exclusive native engine slot is
**`MOTION-UI-NATIVE-20261003-K`**; this lane authored native fixtures but did
**not** run Godot, an importer, a renderer, a server, a benchmark or a nested
agent. Native execution is pending under K.

- Worktree: `/home/mojo/.tmp-on-disk/cocs-polish-flash-lobby-20261003`
- Branch: `feature/polish-flash-lobby`
- Base: `5b5c8791`
- Read-only foundation for discovery: `e43d2d38`

## Owned files

| File | Change |
|---|---|
| `godot/social/room_browser.gd` | truthful filtered-empty state, clear-filters path, in-place selection mark |
| `godot/ui/lobby_choice.gd` | idempotent `disabled` setter + change-detected render (observer counter) |
| `godot/ui/lobby_menu.gd` | single disabled writer per refresh, content fingerprint, total catalog access, honest catalog error |
| `godot/ui/match_setup.gd` | content fingerprint + row rebuild, validated mode ids, removed-map recovery, disabled Start |
| `godot/tests/protocol/lobby_qol.gd` | focused fixture (authored, native execution pending) |
| `port/finish/polish/lobby_qol_source_check.py` | gdtoolkit-parser source check (re-runnable evidence) |
| `tools/godot-dev/verify.py` | one gate line `lobby-qol` — **kept in its own commit** for the parent to include/exclude until K completes |

No K runtime file, Home/Settings/Input-Bindings, campaign Journal, Fighting or
sports/world session source was touched. The shared catalog is only read.

---

## Finding 1 — room browser blanked on a filter that matched nothing

`rebuild()` only named emptiness when `all_rooms.is_empty()`; an advertised list
filtered to nothing cleared the note, leaving a silent blank list.

`godot/social/room_browser.gd`:

- `filter_active()` (line 79) detects a query or the in-progress toggle.
- `rebuild()` (line 150) distinguishes four states: in-flight/unconnected stay
  blank, an empty advertised list says `No rooms to show.`, a filtered-to-empty
  list says `No rooms match the current filters.`
- A focusable `Clear filters` button is shown whenever a filter is active and
  clears only the browser's own query/toggle. It never selects, changes role or
  joins.
- **Follow-up:** `select_room()` (line 138) now updates the marker **in place**
  via `apply_selection_mark()` (line 211) — it does not set `dirty`, does not
  rebuild and therefore does not drop focus from the pressed row, and still
  never re-emits a selection. `row_for()` caches the unmarked base text in node
  metadata so the marker toggles without re-deriving from a prefixed string.

## Finding 2 — per-frame refresh churned the choice rows

`lobby_menu._process` calls `refresh()` every frame.

`godot/ui/lobby_choice.gd`:

- `disabled` is an idempotent property backed by `_disabled` (line 33).
- `refresh()` (line 124) returns early on an unchanged value-of-record;
  `update_count` (line 23) is the observer counter.
- `select()` (line 161) skips re-asserting the active entry.

`godot/ui/lobby_menu.gd` `refresh()` (line 506): the four top-level choice
enable states are owned by a single `apply_choice_enablement()` call (line 409;
one assignment each to `role.disabled`, `maps.disabled`, `modes.disabled`,
`operator.disabled`), and `apply_harness_lock()` owns `harness.disabled`. The
same helper runs immediately after a user map change, so no property has
contradictory writers within one refresh. The previous
`for control in [role, maps, modes]: control.disabled = not editable` followed
by a second `modes.disabled = …role == 1…` made a stable guest (or empty
catalog) frame set `modes.disabled` false then true every frame — two renders
per frame and the exact bug the idempotent setter was meant to prevent.
`populate_modes()` (line 397) no longer writes enablement at all; it only
populates items, so a stale caller cannot reintroduce the double write. Live
reconnect-ticket/status refresh is untouched.

The fixture now proves idle stability for **host, guest and empty-catalog**
menus: five consecutive `refresh()` calls leave every choice row's
`update_count` unchanged (guest settles to `modes.disabled` once, then stays).

## Finding 3 — same-size catalog replacement was invisible

`sync_map_choices` / `reselect_valid_map` only compared count + the current map
id, so a reopened catalog that replaced other ids, a name, or the selected map's
modes left stale rows; and a **newly added key** was absent from the existing
choice rows, so the fallback `map_index` returned `-1` and recovery silently did
nothing.

`godot/ui/lobby_menu.gd` and `godot/ui/match_setup.gd`:

- `catalog_signature()` (lobby `89`, setup `322`) is a read-only projection of
  the sorted ids plus each entry's name and validated modes.
- `sync_map_choices()` (lobby `437`) / `sync_catalog()` (setup `352`) compare the
  signature and only then rebuild — a stable frame performs no work, and a
  same-size replacement that changes content still differs.
- `rebuild_map_choices()` (lobby `421`, setup `334`) rebuilds the map rows from
  the live catalog: it preserves the current selection by metadata, falls back
  to a surviving startable map (or the session's current id in the lobby), and
  makes a newly added key selectable again. Modes are repopulated whenever the
  signature changes, including a modes-only change for the same map id.

The fixture covers: same-size name replacement, same-size modes replacement for
the selected map, removed selected map + newly added key, and selection
preservation across all three (both surfaces).

## Finding 4 — malformed mode arrays

`offered_modes` returned any `Array`, so `for mode: String in offered` raised on
a `null`/dictionary/number element.

`godot/ui/match_setup.gd` `valid_modes()` (line 72) returns only non-empty
`String` mode ids (trimmed, length ≤ 64, no control characters), collapses
duplicates and preserves order. `validate()` (line 53), both `offered_modes`
(lobby `54`, setup `300`) and the content signatures use it. A mode is never
invented and the shared catalog is never mutated.

The fixture asserts `valid_modes` drops non-strings/controls/duplicates and
trims, and that a map with a malformed array recovers to its one valid mode with
an interactive row and an enabled Start — no invalid-dictionary error.

## Second-review corrections (appended)

1. **Host `room.editable` double writer.** `refresh()` excluded `room` from the
   generic `[endpoint, player_name, room]` loop; the guest-only join field now
   has exactly one writer (`editable and role.selected == 1`). Without this a
   host frame wrote `room.editable` true then false every frame. Because
   `LineEdit` exposes no change signal, `lobby_menu.room_editable_writes`
   (guarded observer counter) lets the fixture prove the value is written at
   most once while idle for both host and guest.
2. **`match_setup` had no live update path.** `sync_catalog()` was only reachable
   through the private `populate_modes()`, so an owner that opened or populated
   the catalog after `configure()` could not recover. `match_setup._process`
   now detects `catalog_signature() != catalog_fingerprint`, guards on
   `body`/`is_inside_tree()`/`body.visible`, and calls
   `populate_modes(selected_mode())` exactly once per actual change. The fixture
   mutates `entries` and awaits two process frames **without** calling
   `populate_modes()`, including an initially-empty-then-populated catalog.
3. **Mode reset on unrelated catalog change.** `lobby_menu.populate_modes()` now
   captures the user's current mode first and keeps it when it is still offered;
   only an invalid/absent current mode falls back to `session.selected_mode`
   (or the first offered mode). The fixture sets the user mode to
   `teamdeathmatch` (session stays `deathmatch`), renames an unrelated map
   same-size, and asserts `teamdeathmatch` is preserved.
4. **`valid_modes` contract comment.** Rewritten to match the code exactly:
   `strip_edges()` runs first (so a leading newline is allowed), interior
   control characters reject the entry, empty/over-long ids drop, duplicates
   collapse, and the catalog's own advertised ids (including standalone/lattice
   modes) are not second-guessed by an allowlist.
5. Appended, not rewritten: the prior review commits stay intact.

## Catalog audit (`catalog.open` status / original error)

Corrected per the parent audit; no false freshness promise:

- `world/catalog.gd.open()` clears `error` then sets it on failure. However
  `resolve_map()` sets `error` on later failures and **never clears it on
  success**, so `catalog.error` is not guaranteed to still hold the `open()`
  failure by the time another component reads it.
- `world/viewer.gd:36` opens the catalog and surfaces `catalog.error`, but
  `world/session.gd:506` early-returns on a missing `meridian-exchange` instead
  of routing `catalog.open()`'s boolean through the status path. That session
  file is K-owned and was **not** edited.
- The lobby surfaces only show `catalog.error` verbatim as best-effort original
  text (never a generic replacement) and never mutate or register catalog
  entries. The comment in `lobby_menu.catalog_error_text()` states this
  honestly.

## Privacy / secrets

Room codes are private user input. The filter/clear path performs no logging and
only compares advertised fields in memory (`social_model.filter_rooms`). No
secret, room code or endpoint credential is written to a log, tooltip or status
line by these changes.

---

## Verification

### Passed at source level (this lane)

Real parser (gdtoolkit), not just structural regex:

```
$ PYTHONPATH=/tmp/opencode/gdtlib python3 port/finish/polish/lobby_qol_source_check.py --require-parser
ok   parser godot/social/room_browser.gd
ok   parser godot/ui/lobby_choice.gd
ok   parser godot/ui/lobby_menu.gd
ok   parser godot/ui/match_setup.gd
ok   parser godot/tests/protocol/lobby_qol.gd
LOBBY_QOL_SOURCE_OK files=5 problems=0 parser=gdtoolkit native_execution_pending=true

$ python3 -m py_compile tools/godot-dev/verify.py
py_compile OK
$ python3 -m unittest tools.godot-dev.test_playable_gates tools.godot-dev.test_verifier_report
Ran 7 tests ... OK
```

The source check parses all five files with gdtoolkit (falling back to a
structural scan only when the parser is unavailable) and asserts the QoL
contract symbols the fixture depends on. It is **not** a substitute for the
native gate.

### Native — pending under K (not executed here)

`lobby-qol` (`godot/tests/protocol/lobby_qol.gd`) asserts, against synthetic
session doubles: truthful filtered-empty wording, a focusable clear path that
restores the list without re-announcing a selection, in-place selection marking
that preserves focus; idempotent disabled/selection with `update_count` stable
across five refreshes for **host, guest and empty-catalog** menus; same-size
catalog replacement detected for names and modes with selection preserved; a
removed selected map recovered onto a surviving row and a newly added key
rebuilt into the row; malformed mode arrays filtered to valid unique strings;
and empty/reopened/malformed catalogs disabling the launch path with the
catalog's own error while Back/Close/Retry stay usable.

Registered gates covering the unchanged API: `social-native`, `loadout-lobby`,
`loadout-setup`, `match-selection`, `reconnect-menu`.

Audit note (not owned): `tests/protocol/lobby_popup_free.gd` and the
`lobby_followup_*` / `lobby_spectator_*` / `lobby_independent_*` fixtures are
**not** registered in `tools/godot-dev/verify.py`; recommend the native owner
register `lobby-popup-free` or fold it into `lobby-qol`.

## Resource closure paths

| Touched resource | Depends on / closure |
|---|---|
| `godot/social/room_browser.gd` | loaded by `godot/ui/lobby_menu.gd`; reads `godot/social/social_model.gd` only |
| `godot/ui/lobby_choice.gd` | shared by `lobby_menu.gd` and `match_setup.gd` |
| `godot/ui/lobby_menu.gd` | instantiates `room_browser.gd`, `chat_panel.gd`, `match_setup.gd`; reads `session.catalog.entries/error`; reuses `Setup.valid_modes` |
| `godot/ui/match_setup.gd` | `validate()`/`parse_args()` consumed by `world/session.gd`; `configure()` called from `session.gd:594` |
| `godot/tests/protocol/lobby_qol.gd` | `tests/protocol/lobby_social.gd` fixture pattern; synthetic doubles only |
| `port/finish/polish/lobby_qol_source_check.py` | gdtoolkit parser + the five paths above |

## Commit layout

1. `fix(lobby)`: runtime fixes (4 `.gd` files)
2. `test(lobby)`: tests + report + source check (no runner change)
3. `chore(verify)`: register `lobby-qol` (the one `tools/godot-dev/verify.py`
   line only) — kept separate so the parent can drop exactly this commit until
   K's native gate is stable.
4. Appended second-review fixes (host room writer, match_setup live update,
   mode preservation, `valid_modes` comment).
5. Appended fixture/report update for the second-review corrections.

Existing commits are not rewritten.

## Native acceptance checklist for K

1. Run `lobby-qol` headless; expect `PORT_LOBBY_QOL_OK … failures=0`.
2. Re-run `social-native`, `loadout-lobby`, `loadout-setup`, `match-selection`,
   `reconnect-menu`.
3. Confirm the generated catalog path (real 9-map manifest) still builds map and
   mode rows and enables host/join/Start.
4. Confirm no new popup/Window and no per-frame churn warning in the native log.
