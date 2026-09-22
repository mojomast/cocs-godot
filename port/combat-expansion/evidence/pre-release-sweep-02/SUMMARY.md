# Pre-release sweep, attempt 2 — engine teardown noise (not our content)

With `combat-actions` on a display the checks passed (**90/90**, exit 0) but the gate
runner still failed it because Godot printed two lines as the display process exited:

```
ERROR: Texture with GL ID of 20: leaked 87380 bytes.
ERROR: Texture with GL ID of 21: leaked 87380 bytes.
```

Diagnosis before changing anything:

- A **bare** display session that quits immediately prints **no** such line.
- A display session that creates the shared session/combat visuals **without**
  capturing the pointer prints **no** such line (lead probe, three teardown variants).
- `87380` bytes is consistent with the 128×88 RGBA cursor images the X11 display
  server creates for pointer capture, and the same two lines appear in the only other
  display run that captures the mouse.

Conclusion: Godot's GLES3 reports its own pointer-capture cursor textures as leaked at
shutdown. It is engine teardown behaviour, not a content leak, and it is invisible in
headless runs.

Handling, chosen to keep error detection strict rather than blanket-ignore `ERROR:`:

- `tools/godot-dev/gate_runner.py` now accepts an optional `success_marker` plus
  `allowed_error_patterns`. Noise is tolerated **only** when the gate exits 0, prints
  its own success marker, and the line matches one of the declared patterns.
- `combat-actions` declares `NATIVE_COMBAT_ACTIONS` and the exact cursor-texture regex
  `^ERROR: Texture with GL ID of \d+: leaked \d+ bytes\.$`.
- Negative controls verified: a run containing any other `ERROR:` line still fails; a
  run whose marker is absent still fails; a run containing only the declared line plus
  the marker passes. All other gates keep the original strict behaviour.

Retained because it records the measurement that justified the allowance.
