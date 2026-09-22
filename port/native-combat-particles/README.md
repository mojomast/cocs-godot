# Native in-world combat particles

Integration entry point: `res://combat_particles/manager.gd` (`Node3D`). This lane owns large explosion debris/spark-shock/dust, persistent rocket/plasma/grenade exhaust, and reactor/ice/cinder weather. Muzzle flashes, beams, tracers, and tiny hit feedback belong to the weapon-effects lane.

## Session wiring

```gdscript
const WorldParticles = preload("res://combat_particles/manager.gd")
var world_particles := WorldParticles.new()

# After the normal world and camera exist:
add_child(world_particles)
world_particles.configure(camera, map_id) # catalog original map

# For a built native arena, supply the actual collision root and arena bounds:
world_particles.configure(camera, {
    "id": "cinder-array",
    "bounds": AABB(Vector3(-92, -2, -82), Vector3(184, 87, 164)),
    "collision_root": map_node,
})

# Authoritative public callbacks (not interpolated/predicted visual entities):
world_particles.apply_state(frame.state, client.actor_id)
world_particles.consume(items, client.actor_id)

# Authoritative start/reset, results, disconnect, map replacement:
world_particles.reset()
# Results states also reset automatically. An 0.8s public-state watchdog drains.

# Existing menu/F9/settings owner binds these. This manager binds no input:
world_particles.set_quality("Low") # also "High", "Extreme"
world_particles.set_paused(menu_paused)
var diagnostics = world_particles.snapshot()
```

`configure(camera, AABB)` is supported for custom geometry integration; without a semantic map or `collision_root` it knows only the boundary. Check `collision_shapes` in its result (voxelized box/triangle primitive count, not native node count). Native string IDs discover only the authored map subtree in the current scene so dynamic actors do not become frozen obstacles; explicit `collision_root` is preferable, especially in script-based harnesses. For offline native exploration only, call `set_active(true, false)` to activate ambient fields without a network watchdog. Public `apply_state` activates automatically. Quality changes preserve the existing 32 GPU node, shader, and shared draw-resource identities and resize their buffers in place.

### Quality and diagnostics

| Level | Original arenas | Native `prism-foundry`, `aurora-basin`, `cinder-array`, `lattice`, `lattice-world` |
|---|---:|---:|
| Low | 8,192 | 8,192 |
| High (default) | 32,768 | 131,072 |
| Extreme (explicit selection) | **1,000,000 total** | **1,000,000 total** |

The pool partitions 20 burst slots, 8 persistent trails, and 4 weather quadrants. The total allocation is shared across **all 32 emitters**, never one million per explosion. Idle nodes are hidden, stopped and speed-zero; their allocated capacity is reported separately. `draw_slots` means submitted GPUParticles capacity; no GPU readback is claimed. Transparent, expired, solid-born, frustum/depth-occluded particles do not imply visible pixels. The shader keeps active slots stateful and recycles continuous fields; CPU work only visits bounded emitters/events, never particles.

`snapshot()` includes allocation, submitted slots, active emitters/draw passes, shared resources, collision atlas bytes/shape counts, lifecycle, dedup/drop/recycle counters, and last actual event ID/position and projectile ID. GLES3 estimated process/instance payload is 320 bytes per allocated slot (320 MB decimal at Extreme), plus the shared 442,368-byte occupancy atlas, excluding driver overhead. This is a source-derived estimate, not measured VRAM usage. RD uses real GPUParticles compute but this estimate is specifically labeled GLES3.

### Source correspondence and boundaries

- `game/core.mjs:1155` emits `explosion {pos, weapon}`; this has **no owner** in the common path. The exact position is used; no fictitious local attribution is inferred. Weapon 4 is plasma, weapon 1 rockets, weapon 5 grenades (`game/weapons.mjs`). `detonate` also emits `explosion` with optional metadata. `vehicle-destroyed {pos, actor}` is accepted.
- Only authoritative `state.rockets` IDs/owners/positions/directions create trails. Missing IDs let old exhaust fade and never synthesize an explosion. Large position discontinuities do not interpolate long trails.
- Up to 512 events/rockets are inspected per callback. A 4,096-ID window rejects duplicate and too-old events. Local projectiles receive first refusal; nearer/front-camera effects outrank distant/rear ones. Burst priority decays as its energy fades; active authoritative trail priority is refreshed. Pools recycle the least-priority/oldest slot rather than growing or queueing.
- Original semantic blocks/support triangles, native authority triangle-list surfaces, or native collision shapes rasterize once into a 96×48×96 voxel atlas. GPU bounded axis sweeps prevent voxel tunneling; ordinary scene depth testing remains on. This is presentation collision, not gameplay authority. Surface voxel shells preserve air beneath bridges; sub-voxel details are an approximation. Box and convex/sphere/cylinder/capsule bounding volumes are conservative and can over-clip ramps/rounded corners. Concave triangles are sampled at half-cell spacing. Unsupported collision types are counted explicitly. A source embedded in a solid voxel is suppressed for that particle life rather than guessing the side of the wall. Native string IDs read matching native-authority metadata if present, then inspect the current scene's collision shapes; explicit roots remain preferable.
- Weather quadrants are fixed in world coordinates within map bounds: cinder on ember/cinder/sunscar, ice on aurora/tidal, muted reactor motes otherwise. Particle colors use a shared Moth flow texture in a small depth-tested alpha draw material, not large additive screens. Particle size/opacity decrease the dense-field coverage impact; near-camera fade preserves POV readability.
- There is no shader `TIME`. Pause, hidden ancestors, focus loss and SceneTree pause set GPU speed zero and stop CPU age advancement. Public-state staleness/results/reset drain the effects; a backwards authoritative time also resets the round.

Set `ambient_enabled = false` before activation when the host owns a separate weather presentation. It does not remove already active fields; follow with `reset()` and the next authoritative snapshot when changing this at runtime.

## Owned verification

```sh
GODOT=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
"$GODOT" --headless --path godot --script res://tests/combat_particles/contracts.gd

# Existing display or a private Xvfb; no lab scene is involved:
"$GODOT" --path godot --rendering-method gl_compatibility \
  res://tests/combat_particles/replay.tscn -- --quality=Extreme \
  --output=/absolute/path/to/evidence/extreme-1280
# Add --small for 800×600, --baseline for the same arena without particles.

# Fully automated serial baseline/High/Extreme matrix, both actual resolutions:
python3 port/native-combat-particles/measure.py

# Native map collision extraction and default-budget contract:
"$GODOT" --headless --path godot --script res://tests/combat_particles/native_geometry.gd

# Rendered wall negative control + visible-front positive control:
"$GODOT" --path godot --resolution 320x240 \
  res://tests/combat_particles/occlusion.tscn -- --output=/absolute/path/to/occlusion

# Ordinary source server + independent public-only observer (separate terminals):
node port/native-combat-particles/live-server.mjs
"$GODOT" --headless --path godot --script res://tests/combat_particles/live.gd
```

The replay instantiates the normal `world/viewer.gd` arena geometry/materials and a clearly labeled POV dummy HUD, then drives the public-shaped API with bounded explosion/projectile fixtures. JSON keeps every measured frame, median/p95/max, adapter, geometry counters, pool counts, and screenshot path. `evidence/` contains measured results; software-renderer timings are not claims about the user's GPU. Package/global verification and final menu/session wiring are lead-owned.
