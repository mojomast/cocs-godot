# Vesper stair bevel rebuild (2026-10-05)

Branch `spacebunny/vesper-bevel-rebuild-20261005`, from `f38d4a7d`.
Applies the reviewed bevel of
`port/finish/map-variety/VESPER_STAIR_COLLISION_PROPOSAL_20261005.md` §4 to both
Vesper recipes, rebuilds the accepted runtime world from source, and records
what the source-only verification actually shows.

**Headline: the geometry goal is met and the guard claim is confirmed for the
rebuilt run, but this branch is NOT promotable.** The production source-only
mover loses ground on every civic trial, and the candidate chain cannot be
rebuilt at all. See §7 and §9. Nothing here is a native claim; no engine,
Blender, native run, receipt or promotion was performed.

---

## 1. Applied change

`STAIR_BEVEL = 0.043438367470067386`, the float64 `3fa63d8dbf59e445`, i.e. the
midpoint of the admissible window `[0.041422, 0.045455] m`. 45 degree chamfer,
ascent (`-Z`) face only, all 94 treads.

### `tools/godot-multiplayer/new-maps/vesper-viaduct/recipe.mjs` (civic, 80 treads)

- New `export const STAIR_BEVEL` and `export const bevelTread(quad, leg)`.
- New local `beveled(id, q, mat, leg)` adapter next to `roof`.
- The civic loop now builds the authored quad, calls `beveled(...)`. The walkable
  top keeps the id `civic-stair-<i>`, its material `sandstone`, `walkable:true`
  and its two triangles; a separate `civic-stair-<i>-bevel` surface carries the
  two chamfer triangles with `walkable:false`.

### `tools/godot-multiplayer/new-maps/vesper-viaduct/revisions/urban-v2/recipe-v2.mjs` (roof, 14 candidate-only steps)

- New `export const STAIR_BEVEL`.
- New local `bevelSurfaced(terrain, id, leg)` next to the other helpers.
- Each step is still stamped in full by `stampTerrainFloor` first, then
  `bevelSurfaced(a.terrain, id, STAIR_BEVEL)` bevels its ascent edge **in
  place**: the same surface keeps its id, `walkable` flag and material and gains
  two chamfer triangles.

No other geometry, id, material, route, spawn, objective or nav point changed.
`navNodes` 591 -> 591, `routes` 19 -> 19, `spawns` and `objectiveZones`
byte-identical, `art` byte-identical (verified by diff, §3).

### Transcription note on the patch

`vesper-stair-bevel-20261005.patch` is not `git apply`-clean. One hunk was
ambiguous enough to be worth stating plainly:

- The patch's `bevelTread` ends `return [cham,top].map(q=>[[q[0],q[1],q[2]],[q[0],q[2],q[3]]]).flat()`,
  which returns **four triangles** (12 vertices), while its own `beveled()`
  adapter indexes `p[0..3]` / `p[4..7]` as **four vertices**, and the roof
  helper `bevelSurfaced` builds plain 4-corner quads. Applied literally this
  throws `TypeError: Invalid vertex 0` in `terrain.mjs:9`.
  **Resolution:** transcribed as `return [top,cham].flat()` — the shared
  4-corner-quad convention both adapters already assume. With that single
  change `beveled()` is correct exactly as the patch wrote it, including its id
  and walkable-flag assignment, and the emitted geometry matches
  `stair_clearance.bevel_triangles()` triangle for triangle.
- Everything else was transcribed as written, including `bevelSurfaced`'s
  vestigial `emit(quad, walkable, id2)` parameters; both quads land in the same
  surface, so the flags are inert, which is what "bevel in place" means.

The patch file itself is **unchanged**: it is the reviewed record, and
`test_stair_clearance_patch.py` pins its text (`NOT APPLIED`,
`requires a separate reviewed grant`, `188 -> 376`, `central-row-16-45`,
`highest-residual-risk`).

---

## 2. Hashes and counts

| | before | after |
|---|---|---|
| `geometryHash` | `27c71cc8895eab2ca3a0b5cae3c2b8f96ed9afd75db3deec4a5c96bd2f395ea7` | `d8f7b6bbe39c4ec009cc698215273064259e35277268d4ebecd04d5a459c630c` |
| `recipeHash` | `84aa9e5e7dd415fe9681a35c4bb03403e7b6b23b4713936039936af0cfa7c89f` | `b312e45d0fefde9f46b77f6c629748544414f5d83cd676f189a786a7062941b8` |
| `godot/multiplayer_worlds/generated/vesper-viaduct.json` sha256 | `e273264a789036b26bda83bf8e390c8ae53f78e4357da241ce4a49368e8af885` | `cafb93e54b61c223e62279abdb36e606a1d157682071264dd3753143dc56c172` |
| `port/native-multiplayer-worlds/worlds/vesper-viaduct.json` sha256 | `84aa9e5e7dd415fe9681a35c4bb03403e7b6b23b4713936039936af0cfa7c89f` | `b312e45d0fefde9f46b77f6c629748544414f5d83cd676f189a786a7062941b8` |
| walls | 1910 | 1910 |
| wall triangles | 1910 | 1910 |
| surfaces | 253 | 333 (+80) |
| surface triangles | 502 | 662 (+160) |
| routes / rooms | 19 / 21 | 19 / 21 |

Determinism: `node build.mjs --check` passes, and a second `build.mjs` followed by
`--check` reproduces both files byte for byte.

`fixture_inputs.SOURCE_PINS['accepted']` and `movement.mjs.PINS[...]` were
re-pinned to the new accepted-world hash, with the reason in a comment at each
site. Without that re-pin every post-X tool refuses to read the rebuilt world
with `Reviewed source authority drift` / `Pinned source drift`.

---

## 3. Face-count proof

The accepted world only contains the civic run, so its delta is half of the
proposal's accounting. Both are reported.

Accepted runtime world (`godot/multiplayer_worlds/generated/vesper-viaduct.json`):

| quantity | before | after | delta |
|---|---|---|---|
| surfaces | 253 | 333 | **+80** |
| surface triangles | 502 | 662 | **+160** |
| wall triangles | 1910 | 1910 | **0** |
| surfaces removed | — | — | **0** |
| non-stair surfaces byte-identical | — | — | **79 / 79** |

- 80 `civic-stair-<i>` walkable tops: exactly 2 triangles each, before and after.
- 80 new `civic-stair-<i>-bevel` surfaces: exactly 2 triangles each,
  `walkable:false`, `material:"sandstone"`.
- **160 added faces = 94 treads x 2 chamfer triangles is the proposal's two-run
  accounting**; in the built accepted world 80 treads contribute the 160 faces
  and the 14 roof steps contribute 0, because the roof run is candidate-only
  (§9.2). Nothing else changed: walls, the other 79 surfaces, `navNodes`,
  `routes`, `spawns`, `objectiveZones`, `blocks`, `structures`, `props` and
  `art` are byte-identical.
- Every emitted vertex and triangle list was compared element by element against
  the hand-derived 45 degree chamfer for each tread, and against
  `stair_clearance.bevel_triangles()` in the test suite. Zero mismatches.

Analysis-tool accounting, unchanged and reproduced by
`python3 stair_clearance.py`:

```
geometryDiff.input_face_count  = 188
geometryDiff.output_face_count = 376      # 94 treads x 2 triangles added
```

Overhead clearance: `overheadClearance.wedges_checked = 80`,
`wedge_clashes = 0` — a bevel is a pure subtraction, so headroom can only grow.

---

## 4. Static contact census

New tool `tools/godot-multiplayer/new-maps/botanical-post-x/census_bevel.py`,
writing `census-bevel-evidence.json`.

**Why not `diagnose_contacts.py`.** It cannot be re-run here:
`contacts-evidence.json` is a frozen artifact of the native X-03 run, written
with mode `"x"`, so re-running raises `FileExistsError` by design, and
regenerating it would replace the native record with a source reconstruction.
The census therefore reads that file **read-only** and re-derives the
distances against the current geometry, adding what the original tool did not
measure: the contact **normal angle from `Vector3.UP`** — the quantity
`response_guard.gd` actually tests — and the tread's new bevel companion
collider, unioned in, because the capsule meets the chamfer and the flat top as
one physical solid.

Contacts are pinned to the **id the frozen evidence recorded**
(`central-row-16-45-1602`), not to the positional name `OverheadSide<n>`:
`WorldMap.build` derives `n` from a running triangle count, and the bevel adds
160 surface triangles, so every wall index shifts by 160. Following the index
would silently re-point the two wall contacts at `chimney-1442/1443`.

Contact population is unchanged: **368 records, 356 contact entries, 354 tread
ascent-edge + 2 non-tread** (`184 physics errors`).

### Before -> after, split by build

The accepted and candidate worlds are separate builds and only the accepted one
was rebuilt, so a merged total would credit the bevel with the candidate's
result. Counts are "contacts over 46 deg / overlapping".

**Accepted runtime world, civic run (170 contacts, the only rebuilt run)**

| profile | before | after |
|---|---|---|
| exploration r.35 | 162/170, max **51.3402 deg** | **0/170**, max **45.7619 deg** |
| x native r.41 | 0/170, max 38.8845 deg | 0/8, max 36.0034 deg |
| game envelope r.42 | 0/170, max 42.7974 deg | 0/170, max 45.0000 deg |

The 162 exploration-radius failures are gone; the peak contact normal is now the
45 degree chamfer plane. The r.35 peak of 45.76 deg is the chamfer face meeting
the flat top at the tread's authored edge, i.e. the 45 degree plane plus the
barycentric corner of the face, still 0.24 deg under the guard.

**Candidate world, civic run (170) and roof run (14) — NOT rebuilt, unchanged**

| profile | civic before -> after | roof before -> after |
|---|---|---|
| exploration r.35 | 162/170 -> 162/170 (max 51.3402) | 2/14 -> 2/14 (max 50.3558) |
| x native r.41 | 0/170 -> 0/170 | 0/14 -> 0/14 |
| game envelope r.42 | 0/170 -> 0/170 | 0/14 -> 0/14 |

**The 2 out-of-scope wall contacts persist, as required.**

| profile | before | after |
|---|---|---|
| exploration r.35 | 2/2 overlapping, max 106.9875 deg | 2/2, max 106.9875 deg |
| x native r.41 | 2/2, max 100.4851 deg | 2/2, max 100.4851 deg |
| game envelope r.42 | 2/2, max 103.0431 deg | 2/2, max 103.0431 deg |

They are the roof-terrace wall triangles `central-row-16-45-1602/1603` at
`candidate-route:roof-access-ramp:2:35`, byte-identical triangles before and
after. A stair bevel cannot address them.

### Honest scope of the "45.0 degrees" claim

The proposal predicts the contact normal becomes exactly 45.0 deg. Measured
against real triangles, the **exploration r.35** capsule's peak is **45.7619
deg**, not 45.0: at the worst of the 170 pinned positions the deepest feature is
the junction of the chamfer face with the flat top, which is marginally steeper
than the face normal. It is still under the guard, with 0.2381 deg of margin.
The **game r.42** capsule does measure exactly **45.0000 deg**. The proposal's
figure is right for the game envelope and ~0.76 deg optimistic for the
exploration capsule at these specific foot positions. Nothing in §4 was waived
to reach it.

---

## 5. Height preservation

`python3 stair_clearance.py`, reproduced against the rebuilt authority. 765
audited points (591 navNodes, 168 route points, 6 spawns, 3 objective zones, 99
pinned contact feet).

| result | value |
|---|---|
| audited points | **765** |
| genuine support losses | **0** |
| capsule support preserved (r.35) | **true** (all) |
| strict ray changed | **1** — `navNode[493]`, classification **`on_boundary`** |
| nav490 support | **13.8**, bits `402b99999999999a`, **bit-identical** |
| nav490 supporting tread | `civic-stair-11` |
| nav490 walkable span after bevel | z `[30.56, 31]`, foot clearance **0.3490909090909 m** |
| admissible window | `[0.041422189485588026, 0.045454545454546746]`, midpoint `0.043438367470067386` |
| chamfer / margin | 45.0 deg / 1.0 deg (cos margin 0.012448411) |
| bevel wedges checked / clashes | 80 / **0** |

`navNode[493]` is unchanged: z = 42.5, the seam between `civic-stair-34` (17.25)
and `civic-stair-35` (17.4); strict ray 17.4 -> 17.25, capsule 17.4 -> 17.4,
`classification: on_boundary`, reported as `seamAmbiguityOnly`, not suppressed.
The rejected alternatives still behave as documented: naive ramp 13.772727
(delta -0.027273 m), tread-faithful ramp 13.900568 (delta +0.100568 m),
descent-edge bevel `preserved: false`.

`stair_clearance.civic_treads_from_authority` now **reads the applied bevel out
of the geometry** instead of assuming an unbeveled authority: it recovers the leg
from each `-bevel` chamfer, requires the chamfer to be non-walkable, 45 degrees
to within 4 ulp of the world extent, contiguous with the walkable top, and short
of the going, then restores the authored `z0` so `Tread.z0` keeps meaning "the
ascent face". The same reader runs against the pre-bevel world (leg 0), so the
audit is not specialised to one build.

Note on the recovered leg: it is recovered by subtracting world coordinates up
to 65 m, so it differs from the literal by up to 7.1e-15 m (2 bit patterns
across the 80 treads). The applied literal itself is still pinned exactly by
`node tests/builder-leg-literal.test.mjs`.

---

## 6. Tests

### Python (`botanical-post-x`)

| suite | before | after |
|---|---|---|
| `test_stair_clearance` | 36 pass | **45 pass, 0 fail** (+9 added: `AppliedBevel`, `SeamSupportSlots`) |
| `test_stair_clearance_patch` | 23 pass | **23 pass, 0 fail** |
| the proposal's documented pair | 59 pass | **68 pass, 0 fail** |
| `test_census_bevel` (new) | — | **6 pass, 0 fail** |
| `test_tangent` | 3 pass | **3 pass, 0 fail** |
| `test_contacts` | 3 pass | **2 pass, 1 FAIL** |
| `test_art_binding` | 4 pass | **3 pass, 1 ERROR** |
| `test_native_fixture` | 3 pass | **2 pass, 1 FAIL** |
| **whole directory** | **72 pass, 0 red** | **84 pass, 3 red** (2 failures + 1 error) |

The three red are all direct, explainable consequences of the authorised
geometry change, and none of them was patched around:

1. `test_contacts.test_all_184_original_failures_have_exact_source_geometry` —
   asserts the frozen evidence's recorded triangles still equal the current
   source. 172 of 356 entries no longer match (170 tread, because the top moved;
   2 wall, because `OverheadSide<n>` shifted by 160). The assertion is a
   no-drift guard; the geometry moved under a reviewed grant, so the guard is
   correctly reporting.
2. `test_art_binding` / `test_native_fixture` — both require the accepted
   authority to match the **native-run GLB's** recipe identity. The GLB
   predates the rebuild and cannot be regenerated (no Blender), so they fail with
   `Authority/recipe identity mismatch; static substitution forbidden`.
3. `test_native_fixture.test_missing_candidate_art_cannot_create_a_fixture_or_use_accepted_fallback`
   — same identity mismatch, surfacing before the `no fallback` assertion.

### Node

| suite | before | after |
|---|---|---|
| `botanical-post-x/tests/builder-leg-literal.test.mjs` | 11 pass | **11 pass, 0 fail** |
| `botanical-post-x/movement.test.mjs` | 2 pass | **1 pass, 1 FAIL** |
| `vesper-viaduct/revisions/urban-v2/variety.test.mjs` | 6 pass | **5 pass, 1 FAIL** |
| `map_variety/repair.test.mjs` | 7 pass | **6 pass, 1 FAIL** |
| `botanical-correction/correction.test.mjs` | 5 pass | **5 pass, 0 fail** |
| `game/*.test.mjs` (2399 tests) | 2312 pass / 78 file-level fails / 9 skipped | **2312 pass / 78 file-level fails / 9 skipped** — byte-identical failure sets before and after, all pre-existing |

The three red, precisely:

1. **`movement.test.mjs`** — the decisive one. See §7.
2. **`variety.test.mjs` "passes every source probe"** — the candidate source gate
   now reports 5 failures (`roof-access-ramp` unsupported at z 54.75 and 60.75,
   plus two unreachable route points). See §9.2.
3. **`repair.test.mjs` "accepted civic stair heights remain exact"** — a
   **1 ulp float artefact**, not a height change:
   `index.support(32,z).y` is now `13.8` where the un-beveled base returns
   `13.800000000000002` (2.2e-15 m apart). `terrainSupportAt` computes support as
   `u*a[1]+v*b[1]+w*c[1]`; the top plane value is bit-identical (§5), but moving
   the `-Z` vertex changes the barycentric weights, so the interpolated value
   rounds differently. The assertion is a strict equality over a derived
   quantity. Left unmodified for a reviewer to re-base; the authored planes are
   pinned bit-exactly by the new `AppliedBevel` tests.

---

## 7. Blocking finding: the production mover loses ground

`botanical-post-x/movement.mjs` runs the **actual production mover**
(`game/core.mjs moveActor`, `game/data.mjs RULES`, 60 Hz, r.42) over both runs.
It is source-only, not a native claim, and it is the tightest available
behavioural gate.

| | before | after |
|---|---|---|
| `node movement.mjs` exit | 0 | **throws** |
| trials | 80 | 80 |
| required | 60 | 60 |
| required fully clean | **60** | **40** |
| frames where the actor is not grounded | **0** | **2275** |
| trials not reaching the goal | 20 (accepted roof, not required) | 20 |

Per run:

| variant/run | trials | not reached | bad frames |
|---|---|---|---|
| accepted/civic | 20 | 0 | **2275** |
| accepted/roof | 20 | 20 | 0 (no roof run in the accepted world; not required) |
| candidate/civic | 20 | 0 | 0 (candidate not rebuilt) |
| candidate/roof | 20 | 0 | 0 |

The actor still **reaches the goal on all 20 accepted civic trials**, with
**0 blocked frames, 0 headroom failures and max per-frame rise 0.15 m**. What
fails is `r.trace.every(t => t.grounded && ...)`: the actor goes airborne for
2275 frames across the run.

### Root cause

`recipe.mjs` declares `terrain.maxSlope = 0.7` rad = **40.107 deg**, and
`terrainSupportAt` (`game/terrain.mjs:102`) drops any triangle whose normal is
shallower than `cos(maxSlope) = 0.764842`. A **45 degree chamfer is 0.707107**,
so the chamfer is rejected as support. Combined with the patch's
`walkable:false` chamfer, `floorAt` returns `null` in the leg-deep band at every
seam: `support(32, 25.020)` and `support(32, 25.043)` are `null`, bracketed by
`12` at z=25.000 and `12.15` at z=25.060. Measured in the rebuilt arena, **all
80 civic seams carry a 43.4 mm unsupported slot**, and base-recipe
`navConnectivity` drops **591/591 -> 582/591** (the nine `upper-crosslink-32`
nodes at z 30.909 .. 61.818).

Note the two questions are different, and only a native run settles the first:

* **Physical**: the chamfer is a 45 degree face, under the 46 degree
  `floor_max_angle` guard. §4 measures that, and it clears.
* **Query layer**: `terrainSupportAt` on this map does not consider a 45 degree
  face to be floor at all, so authored-height queries and the production mover
  behave as if the tread's first 43.4 mm were missing.

The proposal never modelled the second. Its §6 "overhead clearance unaffected by
construction" and §4 "contact normal exactly 45.0 deg" are both correct as
stated; neither accounts for `terrain.maxSlope`.

### A viable resolution exists, and it is a design decision, not mine

Read-only diagnostic (fresh arena copy per configuration, nothing written back),
running the production mover over the 20 required civic trials:

| `terrain.maxSlope` | chamfer `walkable` | required civic trials failing |
|---|---|---|
| 40.107 deg (as applied) | `false` (as applied) | **20/20** |
| 45.000 deg | `false` | 20/20 |
| 45.000 deg | `true` | **0/20** |
| 51.566 deg | `true` | **0/20** |

So the production mover is fully clean with `terrain.maxSlope >= Math.PI/4`
**and** a walkable chamfer. Both are deviations from the reviewed patch (which
specifies a non-walkable chamfer) and from "do not alter any other geometry".
Raising `terrain.maxSlope` also loosens the authoring slope budget for the whole
map. **Not applied here; needs its own review.**

---

## 8. What was not touched

- `contacts-evidence.json`, `movement-evidence.json`, `art_binding` records,
  `stair-diagnostic.json`, `physics-report.json`, `probes.json`: frozen, read-only.
- `port/new-maps/vesper-viaduct/variety/urban-v2/*` and `urban-v3/*`: **not
  regenerated**, see §9.2. Still byte-identical to `f38d4a7d`, and therefore
  still describe the *un-beveled* candidate.
- All 40+ native evidence files that pin the old accepted `geometryHash`,
  including `port/godot-package/production_receipts/vesper-viaduct.json`,
  `godot/tests/new_maps/botanical_post_x/*`, `godot/tests/walker_*/*` and
  `port/expansion-three/vesper/evidence/production-h/*`: **no receipt change**.
- `godot/multiplayer_worlds/art/worlds/vesper-viaduct.glb`,
  `godot/multiplayer_worlds/dressing/profile.gd` identity binding and
  `dressing/profiles/vesper-viaduct.json`'s `geometry_hash` still reference the
  pre-bevel `geometryHash`. The map-finish chain cannot be re-established
  source-only; it needs a Blender master rebuild.
- The patch file `vesper-stair-bevel-20261005.patch`, unchanged.
- No engine, no Blender, no native run, no push, no merge to
  `feature/relay-campaign`.

---

## 9. Open items

1. **BLOCKER — production mover regression (§7).** `movement.mjs` goes from
   60/60 to 40/60 required clean trials, 2275 airborne frames. Either accept
   `terrain.maxSlope >= Math.PI/4` plus a walkable chamfer (proven sufficient,
   §7) with a review of the slope-budget change, or drop the bevel. **This must
   be resolved before any promotion.**
2. **BLOCKER — candidate chain cannot be rebuilt (§9.2).** The 14 roof steps are
   in the recipes but the candidate authority is not rebuilt, so the roof run's
   14 contacts still measure 2/14 over 46 deg at r.35 and the proposal's
   "highest residual risk" item is **still open**: the roof geometry has never
   been verified against a built candidate world.
3. **The 2 `central-row-16-45` wall contacts persist** (§4), byte-identical.
   Out of scope for a stair bevel; they are a roof-terrace wall question and
   need a separate proposal if the native batch still fails there.
4. **Repair `terrain.maxSlope` vs 45 deg** as a map-wide authoring decision, not
   a stair-bevel detail. Until then no 45 degree chamfer can be both
   guard-compliant and support-visible on this map.
5. **`repair.test.mjs` strict equality** over a barycentrically derived support
   height now differs by 1 ulp. A reviewer should re-base it on a tolerance and
   keep the bit-exact plane assertions (which are now covered by
   `AppliedBevel`).
6. **Re-pin or retire the 3 red Python tests** once the §7 decision is made; they
   are identity/drift guards against the pre-bevel world and the pre-bevel GLB.
7. **Map-finish identity chain** (`profile.gd`, `dressing/profiles/*.json`,
   `art/worlds/*.glb`) still binds the pre-bevel `geometryHash`; needs a Blender
   rebuild.
8. **Receipts, promotion, and the native re-run are all pending and out of
   scope.** No receipt was changed. The native 60-journey batch has still not
   been run against the beveled geometry; nothing in this report is a native
   claim, and static geometry analysis is not movement.

### 9.2 Why the candidate chain was not regenerated

`recipe-v2.mjs` imports `baseRecipe()`, so the civic bevel propagates into
`urban-v2` and `urban-v3`. Regenerating them requires passing their own source
gates, and those gates now fail:

- `node tools/.../urban-v2/variety-source-check.mjs` exits **1** with 5 audit
  failures: `roof-access-ramp` unsupported at (18, 54.75) and (18, 60.75), plus
  `roof-access-ramp point 18.0,53.0 is unreachable` and
  `roof-terrace-loop point 10.0,40.0 is unreachable`.
- `navConnectivity` for `urban-v2` drops **857/857 -> 810/857** (47 unreachable:
  9 civic nodes at x=32 and 38 roof/terrace nodes).
- Cause: the same 45 deg vs `terrain.maxSlope` conflict of §7. On the roof run
  there is **no lower step underneath** to fall back on, so the 43.4 mm band is
  a genuine hole rather than a 0.15 m step: `support(18, 54.75)` is `null`,
  bracketed by `roof-terrace-deck` at z=53.0 and `roof-ramp-step-0` at z=53.05.
- The `roof-access-ramp` samples that land in a band are z = 53.0, 54.75, 59.0
  and 60.75; only the two non-navigable ones (54.75, 60.75) are reported.

The gate writes nothing on failure, so the candidate artifacts were left
untouched rather than regenerated past their own audit. Bypassing or weakening
that audit would be falsifying evidence.

### 9.3 Roof geometry, verified against the recipe rather than a built world

The roof bevel was checked against the `recipe-v2.mjs:127` formula, because
§9.2 blocks verification against a built candidate world. All 14 steps, in both
`urban-v2` and `urban-v3`:

| | before (HEAD) | after |
|---|---|---|
| triangles per step | 2, 3, 4 or 5 (varies) | **4 for all 14** (2 top + 2 chamfer) |
| vertices per step | 6, 9, 12 or 15 (varies) | 12 (steps 0..12) or 8 (step 13) |
| resolved triangles matching the proof | n/a (no chamfer) | **13 / 14** |
| `material` / `walkable` | `sandstone` / `true` | `sandstone` / `true` |

Two pre-existing `stampTerrainFloor` artefacts, confirmed identical at HEAD and
not introduced here:

- **Step 0's `x0` is `15.999999999999993`, not `16`,** before and after. That is
  why it is the one step that does not match the proof template literally; its
  other three coordinates and both its chamfer triangles are exact.
- **The vertex/triangle encoding of steps 0..12 is re-fanned into 12 vertices**
  by the next step's `stampTerrainFloor` zero-area remainder path, and the
  pre-bevel encoding already varied (6/9/12/15 vertices) for the same reason.
  The resolved triangles are what the bevel is judged on, and they are exact.
  Step 13, the last stamped step, keeps the clean 8-vertex form.

---

## 10. Reproducing

```bash
cd tools/godot-multiplayer/new-maps/botanical-post-x
export COCS_BOTANICAL_X_FIXTURE_ROOT=<a read-only checkout holding the frozen X-03 fixtures>
python3 stair_clearance.py          # rewrites stair-clearance-evidence.json
python3 census_bevel.py             # writes census-bevel-evidence.json
python3 -m unittest test_stair_clearance test_stair_clearance_patch test_census_bevel
node tests/builder-leg-literal.test.mjs
node movement.mjs                   # expected to throw; see section 7

cd ../../vesper-viaduct
node build.mjs && node build.mjs --check
node revisions/urban-v2/variety-source-check.mjs   # expected to exit 1; see 9.2
```

Deterministic, no engine, no Blender, no network. The census reads only the
frozen X-03 fixtures and the two pinned source worlds, and writes only its own
evidence file.