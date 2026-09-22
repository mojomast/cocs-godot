# Native combat overlay

Added a compact high-contrast aiming reticle, short gold confirmed-hit marks,
and a restrained red edge pulse for incoming damage. These are native Godot
draw calls with no external assets. The screen center remains clear. All controls
ignore mouse events, so capture and gameplay input continue through the overlay.

Hit/hurt indications reuse existing authoritative positive-damage event timers;
no hit is inferred from clicking/fire input. Aim reticle requires eligible captured
native controls and disappears on death, focus loss, stale snapshot or release.
Round cleanup clears transient feedback. Existing text feedback remains available.

Verification: existing `res://tests/protocol/combat_feedback.gd` passes all 13
checks and recorded replay (610 shots, 32 hits). `preview.png` was rendered and
directly inspected on owned private Xvfb; `render.json` records normal exit and
complete process-group cleanup. The preview deliberately combines synthetic
visual states and is not live gameplay evidence. Combined gameplay verification
is recorded separately after parallel feature integration.

Reproduce the visual fixture in a private graphical display:

```sh
"$GODOT_BIN" --path godot --audio-driver Dummy \
  --script "$PWD/port/tools/native_combat_overlay/render.gd" -- \
  --capture=/absolute/path/preview.png
```
