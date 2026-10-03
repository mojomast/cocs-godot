# Vehicle views and control audit

Branch `feature/motion-sol-vehicles` (base `94d4f5e6`, merged parent `65aeaeb2`). Native execution is awaiting the shared Godot runtime grant; GDScript grammar, source-kinematics Node check and `git diff --check` passed locally.

## Authority and input signs

- `game/input.mjs:controlsFromState` is the canonical key → world-axis mapping: `x=-sin(yaw)*forward+cos(yaw)*right`, `z=-cos(yaw)*forward-sin(yaw)*right`. At a +Z-facing vehicle, source actor yaw is `heading-PI`; W sends `(0,+1)`, S `(0,-1)`, **D `(-1,0)`**, A `(+1,0)`. Looking +Z, screen-right is **-X**. `game/race.mjs` / `game/soccer.mjs` decode these as throttle `-x*sin(yaw)-z*cos(yaw)` and steer `-x*cos(yaw)+z*sin(yaw)`; D yields negative steer and decreases heading toward screen-right. `game/core.mjs:driveVehicle` uses the same negative-right steer projection. The corrected sports and world-session adapters match web input at all cardinal yaws and preserve full independent W+D axes; combined arms inherits the sports packet. `node port/finish/motion/vehicle_signs.mjs` evaluates the checked-in native expressions against actual `controlsFromState` and `stepVehicle` without an engine run.
- `game/vehicles.mjs:vehicleSeatPosition` uses +Z nose and rotates local offsets by heading. Source gunner aim / driver turret derive from actor yaw and pitch (`game/core.mjs:driveVehicle`, `gunnerVehicle`). Combined Arms now carries driver look yaw through chassis turns and uses the same aim vector in both view modes. The bridge remains an input/seat gate; source collision, steering, weapon and health values are untouched.

## Presentation ownership

- `sports/chase.gd` owns the camera pose for race, soccer and combined arms. It follows source chassis position, damps heading on the shortest arc and critically damps eye/aim with exact per-delta steps, scales the boom gently with finite source speed, bounds lag, immediately pulls in behind map obstruction, and snaps after a discontinuity. It never predicts vehicle movement from velocity. Reduced motion resolves immediately to the current source pose.
- F4 toggles chase and first-person only while mounted (P is a reserved spectator/command key). Settings → **Vehicle camera** persists `third` (default) or `first` via `local_settings.gd`'s explicit allowlist, and mode switches update this setting. Cockpit eyes are offset above the seat/hood for Puma, Titan, Scout, Hornet and Transport; chase stays behind the +Z nose even in reverse. First-person uses current yaw/pitch for sight/shot direction, bounded seat follow and no head bob / roll. Switch, round and mount boundaries discard spring momentum. Passenger and gunner have role-specific offsets.
- Routes: `sports/demo.gd` (Ion/Aurora), its generated `multiplayer_worlds/sports_demo.gd` derivative (Sirocco/Copper), `combined_arms/demo.gd` (Sunscar), and the general `world/session.gd` mounted branch (including multiplayer world session subclasses). `world/session.gd` bypasses infantry `local_motion` for mounted actors; only the presentation render clock advances the vehicle camera rig, while the merged infantry source-time/velocity predictor remains intact for on-foot actors. `first_person/session_binding.gd` owns FOV and hides its weapon while mounted; the vehicle rig writes only pose, never FOV. `vehicles/demo.gd` is a static visual gallery. Renderers keep the source vehicle root pose without a second camera interpolation.
- The rig's render-owned pose and discontinuity snap follow Godot's [advanced physics interpolation guidance](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/advanced_physics_interpolation.html); the chase obstruction is a bounded ray/semantic-box pull-in analogous to [SpringArm3D](https://docs.godotengine.org/en/stable/classes/class_springarm3d.html), with the existing source map boxes rather than vehicle collision authority.
- Generator check currently passes its sports derivative and then reports **`Stale LATTICE scene derivative`** at `tools/godot-multiplayer/generate-scenes.mjs:82`, unrelated to this lane. The generated LATTICE file was restored to the parent version; parent should reconcile that pinned derivative separately.

## Native verification when granted

Run from this worktree, without importing production assets into the published preview:

```sh
node port/finish/motion/vehicle_signs.mjs
godot --headless --path godot --script res://tests/combined_arms/vehicle_views.gd
godot --headless --path godot --script res://tests/combined_arms/test_fleet_visuals.gd
node tools/godot-multiplayer/generate-scenes.mjs --check
```

Then inspect live Puma race and soccer (Ion/Aurora and Sirocco/Copper), combined arms (Sunscar), and a general world-session mounted seat against an authorized local endpoint: W advances the front at heading 0 and PI/2; D decreases heading and moves toward screen-right; S reverses without flipping chase; F4 switches and returns without pop; selected view persists after restart; pitch/yaw sight and projectile align from gunner/driver; a wall behind the hull pulls the chase eye forward; respawn, dismount, focus loss, reduced motion and ±PI yaw transition do not revive old camera momentum. The native acceptance script covers source signs, dt convergence, yaw wrap, reset, seat profiles and wall obstruction. Runtime scene path drift after integration should be reconciled against the current route bindings before live signoff.
