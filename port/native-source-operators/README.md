# Actual source operators: imported, articulated native proof

**All nine actual Three.js operators are exported and animated in Godot 4.5.2.**
This is the output of `robotModel()` → `refineOperatorCharacter()` from the source game, including its sculpted anatomy, precision assemblies, authored proportions, original materials and held world pulse weapon.

## Review evidence

- [Source/native front, side and back — 1280×800 captures](evidence/comparison-1280.png)
- [Source/native front, side and back — 1920×1080 captures](evidence/comparison-1920.png)
- [Animated source/native walk comparison](evidence/walk-source-native.gif)
- [10 m / 25 m comparison, 1280](evidence/distance-comparison-1280.png)
- [10 m / 25 m comparison, 1920](evidence/distance-comparison-1920.png)
- [Native 32-identity-cycle roster](evidence/native-roster-32-1280.png)
- [Machine-readable native checks](evidence/checks.json)
- [Exported world weapons and anchors](evidence/weapons.json)
- [Source grip fixtures, 450 cases](evidence/grips.json)
- [Presentation host-ownership checks](evidence/presentation.json)
- [Passing live session summary — two peers, two bots](evidence/live-07/summary.json)
- [Passing live session close third-person capture at 1280×800](evidence/live-07/actors-1280x800.png)
- [Passing live 960×640 capture](evidence/live-07/actors-960x640.png)
- [Restart-boundary capture](evidence/live-07/restart-1280x800.png)
- [Rendered performance measurements](evidence/performance.json)

The comparison uses Claude, Grok and Meta, with identical cameras, pose inputs, light direction, PBR factors and light-energy settings. Close cameras sit at 3 m to fit the entire source silhouette while using the exported close tier. Three.js and Godot ambient/specular lighting produce different brightness; these are genuine captures, without image recoloring. The native material tests independently verify source linear colors, emission, metallic/roughness values and precision vertex colors.

## Export fidelity

`tools/godot-operators/export.mjs` constructs the actual source model and samples the original visibility policy at **2 / 10 / 50 m**. Each visible mesh is baked only within its nearest rigid articulation, grouped by material, shadow policy and LOD membership. A batch present in multiple tiers is stored once and rendered once. The rig stays a nested Node3D hierarchy, including intermediate shoulder/elbow/hip/knee pivots, hands, backpack, gun mount and grip anchors.

- 31 retained hierarchy nodes per operator, including the 18 source articulated/attachment nodes.
- All nine GLBs together: **12,606,940 bytes** (about 12.0 MiB).
- Shared imported mesh resources across repeated roster instances; per-instance team armor material.
- Godot-generated simplification and lossy vertex compression disabled in checked-in `.glb.import` settings.
- Original source team armor colors and genuine source one/two-bar team meshes included.
- Original neutral base ring, invisible shield and transient flash are presentation effects outside this anatomy export.
- The source builder currently has **no material textures**: it never calls `applyProceduralTexturesToModel`. Vertex colors and PBR materials supply its finish. Export fails explicitly if that source construction gains textures, so a future canvas bake cannot be silently omitted.
- Source files and GLBs have SHA-256 provenance in `godot/source_operators/generated/manifest.json`.

| Source identity | Close triangles / draws | Near triangles / draws | Far triangles / draws | Bind height, including accessories |
|---|---:|---:|---:|---:|
| ChatGPT | 30,708 / 69 | 12,132 / 51 | 5,716 / 51 | 1.956 m |
| Claude | 27,972 / 72 | 10,332 / 54 | 5,468 / 54 | 1.802 m |
| Grok | 29,284 / 68 | 11,528 / 50 | 5,376 / 50 | 2.034 m |
| Meta | 31,184 / 71 | 11,672 / 53 | 5,872 / 53 | 1.802 m |
| Gemini | 29,960 / 68 | 12,064 / 50 | 5,672 / 50 | 1.793 m |
| DeepSeek | 29,400 / 71 | 10,424 / 53 | 5,712 / 53 | 1.891 m |
| Mistral | 28,080 / 67 | 10,464 / 49 | 5,596 / 49 | 1.828 m |
| Kimi | 31,872 / 69 | 12,640 / 51 | 5,696 / 51 | 1.956 m |
| Qwen | 28,760 / 70 | 10,748 / 52 | 6,124 / 52 | 1.956 m |

Counts include the source held pulse, exclude inactive team bars/effects, and exclude shadow passes. The original source-mesh counts are recorded alongside merged counts in the manifest. No anatomy is scaled to fit a nominal 1.8 m collision body: the source soles are at y≈0, and accessories genuinely reach above that body.

## Third-person world weapons and post-pose grips

`tools/godot-operators/world-weapons.mjs` constructs the **actual source `simpleWeaponModel`** for all ten `WEAPONS` entries at source scale, with no rescaling, and writes `godot/source_operators/generated/world_weapons/`:

- Ten GLBs, 20–26 KB each (264 KB total), two source material batches per weapon, 552–792 triangles.
- `Muzzle`, `WeaponGripLeft` and `WeaponGripRight` anchors copied verbatim from the source chassis fallback coordinates (`chassisFor`), the same `contact` vector `alignLivingCharacter` uses when the third-person chassis has no distinct grip nodes.
- `manifest.json` with per-file SHA-256, and `catalog.gd` with the same data for the runtime.

`godot/source_operators/operator_visual.gd` mounts the exported weapon on the authored source `GunMount`, hides the built-in pulse batches, and prefers the equipped weapon's `Muzzle` for `anchor("Muzzle")`. `godot/source_operators/hand_grips.gd` is the native port of the source post-pose hand pass (`placeLimb` + `alignLivingCharacter`). Unreachable contacts report the source's own reach clamp; no faked solution is applied.

## Native animation and integration API

Entry point: **`res://source_operators/operator_visual.gd`**.

```gdscript
const SourceOperator = preload("res://source_operators/operator_visual.gd")

var visual = SourceOperator.new()
add_child(visual)
visual.configure(actor, local_actor_id)
# Host keeps its existing interpolated center position and body yaw:
visual.position = Vector3(actor.x, actor.y + 0.9, actor.z)
visual.rotation.y = actor.get("bodyYaw", actor.yaw)

# On each authoritative snapshot (selects identity, weapon and shared flags):
visual.apply_actor(actor)
# On a presentation shot event:
visual.kick()
```

`godot/world/presentation.gd` uses this script as the default actor visual, feeds `apply_actor(actor)` at the existing snapshot site and kicks bounded recoil on genuine increasing `actor.shots` deltas (reset by `clear_round`). The host still owns world position, interpolation, body yaw, visibility, collision and gameplay.

`apply_identity(actor)` matches the existing actor-visual method and selects identity/team. Animation requires **`apply_actor(actor)`** to feed the snapshot. `apply_actor` also selects the exported third-person weapon from `actor.weapon` for living actors and leaves the built-in pulse in place for unknown/missing assets. `configure(actor, local_id)` also establishes local-actor hiding.

`_process()` advances the native rig from cached snapshot velocity, move speed, grounded/crouching/ADS/reloading/sliding flags, relative aim yaw and pitch. The implementation ports the source contact-foot gait, crouch/ADS/reload poses, aim tracking, hit/landing/strafe/acceleration channels and exponential damping. Recoil is a bounded native visual mount overlay. `automatic_animation = false` plus `advance(dt)` supports deterministic driving. `reset_pose()` restores bind transforms and animation state. `grip_error` and `grip_clamp` expose the current hand-pass residual and its source reach clamp for instrumentation.

`anchor("FeetOrigin")`, `anchor("Helmet")`, `anchor("GunMount")`, `anchor("Muzzle")`, `anchor("GripLeft")` and `anchor("GripRight")` return actual nested source anchors. The wrapper translates the imported model by **y = -0.9**, exactly compensating the host's actor-center placement. Forward remains **-Z**, scale remains **1**, and muzzle comes directly from `simpleWeaponModel.userData.muzzle.position`. Callers should query recursively through this API; old direct-child primitive `Helmet`/`Muzzle` tests are inappropriate for an articulated hierarchy.

LOD switches use source close-detail/anatomy thresholds **5.8 / 18 m**, with 15% hysteresis. The three exported tiers are the source snapshots at 2/10/50 m; source per-mesh transitions at intermediate distances are represented by whole-actor tier switches. Per-instance visibility changes never duplicate-render common geometry.

### Integration state

1. **Done:** `godot/world/presentation.gd` preloads `res://source_operators/operator_visual.gd` and feeds `apply_actor(actor)` at the existing snapshot site.
2. **Done:** each living actor's `actor.weapon` becomes the exported source third-person weapon on `GunMount`, with post-pose grip alignment (`hand_grips.gd`). The source CharacterRig alone deliberately leaves hands in its base pose, as the paired captures show; the world path adds the authored hand pass.
3. **Still lead-owned:** the lifecycle's world corpse trajectory/ragdoll policy. Native death currently applies an actual source-sampled deterministic back-splay, rejects subsequent living writes, and resets correctly on revival. Full source ragdoll physics and seeded death-style variety are not claimed here.
4. **Still lead-owned:** host VFX/secondary-spring events and final world lighting. Base-ring/shield/flash effects are separate from imported anatomy. Production combined-arms/gameplay performance and packaged Windows integration remain lead checks.

Remaining limits in this lane:

- The bounded native recoil overlay (`kick`) offsets the mount; at extreme aim plus recoil a wide chassis contact can exceed arm reach. The hand pass then reports the source's own reach clamp (`grip_clamp`) instead of faking contact. The passing live run measured 1.2e-5 m residual with zero clamp.
- Remote reload observation depends on the ammo economy. Deathmatch's starting pulse has infinite ammo, so the live harness starts the match on the finite-magazine rocket launcher to observe genuine authority reloads.
- `godot/tests/protocol/entity_visuals.gd` still asserts the older primitive actor visual and is lead-owned; it must be updated for the articulated hierarchy.
- Source alpha/materials and the external pulse-rifle reservation remain read-only, as before.

## Verification result

Pinned engine: `/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64`.

The native fixture imports actual GLBs and compares **6,138 world joint matrices** against the real Three.js `CharacterRig`, with maximum absolute matrix component error **2.4024e-7**. It covers bind, idle, walk, run, crouch, aim, crouch+aim, reload, hit/landing, airborne, slide, secondary channels, reduced motion, death, reset, and a 90-frame mixed-state damping sequence. Additional checks cover native triangle count, clockwise conversion with unchanged outward normals, PBR colors/metallic/roughness, precision vertex colors, source anchors, recoil return, death/revival, source team bars, isolated team materials, shared geometry, and complete node cleanup after 32 actors repeatedly cycle all nine identities.

The world-weapon checks add three more headless passes:

- `tests/source_operators/weapons.gd`: all ten exported GLBs match the manifest (SHA-256 provenance, triangles, material batches, bounds) with **0.0 m** anchor error.
- `tests/source_operators/grips.gd`: **450 source cases** (9 operators × 10 weapons × 5 poses) match the real `alignLivingCharacter` joint quaternions, world matrices and grip contacts. Maximum joint error **9.32e-7**, maximum grip world error **3.77e-7**, and the reach-clamp contract holds with maximum clamp excess **3.60e-7**.
- `tests/source_operators/presentation.gd`: host ownership, snapshot feeding, shot-delta recoil, weapon switching, LOD thresholds, fallback identity, death/revival and synchronous round cleanup.

A real normal-rate production session (`tools/godot-operators/live.py`, preserved under `evidence/live-06/` and `evidence/live-07/`) joins the shipped `world/session.tscn` to a private authority as a guest while **two real remote protocol peers and two authority bots** walk, fire and reload. The captured report shows four remote actors with all four walking and firing and both peers reloading, 1,835 snapshots, 1,340 interpolated remote poses, the source operator visual on every actor, mounted world weapons with the built-in pulse hidden, grip residual **1.23e-5 m** with zero reach clamp, real round results, the host restart boundary and a clean unload (exit 0). Captures were taken at **960×640** and **1280×800**, including a 3.9 m third-person close-up, and were inspected directly.

Real Compatibility renders use Mesa **llvmpipe**, on the shared host. Vsync-off is requested; the driver reports changing vsync unsupported. These are measured software-rendered timings, not hardware GPU or match FPS estimates. The benchmark fits every actor onscreen at near LOD, with one directional light plus ambient and no shadows/postprocessing.

| Roster | Resolution | Animation CPU median / p95 | Rendered frame median / p95 | Draws |
|---|---|---:|---:|---:|
| 16 | 1280×800 | 1.442 / 1.651 ms | 28.233 / 32.240 ms | 824 |
| 32 | 1280×800 | 2.583 / 2.989 ms | 57.302 / 66.058 ms | 1,648 |
| 16 | 1920×1080 | 1.411 / 1.672 ms | 28.966 / 33.108 ms | 824 |
| 32 | 1920×1080 | 2.470 / 3.033 ms | 54.927 / 60.630 ms | 1,648 |

The geometry and animation are practical to reuse; the remaining cost is principally many rigid material draws. Measurements should inform host quality settings and hardware validation, rather than motivating another operator redesign.

## Reproduce

```bash
node tools/godot-operators/export.mjs
node tools/godot-operators/world-weapons.mjs
python3 tools/godot-operators/check.py --render
python3 tools/godot-operators/live.py --output port/native-source-operators/evidence/live
CHROMIUM_PATH=/home/mojo/.cache/ms-playwright/chromium-1228/chrome-linux64/chrome node tools/godot-operators/reference.mjs
uv run --no-project --with pillow python tools/godot-operators/contact_sheets.py
```

`check.py` creates a private temporary project containing only this lane's assets and tests, imports with the pinned engine, runs native checks and optionally renders. `live.py` stages a private project copy, imports it, starts an ephemeral loopback authority and Xvfb display, and runs the real transport session with two protocol peers and two authority bots. The source browser server binds an ephemeral loopback port and closes after capture. Neither path uses the shared game preview, shared project cache, a full repository copy, or fixed ports. `--only=claude` on the exporter reproduces the first-operator proof (and deliberately makes a one-operator catalog); rerun without `--only` for the complete roster.
