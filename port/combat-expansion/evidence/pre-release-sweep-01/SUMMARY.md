# Pre-release sweep, attempt 1 — failed at `combat-actions` (real defect)

`combat-actions` was registered headless, but the fixture asserts real pointer
capture: in a headless run Godot's dummy display server ignores
`MOUSE_MODE_CAPTURED`, so `combat_controls_active()` was permanently false and ADS
could never latch. 18 of 90 checks failed.

This was a harness defect, not a gameplay regression: the same fixture passes
**90/90** under a private owned display. `combat-actions` now runs through
`tools/godot-dev/xvfb_run.py`, the same owned-display wrapper used by
`first-person-binding`. An audit of every registered gate for pointer-capture usage
while headless found only one other candidate (`objective-controls`), which passes
both with and without a display and therefore needs no change.

Retained because it documents that the gate had never actually executed since it was
registered.
