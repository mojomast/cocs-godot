# Compact vehicle HUD — source follow-up to parent review

Parent `1f129ab2` merged before this fix. **Source-only during scenery grant F**:
no Godot, Blender, import, render, authority, encoding or OS-input execution.

## Provenance and defect

The original `production-e/titan-ui150.png` is a real 760×520 native screenshot.
The journey fixture subclasses the production combined-arms demo, sets the public
UI-scale preference to 150, and captures its viewport. Its instructions are the
production `godot/combined_arms/hud.gd`, not a replacement fixture panel.
`godot/ui/local_settings.gd` applies `content_scale_factor` and supplies the
separate bottom-right F12 hint (last 27 logical pixels).

The HUD previously allocated a fixed lower 34% band beginning at 66% of logical
viewport height. Wrapped prompt/help text exceeded that band at compact UI150.
The scroll area also ended only 16 pixels above the bottom, intersecting F12's
27-pixel band. A scrollbar alone did not make the captured instructions readable.

**Only production path changed: `godot/combined_arms/hud.gd`.**

## Layout correction

- Uses measured wrapped VBox minimum heights, following existing campaign HUD
  responsive practice. Ordinary short top content frees height for lower actions.
- Anchors lower content above a 36-logical-pixel F12 safe area; a 12-pixel gap
  separates the upper source-status/objective and lower instruction regions.
- Remeasures after text, bindings, viewport or accessibility changes. Existing
  font sizes and user content scale are retained, and every instruction remains.
- Genuine overflow shares bounded regions and exposes an external navigation
  hint. Reuses `experience/scroll_keys.gd` for arrows/PageUp/PageDown/Home/End.
  Released-mode Tab focus cycles between the two visible regions. Recapturing
  clears text focus and returns both scroll offsets to the critical first rows.

## Verification and pending native gate

`node --test godot/tests/vehicle_assets/hud_layout.test.mjs`: **6/6 passed**.
The source-only tests execute the production numeric layout expressions with
supplied wrapped minima, including compact/wide, long objective, long controls,
64 resize/scale/content boundary combinations, and actual global-footer/focus
contracts. These supplied metrics are **not native font measurements**.

New `godot/tests/vehicle_assets/hud_layout.gd` is an unexecuted native check for
actual wrapped minimum sizes, unchanged scale, safe bounds and shared Home/End
navigation at compact UI150 and wide UI100. It does not construct a match.

Queued commands, **only after a new exclusive grant**, through the parent's
owned-process wrapper/nonwaiting lock:

```sh
"$GODOT" --headless --path godot --script res://tests/vehicle_assets/hud_layout.gd
python3 tools/godot-vehicle-assets/production.py journey --kind=titan --compact --granted --evidence-root "$NEW_EVIDENCE"
python3 tools/godot-vehicle-assets/production.py journey --kind=titan --granted --evidence-root "$NEW_EVIDENCE"
```

Native GDScript parsing, actual font/container measurements, released/captured
focus interaction and new screenshots remain pending. Keep the original E shot
as defect evidence; it is not relabeled as a fixed-native result.

## Packaging handoff

Parent packaging must assess/reconcile exactly **`godot/combined_arms/hud.gd`**,
a production dependency of the receipt-bound combined-arms demo. No vehicle
builder, asset, attachment, source physics, E receipt, original E screenshot or
package-pipeline file changed. Existing E asset acceptance remains historical;
this source HUD correction needs its own native review before acceptance.
