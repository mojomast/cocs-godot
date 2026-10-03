# Luna Home lane

## Evidence and selection

Three high-value opportunities were checked against `godot/ui/main_menu.gd`, `menu_preferences.gd`, and `routes.json`:

1. **Make Campaign easier to discover.** The catalog has the validated `campaign` route (“The Quiet Relay”) under Play, while Home only featured Fighting in its action row. Chosen: add a one-click Campaign shortcut that delegates to normal category/route selection and default validation.
2. **Make return-to-play obvious.** Version-1 menu preferences already restore the last route and its sanitized options on startup; changing persistence would duplicate working behavior. No preference schema changes made.
3. **Improve controller/keyboard arrival.** Home already uses focusable Buttons, focus-follow scrolling, responsive stacked columns, and compact wrapping. Chosen: initial focus now lands on the restored route, ready to browse/confirm, rather than the category list. Existing category controls remain available through ordinary focus navigation.

The two selected changes are in `godot/ui/main_menu.gd`; no catalog entries or launch authority were added. The menu contract source test now exercises the featured Campaign action and validates it against the registry.

## Verification

Source-only parse commands (safe under the overnight slot):

```sh
/tmp/opencode/fighting-core-grammar/bin/gdparse godot/ui/main_menu.gd
/tmp/opencode/fighting-core-grammar/bin/gdparse godot/tests/main_menu/contracts.gd
```

Native Home contract/lifecycle checks remain **pending** (not run under the source-only slot). After a native grant, from the project root:

```sh
godot --headless --path godot --script res://tests/main_menu/contracts.gd
godot --headless --path godot --script res://tests/main_menu/live_attract.gd
```

## Closure and gaps

No resources, packages, project settings, routes, input bindings, or production assets changed. Added no assets/import work; package and resource closure impact is none. Runtime controller focus traversal and the in-window Campaign action still require the pending native contract run; visual layout and launch-marker behavior were not exercised here.
