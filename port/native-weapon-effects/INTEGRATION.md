# Native weapon effects integration

Owned files: `godot/weapon_effects/**`, `godot/tests/weapon_effects/**`, this directory. Source game modules are read-only. No combat/projectile/session/first-person edits are included.

## Binding the ADS rig

```gdscript
const WeaponEffects = preload("res://weapon_effects/controller.gd")
var weapon_effects: Node3D

# After first_person.attach_to(source_camera):
weapon_effects = WeaponEffects.new()
add_child(weapon_effects)
weapon_effects.attach_rig(first_person)
# attach_rig sets external_muzzle_fx=true to suppress the old opaque sphere.
# It reads the ADS agent's animated anchors["Muzzle0"], ["Muzzle1"], ...

# REQUIRED on original mesh-only maps: callback returns true if this segment
# intersects source/semantic solid geometry, false only when known clear.
weapon_effects.configure_occlusion(Callable(semantic_geometry, "segment_blocked"))
# On maps whose source solids all have corresponding native collision bodies:
# weapon_effects.physics_occlusion_enabled = true
# weapon_effects.collision_mask = 1  # world solids only, never cosmetic actors

# After latest public actor state and first-person eligibility were applied:
weapon_effects.consume(events, local_id, public_actors)

# Quality 0 = disabled, 1 = muzzle + authoritative tracers, 2 adds smoke/heat/case.
weapon_effects.set_quality(2)
# On authoritative start/results/disconnect, before accepting reused wire IDs:
weapon_effects.reset()
```

The controller deliberately fails closed for local cues until a semantic callback is supplied or a collider-backed world explicitly opts in. The callback signature is `(from: Vector3, to: Vector3) -> bool`; null/unknown results are blocked. It checks camera→visible tip and tip→short authoritative convergence point, including on subsequent animation frames. Source eye-origin blocked-barrel shots suppress the local flash and tracer. Remote shots retain exact source `from`/`to`; no fake remote muzzle anchor is invented. Replace the old `combat_feedback.gd` diagnostic shot line path with this consumer, rather than drawing both. Large explosions and projectile trails remain the combat-particles agent's responsibility.

If adapting a different rig, `configure(source_camera, muzzle_provider)` accepts a no-argument Callable returning:

```gdscript
{
    "visible": true, "actor_id": local_id, "weapon": weapon_id,
    "camera": isolated_weapon_camera,
    "muzzles": [animated_muzzle_node_0, animated_muzzle_node_1],
    "ejection": optional_authored_ejection_port_node,
}
```

Effects are children of these actual `Node3D` anchors in the isolated SubViewport, so recoil/ADS/barrel motion moves the flash. The adapter recognizes optional `anchors.Ejection`; no fake default ejection position is used. Current authored rigs without that anchor omit casings. Profiles enable casings only for pulse rifle, marksman and SMG; break-action/energy/explosive launchers do not invent ejection.

## Projectile handshake (lead-owned integration)

```gdscript
var visual := weapon_effects.resolve_launch_origin(launch_event, local_id)
if not visual.is_empty():
    # Cache against the authoritative launch/projectile identity at reception.
    # visual.position is a cosmetic world projection of the animated visible tip.
    # Blend a render marker from this toward public snapshot positions over a
    # short presentation-only interval (e.g. <= 0.08 s), checking the segment
    # with the same geometry callback. Never write launch.pos or snapshot.pos.
    projectile_presentation.remember_visual_origin(launch_event, visual.position)
```

The last call above is a suggested lead-owned API, **not an implemented projectiles method**. `resolve_launch_origin()` and the returned dictionary are implemented here. Empty means hidden/mismatched/out-of-bounds/occluded; use no local offset. Lead must preserve the source launch association rules (primary launch event IDs are not automatically projectile IDs). No projectile/damage simulation is implemented by this lane.

`origin.gd::map_tip` maps viewmodel-camera depth and normalized screen projection through the source Camera3D projection; it supports differing viewport dimensions/FOV and camera offsets. Returned fields include `position`, `pixel`, `depth`, `projection_error_px`. `resolve` adds `join` and the unchanged `endpoint`. Bounds: view-space depth 0.03–4 m, distance ≤5 m, normalized viewport coordinate within a 10% margin, source visual distance ≤6 m, authoritative origin within 8 m of current camera. These are cosmetic validation bounds, **not source barrel dimensions**.

## Source authority audit

`game/core.mjs:1053–1059` aims from `eye(a)`, selects the eye-ray goal, computes `muzzle = eye + side*0.24 + direction*0.42; muzzle.y -= 0.24`, checks eye→source muzzle, then source muzzle→goal. Primary public `shot.from` and `launch.pos` are already this source muzzle. On `muzzleBlocked`, source emits a short eye-origin shot to the blocking point and applies no damage. Alt-fire around 1092–1114 uses the same mechanism. `shot.hit` may preserve a candidate behind blocked geometry and **is not damage confirmation**.

This lane changes only visual origin/convergence. The visual isolated viewmodel muzzle is not claimed to coincide with that source simulation origin. Endpoint geometry is never moved. `shot.to` is retained byte-for-value as parsed Vector3 values. Marks/sparks require explicit `surface_hit: true` and a finite unit `normal`; current source lacks normals, so normal source events produce none. Shrapnel produces no muzzle flash. No predicted shots, guessed hits, damage callbacks, or disappearance explosions.

## Profiles, Moth, budgets

All ten source-ordered profiles have independent shape/timing/size: pulse petals, axial rocket jet, rail discharge ring, twin shotgun petals, plasma bloom, grenade puff/jet, shock corona, flak starburst, marksman burn flash, compact SMG flash. Quality 2 adds fading smoke and heat rings. Launcher jets use barrel-local crossed cards plus facing bloom. Materials use soft alpha, not opaque spheres or frame rectangles, and work in GL Compatibility. No lights are allocated.

Optional `configure_moth(provider)` requests semantic keys `pulse`, `plasma`, `shock`; provider returns `{frames: Array[Texture2D], fps: number}`. Alias these to approved existing library assets in the integration; no dependency on an external pulse preview is introduced. Opaque black Moth pixels get luminance-derived soft alpha and an edge taper. Missing sheets use procedural profiles. Maximum 32 frames per sheet.

Hard budgets: 64 effect slots/meshes/materials, 128 world line slots/meshes/materials, zero lights, 4096 dedup records, 512 events/actors scanned per call. Slots reuse resources, replace oldest on overflow, expire without allocations, and reset frees even externally parented rig children. Numeric event ID + time + owner dedup; owner/weapon/time volley grouping keeps all pellet endpoint lines but one flash per barrel. Hidden events are still consumed to prevent replay. Invalid/false/dead/hidden/spectating/vehicle actors are suppressed.

## Verification

Pinned engine: `/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64`.

```sh
$GODOT --headless --path godot --script res://tests/weapon_effects/lifecycle.gd
$GODOT --headless --path godot --script res://tests/weapon_effects/rig_integration.gd
node port/native-weapon-effects/source-events.mjs
HOME=/tmp/opencode/weapon-effects-home TMPDIR=/tmp/opencode LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s '-screen 0 1400x1000x24' "$GODOT" --path godot --rendering-method gl_compatibility --script res://tests/weapon_effects/framing.gd -- --evidence-out="$PWD/port/native-weapon-effects/evidence" --source-events="$PWD/port/native-weapon-effects/source-events.json"
```

Framing evidence labels static catalogue-anchor poses and an **ADS-like stub**, not a production ADS test. All ten exported chassis are rendered at 960×640 and 1280×800 in both poses. Measurements are actual projected visible-tip versus world-line-start pixel errors, and actual retained endpoint deltas; no simulated-origin equivalence is asserted. Source-event probes replay real unmodified `Match.fire`/`Match.step` output for pulse and SMG at source simulation cadence; they are not a live network-session capture.

`rig_integration.gd` separately binds the **actual production ADS rig** and verifies all ten weapons in hip/ADS while the authored muzzle moves under recoil. Its observed maximum projection error was `0.00001206 px`; source endpoints were unchanged. Lifecycle tests additionally cover semantic-only occlusion, unknown callback fail-closed, blocked-source eye rays, real physics wall occlusion, supplied-port casing eligibility, validated-normal marks, ID eviction/restart, pellet grouping, hidden/dead actors and pool stress (2299 volleys).

`moth_coverage.gd` runs in graphical GL Compatibility with an explicitly synthetic opaque-black Moth-format frame. Observed input black alpha `1.0` becomes output edge/corner alpha `0.0`; luminous center alpha is `0.94901961`. This is a shader-contract test, not an external-preview asset claim. Run it with the same graphical command as framing, changing `--script` and omitting `--source-events`.

`evidence/` includes 40 two-size/two-pose weapon renders, 30 additional animation ages (45/120/300 ms), two real source-event replay images, a near-wall semantic-geometry image, and the transparent Moth coverage render. `res://tests/weapon_effects/contact_sheet.gd` runs headless with the same `--evidence-out` argument, assembles contact sheets from these real rendered PNGs and writes measured maxima to `evidence/summary.json`. Static fixtures do not include a fabricated casing port; the conditional authored-port behavior is covered by the lifecycle test.

Final recorded framing results: 40 cases, maximum visual-tip mapping error `0.00006103515625 px`, maximum world-tracer start error `0.00006823938019806 px`, and maximum authoritative endpoint change `0 m`. Near-wall fixture spawned zero flashes and zero tracers. Real source replay: pulse 18 source shots / 18 rendered volleys / 18 tracers; SMG 30 / 30 / 30. All tests used pinned Godot 4.5.2; graphical runs used GL Compatibility on Mesa llvmpipe in a private Xvfb session.
