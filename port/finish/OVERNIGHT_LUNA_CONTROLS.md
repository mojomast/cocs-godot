# Overnight Luna controls/settings lane

## Audit findings

Reviewed `godot/input_bindings/{model,service,settings_panel,mapper,hints}.gd`, the local-settings panel wiring, and input-binding contract/native-journey tests.

Three concrete usability gaps found in the current architecture:

1. The reset control changed every persisted keyboard/mouse action, including profile actions not exposed on this page; its prior wording and outcome didn't disclose that full-profile scope.
2. The page exposes all **16** actions in `Model.LABELS`, but had no way to narrow the list by action ID/name/current binding, and no persistent summary of customized visible bindings.
3. Binding an occupied code correctly swaps mappings, including when that code belongs to a profile action not editable on this page. Conflict reporting only searched the 16 visible labels and could falsely omit the affected hidden action.

## Implemented

- The reset button now says **Reset all keyboard / mouse bindings**.
- Its tooltip/accessibility description explicitly says this resets every keyboard/mouse action, including command, cursor, and voice controls not displayed on this page.
- The success/failure note matches that full-profile scope.
- Added an inline, clearable search field. Case-insensitive trimmed query matches action label, stable action ID, or current physical key/button label. Typing only filters rows, retains search focus, and a no-results status offers a clear path back.
- Added a persistent count and rows for visible actions modified from their model defaults. Each changed row shows action label/ID, current binding, and default. The count/list refresh on binding changes and full reset.
- Changed a swap-report lookup across all `Model.DEFAULTS`, not just editable labels. A hidden affected action is explicitly identified by stable ID as “not editable here”; no dead route controls are exposed.
- After an intentional dropdown selection, focus is returned to that visible binding selector; typing in search does not move focus or alter bindings.
- Existing `reset_defaults()` behavior, defaults, preference format, unknown extension-field preservation, binding swaps, routing, and hint APIs are unchanged.
- Contract coverage exercises whitespace/case-insensitive search, no results, changed summary after a hidden-action swap and reset, and truthful hidden-action reporting. Native journey coverage now types into search and checks selector focus recovery after rebinding.

Reset remains full-profile intentionally: the model enforces unique physical mappings across the shared profile. Restoring only visible defaults could collide with a hidden action and implicitly move it, violating a promise that other contexts stayed unchanged.

## Verification

- Passed: `/tmp/opencode/fighting-core-grammar/bin/gdparse godot/input_bindings/service.gd godot/input_bindings/settings_panel.gd godot/tests/input_bindings/contracts.gd`
- Passed: `/tmp/opencode/fighting-core-grammar/bin/gdparse godot/input_bindings/settings_panel.gd godot/tests/input_bindings/contracts.gd godot/tests/input_bindings/native_journey.gd`
- Passed: `git diff --check`.
- GDScript contract and native GUI/keyboard-focus/input journey were authored but are **pending execution**. No Godot/editor/render/server invocation was performed under the source-only lane constraints.
- Native follow-up (in the project’s normal acceptance environment):
  1. Run `godot --headless --path . --script res://tests/input_bindings/contracts.gd`.
  2. Run `godot --path . --script res://tests/input_bindings/native_journey.gd -- --bindings-out=<evidence-dir> --bindings-control=<existing-control-url>` in the normal acceptance environment; verify screen-reader traversal of search/summary and full-reset wording.

## Packaging and remaining gaps

- No new resource/assets, scenes, imports, generated files, preference keys, or schema fields; no package/resource inclusion impact expected.
- Search and summary cover the existing 16 editable actions only; hidden routed contexts remain deliberately non-editable in this panel. Native keyboard-focus and assistive-technology evidence is pending.
