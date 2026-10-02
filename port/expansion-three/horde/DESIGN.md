# Blackwater mission guidance and ordinary-input journeys

Status: **READY FOR ENGINE**. No Godot, Blender, import, rendering or export was
run in this lane. Engine parsing, layout inspection and native journeys await an
explicit grant. Branch `expansion-three/horde`, starting at `27cfaa14`.

## Player-visible changes

- `godot/horde/mission_guidance.gd` projects received mission state only. An active
  repair outranks a nearer available station; otherwise the nearest available
  station is shown. It distinguishes availability, restoration, completion and
  dependency/wave locks, and explains the 5m arm / 6.5m defend ranges, grounded
  requirement, retained progress and tap-E interaction.
- Blackwater signs now expose locked machinery and its actual prerequisite.
  Cyan available / amber defending / green completed / grey locked states have
  textual labels. Non-colliding 6.5m rings show defend areas. They do not steer,
  aim, teleport, activate or advance anything.
- Route text shows source sector and both actual gate-mask states, including
  warning/open transit guidance. Station completion says to finish the waves,
  not that the mission was won.
- Upgrade choices now show source descriptions directly, keep existing 1–9 and
  click actions, and retain single-flight/refusal/confirmation behavior. A bounded
  scroll area follows keyboard focus; unchanged offers retain their button nodes.
- Blackwater uses a small-viewport HUD subclass, compact mission text, and a
  mission position below live connection/status warnings. Vitals and reload
  state remain visible. Both 1280×800/UI100 and 760×520/UI150 need rendered review.
- Corrected a misleading reward claim: the south feeder's real restoration
  receipt has `pickupId:null`, so it must not promise a refreshed supply cache.
  All restored systems say SYSTEM ONLINE; CACHE REFRESHED requires a non-null
  receipt pickup ID. No reward/map rule was changed.

## Ownership and integration

Runtime changes are confined to Horde and Blackwater HUD/sign composition. New
runtime imports are `godot/horde/mission_guidance.gd` and
`godot/horde/compact_hud.gd`. Parent owns package closure/export registration.
No robot visual assets, map recipes, authority adapters, frozen source files,
source pins, difficulty, ammo, damage or transport rules were edited.

Test scenes are under `godot/tests/horde_expansion/` and must remain excluded
from production exports. Node runners are under this directory. They allocate
unique attempt directories and never replace historical evidence.
