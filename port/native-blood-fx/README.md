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
stain plan built from real surface queries:

* a floor pool on the *actual* surface below the death point that grows briefly
  (a ramp, a deck, a mid-air death over the void: a ramp stain takes the ramp's
  own normal; a death with nothing below `stain_depth` places no floor stain);
* a **bounded radial fan** (6/10/14 rays on 4 pitch bands, capped at 14/22/30
  ray-band casts per death) so vertical surfaces get spattered too. Rays are
  cast nearest the lethal shot direction first and spread outward, so the mark
  budget always buys the surface the burst was aimed at; a death with no
  authoritative direction distributes evenly. Each hit grows a small cluster of
  marks (2/3/4) plus at most one drip tail;
* every candidate must pass three real checks before it is drawn: the surface
  must **face the body** (`normal · toward > fan_facing_min`), be **reachable**
  from the death point without an occluder, and not be **inside a solid volume**
  (`solid_at`, so a floor quad under a wall's footprint is rejected);
* delayed short-lived drips near the primary pool.

**Impact spatter cluster.** When a spurting jet reaches a surface within
`spurt_stain_reach`, the impact point and its neighbours get a cluster of
3/5/7 marks (bounded at `spurt_mark_budget`): tight at the impact point, sparser
outward, elongated along the jet's in-plane projection, with an optional drip
tail on vertical surfaces. One quad per impact is no longer the behaviour.

**Stains.** Pooled `MeshInstance3D` quads with one shared stain shader and one
shared quad mesh. Placement is a real surface query plus a visibility check back
to the wound/death point, a `stain_normal_offset` (default 12 mm) along the
surface normal, and a right-handed basis whose long axis is either the surface's
downhill tangent (pools, drips) or the incoming jet projected into the plane
(streaks). `_mark_flat()` probes the plane around every candidate before it is
drawn: a different depth or a miss means an edge or corner, so the mark is
halved once and then skipped (`marks_skipped_edge`) instead of straddling an
edge or floating. Depth testing stays on and no depth is written, so a stain
behind opaque cover changes zero pixels. Pools are bounded (`stain_pool = 256`,
live cap per quality) with oldest-recycled eviction and an optional slow fade
(`stain_fade_seconds`, default 0 = persist for the round). Wall, slope and floor
mark counts are reported separately (`marks_wall/floor/slope`,
`stains_wall/floor/slope`).

**Massive but bounded.** Total allocated fluid particles, shared across the whole
pool, never per event:

| Level | Total allocated | Concurrent emitters | Live stains |
|---|---:|---:|---:|
| Low | 4,096 | 8 | 48 |
| High (default) | 24,576 | 14 | 128 |
| Extreme | 98,304 | 20 | 224 |

Stain pool and caps were raised **only as far as measured cost justifies**:

| | before wall spatter | after |
|---|---:|---:|
| stain pool (nodes created once) | 128 | 256 |
| live caps Low / High / Extreme | 32 / 80 / 128 | 48 / 128 / 224 |
| one saturated frame, aging the whole pool (headless CPU) | 0.067 ms median / 0.10 ms max | 0.105 ms median / 0.14 ms max |
| rendered draw calls with 18–22 live stains | 350 → 368 | 360 → 382 (1 draw call per live mark) |
| one death with full wall spatter | — | 1.1–1.5 ms CPU (measured, 4-walled pen) |
| one wall impact cluster | — | 0.06–0.08 ms CPU |

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

Wall-spatter knobs in the same block (all documented in `settings.gd`):

| key | default (Low/High/Extreme) | meaning |
|---|---|---|
| `fan_rays` | 6 / 10 / 14 | radial rays per death |
| `fan_band_budget` | 14 / 22 / 30 | ray × pitch-band casts per death |
| `fan_reach` | 4.8 m | furthest a mark may land from the body |
| `fan_bands` | `[0.02, -0.34, -0.78, 0.62]` | wall, low wall, floor, ceiling pitches |
| `fan_facing_min` | 0.18 | surface must face the body by at least this dot |
| `fan_bias_pull` | 1.8 | how hard rays bunch toward the lethal azimuth |
| `death_cluster_marks` | 2 / 3 / 4 | marks per surface hit |
| `death_mark_budget` | 10 / 20 / 30 | marks (incl. pool and drips) per death |
| `wall_mark_size` / `wall_mark_spread` | 0.30 m / 0.62 m | mark size and in-plane cluster radius |
| `wall_drip_marks` | 0 / 1 / 1 | drip tails per wall cluster |
| `spurt_marks` / `spurt_mark_budget` | 3 / 5 / 7, cap 6 | impact cluster marks |
| `spurt_spread` / `spurt_elongation` | 0.55 m / 2.4 | how far and how long the impact streaks get |
| `stain_edge_check` / `stain_edge_tolerance` | true / 0.06 m | the plane probe that rejects edge cases |

## Owned verification

```sh
GODOT=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64

# 1) headless contracts: pools, eviction, dedup, shield/armour rejection,
#    damage scaling, quality identity, lifecycle drains, 48-actor kill wave,
#    wall-spatter placement/orientation/far-side rules
"$GODOT" --headless --path godot --script res://tests/blood_fx/contracts.gd
"$GODOT" --headless --path godot --script res://tests/blood_fx/surfaces.gd
"$GODOT" --headless --path godot --script res://tests/blood_fx/stress.gd
"$GODOT" --headless --path godot --script res://tests/blood_fx/spatter.gd

# 2) all of the above plus the rendered matrix in a private Xvfb,
#    private HOME and private TMPDIR (llvmpipe software rendering)
python3 port/native-blood-fx/verify.py

# 3) rendered visibility curve for one budget (measured changed pixels per age)
"$GODOT" --path godot --rendering-method gl_compatibility --resolution 640x400 \
  res://tests/blood_fx/curve.tscn -- --quality=High --output=/abs/path/curve-high

# 4) wall spatter on a real locked map (meridian-exchange, world/viewer.gd)
"$GODOT" --path godot --rendering-method gl_compatibility --resolution 1280x800 \
  res://tests/blood_fx/wall.tscn -- --width=1280 --height=800 --quality=High \
  --output=/abs/path/wall-1280
```

`res://tests/blood_fx/wall.tscn` is the wall-spatter proof: a remote operator is
hit and then killed 1.2 m in front of a real 11.5 × 7 m building wall on
meridian-exchange, rendered through the normal `world/viewer.gd` arena, with the
camera 6 m back on the wall's face side and then moved behind the wall for the
far-side control. At 960×640 and 1280×800, High and Extreme:

| measurement | 960 High | 960 Extreme | 1280 High | 1280 Extreme |
|---|---:|---:|---:|---:|
| marks from the impact cluster (wall / floor) | 6 / 0 | 8 / 0 | 6 / 0 | 8 / 0 |
| marks from the death (wall / floor) | 19 / 3 | 29 / 4 | 19 / 3 | 29 / 4 |
| changed pixels inside the projected wall face | 7,257 | 8,101 | 11,484 | 12,685 |
| changed pixels in the wall's **far** face region after the same death | **0** | **0** | **0** | **0** |
| live marks on the far face (numeric) | **0** | **0** | **0** | **0** |
| static-frame noise floor in that far region | 0 | 0 | 0 | 0 |
| extra draw calls for the live marks / live marks | +22 / 22 | +32 / 33 | +22 / 22 | +32 / 33 |

The fixture also samples the first wall mark's own screen pixel: clean `#929993`
becomes `#a61012` after the death (1280 High), inside the projected wall face.
`marks_skipped_edge` (3–9) records candidates that were halved and dropped for
sitting on an edge; `marks_skipped_solid` is 0 here because nothing landed
inside a volume.

The rendered fixture (`res://tests/blood_fx/render.tscn`) is explicitly labelled
as an arranged source fixture, not live gameplay: a flat floor, a ramp, a wall
and a crate, built from the same description that answers the surface queries.
It captures 960×640 and 1280×800 at High and Extreme (8/8 runs) and computes:

| control | 960×640 High | 960×640 Extreme | 1280×800 High | 1280×800 Extreme |
|---|---:|---:|---:|---:|
| marks placed behind the opaque wall | 68 | 103 | 68 | 103 |
| **changed pixels behind cover** | **0** | **0** | **0** | **0** |
| marks placed in view (positive control) | 134 | 201 | 134 | 201 |
| **changed pixels, positive control** | 3,619 | 4,792 | 5,642 | 7,497 |
| local own-death changed viewport | 0.00 % | 0.00 % | 0.00 % | 0.00 % |
| nearby remote-death changed viewport | 6.1 % | 6.7 % | 5.7 % | 6.2 % |

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
| 440 events (40 deaths + 400 damage) in one callback | ~82 ms (was ~25 ms before wall spatter) |
| one death with wall spatter | 1.1–1.5 ms CPU |
| one impact spatter cluster | 0.06–0.08 ms CPU |
| one saturated frame (24 live emitters, 128 live stains, pool 256) | median 0.10 ms, max 0.14 ms |
| 2,000-event backlog | scanned 512 events, as documented |
| a 48-actor kill wave | 14 concurrent emitters (cap), 128 live stains (cap), 0 new nodes |

`snapshot()` reports `allocated_slots`, `submitted_slots` (allocation ×
`amount_ratio` for live emitters), `active_emitters`, `concurrent_cap`,
`stains_live`, `stains_recycled`, the counters above, the surface backend and the
lifecycle state. `gpu_live_readback` is always `false` and the buffer byte figure
is a source-derived GLES3 estimate, not measured VRAM.

## What this lane did **not** verify

* No hardware-GPU run, no packaged/exported build, and no live networked session
  was executed: all rendering evidence is **llvmpipe software rendering** and all
  gameplay input is fixture dictionaries, not a live server.
* Wall spatter is proven on **one** real locked map (meridian-exchange, one
  building wall). The other eight maps use the same query backend that is
  verified headless for all nine, but no rendered wall capture was taken on them.
* `solid_at()` answers from block boxes on the semantic backend and from a real
  physics point query on the physics backend. A host **Callable** provider cannot
  answer it (it reports false), so a custom provider must keep its own marks off
  solid interiors. Callable providers also cannot be re-queried for the edge
  probe; those checks degrade to the provider's own answers.
* The edge probe is a 3-point plane test: a surface that curves smoothly inside
  the quad (a cylinder) can still pass, and a mark on a face smaller than
  ~2 × `stain_edge_tolerance` is skipped rather than drawn. `marks_skipped_edge`
  reports how often that happens (3–9 per death on the wall fixture).
* The drip tails are presentation only: they do not simulate fluid running down
  the wall, they are delayed marks placed below the cluster.
* `amount - shield` is the wire bound for real health damage; when the public
  snapshot shows no health movement and the victim still has armour/overshield,
  the hit is treated as absorbed. A tick that mixes armour absorption and health
  loss in one event can therefore under-report the spurt (never over-report).
* Colour and scale are tunable, not final art: crimson is the default, the
  synthetic variant is a one-call switch, and no artist review has happened.
* Integration is unchanged and stays lead-owned: the API
  (`configure/apply_state/apply_events/reset/set_quality/snapshot`) and every
  snapshot key the composition already reads are untouched, so the existing
  wiring keeps working. Wall spatter needs **no wiring change**.
