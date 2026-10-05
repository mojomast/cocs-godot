# Stormglass Causeway — road grade plan (grade-v1), 2026-10-05

**Status: proposal only, source-only.** Analysis, an authored elevation profile
and deterministic tooling on branch `spacebunny/stormglass-grade-20261005`
(base `25c189bd`, branched from `feature/relay-campaign`). Nothing in this branch
changes the accepted recipe, the runtime world JSON, the Blender master, the GLB,
the export report, any receipt or any catalog entry. No engine, Blender, import,
server, capture or network ran. This document makes **no native claim** and does
**not** retract the recorded flat-road concession, which remains truthful for the
accepted world.

The concession under address, cited from committed source:

- `port/finish/STORMGLASS_PACKAGE_PROMOTION.md:8-12` — "an explicit **flat-road
  concession: zero drivable relief**. No jumps or elevated-road capability is
  claimed."
- `port/finish/STORMGLASS_PARENT_REVIEW.md:14-17` — "source drivable relief is
  zero. Scenic towers, gateways and observatory height do not establish elevated
  driving or jump routes."
- `port/finish/map-variety/MAP_POPULATION_STATUS_20261005.md:123-127` — the
  blocker, quoting `recipe.mjs` `roadRelief: 0`, `game/race.mjs` passing `()=>0`
  as the vehicle ground callback, and `route_probe.gd` asserting
  `absf(hit.position.y) < 0.001`.
- `port/finish/MAP_VARIETY_REVISION_BLUEPRINT_20261003.md:278-297` — "Plan B
  (playable drivable relief) — only with an explicit parent authority grant, one
  revision", with seven coordinated changes.

Reproduce every number below with:

```sh
cd /home/mojo/.tmp-on-disk/cocs-coastal-corrective-V-20261003
node tools/godot-multiplayer/new-maps/stormglass-causeway/grade-plan/report.mjs
node --test tools/godot-multiplayer/new-maps/stormglass-causeway/grade-plan/grade-plan.test.mjs
```

---

## 0. Headline findings

1. **The vehicle is already able to follow a grade; the race path is what
   suppresses it.** `game/race.mjs:409` passes `()=>0` as `stepVehicle`'s
   `ground` callback. That returns the finite number `0` at all four wheel
   samples, so `groundY` is `0` — not `null` — and `game/vehicles.mjs:824-829`
   drives `position.y` toward it by suspension and **ignores** the Y that
   `match.vehicleCollision` already resolved from `floorAt`
   (`game/core.mjs:815` returns `{...next, y: floor}`). The flat concession is one
   callback, not a missing physics feature.
2. **A real sampler already exists on the same object.** `Match.vehicleGround`
   (`game/core.mjs:850`) is `floorAt` plus a finite-difference normal, and
   `game/soccer.mjs:22-27` already wraps it (`groundY`) and passes it to
   `stepVehicle` at `game/soccer.mjs:349-351`. Race is the only vehicle path
   still flat.
3. **The existing gate rule is the hard blocker, not the grade.** With the
   authored profile, the shipped `y < -.25 || y > 3` window at
   `game/race.mjs:218` admits **12 of 21** gates; gates **8-16** are
   unreachable. An authored per-gate window admits **21 of 21**.
4. **Grades cost essentially no speed in the current model, by construction.**
   `game/vehicles.mjs:765-772` derives thrust from throttle alone and subtracts
   only quadratic drag; there is no gravity-along-slope term anywhere. Measured
   with the real `stepVehicle`: flat top speed **20.0000 m/s**, steepest-sector
   top speed **20.0000 m/s**, delta exactly **0**. The only measured physical
   cost is grip: `8` → **7.98439** (−0.195%).
5. **The one genuinely non-trivial geometry finding**: the accepted road strip
   is **one quad per sector**, and its two long mitred edges have different
   lengths (sector 20: 72.32 m outer vs 22.54 m inner). A longitudinally graded
   trapezoid is **not planar**, so its two triangles disagree and
   `terrainSupportAt` — which returns the *highest* walkable triangle
   (`game/terrain.mjs:96-107`) — reports a **0.2364 m support ridge** on the
   steepest sector. Subdividing the strip fixes it (§3.6).

---

## 1. Touchpoint inventory

Every row is a place the accepted flat world is load-bearing for a grade. "Site"
is the exact authority site; "current" is the accepted behaviour; "needed" is
what a graded revision must do.

### 1.1 Terrain / authority support

| # | Site | Current | Needed for grade-v1 |
|---|---|---|---|
| T1 | `recipe.mjs:12` `terrain:{maxSlope:.8,base:0,amplitude:0,…}` | slope budget 0.8 rad (45.84°, `cos = 0.69671`); `base`/`amplitude` cosmetic | unchanged; 5.87% max grade is far inside it |
| T2 | `recipe.mjs:47` `quad('road-i', [xyz(outer[i]), xyz(inner[i]), xyz(inner[j]), xyz(outer[j])], 'asphalt','floor')` | **one quad per sector**, all four corners at Y=0 | emit the strip as **k sub-quads per sector** (§2.3) with corner Y from the profile, because the accepted trapezoid is not planar under grade |
| T3 | `recipe.mjs:49` barrier quad, Y 0 → 2.8 (`barrier-sea-i` / `barrier-city-i`, 42 quads → 84 wall triangles) | walls sit on the datum | **must** ride the profile. Measured: leaving them behind drops containment from **63/63 blocked to 3/63 blocked** (§3.5) — the road edge stops existing as far as authority is concerned |
| T4 | `recipe.mjs:51-52` reflectors (Y 2.9), `:56` shoulders (Y 0.015), `:59` labels (Y 4) | absolute, datum-relative | ride the profile; 14 of 21 gate labels move |
| T5 | `recipe.mjs:63-75` 31 district/quay structures, all bases at Y=0 | absolute | ride the profile (6030 of 9682 art meshes move, 3725 do not) |
| T6 | `recipe.mjs:78-87` freight vault, `7 + 9·sin θ`, bore sides 2.8 → 7 | absolute | **no change needed**: sectors 4-6 are authored on the datum, so the vault and its 7 m minimum overhead are preserved bit-for-bit |
| T7 | `recipe.mjs:89-98` surge gates at sectors 1, 14, 18 (buttress 0→24, leaf 9→15, gantry 22→24) | absolute | sectors 1/14/18 must ride the profile (sector 14 sits at 4.6 m, sector 18 at 1.35 m) |
| T8 | `recipe.mjs:100` `quad('ocean', …, 'ocean')` at Y = −4, `collision:'none'` | cosmetic, art-only, never in `terrain.surfaces` | **exempt**; must stay flat. Asserted by test |
| T9 | `recipe.mjs:106` `metrics:{… roadRelief:0, architectureRelief:24}` | reports the concession | becomes `roadRelief: 6.8`, plus new `maxGrade` / `maxRelief` metrics |
| T10 | `recipe.mjs:105` `m.race={centerline,gates,grid,boundary,…}` — `centerline`, `gates`, `grid`, `boundary` all carry **only** `{x,z[,nx,nz,halfWidth,heading]}` | no Y anywhere | add `y` (and `y0`/`y1` on gates); `raceSnapshot` (`game/race.mjs:203`) already spreads gates verbatim, so the wire shape grows by two numbers and needs a protocol note |
| T11 | `build.mjs:10` `spawnPoints: arena.spawns.map(([x,z]) => ({x, y:0, z}))` | hardcoded `y:0` | **must** compute via `terrainSupportAt`; `port/multiplayer-worlds/catalog.mjs:42` throws `Unsupported spawn` when `Math.abs(p.y - support) > 0.15`. The revision-2 candidate builder already does this correctly (`revision2/build.mjs:20`) — precedent to copy |
| T12 | `port/multiplayer-worlds/catalog.mjs:36` `geometryHash!==hash` | `6afb8a36ee954ff9457a5522a7412c809191fb070eb7fe9eda4d379753acce48` | must change; see §4 re-derivation list |

### 1.2 Race ground callback, spawn/reset and gate bounds

| # | Site | Current | Needed |
|---|---|---|---|
| R1 | `game/race.mjs:407-409` `stepVehicle(…, next=>match.vehicleCollision(next,vehicle), ()=>0)` | flat | pass a sampler. Mirror `game/soccer.mjs:22-27`/`349-351`: `typeof match.vehicleGround === 'function' ? (x,z)=>match.vehicleGround(x,z) : ()=>0`. The `typeof` guard is **required** — `game/race.test.mjs:15-26` builds fixtures without `vehicleGround` |
| R2 | `game/race.mjs:218` `y < -.25 \|\| y > 3` | absolute window | read an authored window, defaulting to today's numbers. Measured: **9 of 21 gates unreachable** with the shipped rule (§3.4) |
| R3 | `game/race.mjs:226` `racer.anchor = {x, z, heading}` — no Y | `resetRaceRacer` cannot recover height | store `y` from the crossed gate |
| R4 | `game/race.mjs:242` `respawnVehicle(vehicle, {x:a.x, y:0, z:a.z}, a.heading)` | respawns at Y=0 | respawn at `a.y ?? 0`. At a 6.8 m gate this is a 6.8 m fall; see §3.7 for the measured consequence |
| R5 | `game/race.mjs:161` `vehicle.spawn = {x:grid.x, y:0, z:grid.z}` | flat spawn | derive from the grid slot's Y. Grade-v1 keeps all 8 slots on the datum, so this is robustness, not a behaviour change |
| R6 | `game/race.mjs:130` `match.vehicleCollision({x, y:0, z}, probe)` in `acceptSlot` | probe Y ignored by `vehicleCollision` for ground vehicles | harmless; no change needed |
| R7 | `game/race.mjs:3` `distance = (a,b) => hypot(a.x-b.x, a.z-b.z)` — XZ only | pickup reach, stuck detection, `progress` | **correct as-is**: grade cannot trigger the `r.stuck > 3` reset (`game/race.mjs:434`) or change pickup reach |
| R8 | `game/race.mjs:420/424/428/432` event Y values `2.2` / `1.2` / `0` / `0` | absolute VFX anchors | Stormglass has `itemBoxes:[]`, `coins:[]`, `boostPads:[]`, so nothing is currently misplaced; still a latent assumption |
| R9 | `game/race.mjs:434` `r.stuck` and `:436` `checkpointAge>20` recovery | unchanged | unchanged — both are XZ/time based |

### 1.3 Vehicle ground sampling and physics effects

| # | Site | Current | Needed / measured |
|---|---|---|---|
| V1 | `game/vehicles.mjs:713-729` four wheel samples at `±track/2` (1.05 m) and `±wheelBase/2` (1.8 m) | never exercised in race | with a real sampler these are the only vertical authority. Measured cross-level: sampled normal `y` tracks `1/√(1+grade²)` to within **0.005** over 449 samples |
| V2 | `game/vehicles.mjs:756` `grounded = position.y - groundY <= 0.4` | always true at Y=0 | worst modelled vertical error is **0.1354 m** (break 0.0602 + sustained lag 0.0753) → **0.2646 m headroom** (§3.3) |
| V3 | `game/vehicles.mjs:776-777` `slopeGrip = clamp(groundNormal.y, 0.4, 1)`; `grip = 8 * slopeGrip` | `slopeGrip = 1`, grip 8 | measured **7.98439** at the steepest sector: −0.195%, i.e. −0.31 ms on the 125 ms lateral time constant. Not a balance change |
| V4 | `game/vehicles.mjs:765-772` thrust/drag | `thrust = throttle·a·speedScale`, `drag = 0.035·v²` | **no longitudinal slope term exists.** Measured speed delta on grade: exactly **0** (§3.2). Adding one would be a *new* physics feature, deliberately out of scope |
| V5 | `game/vehicles.mjs:760-762, 828-834` body pitch/roll | 0 | `groundPitch` becomes the real ramp angle; measured max **3.36°** against `pitchMax` 20.05°. `groundRoll` stays **0** because camber is authored at exactly 0 |
| V6 | `game/vehicles.mjs:764` `engineAir = grounded ? 1 : 0.35` and `:768-770` `grip *= 0.25` when airborne | never triggered | never triggered on grade-v1: `anyUngrounded = false` across all 21 sectors driven at top speed (§3.2) |
| V7 | `game/vehicles.mjs:824-829` `position.y` suspension lerp vs `resolved.y` | race never uses `resolved.y` | with R1 the sampler wins and the collision Y is ignored — which is correct, and the reason R1 alone fixes vehicle height |
| V8 | `game/core.mjs:815` `vehicleCollision` uses `obstructed(next.x, floor, next.z, radius, arena)` | correct on a graded floor | already height-correct; **no change** |
| V9 | `game/race.mjs:255-303` `botControls` corner speed `sqrt(AI_MAX_LAT_ACCEL/curvature)` | curvature only | bots are grade-blind; measured lap-relevant target speed is unchanged. Stated as a limitation, not a fix |

### 1.4 HUD / chase / presentation assumptions

| # | Site | Current | Needed |
|---|---|---|---|
| H1 | `game/race-camera.mjs:120` chase `y = focus.y + 5`, `:124` orbit `y = focus.y + 4.2` | relative to the car | **safe unchanged** |
| H2 | `game/race-camera.mjs:129` flyover `y = 12 + 1.4·sin(t)`, `:137` cinematic `y = 2.6`, `:142` trackside `y = 3.4` | **absolute world heights** | at a 6.8 m crest: trackside clearance **−3.4 m** (below the road), cinematic **−4.2 m**, flyover **+3.8 m** (only 3.8 m of ground clearance). These are the menu-reel rigs (`RACE_DEMO_MODES`), not the in-match camera (`game/view.mjs:4223` uses `mode:'chase'`) |
| H3 | `game/race-camera.mjs:147` `y = Math.max(0.8, …)` | absolute floor | harmless while the profile is non-negative; would clamp an elevated trackside rig |
| H4 | `game/race-presentation.mjs:99` barrier wall base Y = 0, top = `height` | absolute | needs per-point `y` from `race.boundary`, which currently carries only `{x,z}` |
| H5 | `game/race-presentation.mjs:216-217` start line and grid slots at Y `.08` | absolute | needs local road Y |
| H6 | `game/race-presentation.mjs:140` boost pads at `.06`; `:50` boxes at `2.2`; `:64` coins at `1.2` | absolute | latent; Stormglass authors none of them today |
| H7 | `game/race-ui.mjs`, `game/hud.mjs:1599` | no Y at all | no change |

### 1.5 Compatibility constraints with existing modes and tooling

| # | Site | Constraint |
|---|---|---|
| C1 | `game/soccer.mjs:22-27, 349-351` | already passes a real `groundY(match,x,z)` sampler. **Any change to R1 must not regress soccer**, and the natural shared helper is exactly this one |
| C2 | `game/race-maps.mjs` `PUMA_CIRCUIT` (the non-world `puma-race` map) has **no terrain** | `terrainSupportAt` returns `null` → the sampler yields `null` → `stepVehicle` takes the `groundY === null` branch and falls back to `resolved.y` from `vehicleCollision`, which returns `floorAt` = **0** for a non-raised arena. Behaviour preserved. Asserted by test |
| C3 | `port/multiplayer-worlds/catalog.mjs:6` `WORLDS['stormglass-causeway'].modes = ['puma-race']` | unchanged; grade-v1 adds no pair |
| C4 | `port/multiplayer-worlds/mode-matrix.mjs:41` `assert.equal(room.match.race.gates.length, 14)` | **already failing on the base commit**: Stormglass has 21 gates. Reproduced on `25c189bd` (`node port/multiplayer-worlds/mode-matrix.mjs` → `AssertionError: 21 !== 14`). Pre-existing, unrelated to grade, recorded not hidden |
| C5 | `tools/godot-multiplayer/new-maps/stormglass-causeway/revision2/source.test.mjs:39-55` | asserts `arena.metrics.roadRelief === 0`, `floorAt(...) === 0` at every gate and grid slot, and `deepEqual(arena.terrain, base.terrain)`. Passing today (6/6). A graded base recipe **breaks all three** — revision 2 has to be superseded by a revision 3, not edited |
| C6 | `tools/godot-package/production_receipts/stormglass-causeway.json:8-9` pins `recipe.mjs` = `427d7d4b9ade4d19bfecc7f061b6bc87146a44b56f79aa5c6de2b95a1daa162a` and `build.mjs` = `182ecaf1…`; `tools/godot-package/production_resources.mjs:26-33` lists both as `BUILD_INPUTS` | editing either file invalidates the promotion receipt. **A graded change must land as a new revision + a new receipt transaction**, exactly like revision 2 did |
| C7 | `tools/map-variety-support/road.py:6` `VERTICAL_BAND = (-1.0, 6.0)` | the shared scenic-placement clearance band is an absolute Y range. At a 6.8 m crest the upper half is inside the road. The revision-2 `layout.py` placement check would need the band made road-relative |
| C8 | `godot/tests/new_maps/stormglass_causeway/route_probe.gd` | asserts `absf(hit.position.y) < 0.001` on 21×21 road rays and `hit.position.y >= 7 && <= 17` for six overhead rays from `y=1`. Both encode the flat road. (File is in the commit but sparse-checkout-skipped in this worktree; content read from `git show f0bb6019:godot/tests/new_maps/stormglass_causeway/route_probe.gd`) |
| C9 | `godot/multiplayer_worlds/map.gd:52-95` | builds collision from `terrain.surfaces` / `terrain.walls` generically. A graded road needs **no** Godot change; the tri count grows |
| C10 | `port/finish/map-variety/VESPER_STAIR_COLLISION_PROPOSAL_20261005.md` | precedent for a source-only, proposal-shaped document with an explicit "cannot be validated source-only" section. This plan follows that shape |

---

## 2. The smallest coherent versioned change

### 2.1 Shape

**One versioned recipe revision (`layoutRevision: 3`, `gradeProfile:
'stormglass-causeway/grade-v1'`) that adds a longitudinal elevation profile and
nothing else, plus four one-line behaviour changes in shared race source that
default to today's behaviour for every map without an authored gate height.**

The smallest version that is *coherent* is not smaller than this, because each
of these is independently fatal if omitted:

- Omit the **road-strip subdivision** → a 0.2364 m support ridge (§3.6).
- Omit the **barrier rebase** → the road edge stops existing for authority
  (63/63 → 3/63 blocked contacts, §3.5).
- Omit the **gate window** → 9 of 21 gates unreachable (§3.4).
- Omit the **spawn/reset Y** → a 6.8 m fall on every reset (§3.7).
- Omit the **`build.mjs` spawn Y** → `readWorld` throws on the first spawn.

Conversely, nothing *else* has to change. No new mode, no new pair, no physics
constant, no camera rig in match play, no catalog entry, no new surface
material, no collision schema change.

### 2.2 Where the grade goes

Authored as 21 knot heights, one per accepted centerline node, in
`grade-plan/grade-profile.mjs` `KNOT_HEIGHTS`:

```
node   0  1  2  3  4  5  6 | 7    8    9    10   11   12   13   14   15   16   17   18   19 | 20
Y (m) 0  0  0  0  0  0  0 | 1.8  4.8  6.2  6.8  6.8  6.4  5.8  5.0  4.2  3.4  2.6  1.8  0.9 | 0.0
```

- **Sectors 0-6 and 20 hold the 0.0 datum.** Start/finish straight, weather
  terminal and the arched freight bore are untouched, so the bore vault, its
  7 m minimum overhead, the surge gate at sector 1 and the whole starting grid
  keep their accepted heights exactly.
- **Sectors 6-11 climb to a 6.8 m crest** over the stepped quay (node 10 at
  `(45,145)`, the quay-chicane camera line), then **12-19 descend** back to the
  datum, closing the loop exactly at node 0.
- **Camber is exactly 0.** No cross-slope is authored, so `groundRoll` stays 0
  and the four-corner sampler has no lateral tilt to average.

### 2.3 Targets, and why these numbers

| target | value | derivation |
|---|---|---|
| max grade, any driven line | **≤ 8%** | the blueprint's own "~8%" target (`MAP_VARIETY_REVISION_BLUEPRINT_20261003.md:288`) |
| max grade, achieved | **5.874%** (sector 7 inner edge) | the *inner mitred edge* is the steepest driven line, not the centerline (5.644%) and not the outer edge (5.432%) — because the strip is a trapezoid. Headroom 2.126% |
| max knot step | **3.000 m** | caps a single sector's contribution to the relief budget |
| total relief | **6.8 m** | visually readable elevation (≈2 storeys) with a bounded rebase surface |
| camber | **0°** | keeps `groundRoll = 0`; banking is a separate proposal |
| min crest transition run | **≥ 25 m** | the largest grade change is 3.343% at sector 6 over a 53.9 m sector |
| worst vertical error budget | **≤ 0.4 m** | the `grounded` tolerance in `game/vehicles.mjs:756`; achieved 0.1354 m |
| gate window | `roadY − 0.25 … roadY + 3.0` | **the existing band, translated.** A map with no authored gate height is bit-identical |

### 2.4 Preservation rules (hard, testable)

1. **XZ is immutable.** Every road corner, barrier vertex, structure, label,
   gate, navNode, route point, spawn and grid slot keeps its accepted plan
   position. Only Y is added. Asserted vertex-by-vertex.
2. **Road width stays 28 m**, barrier at the existing mitred ±14, `halfWidth`
   stays 13.9, gate count stays 21, `candidateModes` stays `['puma-race']`,
   `modeBindings` stays `{}`.
3. **Relative heights inside an attachment never change.** Barriers stay 0→2.8,
   reflectors 2.9, vault 7→16, gate leaf 9→15, gantry 22→24, labels 4. They
   ride the profile; they are not re-authored.
4. **The freight bore and the starting grid stay on the datum**, so the vault's
   7 m overhead and all 8 grid slots are bit-identical.
5. **The cosmetic ocean stays flat at Y = −4** and never becomes authority
   geometry.
6. **No physics constant changes.** `PUMA` is untouched.

### 2.5 What must be re-derived

| artifact | why |
|---|---|
| `geometryHash` | changes with any arena byte (`catalog.mjs:36` enforces it) |
| `recipeHash` + the 3 generated world files | `build.mjs` writes `port/native-multiplayer-worlds/worlds/…`, `godot/…/generated/worlds/…`, `godot/…/generated/…json` |
| `spawnPoints[].y` | must come from `terrainSupportAt`, not `0` (T11) |
| `revision2/{arena,candidate,probes}.json` | rebuilt at the new geometry hash; `probes.json` node Y changes |
| `revision2/source.test.mjs` | its `roadRelief === 0` / flat-support / `deepEqual(terrain)` assertions must be replaced by revision-3 equivalents (C5) |
| `route_probe.gd` | road rays compare against authored local Y (±0.02); the overhead ray must start at the local road Y (C8) |
| `tools/map-variety-support/road.py` `VERTICAL_BAND` | made road-relative (C7) |
| `race-presentation.mjs` boundary/gate/grid Y | presentation, not authority (H4-H5) |
| Blender master + GLB + export report | every road-anchored vertex moves; **heavy owner only** |
| promotion receipt + package inputs | `recipe.mjs`/`build.mjs` hashes are pinned (C6); needs a new receipt transaction |

---

## 3. Quantified effects (deterministic, source-derived)

All from `node tools/godot-multiplayer/new-maps/stormglass-causeway/grade-plan/report.mjs`,
which walks the accepted recipe and the real `game/` modules.

### 3.1 Support heights along a sample route

449 samples: all 21 centerline nodes, 20 interior points per sector, and all 8
grid slots, each resolved through `terrainSupportAt(x, z, terrain, maxSlope)`.

- Every sample is supported; none is `null`.
- Sampled triangle normal `y` matches the analytic ramp normal
  `1/√(1+grade²)` to within **0.005** — the profile is realised exactly.
- Worst deviation of authority support from the authored profile:
  **0.2364 m** at `sector-7-10`. This is the non-planar-strip ridge, not a
  profile error. §3.6's table measures the *same* ridge on the road strip in
  isolation (0.1758 m at k=1); the full-arena figure is larger because the
  whole road is in play rather than a road-only surface set.
- All 8 grid slots resolve to support `0` (the datum), as authored.

### 3.2 Vehicle speed / grade sensitivity (real `stepVehicle`)

Each sector is driven at top speed for its full length with a ground sampler fed
by the real support query.

| quantity | flat | steepest (sector 7) |
|---|---|---|
| settled speed | 20.0000 m/s | **20.0000 m/s** |
| speed delta | — | **exactly 0** |
| grip (8 × `slopeGrip`) | 8.00000 | **7.98439** (−0.195%) |
| ramp angle | 0° | **3.362°** (against `pitchMax` 20.05°) |
| ever ungrounded | no | **no**, all 21 sectors |
| max \|y − support\| | 0 | **0.1282 m** |

The zero speed delta is a **structural** result, not a measurement artefact:
`game/vehicles.mjs:765-772` computes
`acceleration = throttle·accel·speedScale − 0.035·v²` with no slope term. Adding
one would be a new physics feature with its own balance review, and is explicitly
**out of scope** for grade-v1. PUMA's flat top speed is exactly
`√(14/0.035) = 20`, which is why the config value is 20.

Grip loss, derived: `slopeGrip = 1/√(1+0.058740²) = 0.998279`; `8 × 0.998279 =
7.98623`. The measured 7.98439 uses the per-step sampled triangle normal rather
than the analytic ramp normal — the 0.023% difference is the crease tilt of the
un-subdivided strip and disappears at k = 16 (§3.6). The lateral decay time
constant moves from 125.000 ms to 125.215 ms.

### 3.3 Vertical envelope

| term | value | source |
|---|---|---|
| largest grade break | 3.343% (sector 6) | knot ledger |
| corner-crest break amplitude `0.5·wheelBase·\|Δgrade\|` | **0.0602 m** | `vehicles.mjs:717-722` samples ±1.8 m |
| sustained suspension lag at 20 m/s | **0.0753 m** | walking `vehicles.mjs:825-826`'s own recursion |
| worst vertical error | **0.1354 m** | sum |
| grounded tolerance | **0.4000 m** | `vehicles.mjs:756` |
| **headroom** | **0.2646 m** | |

A hand-driven 400-step run from the foot of the climb stays within 0.4 m of the
sampled surface, ends above Y = 1 and reports `grounded === true`.

### 3.4 Gate admission — the decisive measurement

The **shipped** `crossRaceGates` rule was executed on a swept crossing at each
gate's authored road height:

| rule | gates admitted |
|---|---|
| shipped `y < −0.25 \|\| y > 3` | **12 / 21** |
| proposed per-gate window `roadY−0.25 … roadY+3` | **21 / 21** |

Gates **8, 9, 10, 11, 12, 13, 14, 15, 16** are unreachable under the shipped
rule — nine of twenty-one, i.e. the race cannot be completed. Separately, the
proposed predicate was cross-checked against the shipped behaviour on a flat map
across `y ∈ {−1, −0.3, −0.25, 0, 1, 2.9, 3, 3.1, 4, 8, NaN, undefined, ∞}` and
agrees at every sample.

### 3.5 Lateral containment

63 probes: per sector, a Puma-radius (`2.08387 m`) contact probe 0.1/0.8/1.6 m
beyond the **actual mitred barrier distance** at that gate, evaluated with the
real `obstructed`.

| world | blocked | free |
|---|---|---|
| accepted flat baseline | **63** | 0 |
| graded, **barriers rebased** | **63** | 0 |
| graded, barriers **left on the datum** | **3** | **60** |

Rebasing the barriers preserves containment exactly. Not rebasing them loses 60
of 63 contacts: the road surface rises while the wall stays at Y 0→2.8, so at the
crest the chassis is simply above the wall top and the edge is open.

### 3.6 Road-strip subdivision (the real geometry finding)

| k | road surfaces | road triangles | worst support ridge | sectors over 2 cm |
|---:|---:|---:|---:|---|
| 1 (accepted today) | 21 | 42 | **0.1758 m** | 6,7,8,9,13,14,15,17,18,19 |
| 2 | 42 | 84 | 0.0879 m | 7,8,13,14,15,17,18,19 |
| 4 | 84 | 168 | 0.0439 m | 8,13,14,15,17,18 |
| 8 | 168 | 336 | 0.0220 m | 8 |
| **16** | **336** | **672** | **0.0110 m** | **none** |
| 32 | 672 | 1344 | 0.0055 m | none |

**Recommendation: k = 16.** It is the first value that clears the ±0.02 m probe
budget everywhere, costs +630 triangles against a 150,000-triangle advisory
budget, and the convergence is clean 1/k. Sector 8 is the straggler at k = 8
because it carries the worst mitred edge-length ratio (1.682) of any graded
sector; sector 20's ratio is 3.208 but it is flat, so it never contributes.
Barriers should be subdivided with the same k for *visual* continuity (a chord
between sector ends would cut through a 3 m crest); for *authority* they do not
need it, because `terrainObstructed` (`game/core.mjs:173`) projects to XZ and
only range-checks Y.

### 3.7 Spawn / reset consequence

At a 6.8 m gate the shipped `resetRaceRacer` (`game/race.mjs:242`) respawns at
`y: 0`, i.e. 6.8 m *below* the road. With a real sampler this is not fatal — the
suspension follower at `k = 12·dt = 0.2` per step needs
`ln(0.001)/ln(0.8) ≈ 31` steps ≈ **0.516 s** to close 6.8 m, and
`grounded = position.y − groundY ≤ 0.4` stays true because the car starts
*below* support, not above. But it is a 0.52 s visible sink and a 0.35×-thrust
window per reset, so the anchor Y is required rather than cosmetic.

### 3.8 Chase / menu-reel camera

At the 6.8 m crest: chase `focus.y+5` and orbit `focus.y+4.2` are relative and
safe; **trackside (3.4) sits 3.4 m below the road surface**, **cinematic (2.6)
sits 4.2 m below it**, flyover (`12 + 1.4 sin`) clears by only 3.8 m. These three
are the title-screen reel only (`game/race-camera.mjs:6`,
`RACE_DEMO_MODES`); in-match play uses `mode:'chase'` (`game/view.mjs:4223`).

---

## 4. Patch sketch — **NOT APPLIED**

Files and functions only. Nothing in this branch edits any of them.

### 4.1 `tools/godot-multiplayer/new-maps/stormglass-causeway/recipe.mjs`

```js
// new: one knot table + one height resolver, mirroring grade-plan/grade-profile.mjs
const GRADE_KNOTS = [0,0,0,0,0,0,0, 1.8,4.8,6.2,6.8,6.8, 6.4,5.8,5.0,4.2,3.4,2.6,1.8,0.9, 0];
const GRADE_ID = 'stormglass-causeway/grade-v1';
const ROAD_SUBDIVISIONS = 16;
const roadY = (i, t) => GRADE_KNOTS[i] * (1 - t) + GRADE_KNOTS[(i + 1) % GRADE_KNOTS.length] * t;

// mesh() gains an optional lift so every attachment rides the road:
const mesh = (id, vertices, triangles, material, collision = 'none', lift = null) => { … }
//   lift is (i, t) => roadY(i, t) or null for the exempt ocean

// line 33 `at()` gains the local road height, which fixes EVERY attachment at once:
const at = (i, t, lateral = 0, y = 0) => ({x: …, y: y + roadY(i, t), z: …});

// line 34 xyz() gains per-corner heights
const xyz = (p, y = 0, at = null) => at ? [p.x, y + roadY(at.i, at.t), p.z] : [p.x, y, p.z];

// line 47 road strip: 21 quads -> 21 * ROAD_SUBDIVISIONS sub-quads (T2)
for (let s = 0; s < ROAD_SUBDIVISIONS; s++) {
  const ta = s / ROAD_SUBDIVISIONS, tb = (ta + 1) / ROAD_SUBDIVISIONS;
  quad(`road-${i}-${s}`,
    [xyz(mix(outer[i], outer[j], ta), 0, {i, t: ta}),
     xyz(mix(inner[i], inner[j], ta), 0, {i, t: ta}),
     xyz(mix(inner[i], inner[j], tb), 0, {i, t: tb}),
     xyz(mix(outer[i], outer[j], tb), 0, {i, t: tb})],
    'asphalt', 'floor');
}
// lines 49 / 51-52 / 56 / 59 / 63-75 / 78-87 / 89-98: same `lift`, no new numbers (T3-T7)

// line 105 race data gains Y
gates[i] = {…gates[i], y: roadY(i, 0), y0: roadY(i, 0) - 0.25, y1: roadY(i, 0) + 3};
centerline[i] = {…centerline[i], y: roadY(i, 0)};
grid[i] = {…grid[i], y: roadY(i, tOfGridSlot)};
boundary.outer[i] = {…boundary.outer[i], y: roadY(i, 0)};   // needed by H4

// line 106 metrics stop reporting the concession
m.metrics = {…m.metrics, roadRelief: 6.8, maxGrade: 0.05874, gradeProfile: GRADE_ID};
m.race.gradeProfile = GRADE_ID;
```

### 4.2 `tools/godot-multiplayer/new-maps/stormglass-causeway/build.mjs:10`

```js
-import {ID,makeStormglass} from './recipe.mjs';
+import {ID,makeStormglass} from './recipe.mjs';
 import {canonical} from '../../../../port/multiplayer-worlds/catalog.mjs';
+import {terrainSupportAt} from '../../../../game/terrain.mjs';
-const wrapper={…, spawnPoints:arena.spawns.map(([x,z])=>({x,y:0,z})), arena};
+const wrapper={…, spawnPoints:arena.spawns.map(([x,z])=>({x,
+  y:terrainSupportAt(x,z,arena.terrain,arena.terrain.maxSlope)?.y ?? null, z})), arena};
// (copy the working pattern already in revision2/build.mjs:20)
```

### 4.3 `game/race.mjs` — four small edits, all defaulting to today

```js
 // (a) line 409 — the whole vehicle-height fix, mirroring game/soccer.mjs:22-27
-        next=>match.vehicleCollision(next,vehicle),()=>0);
+        next=>match.vehicleCollision(next,vehicle),
+        typeof match.vehicleGround==='function' ? (x,z)=>match.vehicleGround(x,z) : ()=>0);

 // (b) line 218 — per-gate window; identical to today when a gate has no y
-    if (t <= lastT || !Number.isFinite(y) || y < -.25 || y > 3 || Math.abs(…) > gate.halfWidth) break;
+    const y0 = Number.isFinite(gate.y0) ? gate.y0 : -.25;
+    const y1 = Number.isFinite(gate.y1) ? gate.y1 : 3;
+    if (t <= lastT || !Number.isFinite(y) || y < y0 || y > y1 || Math.abs(…) > gate.halfWidth) break;

 // (c) line 226 — bank the crossed gate's height
-    racer.anchor = {x: gate.x+gate.nx*.5, z: gate.z+gate.nz*.5, heading: Math.atan2(gate.nx,gate.nz)};
+    racer.anchor = {x: gate.x+gate.nx*.5, z: gate.z+gate.nz*.5,
+                    y: Number.isFinite(gate.y) ? gate.y : 0, heading: Math.atan2(gate.nx,gate.nz)};

 // (d) line 242 — respawn at the anchored height; line 161 uses grid[i].y
-  respawnVehicle(vehicle, {x:a.x,y:0,z:a.z}, a.heading);
+  respawnVehicle(vehicle, {x:a.x,y:a.y ?? 0,z:a.z}, a.heading);
-    vehicle.spawn = {x: grid.x, y: 0, z: grid.z};
+    vehicle.spawn = {x: grid.x, y: Number.isFinite(grid.y) ? grid.y : 0, z: grid.z};
```

No other line of `game/race.mjs` changes. `distance` stays XZ-only (R7), so the
stuck detector, pickup reach and `progress` are unaffected.

### 4.4 Presentation and tooling (same revision, not authority)

- `game/race-presentation.mjs:99` — `raceBarrierGeometry` takes per-point `y`
  instead of a hardcoded `0`; `:216-217` start line and grid slots use local road
  Y. Default `p.y ?? 0` keeps `puma-circuit` byte-identical.
- `game/race-camera.mjs:129,137,142` — the three absolute rigs add the local road
  height (menu reel only; `game/view.mjs:4223` in-match chase is untouched).
- `godot/tests/new_maps/stormglass_causeway/route_probe.gd` — road rays compare
  `absf(hit.position.y - authoredRoadY) <= 0.02`; the overhead ray starts at
  local road Y; keep the `>= 7 && <= 17` band by anchoring it to the road.
- `tools/map-variety-support/road.py:6` — `VERTICAL_BAND` becomes road-relative.
- New `revision3/` replacing `revision2/`'s flat assertions (C5).

---

## 5. Acceptance evidence a future grant must produce

Static, source-executable (re-derivable from the rebuilt candidate):

1. **Footprint diff** — a vertex-level XZ diff proving every road, barrier,
   structure, label, gate, navNode, route, spawn and grid slot is unchanged in
   plan position; only Y moves. Expected counts: **96 / 137** authority surfaces
   and **318 / 440** wall triangles move; **63 / 137** and **150 / 440** do not
   (sectors 0-6, 20). **6030 / 9682** art meshes move, **3725** do not.
2. **Support census** — `terrainSupportAt` at all 21 nodes, ≥ 20 interior points
   per sector and all 8 grid slots, with max \|support − authored\| **≤ 0.02 m**
   and every triangle normal `y > 0.99`.
3. **Containment census** — 63 probes at `r = 2.08387 m` beyond the actual mitred
   barrier, **63 / 63 blocked**, matching the flat baseline exactly.
4. **Gate completeness** — one ordinary-input lap with all 21 gates counted in
   order and a finish time; plus 9 elevated-gate crossings specifically, since
   those are the ones the shipped rule rejects.
5. **Reset at grade** — a reset on an elevated gate retains banked credit
   (`game/race.mjs:251`), respawns on support, and does not re-trigger
   `stuck > 3` (`game/race.mjs:434,436`).
6. **Chase-camera clearance** — in-match chase (`game/view.mjs:4223`) over the
   crest with no barrier, label or structure intersection, plus the three menu
   reel rigs re-shot at the crest.
7. **Motion accounting** — `godot/tests/…/route_probe.gd` re-run at the new
   geometry hash with a **new** `STORMGLASS_ROUTE_PROBE` record; old J/P/I
   evidence untouched and not relabelled.
8. **Spin-out / recovery** — a full-stock spin-out on the steepest sector
   (5.874%) with recovery, per the blueprint's own gate list.
9. **Fresh package** — new `layoutRevision: 3` + `gradeProfile` hashes, new
   `geometryHash`/`recipeHash`, new GLB/master/export hashes, and a **new**
   promotion receipt, because `recipe.mjs`/`build.mjs` hashes are pinned (C6).
10. **Registration unchanged** — `stormglass-causeway: ['puma-race']`, catalog
    13 worlds / 73 pairs, no new pair.

Runtime/native, which source-only work **cannot** substitute for:

- Godot `ConcavePolygonShape3D` slope behaviour on the 672 graded road triangles
  and the rebased barriers (`godot/multiplayer_worlds/map.gd:52-95` builds them
  generically but has never seen a graded Stormglass).
- Chase-camera feel and human lap times.
- Blender master/GLB re-export fidelity on 6030 moved art vertices.
- Receipt/package reconciliation and any production, capture or performance run.

---

## 6. Risk list

| risk | severity | evidence / mitigation |
|---|---|---|
| **Partial change ships** — road graded, barriers not | **critical** | measured: containment **63/63 → 3/63**. The four race-source edits and the recipe rebase must land in one versioned transaction |
| **Un-subdivided strip ridge** — a 0.2364 m support step under the wheels | **high** | measured; fixed by k = 16 (0.0110 m). Cheap, so there is no reason to accept the risk |
| **Ships with an unreachable gate** — 9 of 21 rejected, race uncompletable | **critical** | measured 12/21; fixed by the authored window. Assert 21/21 in source tests before any build |
| **Receipt invalidation** — `recipe.mjs`/`build.mjs` hashes pinned at `427d7d4b…` / `182ecaf1…` | **high** | `production_resources.mjs:26-33`. Requires a new receipt transaction; a partial one fails closed, which is correct |
| **revision-2 assertions break** | medium | `revision2/source.test.mjs:39-55` passes today (6/6) and asserts `roadRelief === 0`. Supersede with revision 3; do not edit the flat assertions away silently |
| **Reset fall** — 6.8 m sink over ~0.52 s per reset | medium | measured; fixed by the anchor Y. Not fatal (never ungrounded) but visible |
| **Menu-reel rigs below the road** — trackside −3.4 m, cinematic −4.2 m | medium | measured; presentation-only, but the first thing anyone sees on the title screen |
| **Route-probe / clearance band absolute Y** | medium | `route_probe.gd` and `road.py:6` both hardcode flat-world heights; both need the local road Y |
| **No gameplay differentiation from the grade** | medium, honest | speed delta is **exactly 0** by construction; only grip moves (−0.195%). If "variety" means *handling* variety, grade-v1 does not deliver it and a slope-resistance term is a separate proposal with its own balance review |
| **Bots are grade-blind** | low | `botControls` corner speed is curvature-only; no lift or brake for grade. Unchanged by design |
| **mode-matrix already red** | low, pre-existing | `mode-matrix.mjs:41` asserts 14 gates; Stormglass has 21. Reproduced on the base commit. Unrelated to grade; recorded, not fixed here |
| **Wire/snapshot growth** — `raceSnapshot` spreads gates verbatim (`game/race.mjs:203`) | low | two additive numbers per gate. Older clients ignore them; a protocol/version note belongs in the receipt |
| **Cosmetic ocean vs an 8.4 m sea-to-crest column** | low, art | ocean stays flat at −4 by design (T8); the elevated seaward edge needs a fascia/pier, which is a Level-A art task, not an authority one |
| **Mitred-edge asymmetry misread as a defect** | low | the inner edge is steeper than the centerline on most graded sectors (sector 20's ratio is 3.208, though flat). Grade caps are stated per edge, not per centerline |

### What cannot be validated source-only, stated plainly

- **Native physics on graded collision.** Everything above uses `game/` source
  arithmetic. Godot's own slope friction, its `ConcavePolygonShape3D` response
  on 672 road triangles and the rebased barriers are unmeasured.
- **Chase-camera and human feel.** The camera measurements are static rig
  arithmetic; no view was rendered and no human drove.
- **Lap times, race completion, spin-out recovery.** The 21/21 gate admission is a
  *predicate* measurement on synthetic sweeps, not a completed race.
- **Blender/GLB export.** 6030 art vertices would move; nothing was exported,
  imported or reopened.
- **Receipts, packaging, production and release accounting.** No receipt was
  written; C6 predicts exactly what a future one must replace.
- **Performance.** No benchmark of any kind was run.
- The **flat-road concession stands**. This document proposes how to retire it
  under one versioned grant; it does not retire it.

---

## 7. Analysis tooling and tests

New, source-only, under
`tools/godot-multiplayer/new-maps/stormglass-causeway/grade-plan/`:

| file | role |
|---|---|
| `README.md` | directory scope note |
| `grade-profile.mjs` | the authored knot table, limits, grade ledger, relief, gate windows, the proposed gate predicate, break amplitude and suspension-lag models |
| `grade-analysis.mjs` | builds the proposed graded world **in memory**, rebases terrain, drives the real `stepVehicle` over the real support query, and produces every number in §3 |
| `report.mjs` | prints §3 to stdout (`--json` for the raw object). Writes nothing |
| `grade-plan.test.mjs` | 30 bounded source tests |

Neither module imports `node:fs` or calls any write API; asserted by test.

```sh
node --test tools/godot-multiplayer/new-maps/stormglass-causeway/grade-plan/grade-plan.test.mjs
```

**Result on this branch: 30 tests, 30 pass, 0 fail.** Coverage: profile closure
and linearity; relief and knot-step caps; the 8% grade cap on all three edges per
sector; relief placement; bit-exact XZ footprint preservation (137 surfaces,
440 walls, all X/Z compared vertex-by-vertex); the `rebaseVertex` contract; the
ocean exemption; 449-point support agreement against the analytic ramp normal;
subdivision convergence and the 2 cm budget; node/grid support; gate admission
12/21 vs 21/21; the default-window equivalence with `crossRaceGates` over 13
probe heights; containment 63/63 vs 3/63; the Puma contact radius; zero speed
delta; grip equal to `8 × slopeGrip`; ledger reproduction from a driving run; the
sampler normal vs the analytic plane; grounded across every break; the vertical
envelope; `breakAmplitude`/`suspensionLag` monotonicity; a 400-step hand-driven
climb; the camera-rig relative/absolute split; no new mode; determinism; and the
no-write source scan.

Baseline recorded on the same worktree at `25c189bd`:

- `node --test tools/godot-multiplayer/new-maps/stormglass-causeway/revision2/source.test.mjs`
  → **6 tests, 6 pass** (unchanged by this branch).
- `node port/multiplayer-worlds/mode-matrix.mjs` → **already failing**,
  `AssertionError: 21 !== 14` at `mode-matrix.mjs:41`.

This worktree has **no `node_modules`**, so the repository's own suites
(`npm run test:game`, `npm run typecheck`, `npm run lint`) could not be run here
and are **not** claimed. The grade-plan tooling and its tests deliberately depend
on nothing but Node builtins (`node:test`, `node:assert`, `node:fs`) and
committed repo modules, so they run in a bare checkout.