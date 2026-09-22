# Native ADS integration contract

`godot/first_person/rig.gd` remains presentation-only. Call after `attach_to(camera)`:

- `apply_actor(actor: Dictionary, can_show: bool)`: existing visibility/lifecycle/snapshot authority. Hidden/dead/spectating/in-vehicle actors reset ADS immediately. Source `reloading`, `sprinting`, or positive `weaponSwitch` blocks ADS.
- `apply_aim(active: bool, weight: float = 1.0) -> bool`: independent local presentation request (no snapshot ADS field required). Weight is a **target** blend in [0,1], not instantaneous progress. Returns whether the request was accepted; reload/hidden states return false. Reapply each frame from the session's already-gated aim intent. Switch lowering temporarily blocks blending in.
- `get_aim_state(base_fov: float = 75.0) -> Dictionary`: `active`, `weight` (animated progress), `ready`, `kind`, `magnification`, `fov` (recommended current source-camera FOV). No camera or input writes. FOV follows source `reticle.mjs` policy; pass the unzoomed base, never last frame's zoomed FOV.
- `get_muzzle_world_transform(index: int = 0) -> Transform3D`: animated barrel-tip pose mapped from the isolated weapon viewport through the source camera's **camera transform**. `-basis.z` is physical barrel direction, not the ballistic convergence ray. Only consume when `showing` is true and `get_muzzle_count() > 0`; invalid/hidden requests return `Transform3D.IDENTITY`.
- `get_muzzle_screen_position(index: int = 0) -> Vector2`: matching source viewport pixel coordinate; invalid/hidden returns `Vector2(INF, INF)`. Scattergun has two indices; all other weapons have one.
- `get_muzzle_count() -> int`: zero when hidden.
- `get_sight_screen_positions() -> Dictionary`: `rear`, `front`, `optic` projected live anchors (empty while hidden).
- `external_muzzle_fx: bool = false`: set true when the separate FX implementation owns flash rendering, to suppress the rig's fallback flash.

The passive `session_binding.gd` calls `session.aim_requested() -> bool` when provided (then legacy `weapon_aim_active()`, boolean `session.aiming`, or `local_actor.aiming`/`local_actor.ads` fallbacks). Visibility/lifecycle gates, `can_capture_pointer()` and actual captured mouse mode always apply first. `weapon_controls_active()` is deliberately not a visibility gate: Arms Race disables weapon selection but still displays its weapon. Binding exposes `get_aim_state(base_fov)` and delegates muzzle APIs for shared integrations. Session owns applying recommended FOV and HUD reticle policy. Direct rig users (combined arms/new arenas) call `apply_actor` then `apply_aim` themselves.

The rig does not accept input, aim the gameplay camera, alter spread/damage, or originate authoritative shots. FX should converge from the returned barrel tip toward the source shot's aim/hit point according to the existing source event contract.
