# Vehicle views and control audit

Branch `feature/motion-sol-vehicles` (base `94d4f5e6`). Native execution is awaiting the shared Godot runtime grant; GDScript grammar and `git diff --check` passed locally.

## Authority and input signs

- `game/vehicles.mjs` defines chassis forward `(sin(heading), cos(heading))` and increases heading for positive steer. `game/core.mjs` sets the driver's actor yaw to `heading - PI` on entry; both `game/race.mjs` and `game/soccer.mjs` project wire x/z against that actor yaw. Thus at heading zero, W must send `(x=0,z=+1)`, S `(0,-1)`, D `(x=+1,z=0)` and A `(x=-1,z=0)`. The existing `sports/controls.gd` projection produces those values; flipping it would reverse source throttle/steer. `combined_arms/controls.gd` inherits that packet. The new acceptance checks these signs through both real adapters.
- `game/vehicles.mjs:vehicleSeatPosition` uses +Z nose and rotates local offsets by heading. Source gunner aim / driver turret derive from actor yaw and pitch (`game/core.mjs:driveVehicle`, `gunnerVehicle`). Combined Arms now carries driver look yaw through chassis turns and uses the same aim vector in both view modes. The bridge remains an input/seat gate; source collision, steering, weapon and health values are untouched.

## Presentation ownership

- `sports/chase.gd` owns the camera pose for race, soccer and combined arms. It follows source chassis position, damps heading on the shortest arc and critically damps eye/aim with exact per-delta steps, bounds lag, immediately pulls in behind map obstruction, and snaps after a discontinuity. It never predicts vehicle movement from velocity. Reduced motion resolves immediately to the current source pose.
- P toggles chase and first-person while mounted (the reserved source third-person camera key). Cockpit eyes are offset above the seat/hood for Puma, Titan, Scout, Hornet and Transport; chase stays behind the +Z nose even in reverse. First-person uses current yaw/pitch for sight/shot direction, a bounded seat follow, and zero head bob / roll. Switch, round and mount boundaries discard spring momentum. Passenger and gunner have role-specific offsets.
- The route scenes reference the edited scripts: `sports/demo.tscn` → `sports/demo.gd`; `combined_arms/demo.tscn` → `combined_arms/demo.gd`. The separate `vehicles/demo.gd` is a synthetic static gallery, not an input acceptance route. `vehicles/renderer.gd` and `combined_arms/fleet.gd` remain the source-pose vehicle visual owners; no duplicate root camera interpolation was added there.

## Native verification when granted

Run from this worktree, without importing production assets into the published preview:

```sh
godot --headless --path godot --script res://tests/combined_arms/vehicle_views.gd
godot --headless --path godot --script res://tests/combined_arms/test_fleet_visuals.gd
```

Then inspect actual live local Puma race and soccer (`--map=ion-speedway` / `--map=aurora-stadium`) and combined arms (`--map=sunscar-convoy`) against an authorized local endpoint: W advances the front at heading 0 and PI/2; D increases heading; S reverses without flipping chase; P switches and returns without pop; pitch/yaw crosshair and projectile align from gunner/driver; a wall behind the hull pulls the chase eye forward; respawn, dismount, focus loss, reduced motion and ±PI yaw transition do not revive old camera momentum. The native acceptance script covers source signs, dt convergence, yaw wrap, reset, seat profiles and wall obstruction. Runtime route/scene path drift after integration should be reconciled against the current route scene bindings before live signoff.
