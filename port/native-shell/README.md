# Shared native shell and responsive UI

This is the NATIVE-03 settings/navigation and NATIVE-04 compact-layout increment.
It evolves the existing menu → route process → menu supervisor journey.

## Player controls

- **Home → Settings** or **F12** in a route opens device preferences.
- **Esc / Back** closes Settings without recapturing the pointer. Follow the
  current mode's normal click/Enter controls to re-engage.
- **Leave Match** exits the native route process. The menu supervisor then
  returns Home; a direct CLI route invocation exits completely.
- Settings does not pause the source simulation. The panel states this clearly.
- F7 benchmark, F8 scenery, F9 effects quality, F10 metrics and F11 diagnostics
  retain their existing roles.

Available preferences: master volume, mute, fullscreen/windowed mode, mouse
sensitivity (25–250%) and interface scale (75–150%). Display flags supplied
directly to Godot take precedence at startup; an explicit Settings change can
subsequently select another window mode. Mouse sensitivity affects combat,
LATTICE world, Horde and combined-arms look; sports uses its existing chase
camera controls.

Mouse-look adapters use unscaled screen motion so interface scale cannot change
aim sensitivity. This follows Godot 4.5's
[mouse-motion coordinate contract](https://docs.godotengine.org/en/4.5/classes/class_inputeventmousemotion.html#class-inputeventmousemotion-property-screen-relative).

The Home categories have stable internal IDs and distinct player-facing labels:
Play, Bot Matches, Activities, Extras and Cheats. Generated capability summaries
describe local, externally hosted and offline routes using launcher-derived
facts. Both launch parsers remain checked against the generated capability set.

## Persistence and authority

The versioned settings file accepts only the five documented preference fields.
It validates values, bounds file size, recovers from malformed/unsupported data,
and saves by same-directory temporary file and rename. Menu activity selections
remain in their existing separate preference store.

The supervisor passes the same absolute `COCS_SETTINGS_PATH` to menu and route
processes, including routes with disposable XDG runtime directories:

| Launch | Default settings path |
| --- | --- |
| Development supervisor | `<checkout>/.port-runtime/local_settings.json` |
| Linux package | `$XDG_CONFIG_HOME/cocs-native/local_settings.json`, or `~/.config/cocs-native/local_settings.json` |
| Windows package | `%APPDATA%\cocs-native\local_settings.json` |
| macOS path helper | `~/Library/Application Support/cocs-native/local_settings.json` (path contract only; no macOS package acceptance claimed) |
| Standalone Godot/editor | `user://local_settings.json` |

An explicit absolute path overrides the default. Headless contracts retain
deterministic defaults and inject private fixture paths when testing persistence.

The Node supervisor still owns local server cleanup. External guest leave closes
only the client. The source may retain the disconnected participant during its
reconnect grace interval; native UI does not delete source actors or invent a
match outcome. Wallets, purchases, progression and unlocks are not settings.

## Layout

Home reflows vertically at compact logical widths and follows keyboard focus
through its scroll area. The command deck places long objective details in a
wrapping selected-target card, with vertical scrolling and stacked objective/REQ
pages at large interface scales. Modal deck/setup surfaces render above combat
diagnostics. Compact labels preserve legality, supply, unknown-state and purchase
receipt distinctions.

At narrow logical widths the tactical HUD stacks its objective and live-mission
cards and reduces supplemental prose. Objective/range, legality/supply,
dominance or wave progress, HQ/force, health, REQ/FLUX and active receipts remain
visible. Effects metrics are opt-in through F10 instead of covering those cards.

Interface scale uses the actual window as its layout basis: changing the window
size reflows controls rather than squeezing a fixed 1280×800 layout. ItemList
rows can still ellipsize at narrow widths; selecting a row exposes its complete
facts in the detail card and tooltip.

## Verification commands

Use the pinned engine and explicit derivative as documented in
[native CI](../native-ci/README.md). Heavy checks run serially.

```sh
node --test tools/godot-package/settings_path.test.mjs tools/godot-package/menu_journey.test.mjs
node tools/godot-package/gen_routes.mjs --check
node --test tools/godot-package/route_parity.test.mjs
"$GODOT_BIN" --headless --path godot --script res://tests/product_shell/settings_contract.gd
"$GODOT_BIN" --headless --path godot --script res://tests/main_menu/contracts.gd
"$GODOT_BIN" --headless --path godot --script res://tests/lattice/world_commands_contract.gd
"$GODOT_BIN" --headless --path godot --script res://tests/lattice/world_tactical_contract.gd
python3 tools/godot-dev/xvfb_run.py node tools/godot-dev/product_journey.mjs --capture
python3 tools/godot-dev/xvfb_run.py node tools/godot-dev/guest_leave_journey.mjs
python3 tools/godot-dev/verify.py
```

The supervisor unit test uses synthetic native children and real owned HTTP
listeners. The rendered journey instead launches actual Godot scenes and source
servers, drives Home/combat/LATTICE/sports three times, changes preferences across
processes, exercises Settings/Back/Leave, and checks every owned listener closes.
The separate guest journey uses one native guest and one protocol host and
checks continued host snapshots after guest exit. Both are scripted lifecycle
evidence, not natural rounds, two-native-human acceptance or hardware feel.

Attempt summaries/logs are retained under `.port-runtime/product-journeys/` and
`.port-runtime/guest-leave/`. The aggregate records the tested commit, source
identity, actual executions and unrun checks in `port/reports/verification.json`.

The broader roadmap still includes Cinderwake authority reconciliation and
integration, extracted-package multi-mode acceptance, and a consolidated release.
