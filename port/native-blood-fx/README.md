# Native blood / injury-fluid FX

Damage-driven fluid spurts and death splatter for the Godot port, with pooled,
occlusion-checked surface stains instead of Decal nodes (the Compatibility
renderer has none).

**Implementation:** `res://blood_fx/controller.gd` (`Node3D`), one shared
settings block (`res://blood_fx/settings.gd`), three shaders, one surface-query
backend module. Presentation only: it reads authoritative `damage` / `death`
events and the public actor snapshot. It never predicts a hit, never changes
damage, and never claims GPU readback.

## One-call wiring (lead integrates this)

```gdscript
const BloodFX = preload("res://blood_fx/controller.gd")
var blood_fx := BloodFX.new()
add_child(blood_fx)
blood_fx.configure(camera, surface_provider)   # Callable(from, to) -> {hit, position, normal}
blood_fx.apply_state(state, local_id)          # public snapshot (actors/positions)
blood_fx.apply_events(items, local_id)         # authoritative events
blood_fx.reset()                               # round boundary
blood_fx.set_quality(level)                    # "Low" | "High" | "Extreme"
blood_fx.snapshot()                            # real counts for F10-style metrics
```

Inside the existing composition the natural shape is the same one the other
effect managers already use in `world/combat_feedback.gd`:

```gdscript
# once, where the other effects are configured
blood_fx = BloodFX.new()
add_child(blood_fx)
blood_fx.configure(effect_camera, blood_surfaces)

# every public frame / event batch
blood_fx.apply_state(state, effect_local_id)
blood_fx.apply_events(items, effect_local_id)

# quality (F9) and lifecycle
blood_fx.set_quality(CombatQuality.LEVELS[level])
blood_fx.reset()            # results, restart, disconnect, map replacement
blood_fx.set_paused(false)  # optional; SceneTree pause is respected anyway
```

`surface_provider` is either

* a **Callable** `(from: Vector3, to: Vector3) -> Dictionary` returning
  `{hit: bool, position: Vector3, normal: Vector3}` — the composition can pass
  `occlusion.something` or its own query, or
* a **semantic map dictionary** (the locked nine-map export, or any dictionary
  with `blocks` + `terrain.support_triangles`/`surfaces`/`wall_triangles` +
  `bounds`) — the controller builds the query itself, or
* a **collision root `Node3D`** for native arenas / identity maps whose builders
  place `StaticBody3D` geometry (physics raycasts, world-only collision mask).

Convenience adapters exist for hosts that want a Callable instead:

```gdscript
const SurfaceQuery = preload("res://blood_fx/surface_query.gd")
blood_fx.configure(camera, SurfaceQuery.semantic_provider(map))        # nine locked maps
blood_fx.configure(camera, SurfaceQuery.physics_provider(map_node))    # StaticBody3D maps
blood_fx.configure(camera, map)                                        # same as semantic_provider
blood_fx.configure(camera, map_root)                                   # same as physics_provider
```

## What it does

**Damage → spurts.** On an authoritative `damage` event the controller derives
real health loss as `amount - shield` and refines it with observed snapshot
health. It then emits, from the wound area, along the attacker→victim axis:

| real health damage | profile |
|---|---|
| `<= 8` (settings `mist_max`) | small **entry mist** only, back toward the shooter |
| `8 .. 45` | entry mist + **forward exit jet**, scaled by damage |
| `>= 45` (`arterial_min`) or lethal | entry mist + **heavier arterial pulse** (multi-pulse) |

Damage with `amount - shield <= 0` (shield-only), a victim outside the public
actor list, a victim whose health bar did not move while armour/overshield was
still up, and damage on an already dead actor are all rejected and counted
(`snapshot().no_bleed / absorbed_only / unknown_actors`). A spurt that visibly
hits a surface inside `spurt_stain_reach` also leaves a small stain there.

**Death → splatter.** Each authoritative `death` emits one dense burst plus a
stain plan built from real surface queries: a floor pool that grows briefly,
radial splatter stains on nearby surfaces, and delayed short-lived drips. The
`death.pos` is used verbatim; the primary pool is the *actual* surface below the
death point, so a ramp, a deck or a mid-air death over the void all answer
correctly (a ramp stain takes the ramp's own normal; a death with nothing below
`stain_depth` places no floor stain at all).

**Stains.** Pooled `MeshInstance3D` quads with one shared stain shader and one
shared quad mesh. Placement is a real surface query plus a visibility check back
to the wound/death point, a `stain_normal_offset` (default 12 mm) along the
surface normal, and a right-handed basis whose local +Y is the surface's
downhill tangent so drips run downward. Depth testing stays on and no depth is
written, so a stain behind opaque cover changes zero pixels. Pools are bounded
(`stain_pool = 128`, live cap per quality) with oldest-recycled eviction and an
optional slow fade (`stain_fade_seconds`, default 0 = persist for the round).

**Massive but bounded.** Total allocated fluid particles, shared across the whole
pool, never per event:

| Level | Total allocated | Concurrent emitters | Live stains |
|---|---:|---:|---:|
| Low | 4,096 | 8 | 32 |
| High (default) | 24,576 | 14 | 80 |
| Extreme | 98,304 | 20 | 128 |

The pool is 24 `GPUParticles3D` nodes created once at `configure()`. Quality
switching only changes `amount` in place: node, mesh and material identities are
preserved (verified). Emitters are recycled, never grown; a stronger event can
evict a weaker live emitter, otherwise the event is counted in `dropped`.
`visibility_aabb` is set explicitly, idle nodes are hidden with `speed_scale = 0`,
and there is no per-frame node/material allocation and no CPU loop over
particles. The process shader has no `TIME`: `speed_scale` genuinely freezes
transport and age.

**Screen coverage cap.** `_coverage_dampen()` computes the emitter's angular
radius as a fraction of the vertical half-FOV and damps the submitted capacity
and gain when it would flood the view (`coverage_limit` 0.7 remote,
`local_coverage_limit` 0.38 plus `local_gain` 0.45 for any local-actor emitter).
The local player's own death additionally pushes the burst behind the eye
(`local_death_offset`) and widens its near-fade radius. Measured in the rendered
fixture, a local death changes **0 pixels** while an equivalent nearby remote
death covers 26–70 % of the viewport.

**Lifecycle.** Dedup is by the wire numeric `id` in a 4,096-entry window; the id
is recorded even while drained so a stale event can never replay. A backwards
public `time`, `state.over`, a map change and `reset()` clear the round
(pools included); focus loss and a stale public state (> `stale_seconds`) drain
the visuals but keep the wire window. SceneTree pause, `set_paused(true)` and a
hidden ancestor freeze without aging. A public `mapId` change drops the old
surface binding and reports `surface_error` so the host re-binds geometry.

## Art direction: one documented settings block

`res://blood_fx/settings.gd` is the only place colours, sizes, viscosity,
budgets, caps and thresholds live.

```gdscript
const BloodSettings = preload("res://blood_fx/settings.gd")
var s := BloodSettings.new()
s.fluid_color = Color("c21807")   # crimson is the default
s.fluid_scale = 1.15              # global particle size
s.viscosity = 0.65                # 0 watery spray .. 1 thick
blood_fx.settings = s             # assign before configure()

blood_fx.apply_variant("synthetic")  # armoured-operator coolant: teal, thinner
```

`apply_variant("blood" | "synthetic")` is the single-point override: it swaps
colour, scale, viscosity and density only. Emission logic, budgets, pools and
lifecycle rules are identical for both variants — a synthetic-fluid build never
touches a code path. `snapshot().variant` and `.fluid_color` record which one is
active. Everything is procedural: the only texture used is the project's
existing `res://moth/` flow-field; no new or paid assets.

## Owned verification

```sh
GODOT=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64

# 1) headless contracts: pools, eviction, dedup, shield/armour rejection,
#    damage scaling, quality identity, lifecycle drains, 48-actor kill wave
"$GODOT" --headless --path godot --script res://tests/blood_fx/contracts.gd
"$GODOT" --headless --path godot --script res://tests/blood_fx/surfaces.gd
"$GODOT" --headless --path godot --script res://tests/blood_fx/stress.gd

# 2) all of the above plus the rendered fixture matrix in a private Xvfb,
#    private HOME and private TMPDIR (llvmpipe software rendering)
python3 port/native-blood-fx/verify.py

# 3) rendered visibility curve for one budget (measured changed pixels per age)
"$GODOT" --path godot --rendering-method gl_compatibility --resolution 640x400 \
  res://tests/blood_fx/curve.tscn -- --quality=High --output=/abs/path/curve-high
```

The rendered fixture (`res://tests/blood_fx/render.tscn`) is explicitly labelled
as an arranged source fixture, not live gameplay: a flat floor, a ramp, a wall
and a crate, built from the same description that answers the surface queries.
It captures 960×640 and 1280×800 at High and Extreme (8/8 runs) and computes:

| control | 960×640 High | 960×640 Extreme | 1280×800 High | 1280×800 Extreme |
|---|---:|---:|---:|---:|
| stains placed behind the opaque wall | 22 | 28 | 22 | 28 |
| **changed pixels behind cover** | **0** | **0** | **0** | **0** |
| stains placed in view (positive control) | 43 | 56 | 43 | 56 |
| **changed pixels, positive control** | 1,295 | 1,431 | 2,033 | 2,251 |
| local own-death changed viewport | 0.00 % | 0.00 % | 0.00 % | 0.00 % |
| nearby remote-death changed viewport | 6.1 % | 6.7 % | 5.7 % | 6.3 % |

`res://tests/blood_fx/curve.tscn` measures rendered droplet visibility against a
clean baseline at fixed sample ages (640×400, one death splatter ~5 m from a
fixed camera):

| fluid age | High changed pixels | Extreme changed pixels |
|---|---:|---:|
| 0.15 s | 0 | 0 |
| 0.30 s | 3,960 | 4,265 |
| 0.45 s | 4,769 | 5,076 |
| 0.60 s | 3,047 | 3,802 |
| 1.00 s | 863 | 952 |

The first sample is 0 by design: the near-eye fade hides droplets that have not
travelled clear of the camera yet. Extreme submits 4× the particles of High and
covers ~10–25 % more *area*; the rest of the budget goes into droplet density
inside the same cloud volume (a real difference, not a 4× pixel difference).

`evidence/` holds the JSON records, logs and PNG captures from the last run
(`verification-summary.json`). Timings and coverage in the logs are llvmpipe,
not hardware.

### Measured CPU cost (headless, no rendering)

| case | result |
|---|---|
| 440 events (40 deaths + 400 damage) in one callback | ~25 ms |
| one saturated frame (24 live emitters, 80 live stains) | median 0.08 ms, max 0.14 ms |
| 2,000-event backlog | scanned 512 events, as documented |
| a 48-actor kill wave | 14 concurrent emitters (cap), 80 live stains (cap), 0 new nodes |

`snapshot()` reports `allocated_slots`, `submitted_slots` (allocation ×
`amount_ratio` for live emitters), `active_emitters`, `concurrent_cap`,
`stains_live`, `stains_recycled`, the counters above, the surface backend and the
lifecycle state. `gpu_live_readback` is always `false` and the buffer byte figure
is a source-derived GLES3 estimate, not measured VRAM.

## What this lane did **not** verify

* No hardware-GPU run, no packaged/exported build, and no live networked session
  was executed: all rendering evidence is **llvmpipe software rendering** and all
  gameplay input is fixture dictionaries, not a live server.
* Integration is not done here by design: `godot/world/combat_feedback.gd` and
  `combat_overlay.gd` belong to another active lane. The lead performs the single
  `configure/apply_state/apply_events/reset/set_quality` wiring call. Until then
  nothing calls this controller.
* The nine-map semantic backend is verified headless against the real locked
  exports (all nine resolve, floor normals up, real triangle counts); no rendered
  capture was taken inside a real locked map.
* `amount - shield` is the wire bound for real health damage; when the public
  snapshot shows no health movement and the victim still has armour/overshield,
  the hit is treated as absorbed. A tick that mixes armour absorption and health
  loss in one event can therefore under-report the spurt (never over-report).
* Colour and scale are tunable, not final art: crimson is the default, the
  synthetic variant is a one-call switch, and no artist review has happened.
