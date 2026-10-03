# DeepSeek campaign lane — Relay Journal and chapter route context

Overnight fan-out lane. Worktree
`/home/mojo/.tmp-on-disk/cocs-overnight-deepseek-campaign-20261003`, branch
`feature/overnight-deepseek-campaign`, created from `aa3b8f0f`. SOURCE ONLY under
exclusive heavy grant `ABYSSAL-ASSET-PRODUCTION-20261003-I`
(`ses_f03a3024cffeNO1Cc3Qr1zSLTG`): no Godot, Blender, import, render, encoding,
audio, server or full-map benchmark ran. Small source parsing only.

## Evidence reviewed before choosing

The lane inspected the actual public state and the current presentation, not a
plan:

- `port/native-campaign/match.mjs` builds `snapshot.campaign` with `mapId`,
  `index`, `title`, `stepIndex`, `stepCount`, `objective`, `detail`, `checkpoint`,
  `elapsed`, `totalElapsed`, `kills`, `enemiesRemaining`, `holdProgress`,
  `transmission`, `nextMapId`, and the full `interludes`/`story` sub-objects.
- `port/native-campaign/interludes.mjs` reports per-workshop `id`, `title`,
  `family`, `theme`, authored `actions`, `hint`, `result`, `stage`, `completed`
  and `choice`; completion carry is `interludeCarry`.
- `port/native-campaign/story.mjs` reports active `entities` (Mara, Ivo, Patch),
  `completed` story beats and a `pets` count.
- `godot/campaign/hud.gd` already owns objective/detail/comms/waypoint and the
  death/level/campaign cards, but exposed no way to review optional workshop
  progress or the four-chapter route as a whole.
- `godot/campaign/model.gd` validates those structures but intentionally never
  derives objectives locally; the lane preserved that contract untouched.
- `port/finish/` scenery F promotion (`aa3b8f0f`) is presentation-only and was
  not restamped or rebuilt.

Nothing in `godot/campaign` or `godot/tests/campaign` offered a journal, route
strip or workshop listing.

## Three opportunities and selection

1. **Relay Journal (chosen, implemented).** A read-only, focus-navigable panel
   that renders the current objective metrics, the chapter's optional workshops
   with authored hints/results, the companions present, and the four-chapter
   route — using only public snapshot state plus events this client observed.
2. **Chapter route context on the mission cards (chosen, implemented).** The
   pre-chapter brief and the death/complete cards now show a four-chapter route
   strip that marks the current chapter and only marks `✓` chapters whose
   `level-complete` this client actually observed.
3. **Off-screen objective bearing ribbon (deferred).** The HUD waypoint already
   reports distance and flips to a clamped `→ ◇ N m` when the marker is behind
   the camera. Adding chevrons would duplicate projection math owned by targeting
   and add HUD clutter without new public events, so it was not built.

## Implemented UI behaviour

New files:

- `godot/campaign/journal_model.gd` — pure `RefCounted` derivation.
- `godot/campaign/journal.gd` — the panel, entered from the existing HUD menu
  (`Journal` button, between the cursor-mode `Settings`/`Leave` controls) and
  from an unhandled `I` route.
- `godot/tests/campaign/journal_model.gd` and
  `godot/tests/campaign/journal_input.gd` — source-authored native gates.
- `godot/tests/campaign/session.gd` gained three assertions for the brief route
  strip and journal entry point.
- `godot/campaign/hud.gd` owns the entry point, route strip and per-snapshot
  observation; `godot/campaign/demo.gd` needed no change because the HUD already
  receives every accepted campaign state in `refresh()`.

Journal content:

- Objective title, objective text, authoritative detail, and a metrics line:
  `Step n/6 · Robots N · Link %· Disabled N · Time m:ss`.
- Optional workshops for the current chapter. `✓` when completed, `◐` when a
  `link` workshop's first cable is connected, `○` otherwise, with the authored
  hint while open and the authored result (including the reward text) once done.
- `WITH YOU` companion list from active story entities (Mara/Ivo/Patch) plus the
  observed story-beat and Patch-pet counts.
- `ROUTE` strip over the public catalog: `◆` current, `✓` observed complete,
  `○` not yet observed.

Route strip on the cards:

- Brief: `◆` marks the selected chapter, others `○`.
- Death: the current chapter stays `◆` and previously observed chapters keep `✓`.
- Level-complete / campaign-complete: the just-finished chapter flips to `✓`.

## Reset, death, retry and epoch decisions

`JournalModel` keeps a per-chapter record of workshops and story beats that were
observed complete. It never invents completion:

- **Death and retry:** the authority carries `interludeCarry`/`storyCarry`, so
  completed workshops remain reported; the record is retained across death and
  retry and is shown for the recovered checkpoint.
- **Restart:** the authority deletes the chapter carry, so a previously
  completed workshop/beat is reported incomplete. That authoritative regression
  is the only thing that clears the chapter record, and it also clears the
  chapter's route `✓`.
- **Chapter transition:** each chapter has its own record; earlier `✓` marks are
  retained while the next chapter becomes `◆`.
- **Malformed/foreign payloads:** states without `id == "quiet-relay"` or with an
  unknown `mapId` are ignored and cannot replace or erase the observed record.

## Focus, accessibility and compact behaviour

- The toggle is an `_unhandled_input` route, so a focused `LineEdit`/`TextEdit`
  swallows it first; `Settings`/career overlays, the cheats overlay and any
  `world_commands`/`session_panel` modal also block it. No new input binding and
  no `input_bindings` edit was made.
- Controller/keyboard focus uses ordinary Godot focus: the body `ScrollContainer`
  and the `Close journal` button are `FOCUS_ALL`; `follow_focus` is on; `Esc` /
  `ui_cancel` closes. A D-pad `ui_up`/`ui_down` handler scrolls the body for
  controllers; `ScrollKeys` keeps owning keyboard arrows/page keys.
- Opening releases the pointer exactly like the existing HUD menu, so gameplay
  input is cancelled through the established campaign cursor lifecycle. No pause
  or other authority message is sent.
- `resize()` uses the same `<540`/`<800` compact threshold as the rest of the HUD,
  wraps all text with `AUTOWRAP_WORD_SMART`, clamps the panel to
  `min(680, view.x-24) × min(560, view.y-24)`, and scrolls the body at UI150
  instead of overlapping the objective or comms.

## Passed vs native pending

Passed in this source-only slot (exact commands):

```sh
/tmp/opencode/fighting-core-grammar/bin/gdparse godot/campaign/journal.gd
/tmp/opencode/fighting-core-grammar/bin/gdparse godot/campaign/journal_model.gd
/tmp/opencode/fighting-core-grammar/bin/gdparse godot/campaign/hud.gd
/tmp/opencode/fighting-core-grammar/bin/gdparse godot/tests/campaign/journal_model.gd
/tmp/opencode/fighting-core-grammar/bin/gdparse godot/tests/campaign/journal_input.gd
/tmp/opencode/fighting-core-grammar/bin/gdparse godot/tests/campaign/session.gd
```

All six parsed clean. No Godot process was started.

Native pending (authored, **not yet executed**; parent owns native execution,
integration and publication):

```sh
godot --headless --path godot --script res://tests/campaign/journal_model.gd
godot --headless --path godot --script res://tests/campaign/journal_input.gd
godot --headless --path godot --script res://tests/campaign/session.gd
```

`journal_input.gd` is an ordinary-input test: it feeds real `InputEventKey`
objects through `_unhandled_input`, checks the open/close toggle, pointer release,
the text-field guard, the cheat-modal guard, and the restart regression. None of
this runtime behaviour has been observed executing; only grammar is proven here.

## Package and closure impact

- Source-only. No `game/`, `server/`, receipt, requirements, package-input or
  `tools/godot-package` file was changed; `input_bindings/`, settings, Home menu,
  fighting and robot/biome production files are untouched.
- `godot/campaign/journal.gd` and `journal_model.gd` are referenced from
  `hud.gd` and thus ship in the export; the package closure tests enumerate
  `port/native-campaign/*.mjs` and `godot/campaign/generated/*.json`, not these
  presentation scripts, so no registered package-input count changes.
- A native/export run will emit new `journal.gd.uid` / `journal_model.gd.uid`
  sidecars (currently untracked, like other generated `.uid` files). Parent
  should add or ignore them at export reconciliation as usual.

## Hooks and protected evidence

No hooks were pinned and no native evidence was restamped. Published preview
`cb6e4c9f` is untouched. Scenery F identities remain anchored to `b320c270`
(release `b8ba1de8`); this lane did not read, rebuild or relabel them.

## Remaining gaps

- Native grammar-adjacent runtime execution of the two new gates and the updated
  session gate, on an ordinary input device, requires a later grant.
- Rendered layout at 720p/1080p/UI150 and real controller focus traversal were
  not visually inspected in this slot.
- The HUD's shared `player_info` layer (layer 6) sits above the campaign layer
  (layer 5); campaign captions are docked into the HUD and hidden with the
  journal, but a live inspection should confirm no other top-layer readout draws
  over the open journal.
