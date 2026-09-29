# External compact live HUD probe

Run `python3 tools/godot-package/compact_verify.py --package /absolute/extracted/cocs-native-linux --output /absolute/new/evidence-directory`.

This starts the actual release binary with its unchanged PCK and an external
read-only SceneTree observer. The packaged options parser selects the real
Assault/Sunscar and Uplink/Meridian scenes and normal arguments. The authority
is the artifact's ordinary `createGameServer`, with no state injection or cheats.
Private Node-only PATH, Xvfb, ALSA null sink, settings, and user directories keep
the run isolated. The observer waits for three actual phase-3 snapshots with a
received local pose, advancing source time, a non-stale session, the 760x520
window, and two post-draw frames. PNGs contain the actual rendered viewport.
HUD rectangles are converted from logical coordinates to physical screenshot
pixels (UI scale 150 gives a 506.67x346.67 logical viewport).

The runtime assertions establish **live capture**, not visual acceptance.
Inspect the PNGs for overlap, truncation, and legibility. JSON contains source
state, local actor, phase, snapshot count, objective label text/rectangles,
settings scale, launch arguments, and unchanged binary/PCK/manifest hashes.

## Final 8ba6371b release observation (2026-09-29)

`compact-live-final-3` established live snapshots on the final package. Manual
review found product layout defects at 760x520 / UI 150:

- Assault: the shared combat-quality line overprints the objective's attack/
  defend drain row; the session/control block extends below the screen.
- Uplink: the objective panel overlaps health/weapon panels; bottom controls
  collide with the click-to-play panel and extend below the screen. Objective
  title, relay progress, neutral hill status, and capture instruction are live.

Scope for a parent-authorized fix: responsive Assault HUD composition plus
shared zone/status/vitals/control layout at compact scaled viewport sizes.
No production files are changed by this probe. Preserve previous failed or
waiting-state screenshots; create a new evidence directory for each run.

## Responsive-layout verification

Use `--strict-layout` to require separate, in-bounds objective, top, vitals,
weapon, controls, and Settings-hint regions. The observer records every visible
region in physical pixels as well as essential label text. Optional quality
help is included in overlap checks if visible. Direct PNG review is still
required to assess legibility.

The same probe accepts `--width 1280 --height 800 --ui-scale 100` for desktop
verification. For development only, `--engine /absolute/Godot --project godot`
runs source scenes against the package's unchanged ordinary authority and
options parser. Its summary explicitly identifies **development source
project**, not release-PCK verification. The final rebuilt PCK must subsequently
pass the default release invocation at both sizes.

The responsive product patch uses `res://ui/objective_hud.gd` for zone and
Assault presenters. Compact layout is based on the **logical** viewport, with
measured panel heights and a two-column health/equipment row. It keeps source
objective/rule/time text, disables only the optional combat-quality startup
hint, and reserves the existing single Settings hint. Desktop retains expanded
controls and full-size vitals. No source state, scoring, timer, or input logic
is changed.

Development verification: both actual source scenes against ordinary packaged
authority, at 760x520/UI150 and 1280x800/UI100; strict visible-region bounds and
non-overlap assertions plus direct PNG review. Focused existing regressions:
game HUD normal/setup/debug, scoreboard model/session/objective ranking,
objective key-release timing, zone model/variants, Assault state, and seven
objective-routing/Assault-composition Node assertions. Final release acceptance
still requires rebuilding and running this same probe against the new PCK.
