# Muzzle alignment handoff

The authoritative shot ray, hit, spread, damage, projectile state, and launch
position remain source-owned. The native effects controller projects the
animated first-person `MuzzleN` nodes from its isolated viewport into the
source camera at the authoritative muzzle's *depth* (not the enlarged
viewmodel's depth), starts cosmetic tracers there, and joins the untouched public
shot ray. For projectile launches, the existing `world/projectiles.gd`
handshake interpolates the marker from the resolved visible muzzle toward
authoritative samples, never changing those samples. SightRear/SightFront are
coaxial with the settled ADS crosshair; the barrel is necessarily below the
sight at short range and cosmetic trajectories converge on the source ray.

For third-person actors, `weapon_effects/controller.gd` now accepts
`configure_remote_muzzles(Callable(actor_id, weapon_id) -> Node3D)`. The node
must be the visible actor's exported world weapon `Muzzle` anchor; remote
tracers follow it through animation and fail closed behind cover.
`godot/world/combat_feedback.gd` now supplies this callback: it resolves the
visible actor from `presentation.actors`, checks the exported weapon and its
type, and returns the animated `Muzzle` anchor. Missing or mismatched models
retain the public-origin fallback. The `combat-remote-muzzle` gate checks the
lookup and its fail-closed cases. This does not change the source shot ray.

Lightweight checked: all ten generated sight pairs are coaxial and every
catalogued MuzzleN is bound to a moving barrel assembly; `git diff --check`.
After integration the Godot import, both new geometry suites (263 and 279
checks), the existing weapon lifecycle/rig suites, and the full aggregate
passed, run serially. The commands below reproduce the targeted checks:

```sh
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
"$GODOT_BIN" --headless --path godot --editor --import
"$GODOT_BIN" --headless --path godot --script res://tests/first_person/muzzle_geometry.gd
"$GODOT_BIN" --headless --path godot --script res://tests/weapon_effects/muzzle_path_geometry.gd
"$GODOT_BIN" --headless --path godot --script res://tests/weapon_effects/rig_integration.gd
"$GODOT_BIN" --headless --path godot --script res://tests/weapon_effects/lifecycle.gd
"$GODOT_BIN" --headless --path godot --script res://tests/weapon_effects/projectile_flight.gd
```
