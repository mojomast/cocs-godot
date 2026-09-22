# Payload guidance plan

Baseline `e1defc0`; isolated branch `native-payload-guidance`. Read the primary
ACTIVE_LANES (including uncommitted reservations), audit `29b0a59`, objective
renderer/HUD/demo, progression fixtures and completion handoff before editing.

## Source contract

- `game/payload.mjs:149–180`: living actor, horizontal distance <= snapshot radius,
  vertical separation <= 5; attacker-only advances, defender-only rolls back at
  half speed to bank, both teams contest, no occupants idle. Released controls do
  not remove occupancy. `pushing=defender` can remain true at the checkpoint floor.
- `game/core.mjs:1310`: actual snapshot includes position, radius, distance,
  total, pushing, contested, delivered, progress, checkpoint counts; objective
  attacker/defender and zone distance/owner are public. No local completion guess.
- `godot/world/session.gd`: infantry camera uses Godot forward -basis.z and right
  basis.x, unlike the sports chase convention. Validate with real projection.

## Implementation

1. Objective-only pure presentation model: source coordinates/radius, clear
   unknowns, team role, contest/push/rollback/bank/delivery explanations.
2. Separate cart direction + horizontal distance + range row from explicitly
   labelled route progress. Use current camera basis, not remembered server yaw.
   Explicit released/dead context; distance never asserts local contribution.
3. Preserve CTF, scoreboard and controls. Responsive objective/status separation.

## Verification

- New geometry/projection and snapshot-state/unknown fixtures under guidance_*.
- Existing objective renderer 19, controls 11, progression HUD 33, queued-input
  timing; completion/progression replay tests and archived Payload replay.
- At most two normal-rate graphical runs <=120 s each, owned port-0 authority,
  private Xvfb with both listeners disabled and private XDG. Fresh 960x640 and
  1280x800 off-cart/approach/escort/release PNGs, opened directly. No injected
  state/time/physics. Reuse accepted ordinary native-input path where practical.
- Record exact runtime/source hashes, logs, failures, owned cleanup and limits.
  Fixture/projected synthetic evidence is explicitly separate from live states.

No shared files, source, launcher, package or root edits; no merge/push/deploy.
