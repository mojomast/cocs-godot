# Map variety revision blueprint — Gravemill Foundry, Abyssal Pressureworks, Stormglass Causeway

**Status:** source-only audit + production design. No engine, Blender, import, server,
benchmark, API call, bake or render ran. Nothing in `godot/` or `port/native-multiplayer-worlds/`
was modified. This is one new parent doc only.

**Canonical:** `55edd9f28a7ae059ca8dc4f96c20acb9d53629b7` (branch `feature/relay-campaign`).
Read-only audit target. This report does **not** commit, stage or promote anything.

**Ownership (do not cross):**

| Scope | Owner | Notes |
|---|---|---|
| Grants, ranking, relay of resource requests | parent session (this report's caller) | owns the actual Blender grant |
| New Moth API resources + generic `mothbake` | Astra `ses_efdbb8a90ffeBrpRZAFfraUSXv` | must finish **before** any application |
| Helix / Parallax / Vesper | independent other Flash | **not touched here** |
| Stormglass package / runtime | `ses_f03437da1ffeli91L87Q6CVyRP` (package), `ses_f03a3885fffehx9yFhHubuPCft` (native motion/UI, grant K), `ses_effc08498ffeMuhuRDvyAoXEpj` (SOL vehicle) | existing P/J acceptance frozen |
| Abyssal | grant I released, package registered | revision needs a fresh grant |
| This audit + blueprint | this Flash subagent (source-only) | deliver to parent for YOU/SOL once Blender grant assigned |

**Frozen and not to be touched:** the existing Stormglass J acceptance
(`port/finish/STORMGLASS_PARENT_REVIEW.md`, `STORMGLASS_PACKAGE_PROMOTION.md`), the Abyssal I
acceptance (`port/finish/ABYSSAL_PACKAGE_PROMOTION.md`), `tools/godot-package/*_inventory.json`,
all `production_receipts/`, and the current three public mode registrations. A revision is a
**new** layout revision with **fresh** native evidence; it never restamps old native production.

---

## 1. Generation entrypoints and authority map (exact paths)

### Shared finish / queue / packaging
- `tools/asset-production/moth_finish.py` — grant-only finisher `finish_scene(root, unit)`. Fixed
  attachment-local UV (`MothLocal`), real baked albedo modulation + tangent normal, ≤64 source
  materials, role table `MATERIAL_ROLES` keyed by unit id.
- `port/finish/ASSET_PRODUCTION.json` + `.md` — executable queue (units, commands, budgets, evidence root).
- `tools/asset-production/run.py` — serial non-waiting lock, one stage per grant.
- `tools/asset-production/package-receipt.mjs`, `receipt.mjs`, `candidate-contract.test.mjs`.
- `tools/godot-package/abyssal_imports.mjs`, `stormglass_imports.mjs`, `production_resources.mjs` — strict inventories/verifiers.
- `godot/multiplayer_worlds/map.gd` — **the authority/runtime rule**: JSON gameplay geometry owns
  physics; GLB nodes are `BlenderArtNoGameplayCollision` (art only). `art_covers_surfaces` hides the
  source surface draw when the GLB covers it.

### Gravemill Foundry (currently the one good "authored districts" precedent)
- Authority recipe: `tools/godot-multiplayer/new-maps/gravemill-foundry/revision3/recipe.mjs`
  (re-exported by `.../recipe.mjs`; base retained in `checkpoint-recipe.mjs`).
- Geometry build: `.../revision3/build.mjs` → writes `port/native-multiplayer-worlds/worlds/gravemill-foundry.json`,
  `godot/multiplayer_worlds/generated/worlds/gravemill-foundry.json`, `godot/multiplayer_worlds/generated/gravemill-foundry.json`,
  `godot/tests/new_maps/gravemill_foundry/probes.json`.
- Blender author: `.../revision3/author.py` (substitutes strings into `checkpoint-blender.py` then `exec`s it);
  entry `.../blender.py`. Promotion: `.../revision3/promote.mjs`.
- Runtime geometry hash: `8ebb148f209aca14c54246517f7332a18e5fbb5c68f7b607d980f5664fcde25f`
  (already promoted, commit `cae7cda7`). Structures 2, routes 10, nav 1026, surfaces 334, walls 2320.
- **Gap:** `checkpoint-blender.py` never imports or calls `moth_finish.finish_scene`, and
  `gravemill-foundry` has no entry in `moth_finish.MATERIAL_ROLES`. Its real GLB embeds **0 images**
  (8 meshes / 8 materials / 8 nodes), unlike Abyssal (5 PNGs) and Stormglass (11 PNGs). It relies on
  `godot/multiplayer_worlds/dressing/profiles/gravemill-foundry.json` for surface detail.

### Abyssal Pressureworks
- Recipe: `tools/godot-multiplayer/new-maps/abyssal-pressureworks/recipe.mjs`.
- Build: `.../build.mjs` → `port/native-multiplayer-worlds/worlds/abyssal-pressureworks.json` +
  `godot/multiplayer_worlds/generated/abyssal-pressureworks.json`.
- Blender author: `.../blender_author.py` (calls `finish_scene(ROOT,'abyssal-pressureworks')`).
- Runtime geometry: `32366a6c3df7f95f8d89281c5f83b24d9583cefeb4c0099790303d15349b53be`.
  252 surfaces / 796 wall tris / 165 solids; GLB 32,500 tris, 7 batches, 2,210,172 bytes, 5 PNGs.

### Stormglass Causeway
- Recipe: `tools/godot-multiplayer/new-maps/stormglass-causeway/recipe.mjs`.
- Build: `.../build.mjs` → 3 JSON files (`port/native-multiplayer-worlds/worlds/`, `godot/multiplayer_worlds/generated/worlds/`,
  `godot/multiplayer_worlds/generated/`).
- Blender author: `.../blender_export.py` + `architecture.py` (calls `finish_scene(ROOT,'stormglass-causeway')`);
  reopen verify `--verify-only`.
- Runtime geometry: `6afb8a36ee954ff9457a5522a7412c809191fb070eb7fe9eda4d379753acce48`.
  137 surfaces / 440 wall tris / 21 routes / nav 207; GLB 56,552 tris, 9 batches, 3,901,880 bytes, 11 PNGs.

### Existing masters / real exports (audit read)
| Asset | Path | Bytes | SHA-256 (head) |
|---|---|---:|---|
| Foundry master | `tools/godot-multiplayer/new-maps/gravemill-foundry/gravemill-foundry.blend` | 40,527,432 | `c7a7551cd45bae86…` |
| Abyssal master | `tools/godot-multiplayer/new-maps/abyssal-pressureworks/masters/abyssal-pressureworks.blend` | 19,087,887 | `0b450d5a…` (matches I) |
| Stormglass master | `tools/godot-multiplayer/new-maps/stormglass-causeway/stormglass-causeway.blend` | 74,318,785 | `970d244fbec4d352…` (matches J) |
| Foundry GLB | `godot/multiplayer_worlds/art/worlds/gravemill-foundry.glb` | 3,744,260 | `46bf1648b32d23e3…` |
| Abyssal GLB | `…/abyssal-pressureworks.glb` | 2,210,172 | `fa6888d1…` (matches I) |
| Stormglass GLB | `…/stormglass-causeway.glb` | 3,901,880 | `ff318582…` (matches J) |

---

## 2. Moth pack currently available (so we do not over-request)

`godot/moth/generated/manifest.json` (31 textures, 13 baked normals, 5 skies, 5 LUT pairs, 10 effects)
and `godot/moth/derived/manifest.json` (38 derived: 24 data, 12 normals, 2 masks). Relevant reusable
slots:

- Concrete: `weathered_concrete`, `-worn`, `-damp` (+derived normals 0.42/0.34), `rough_stucco-weathered`.
- Metal/alloy: `metal` (baked normal), `brushed_metal`, `metal-oxide` (derived normal 0.44),
  `riveted_armor` (derived 0.55), `riveted_armor-scorched` (derived 0.50), `corrugated_metal` (baked normal),
  `diamond_plate`, `metal_grating`.
- Stone/organic: `rock` (baked normal), `rock-moss` (derived 0.60), `sand` (baked normal), `grass`, `macro-organic`.
- Panels/marks: `hex_paneling`, `hex_paneling-mottle` (derived 0.30), `carbon_fiber`,
  `circuit_board-etch` + `circuit_board` mask, `hazard_stripes` + mask.
- LUTs: `entanglement`, `-arcane`, `-ceramic`, `-ember`, `-void`. Skies: `ashen`, `ember`, `frost`, `nebula`, `void`.
- Preserved (no finish): `glass`, `water`, `ocean`, `cyan`, `amber`, `letter`.

Moth material roles already registered in `moth_finish.MATERIAL_ROLES`:
`abyssal-pressureworks` = navy/ivory/coral/copper; `stormglass-causeway` = asphalt/concrete/salt/brick/teal/steel.
`gravemill-foundry` is **absent** and must be added before it can use the shared finish.

---

## 3. Current-state audit: where the repetition actually is

### 3.1 Stormglass Causeway — flat road + serial modules (primary problem)
- `recipe.mjs:106` records `roadRelief:0, architectureRelief:24`; road width is a constant 28,
  barrier at ±14, shoulders at ±11.5 every 8 m, reflectors every 5 m (`recipe.mjs:45-56`). The road is
  Y=0 everywhere.
- `recipe.mjs:61-75`: each sector `i` emits 3 modules `district-i-k` with the *same* body
  (`14 × h × len/3-3`), the *same* story×bay window grid, the *same* pier/sill/cornice/roof-machinery
  pattern. Height only selects `{16,22}` (terminal) or `8+(i%3)*3` (quay). 31 structures total.
- Gates at `i ∈ {1,14,18}` are byte-identical (`recipe.mjs:89-98`).
- `architecture.py:41-45` repeats `tidewall` / `salt-tidemark` / `raking-buttress` per edge;
  `:47-51` repeats `light-mast` every 15 m; `:83-88` regular hall buttress/glazing grid;
  `:95-105` identical observatory plinth/glass/crown.
- Parent-recorded visual limits (`STORMGLASS_PARENT_REVIEW.md:9-17`): "hard rectangular ocean boundary
  and sparse/repeated exterior silhouettes; dark wall and tunnel contrast remain visual limitations";
  "**explicit flat-road concession: source drivable relief is zero** … This delivery contributes a
  circuit race, not the requested vertical traversal variety by itself."

**Native "before" cameras** (`godot/tests/new_maps/stormglass_causeway/inspection.gd:49-56`; images under
`cocs-expansion-four-stormglass-evidence-20261002/production-j/*-representative/`):
| view | eye | target |
|---|---|---|
| overview | `(-350,320,-330)` | `(-35,0,5)` |
| terminal | `(-108,3.4,-133)` | `(-5,9,-120)` |
| freight-bore | `(150,3.4,22)` | `(138,7,70)` |
| quay-chicane | `(45,3.4,145)` | `(-45,8,133)` |
| surgeworks | `(-183,3.4,101)` | `(-207,13,47)` |
| return-gate | `(-118,3.4,11)` | `(-72,13,-28)` |

### 3.2 Abyssal Pressureworks — 12 cloned room interiors
- `recipe.mjs:19-57`: 3×4 vessels from one template. Row changes name/silhouette/roof scale, but every
  one of the 12 gets the identical prop set at the identical offsets: `workstation-±`, `equipment-±`,
  `bay-screen-±`, `bay-canopy-±`, `overhead-rib-±`, `instrument-±`, `rib-±`. Roof is always the same
  8-facet fan to a crown.
- `connect()` (`recipe.mjs:58-70`): 17 identical galleries (widths 10/14, height 7).
- `recipe.mjs:74`: 9 reefs on a perfectly even line `x=-110+i*27`; `blender_author.py:200-204`:
  8 escarpment beds at `x=-112+i*32`.
- Recorded limitation (`port/expansion-three/abyssal/PRODUCTION_I.md:77`): "Overall room-shell
  repetition remains a parent art-review consideration."

**Native "before" cameras** (`godot/tests/new_maps/abyssal_pressureworks/inspection.gd:52-65`);
`cocs-expansion-three-abyssal-evidence-20261002/production-i/20261003T044433.844034Z-representative/`):
overview `(-178,174,182)→(0,10,0)`; equalizer `(23,11.65,-11)→(44,24,8)`; reef-window `(-94,7.65,-70)→(-94,9,-101)`;
plus pump-spine/operations-gallery/maintenance-bypass/reactor-overlook and 12 room interiors at
`(room.x-5, room.y+1.65, room.z-3) → (room.x+8, room.y+3, room.z+12)`.

### 3.3 Gravemill Foundry — districts authored, secondary props still cloned
- `checkpoint-recipe.mjs` clones: `filter-bank` at 6 X values (same `cylinder(4.2,10)`);
  `ore-hopper-x` 6 identical 9×8×3.5 prisms; `maintenance-incline-x` 4 identical 7 m routes;
  `ore-bin-x-q` 5×3×1.5 at 3 Q rows (~16 identical bins); `fracture-` rocks from one outline template.
- `revision3/recipe.mjs` already differentiates **districts** (crusher house, closed cooling works,
  asymmetric assay control rooms, brick kiln district; `art.revision3` in the runtime JSON). This is the
  model to extend, not replace.
- **Real-export gap:** GLB embeds no textures and bypasses `moth_finish`.

**Native "before" cameras** (`godot/tests/new_maps/gravemill_foundry/inspection.gd:36-49`):
overview `(275,230,-290)→(0,12,0)`; reverse `(-270,160,220)→(0,12,0)`;
crusher-eye `(-94,1.45,-51.16)→(-49,8,-27)`; crusher-maintenance `(-88,11.53,4.68)→(-65,14,-8)`;
cooling-eye `(-82,13.45,24.52)→(-46,16,29.56)`; cooling-cross-aisle `(-66,13.45,26.76)→(-82,17,17.52)`;
assay-eye `(48,13.45,42.72)→(85,17,47.9)`; assay-inspection `(66,13.45,45.24)→(72,14.5,51)`;
assay-room-centered `(66,13.45,45.24)→(80,19,48)`; crown-eye `(-101,25.45,94.86)→(55,25,116.7)`;
furnace-eye `(88,1.45,-25.68)→(64,10,-10)`; transfer-eye `(0,1.45,-64)→(27,5,-58)`.

---

## 4. Two-level revision model (applies to all three maps)

**Level A — visual, non-collision mesh (GLB, art only).**
- Exported exactly as today: `godot/multiplayer_worlds/art/worlds/<id>.glb`, loaded by `map.gd` as
  `BlenderArtNoGameplayCollision`. Never participates in `terrainTriangles`, `terrainWallTriangles`,
  `terrainSupportAt`, `floorAt`, `visible`, `rayWorld` or `vehicleCollision`.
- Versioned by: `visualRevision` (integer, new key in `arena.art`) + GLB SHA-256 + export report.
- May change silhouette, materials, props, and background relief **only outside** the authoritative
  support/nav envelope. A pure Level-A revision does not change `geometryHash` traversal behaviour and
  must not claim new traversal.
- Existing art coverage rule stays: `art_covers_surfaces` in `map.gd` is unchanged for these maps.

**Level B — actual geometry layout revision (JSON authority).**
- Changes `arena.terrain.surfaces` (walkable + non-walkable), `arena.terrain.walls`, `arena.blocks`,
  `arena.navNodes`, `arena.spawns`/`teamSpawns`/`flagSpawns`, `objectiveZones`, `routes`, and for
  Stormglass `arena.race` (centerline/gates/grid/boundary/metrics).
- Versioned by: `layoutRevision` (integer) + the recomputed canonical `geometryHash` (64 hex). Any
  change to Level B requires rebuilding the wrapper so `readWorld`'s
  `data.geometryHash === sha256(canonical(arena))` invariant holds.
- Requires: `terrainTriangles`/`terrainWallTriangles` valid, `readWorld` spawn/objective/team/flag
  support checks, `nav` connectivity, body-contact/window/ceiling probes, and (for vehicles) a vehicle
  support/clearance probe. Fresh native evidence only.

**Hard rule:** a Level-A-only delivery must be labelled "varied background, no traversal change".
Do not claim varied traversal for static background.

---

## 5. Blender asset class catalog (18 classes, 6 per map)

Common geometry rules for every class (fixes the current flat-box/beam look):
- **Bevel:** 2-segment bevel, ~0.03–0.06 m on hard edges (hero 0.06, kit 0.03), clamp overlap.
- **Normals:** Weighted Normal modifier, `shade_smooth_by_angle` 35° (35–40°); no custom split normals
  that break tangents. All hard industrial surfaces keep authored bevel highlights under raking light.
- **UV:** unique non-mirrored islands per variant; `MothLocal` per connected component with stable
  phase (already implemented by `moth_finish.uv_project`); texel density from `FAMILIES[role][3]`.
  No mirrored/negative-scale UVs (they flip tangent handedness).
- **Tangents:** export UV channel 0; Godot import must show `tangents == vertices*4` (verified by
  `inspection.gd` stream audit). Normal maps only on relief roles.
- **Collision:** visual-only unless an authority proxy is named. Proxies are authored in Level B
  (walls/blocks/surfaces), never inferred from the GLB.
- **Instancing:** kit variants exported once; repeated placement via a new map-scoped instancer
  (see §7). Hero forms are single meshes.

Budget summary: Foundry ≤150,000 tris / ≤16 export nodes / ≤12 materials / GLB ≤7 MB;
Abyssal ≤90,000 tris / ≤12 batches / GLB ≤5 MB; Stormglass ≤180,000 tris / ≤14 batches / GLB ≤9 MB.
Top-level per hero ≤10,000 tris; per kit variant ≤4,000; per instanced span ≤2,000. Draw target
≤64 per map at 1280×800 (existing 48-config ceiling retained for Abyssal).

### Gravemill Foundry
| # | Class | Role | Variants | Hero form / normals | Moth slots | Placement / instancing | Authority proxy | Tri |
|---|---|---|---|---|---|---|---|---|
| G1 | Headframe / gantry tower | hero | 3 (crusher, cooling, kiln) | A-frame lattice + sheave wheel + hook block; bevel 0.06, WN 35° | `riveted_armor`+`brushed_metal`+`metal-oxide`; `hazard_stripes` band | at existing silo/conveyor landmarks; hero mesh | 4 leg blocks only | 6–9k |
| G2 | Smelter furnace battery | hero | 3 | cladded furnace shells + tap-hole platform + launder + stack | `riveted_armor-scorched`+`metal-oxide`+brass(copper) | replaces furnace-a/b + ore-silo silhouettes | radial shell + tap platform block | 8–12k |
| G3 | Loading dock + rail gantry + tipple | hero | 3 (crusher dock, kiln dock, transfer) | covered tipple over rail, truck apron, columns | `corrugated_metal`+`weathered_concrete-worn`+`brass` | kiln/crusher aprons; hero mesh | columns + canopy block; lane kept clear | 7–10k |
| G4 | Conveyor trestle kit | kit | 4 span + 2 head/tail | lattice truss + belt + rollers | `metal_grating`+`metal-oxide`+rubber(new) | exactly on the 6 existing conveyor landmarks; MultiMesh | trestle legs only | 1.5–3k/span |
| G5 | Ore bunker / hopper cluster | kit | 4 (surge bin, cone hopper, live-bottom, stockpile) | ribbed bins + chute + retaining walls | `rock`/`rock-moss`+ore(new)+`weathered_concrete` | replaces 6 cloned hoppers + ~16 cloned bins; varied rotation | bin boxes | 2–4k |
| G6 | Crusher drum + drive house | hero | 2 | toothed drum + gearbox + motor house | `metal`+`riveted_armor-scorched`+`hazard_stripes` | existing crusher landmarks | radial drum + base block | 5–8k |

### Abyssal Pressureworks
| # | Class | Role | Variants | Hero form / normals | Moth slots | Placement / instancing | Authority proxy | Tri |
|---|---|---|---|---|---|---|---|---|
| A1 | Pressure vessel shell | hero | 3 district forms (splayed observation vault, tall ribbed vessel, low faceted habitat) | unique faceted shells, ribs + crown | `navy`(damp concrete)+`ivory`(stucco-weathered)+`coral` | replaces cloned 8-facet roof on ≥6 of 12 vessels | shell walls already in source | 6–10k |
| A2 | Wet service cave manifold | hero | 3 pressure ratings | valve tree + pump skid + drip curtain (no collision) | `copper`+`metal-oxide`+concrete | side bays, 3 vessels each district | skid block + valve cage | 4–6k |
| A3 | Pipe bridge / trestle | kit | 4 (straight, elbow, expansion loop, catwalk) | lagged pipe runs + truss | `copper`+`steel`(brushed_metal)+`coral` lagging | above galleries y+7.2; MultiMesh | elbow stanchions only (no head obstruction) | 2–4k/span |
| A4 | Observation blister | hero | 3 sizes | faceted glazing + frame + sill/lintel | glass(preserve)+`ivory`+`copper` | observation ends of rows 0/1 | frame only; glass non-blocking (existing policy) | 3–5k |
| A5 | Equalizer reactor crown | hero | 1 | segmented casing + gauges + 5 bands + cap | `copper`+`metal-oxide`+amber/cyan emissive | single landmark at `(x+10,y,z+8)` | core block + cap surface | 6–9k |
| A6 | Reef / escarpment buttress | background hero | 5 (coral branch, faceted buttress, silt fan, vent chimney, anchor leg) | irregular faceted geology | `rock`/`rock-moss`+seabed(new)+`coral` | replaces the even `x=-110+i*27` line; outside dry hull | none (non-traversal) | 3–8k |

### Stormglass Causeway
| # | Class | Role | Variants | Hero form / normals | Moth slots | Placement / instancing | Authority proxy | Tri |
|---|---|---|---|---|---|---|---|---|
| S1 | Seawall retaining module | kit | 5 height (3–12 m) + 2 copings + raking buttress | battered wall + weep holes + coping | `weathered_concrete-damp`+`weathered_concrete-worn`+salt(new) | outside ±14 m barrier; MultiMesh with varied height/seed | **none** — existing 2.8 m barrier stays authority | 1.5–3k |
| S2 | Grandstand / terrace module | kit | 4 | tiers + crowd rail + canopy | `weathered_concrete`+`brick`+`salt` | infield/streetside, outside road envelope; MultiMesh | none (visual) | 2–4k |
| S3 | Cliff stair / switchback kit | kit | 4 (flight, landing, cantilever, arched underpass) | coastal masonry switchbacks | `weathered_concrete-worn`+`salt`+`brick` | coastal shelf outside barriers; MultiMesh | none (visual) | 1.5–3k |
| S4 | Gatehouse / checkpoint arch | hero | 3 (gates 1/14/18) | masonry arch + signals over the existing gate | `brick`+`salt`+`steel` | on existing gates; keep 28 m clear / 9 m high | existing buttress blocks; opening unchanged | 5–8k |
| S5 | Lighthouse / observatory tower | hero | 1 | base + gallery + lamp room + radar | `salt`+`brick`+`teal`+glass(preserve) | replace the observatory crown | base block | 7–10k |
| S6 | Quay crane / dockside gantry | kit | 3 (portal, cantilever, rail gantry) | boom + counterweight + rails | `steel`(brushed_metal)+`metal-oxide`+`hazard_stripes` | quays outside barriers; MultiMesh | none (visual; rail optional) | 2–4k |

**Moth normal/tangent table:** relief roles on concrete/metal/stone classes require a normal map and
`tangents == vertices*4`; `coral`, coating, and glass roles keep geometry normals (no normal map).
This matches the existing `inspection.gd` assertions for Abyssal (`copper` normal only) and Stormglass
(`asphalt/concrete/salt/brick/steel` normals; `teal` none).

---

## 6. Stormglass terrain: the decision

The frozen race authority currently forbids honest drivable relief:
- `game/race.mjs:184` rejects a gate crossing when `y < -.25 || y > 3`.
- `game/race.mjs:208` respawns at `{x:a.x,y:0,z:a.z}`.
- `game/race.mjs:303-305` calls `stepVehicle(..., ()=>0)` — the ground callback is a constant 0, so
  vehicle support does not consume terrain Y.
- `godot/tests/new_maps/stormglass_causeway/route_probe.gd` asserts `absf(hit.position.y) < 0.001`
  for every road support ray.
- Puma envelope (from `DESIGN.md`): chassis 3.6×2.1×1.7, race pair radius 1.7 m, world radius
  2.08387 m, sampled full-steer radius 5.87 m.

**Plan A (safe, no authority change) — chosen default unless parent authorizes Plan B.**
Author the coastal relief as Level-A scenery outside the barriers: near-vertical cliffs, retaining
walls, switchback stair terraces, elevated grandstand/viaduct silhouettes and a bounded harbour. The
road stays exactly Y=0. This directly answers "varied terrain if playable change is not authorized"
and is honest: **varied scenery, not varied traversal**. Keep `puma-race` as the sole mode.

**Plan B (playable drivable relief) — only with an explicit parent authority grant, one revision.**
All of the following must change together and be re-proven; no partial claim:
1. `game/vehicles.mjs` `stepVehicle`: consume the collision callback's Y as terrain support (slope,
   wheel contact) instead of ignoring it. `game/multiplayer_worlds/map.gd` already supplies exact
   triangle collision, so support geometry is available.
2. `game/race.mjs:303-305`: pass `next=>terrainSupportAt(next.x,next.z,arena.terrain,arena.terrain.maxSlope)?.y ?? 0`
   (or `match.vehicleCollision`) instead of `()=>0`.
3. `game/race.mjs:184`: replace the absolute `y < -.25 || y > 3` with a per-gate authored window
   (`gate.y0/gate.y1` computed from the local road Y); default preserves the old rule for all other maps.
4. `game/race.mjs:208` + `:192`: store the gate anchor `y` and respawn at `anchor.y ?? 0`.
5. `recipe.mjs`: author a constrained elevation profile (grade ≤ ~8% / camber ≤ ~2.5°), emit graded
   walkable road strips with `terrain.surfaces` Y, and attach Y to `race.centerline`, `race.gates`,
   `race.grid`, `race.boundary`; `build.mjs` computes `spawnPoints` via `terrainSupportAt`.
6. `route_probe.gd`: compare against the authored local road Y (±0.02), not `< 0.001`; overhead check
   uses local road Y; add wheel-clearance and checkpoint-height assertions.
7. Fresh Level-B revision hash + fresh native evidence. Keep exactly `stormglass-causeway: ["puma-race"]`.

Plan B must pass: one continuous ordinary-input lap at grade, a full-stock spin-out/recovery, reset at
elevated checkpoint with retained gate credit, barrier contacts at the new heights, and vehicle
clearance (no chassis clipping on grade transitions). Until then, Plan B stays unclaimed.

---

## 7. Instance/placement and runtime hook strategy

- Kits are exported once per variant in Blender and placed many times. To avoid per-copy draw calls,
  add a **new map-scoped** file `godot/multiplayer_worlds/kit_instancing.gd` (not a change to
  `map.gd`), gated to the three map ids, reading a versioned `arena.art.kits` table
  (`{kit, variant, transform[], material}`) and instancing the GLB mesh via
  `MultiMeshInstance3D` (one draw per kit+material). `map.gd` gains at most a single additive call
  after `Dressing.apply(...)`, or the instancer is attached from the map's presentation path. This
  keeps Helix/Parallax/Vesper and all accepted maps byte-identical.
- Placement rules: never place a kit inside a nav corridor or over a nav node; background kits sit
  outside `bounds`/behind barriers; heroes get a reserved footprint matching their Level-B proxy.
- Occlusion/camera safety: every placement is checked against spawn cylinders (Puma r=1.7 m,
  infantry r=0.42 m) and the chase-camera corridor (boom 4–6 m behind, 2–3 m up at eye height) during
  acceptance; no class may intersect a spawn or camera corridor.

---

## 8. Resources needed from the Astra pack (ranked requests for parent to relay)

Existing Moth slots cover most of the albedo needs. These are the genuine gaps; each is a request for
Astra to create as an actual API resource and export through the updated generic `mothbake`, **before**
application. Parent ranks/owns the ask.

| P | Request | Form | Used by | Why existing is insufficient |
|---|---|---|---|---|
| 1 | `rock-seabed` (wet basalt / pillow lava) | 64² albedo + normal | A6, Abyssal escarpment | `rock`/`rock-moss` read dry; `sand` is too soft |
| 2 | `concrete-salt` (brine/salt encrusted) | 64² albedo + normal + data | S1, S2, S3, quay | `weathered_concrete-damp` is wet, not crystallised |
| 3 | `copper-patina` (verdigris) | 64² albedo + normal | A2, A3, A5 | `metal-oxide` is iron rust, wrong hue |
| 4 | `steel-forge` (mill scale + soot) | 64² albedo + data | G1, G2, G3, G6 | `riveted_armor-scorched` is armour, not process steel |
| 5 | `ore-aggregate` (crushed ore/tailings) | 64² albedo + normal + macro | G5, Foundry stockpiles | no aggregate/material-pile slot exists |
| 6 | `timber-weather` (dock plank) | 64² albedo + normal | G3, Stormglass quay | no wood/plank slot exists |
| 7 | `rust-layered` (flaking layered rust) | 64² albedo + normal + mask | all three | `metal-oxide` lacks flake mask/edge wear |
| 8 | `seawater-surface` | 64² normal + flow | Stormglass cosmetic ocean | `ocean` is preserved flat; no animated normal |
| 9 | `paint-industrial` set (teal/amber/ivory) with `paint-chip` mask | 3× albedo + 1 mask | S2, S4, A2, G6 | current paint is a flat `diffuse_color`, no chipping |
| 10 | `glass-grime` (streaked/edge-dirty) | 64² albedo + roughness | S5, A4 | `glass` is fully preserved (no wear) |
| 11 | `calcite-barnacle` decal | 64² mask + normal | S1, A6 | no encrustation detail |
| 12 | `cable-rubber` (belt/lagging) | 64² albedo + data | G4, A3 | no rubber-belt/lagging slot |
| 13 | `sky-storm` coastal squall + `sky-abyss` | 128×64 equirect each | Stormglass, Abyssal | skies are ashen/ember/frost/nebula/void only |
| 14 | 2 new LUT pairs (`-verdigris`, `-brine`) | LUT pair | Abyssal metal, Stormglass salt | current LUTs are ceramic/ember/void/arcane |

Also required on the pipeline side (not a texture): add `gravemill-foundry` to
`moth_finish.MATERIAL_ROLES` so its GLB can carry `MothLocal` textures like the other two. That is a
`tools/asset-production` change owned by the finish lane, gated on the shared finish being run.

---

## 9. Acceptance plan (what "done" means; all fresh, no old native reuse)

Source-only (safe now, no engines):
- `node tools/godot-multiplayer/new-maps/gravemill-foundry/revision3/build.mjs` (and `--check`)
- `node tools/godot-multiplayer/new-maps/abyssal-pressureworks/build.mjs --check`
- `node tools/godot-multiplayer/new-maps/stormglass-causeway/build.mjs --check`
- `node --test tests/new_maps/abyssal_pressureworks/source.test.mjs`
- `node --test godot/tests/new_maps/stormglass_causeway/source.test.mjs`
- `node tools/godot-multiplayer/new-maps/gravemill-foundry/revision3/architecture-check.mjs`
- `node --test tools/asset-production/candidate-contract.test.mjs tools/asset-production/consolidation.test.mjs`
- Python AST parse of every author script.

Grant-gated (only after an explicit Blender slot; parent assigns):
- Foundry: build/reopen + native `inspection.gd`, `physics_probe.gd`, `journey.gd` for the 6 modes.
- Abyssal: build + `map_probe.gd --map=abyssal-pressureworks`, then hosted mode journeys.
- Stormglass: build + reopen `--verify-only` + `route_probe.gd`, then hosted `puma-race`.
- Package receipt + strict inventory verifier per unit.

Mandatory per revised map:
1. **Walk support:** every nav node and spawn resolves via `terrainSupportAt`; `readWorld` spawn/objective/
   team/flag checks pass; no floor gaps.
2. **Vehicle support (where used):** Puma mounted lap with wheel/ground contact; `vehicleCollision`
   returns a finite resolved position; no chassis clipping on grade/camber (Plan B only).
3. **Navigation:** one connected component covering all spawns/flags/objectives; every nav edge
   walkable; nav-safe placement (no prop over a node).
4. **Checkpoint:** gate crossing advances exactly once, in order; reset preserves earned credit
   (Stormglass); objective zones resolve on support.
5. **Vehicle clearance:** barrier contacts at the new heights (Stormglass 42 faces × infantry r=0.42
   and Puma r=2.08387); vertical clearance under vaults/ceilings ≥ config.
6. **Mode registration:** catalogs unchanged — Foundry 6, Abyssal 6, Stormglass only `puma-race`.
   No new unproven pair. Wrapper `geometryHash` matches `canonical(arena)`.
7. **No spawn occlusion / camera:** no new mesh intersects a spawn cylinder or the chase-camera
   corridor; spawn/team/flag/objective sightlines validated.
8. **Budgets:** tri/node/material/GLB ceilings in §5; imported streams show correct UV and tangents
   for relief materials, none for coatings/glass.
9. **Fresh evidence:** new `layoutRevision`/`visualRevision` hashes, new native capture set at the §3
   camera coordinates plus the new district hero shots. Old P/J/I evidence untouched.

---

## 10. Recommended sequence (post-grant, one serial lane)

1. Astra completes the requested Moth resources + generic `mothbake` update. (blocks everything)
2. Finish lane adds `gravemill-foundry` to `moth_finish.MATERIAL_ROLES`; source tests updated.
3. Level-A pass per map in Blender (new classes, bevels, WN, non-mirrored UV, `MothLocal`), exported
   to versioned GLBs; no Level-B change. Native art inspection only.
4. Level-B pass per map (authored districts/relief, authority surfaces/walls/blocks/nav/routes; for
   Stormglass Plan A now, Plan B only if separately granted), rebuilt wrappers + probes.
5. Source suites + native probes + hosted mode journeys; package receipts; parent review.
6. Only then a package promotion. No engines before step 3's explicit grant.

**Open decisions for the parent:** (a) authorize Stormglass Plan B drivable relief or keep Plan A
scenery-only; (b) confirm the Astra resource ranking; (c) assign the implementation owner (YOU or SOL)
and the exact Blender grant id; (d) confirm whether Gravemill should join the shared Moth finish
(adds embedded textures, changes its GLB identity and its dressing profile).
