# Overnight Luna controls/settings lane

## Audit findings

Reviewed `godot/input_bindings/{model,service,settings_panel,mapper,hints}.gd`, the local-settings panel wiring, and input-binding contract/native-journey tests.

Three concrete usability gaps:

1. The settings page displays six actions, but its reset button reset *all* persisted keyboard/mouse actions, including hidden command, cursor, voice, and tactical controls. The scope was not apparent from the button or outcome message.
2. Rebinding a key already assigned elsewhere intentionally swaps the two actions. The current status message reports that swap, but conflict visibility is transient; there is no persistent overview/search for all editable contexts. This lane leaves that larger cross-context UI unchanged.
3. The page supports keyboard focus on binding selectors and descriptive labels, but reliable post-selection focus recovery and screen-reader traversal need native keyboard/assistive-technology validation. No speculative focus changes made.

## Implemented

- The reset button now says **Reset all keyboard / mouse bindings**.
- Its tooltip/accessibility description explicitly says this resets every keyboard/mouse action, including command, cursor, and voice controls not displayed on this page.
- The success/failure note matches that full-profile scope.
- Existing `reset_defaults()` behavior, defaults, preference format, unknown extension-field preservation, binding swaps, routing, and hint APIs are unchanged.
- Contract coverage asserts the reset control communicates that its scope includes hidden contexts; existing persistence tests continue to exercise whole-profile reset and compatibility.

The tempting “reset only the six visible actions” change was rejected: the model enforces unique physical mappings across the shared profile. Restoring visible defaults could collide with a hidden action and implicitly move it, violating the promise that other contexts stay unchanged.

## Verification

- Passed: `/tmp/opencode/fighting-core-grammar/bin/gdparse godot/input_bindings/service.gd godot/input_bindings/settings_panel.gd godot/tests/input_bindings/contracts.gd`
- Native GUI/keyboard-focus/input journey: **pending**. No Godot/editor/render/server invocation was performed under the source-only lane constraints.
- Native follow-up (in the project’s normal acceptance environment):
  1. Run `godot --headless --path . --script res://tests/input_bindings/contracts.gd`.
  2. Run the existing `godot/tests/input_bindings/native_journey.gd` flow with its normal `--bindings-out` and `--bindings-control` arguments; test reset copy with a screen reader and verify visible selector focus remains usable after apply.

## Packaging and remaining gaps

- No new resource/assets, scenes, imports, generated files, preference keys, or schema fields; no package/resource inclusion impact expected.
- Persistent cross-context binding search/overview and native focus/assistive-technology evidence remain follow-up usability work.
