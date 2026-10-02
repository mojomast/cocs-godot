# Keyboard/mouse binding parity — source/code checkpoint

Status: **READY FOR ENGINE**. Base `e9d784a7`, branch `expansion-four/controls`.
Parallax retains the exclusive engine/Blender slot. No Godot, imports, renderer,
Blender, capture or export ran in this lane.

## Player-facing change

Home or a live route → **Settings / F12 → Keyboard / Mouse Bindings** now has
16 named, focusable action dropdowns, occupied-input swapping and a reset button.
The existing vertical Settings scroll follows keyboard focus. Each dropdown has
a native Godot 4.5 accessibility name and current-binding description. Mouse
left/right/side buttons and physical keyboard keys are supported; middle mouse
remains the source's fixed alt-fire alternate. This is a gameplay setting, not a
developer JSON editor. Save failures are shown without discarding the session's
chosen controls.

The model preserves all **25 exact source keyboard action IDs/defaults**, with
native `fire`/`ads` mouse-path preferences. Only the 14 keyboard actions already
consumed by live native gameplay, plus fire/ADS, are offered for editing.
Command/voice/free-cursor/spectator contexts are explicitly inventoried in
`godot/input_bindings/contexts.json`; this lane does not fabricate those features.
Native exploration/showcase walkers and developer galleries are separate local
contexts, explicitly outside the live combat/sports field's stated scope.

## Input architecture

- `model.gd`: ordered source canonicalizer, source swap semantics, labels and
  physical-event codecs. Modifier side is taken from `InputEventKey.location`.
  An unspecified side keeps the existing native test/event convention of left.
  Left/right modifiers are individual inputs, not chord strings. Holding the
  crouch binding and jump binding still composes the source Grok chord.
- `mapper.gd`: **per-sampler** physical-down ledger, physical-to-default virtual
  event conversion, suppressed-held ledger and release-to-original-target lookup.
  A release after a binding change resolves to the action pressed originally.
  No global `InputMap` rewrite, `Input.action_press`, input polling override,
  packet writer or synthetic global event reinjection exists in production.
- The four existing samplers consume translated events, then run their existing
  movement, pulse/hold, aim cancellation, vehicle and queue-consumption logic.
  Raw route events remain available to raw-event accounting, weapon selection,
  command widgets and the existing `GameInput`/authority FIFO.
- Settings calls the existing route release method **before** changing the map.
  Clears preserve physical down until release; inactive presses are recorded but
  never promoted on recapture. Rebinding fire to a keyboard key cannot turn a
  suppressed key into the special default left-click capture/fire pulse.
- Modal routes now observe inactive presses and releases, including Horde and
  Arms Race. LATTICE/identity-zone/Horde and sports cancellation/sample paths have
  spectator guards. The settings/binding service itself sends no network frames.
- `hints.gd` is an explicit opt-in binding-label provider. Static help labels
  subscribe once to `changed`; existing dynamic HUD/ability text resolves at its
  normal presentation boundary. No per-frame scene scanning or static text
  overwrite loop is added. Reused story/results labels end hint ownership when
  another owner replaces their text.

## Persistence and migration

Bindings are device-local in `user://input_bindings.json`:

```json
{"version":1,"bindings":{"forward":"KeyW","fire":"MouseLeft"}}
```

Missing file/fields use source defaults. Malformed/duplicate known values are
repaired in source action order. Unknown binding fields and envelope fields are
retained on save and reset; they never resolve gameplay actions. Writes use a
same-directory PID temp file and atomic rename, with a 16 KiB bound. An injected
absolute `COCS_BINDINGS_PATH` isolates tests; headless startup does not load a
user file automatically. Unsupported schema versions are not loaded.

The existing `local_settings.json` schema, unknown fields, percentage units,
sensitivity/display values and version are untouched by this store. This avoids
enlarging or rewriting that shared 4 KiB preferences document. Reset bindings
does not reset other preferences.

## Parent integration / collision report

New implementation/resources live solely under `godot/input_bindings/`; tests
under `godot/tests/input_bindings/`; tools under `tools/port/input-bindings/`.
Shared hooks are a **separate commit**, to apply after the owned implementation.

Important shared hooks to preserve when merging incoming lanes:

| Surface | Hook | Likely owner overlap |
|---|---|---|
| `project.godot` | InputBindings autoload before LocalSettings | Parent catalog/autoload integration |
| `ui/local_settings.gd` | One child panel insertion | Parent / Career settings |
| Four `world/combat_actions`, `horde/controls`, `sports/controls`, `combined_arms/controls` | Per-instance mapper; clear suppression; one translation per physical event | Input integrations |
| `world/session.gd`, Arms/Horde/sports/combined and two LATTICE demos | Observe modal inputs; guarded spectator cancellation | Gameplay / Experience / LATTICE / Horde |
| `arms_race/fresh_input.gd` | Configured physical-key gate; modifier-side-safe release | Existing native controls |
| Objective, zone and LATTICE recapture gates | Existing sampler ledger instead of fixed WASD polling | Parent route composition |
| `player_gameplay/session_binding.gd` | One `Hints.resolve(Status.text(model))` consumer call | Gameplay pass two |
| `experience/player_info.gd` | One `Hints.resolve(AbilityText.text(model))` consumer call | Experience pass two |
| HUD help labels | Explicit resolver/bind calls; LATTICE obsolete F-mobility hint corrected to X mobility/F melee | Shared UI |

**No `player_gameplay/status.gd` or cue/body overwrite**, no Career service change,
no frozen source/core/server edit, no package/canonical catalog mutation. The
parent should keep both ability-label consumer hooks when merging the incoming
Gameplay/Experience revisions. Future code may call `Access.label(action)`
directly instead of passing a source-default help string through the resolver.
Exporter closure needs the new production `.gd` files; source fixtures and native
journeys remain excluded test resources. Parent owns registration and exports.
