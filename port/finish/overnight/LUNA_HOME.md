# Luna Home lane

## Evidence and selection

Three high-value opportunities were checked against `godot/ui/main_menu.gd`, `menu_preferences.gd`, and `routes.json`:

1. **Make Campaign easier to discover.** The catalog has the validated `campaign` route (“The Quiet Relay”) under Play, while Home only featured Fighting in its action row. Chosen: add a one-click Campaign shortcut that delegates to normal category/route selection and default validation.
2. **Make return-to-play obvious.** Version-1 menu preferences already restore the last route and its sanitized options on startup; changing persistence would duplicate working behavior. No preference schema changes made.
3. **Improve controller/keyboard arrival.** Home already uses focusable Buttons, focus-follow scrolling, responsive stacked columns, and compact wrapping. Chosen: initial focus now lands on the restored route, ready to browse/confirm, rather than the category list. Existing category controls remain available through ordinary focus navigation.

The first checkpoint added the Campaign shortcut and restored-route focus. Follow-up discovery work adds a focused search field backed by the self-contained `godot/ui/route_search.gd` helper. It searches route IDs, labels and descriptions plus only the map IDs/labels in each route's declared map option list. Search results are hidden for `cheats` unless `COCS_DEBUG=1`; no private/debug map universe is inferred. Typing changes only the result list/count; choosing a map result selects its catalog route, then applies the map through the existing validated choice-row path. Enter in the search field does not launch; Escape clears a nonempty focused query before Home's normal quit handling. Empty results are explicit, and result Buttons participate in regular focus traversal.

The menu contract now checks that filtering preserves the current selection/options, zero-results are visible, and a real map result produces a registry-valid selection. `godot/tests/main_menu/search.gd` covers case-folded/whitespace search, route descriptions, a real map name and ID, no matches, and the debug-only gate against the production catalog.

## Verification

Source-only parse commands (safe under the overnight slot):

```sh
/tmp/opencode/fighting-core-grammar/bin/gdparse godot/ui/main_menu.gd
/tmp/opencode/fighting-core-grammar/bin/gdparse godot/ui/route_search.gd
/tmp/opencode/fighting-core-grammar/bin/gdparse godot/tests/main_menu/contracts.gd
/tmp/opencode/fighting-core-grammar/bin/gdparse godot/tests/main_menu/search.gd
```

Native Home contract/lifecycle checks remain **pending** (not run under the source-only slot). After a native grant, from the project root:

```sh
godot --headless --path godot --script res://tests/main_menu/contracts.gd
godot --headless --path godot --script res://tests/main_menu/search.gd
godot --headless --path godot --script res://tests/main_menu/live_attract.gd
```

## Closure and gaps

No resources, packages, project settings, routes, input bindings, or production assets changed. The helper is reached via `main_menu.gd` preload, so no manifest/receipt changes are needed; no asset/import work was added and package/resource closure impact is none. The new native search and Home contract runs remain pending under the source-only slot. Runtime controller traversal, map-result activation, compact visual fit, debug-gate runtime behavior, and launch-marker behavior have not been exercised here.
