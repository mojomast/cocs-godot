# Source audit and route coverage

## Actual source inspected

| Source | Contract used |
|---|---|
| `game/keybinds.mjs:5–50,87–126` | Exact action order/defaults, reserved shell keys, physical code validation, deterministic duplicate repair, occupied-key swapping |
| `app/game-ui/configuration.tsx:46–121` | Labeled focusable capture/select controls, occupied-key swap, defaults reset; source also offers JSON transfer |
| `app/page.tsx:874–896` | Actual keyboard press/held/keyup handler, non-repeat edges; extracted and executed by the Node oracle |
| `app/page.tsx:624,637` | Actual queued-input pulse consumption and local/network sampler composition |
| `game/input.mjs:30–65` | Held movement/posture/jump/mobility/alt-fire, independent pointer fire/ADS, source action field names |
| `game/movement-input.test.mjs` | Existing actual-source movement/hold regression coverage (there is no `movement-input.mjs` file in this checkout) |
| `game/cursor-mode.mjs:56–99,150–232` | Keyboard owner ordering, modal clear-input transitions, free-cursor behavior; shell context remains separate |
| `game/onboarding.mjs:218–231` | Binding-derived onboarding text rather than frozen default key hints |
| `godot/ui/{local_settings,settings_access}.gd`, product-shell tests | Existing release/capture/scroll/focus and local-unit contracts |

Source files are unchanged. The oracle fixture records SHA-256 for the exact
keybind module, sampler and page used. The frozen source/core pins in the shared
brief remain unchanged.

## Native path matrix

| Native path | Binding consumer | Preserved sampling behavior | Prepared acceptance |
|---|---|---|---|
| Base world; native arenas; mode expansion; campaign; objective/zone routes; Assault | `world/combat_actions.gd` | Existing normalized movement, Q/R/E/F/G edges, held jump/X/Z, **existing short X pulse**, click-capture/fire exception, actor/reload ADS cancellation | Source sampler fixtures; remapped InputEvent live scene/wire journey; existing combat/player-gameplay gates |
| Horde and identity Horde maps | `horde/controls.gd` | Source edges and held X/Z, source ADS look gain, weapon selection and successful-queue consumption | Source sampler fixtures; release contracts; existing Horde controls gate |
| Arms Race | Base world sampler plus `arms_race/fresh_input.gd` | Locked weapon choice, mapped ADS/combat, release-before-recapture, modifier side retained in physical ledger | Source sampler fixtures; remapped fresh-gate contract; existing independent/fresh fixture gates |
| Sports and multiplayer sports | `sports/controls.gd` | Enter engagement, Escape release; forward/back throttle, steering, jump brake, sprint boost, reload→source interact/reset | Mouse-to-movement contract and existing sports contracts |
| Combined Arms | `combined_arms/controls.gd` / sports base | Exactly one translation before subclass and base processing; existing infantry/vehicle pulse/hold rules and bridge restrictions | Remapped movement/held boundary contract; existing combat/combined contracts |
| LATTICE native/multiplayer world | Base sampler; command modals retain raw shell controls | C command precedence, digits/menu navigation, wait-for-release; no spectator neutral command | Source sampler fixtures; modal-ledger and spectator-guard review; live LATTICE regression still required |

Additional HUD hooks cover shared game HUD, native arena help, Arsenal, objectives,
Assault vehicle help, campaign briefing, sports/Combined Arms, LATTICE guidance,
the gameplay fallback panel and **the actual Experience ability panel**. Incoming
Gameplay's hold-X and hold-Ctrl text can pass through the same provider without
changing its status projection or cue logic.

## Deliberate distinctions

- Source keyboard remapping is ported; source browser key-capture and JSON
  import/export widgets are not needed for the native select-based workflow.
- Mouse remapping is a native extension of existing `fire`/`ads` and existing
  action paths. Godot side-button indices are translated explicitly; wheel and
  middle mouse are not mistakenly offered as side buttons.
- Every accepted source keyboard mapping is representable in the model. The
  native editor excludes keys occupied by command/voice/cursor contexts lacking
  a native remap adapter. It adds Backslash, which source validation accepts but
  the source dropdown omits. Source-valid stored mappings remain readable.
- Source `ControlLeft`/`ShiftLeft` defaults are retained. Real right modifiers are
  now distinguishable and selectable, rather than collapsing physical sides.
- Multi-key shortcut strings are rejected. Modifiers are independently held
  controls; crouch+jump composes normally. No new gameplay chord protocol exists.
- World short-X tap retention predates this lane and remains unchanged. Horde
  and Combined Arms keep their existing sampler semantics, rather than acquiring
  invented world-only pulses or abilities through the mapper.
- Context rows in `contexts.json` are a scope declaration, not new public game
  actions. Spectator/freecam remapping belongs to Experience; local galleries
  and exploration walkers retain their own controls and help.

## Remaining acceptance, not claimed as passed

Engine type/runtime checks; native fixture comparisons; live remapped Horde,
Arms Race, LATTICE, sports and mounted Combined Arms; real lobby chat, death and
reconnect with remapped held controls; OS keyboard/mouse input (including both
modifier sides and side buttons); mouse-operated settings/reset/conflict swap;
screen-reader announcement; inspected wide and compact/UI150 screenshots; source
effect counts from the prepared native live journey; parent package closure.

The direct boundary contract intentionally calls sampler clear/release for named
focus/death/reconnect cases. That proves the shared local ledger only after it is
executed; it is **not** a claim that all real route lifecycle integrations ran.
