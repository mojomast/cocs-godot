# Vesper support-visible stair edge (2026-10-05)

Branch `spacebunny/vesper-bevel-support-visible-20261005`, from `e3e268ba`.
Supersedes the 45 degree chamfer of
`port/finish/map-variety/VESPER_BEVEL_REBUILD_20261005.md`.

**Outcome: the coupling is closed.** `game/*.mjs` is byte-identical. The rebuilt
world restores `navConnectivity` to 591/591, the production mover to 60/60 clean
trials with 0 blocked and 0 airborne frames, all 354 tread contacts under the
46 degree guard in **both** builds, zero support losses in the 765-point audit,
and the candidate chain rebuilds for the first time. One cost is quantified and
flagged rather than waived: **nav490 moves 13.8 -> 13.873636363636354
(+0.0736 m)**, and three audited locations rise with it. Section 6 proves that
figure is the minimum achievable by any admissible treatment.

No engine, Blender, native run, receipt, promotion or push.

---

## 1. The coupling, read from source

`stair_clearance.support_query_rules()` documents this, citing every line. The
summary, all from code that is **not** modified:

| predicate | rule | source |
|---|---|---|
| P1 bounds | `x`/`z` finite; the lattice path also requires the point inside the baked grid | `terrain.mjs:93`, `floor-lattice.mjs:227-228` |
| P2 non-degenerate | `abs(barycentric denominator) > 1e-9` — a vertical face has no XZ extent and is skipped **here**, before any slope test | `terrain.mjs:97`, `floor-lattice.mjs:241` |
| P3 containment | `u, v, w >= -1e-9`, exact per triangle, no dilation | `terrain.mjs:98-101` |
| P4 positive-up + walkable | `normal[1] > 1e-9` and `walkable !== false` (a missing flag defaults to walkable); walls are a separate collection | `terrain.mjs:39,101`, `floor-lattice.mjs:107-109` |
| **P5 slope budget** | `normal[1] >= cos(terrain.maxSlope) - 1e-9`, applied at **lookup** time | `terrain.mjs:102`, `floor-lattice.mjs:249` |

Selection is `y = u*a[1]+v*b[1]+w*c[1]`, highest wins, incumbent replaced only by
more than 1e-9 (`terrain.mjs:103-104`).

Three facts decide the whole problem:

1. **There is no fallback.** No admissible triangle in the column means `null`,
   and `floorAt` propagates it (`floorAt(...)?.y ?? null`, `core.mjs:108`). No
   "next best surface", no slope relaxation, no neighbouring cell.
2. **The budget comes from the map, not the caller.**
   `makeFloorQuery` uses `options.maxSlope ?? (terrain?.maxSlope ?? 0.9)`
   (`floor-lattice.mjs:285`). Vesper authors `terrain.maxSlope = 0.7` rad =
   **40.107001667277394 deg**, `cos = 0.7648421872844885`.
3. **A 45 degree chamfer is inadmissible there.** `cos(45 deg) = 0.707107 <
   0.764842 - 1e-9`. The chamfer is invisible to the entire movement and nav
   stack, so subtracting its band out of a tread top does not soften the riser —
   it **deletes the floor**.

That is the whole mechanism behind the previous branch's 1920 null samples, the
582/591 navConnectivity and the 2275 airborne frames.

### The geometric bound this implies

A plane `y = a*z + b*x + c` has unit normal proportional to `(-b, 1, -a)`, so
P5 requires `a^2 + b^2 <= tan(maxSlope)^2` and, for the ascent direction,
`|a| <= tan(0.7) = 0.8422883804630794`
(`stair_clearance.max_admissible_gradient`). Tilting a face in X cannot buy extra
rise in Z — it only spends budget. The bound holds for any monotone staircase of
admissible facets too, so **no amount of tiering beats it**.

---

## 2. The design space, and why it is empty for a subtractive treatment

`stair_clearance.edge_design_space()` derives, per run and per face angle θ, the
five constraints an edge treatment must satisfy:

- **C1 support visible** — `θ <= 40.107 deg` (P5).
- **C2 guard** — `θ <= 46 deg`, because a planar face's contact normal equals its
  face angle.
- **C3 capsule on the face** — generalising the proposal's inequality to a
  general θ: `drop >= rise - radius*(1 - cos θ) + separation`. Below that the
  capsule catches the face's *lower edge* and the normal stays edge-steep.
- **C4 going** — `W = rise/tan θ <= going`.
- **C5 audited heights** — `W` must stay inside the clearance budget below.

C1 and C2 bound θ from above; **C5 bounds it from below**, because the treatment
has to fit in the horizontal room the audited points leave. They are empty
together:

| run | clearance budget | tightest audited point | max rise inside the budget | min θ for the full rise |
|---|---|---|---|---|
| civic | **0.045454545 m** | `contact:accepted-nav-497` (and `navNode[489]`, `navNode[497]` at 0.045455 m) | 0.038286 m = **25.5 %** of 0.15 m | **73.1416 deg** |
| roof | **0.035714286 m** | `contact:candidate-route:roof-access-ramp` | 0.030082 m = **21.1 %** of 2/14 m | **75.9638 deg** |

`nonEmpty: false`. 73.14 deg > 46 deg, so the budget cannot hold an admissible
face covering the rise. The gap is **27.14 deg**, and it is not a `maxSlope`
problem: even raising `terrain.maxSlope` all the way to the guard limit of 46 deg
only reaches 0.047070 m, **31.4 %** of the rise.

The budget comes from two directions, and they are different treatments:

- **subtractive** (top pulled back): measured forwards from a riser. civic
  0.045455 m (`navNode[489]`), roof 0.607143 m.
- **additive apron** (face added in front): measured backwards from the next
  riser. civic 0.045455 m (`contact:accepted-nav-497`), roof 0.035714 m.

Only one of the 107 tread-resolved audited points sits exactly on a riser
(`navNode[493]`, classified `on_boundary`, so its change is reported and not
counted). Every other one is strictly inside, and so is counted.

### Options evaluated, and what each one costs

Measured against the real production code paths (`floorAt`, `navConnectivity`,
`moveActor`) with a fresh arena per treatment so no `WeakMap` cache carries over.
The audit column compares each treatment's `floorAt` against the **authored**
world's, so the 13 pre-existing model-vs-`floorAt` disagreements cannot leak in.

| treatment | floorAt nulls | navConnectivity | audit losses | audit raises | nav490 | census r.35 max / over 46 | sweep r.35 | mover clean | airborne |
|---|---|---|---|---|---|---|---|---|---|
| **T0** authored | 0 | **591/591** | 0 | 0 | 13.8 | 51.3402 / **324** | 48.8141 | 20/20 | 0 |
| **T1** 45 deg chamfer (previous branch) | **1920** | **582/591** | 1 | 0 | 13.8 | 45.7619 / 0 | 45.4738 | **0/20** | **2275** |
| **T2** single shallow face, 40.107 deg, subtractive, W=0.178 | 0 | 591/591 | **4 (−0.15 m)** | 0 | 13.8 | 40.107 / 0 | 40.107 | 20/20 | 0 |
| **T3** tiered apron, 4 tiers + vertical micro-risers | 0 | 591/591 | 0 | 6 | +0.075 | **51.3402 / 324** | **48.8141** | 20/20 | 0 |
| **T4** chamfer + walkable shelf under the band | 0 | 591/591 | **1 (−0.043 m)** | 0 | 13.8 | 45.7619 / 0 | 45.4738 | 20/20 | 0 |
| **T5** shallow apron at 40.107 deg (chosen, at 40.03 deg) | 0 | 591/591 | **0** | 6 | **+0.073** | **40.107 / 0** | 40.107 | 20/20 | 0 |

Two escape hatches are closed by measurement, not argument:

- **T3, tiering.** Horizontal micro-treads are trivially support-visible, but the
  vertical micro-risers between them are not a fix: they put a 90 degree face
  back on the ascent, and both the census (324 over 46) and the analytic sweep
  (48.8141 deg) reproduce the unbeveled failure exactly.
- **T4, covering the chamfer with a walkable shelf.** This restores support
  continuity (0 nulls, 591/591, mover 20/20) while keeping the 45 degree contact
  face, so it looks like the fix. It still fails C5: filling the band with a
  horizontal shelf 43.4 mm *below* the tread top drops support at one audited
  point, and a shelf at the top level would just be the top again, restoring the
  90 degree corner.

---

## 3. The treatment

**An additive, walkable, support-visible apron in front of each riser.**

Each riser at `zRiser` gets one walkable quad that starts on the lower tread's
top plane and reaches this tread's top plane exactly at the riser:

```
APRON_SLOPE = 0.84                      # atan = 40.0302592718897 deg
run        = rise / APRON_SLOPE         # civic 0.17857142857142858 m
                                          # roof  0.17006802721088435 m
vertices  = [[30, y-rise, zRiser-run], [30, y, zRiser],
             [34, y, zRiser],           [34, y-rise, zRiser-run]]
```

`recipe.mjs` exports `edgeApron(x0, x1, zRiser, yTop, rise, slope)` and
`apronSurfaced`/`aproned` wire it in; `recipe-v2.mjs` imports the same helper so
both runs cannot drift apart.

| parameter | value | why |
|---|---|---|
| face angle | **40.030259 deg** | C1: 0.0767 deg inside `terrain.maxSlope`, so `cos` clears by **8.63e-4** — 862,678x the 1e-9 epsilon actually tested, not a knife-edge |
| contact normal | 40.030259 deg | C2: **5.9697 deg** of margin under the 46 deg guard |
| horizontal run | 0.178571 m | C4: 35.7 % of the 0.5 m going |
| C3 drop needed | 0.067997 m | `0.15 - 0.35*(1-cos 40.03 deg)`; the full 0.15 m drop satisfies it for every profile |
| walkable | `true` | C1's other half |
| material | `sandstone` | matches its tread |

The resulting profile is flat 0.321429 m, ramp 0.178571 m at 40.03 deg, flat
0.321429 m, ... — no 90 degree face anywhere on the ascent, and continuous
support across every seam.

**Why 40.03 and not exactly 40.107.** The steepest admissible angle minimises the
nav490 raise (section 6), but sitting *on* the threshold leaves only the 1e-9
epsilon. 0.84 sits 0.0767 deg inside it and costs 0.2 mm of nav490 height.

**Purely additive.** All 80 `civic-stair-*` tops and all 14 `roof-ramp-step-*`
stamped steps are byte-identical to the authored world. Nothing is cut, nothing
floats, no authored plane moves.

---

## 4. Rebuild and diff

| | authored (`f38d4a7d`) | 45 deg chamfer (`e3e268ba`) | support-visible apron (this branch) |
|---|---|---|---|
| `geometryHash` (accepted) | `27c71cc8…` | `d8f7b6bb…` | **`db20ce1f…`** |
| `recipeHash` (accepted) | `84aa9e5e…` | `b312e45d…` | **`6886cf86…`** |
| accepted world sha256 | `e273264a…` | `cafb93e5…` | **`0f7f8a0a…`** |
| `urban-v2` geometryHash | `c044bc54…` | not rebuilt (gate failed) | **`4635efd5…`** |
| `urban-v3` geometryHash | `fd8e7134…` | not rebuilt | **`096226e3…`** |
| surfaces / surface triangles | 253 / 502 | 333 / 662 | 333 / 662 |
| wall triangles | 1910 | 1910 | 1910 |

Determinism: `build.mjs --check` passes and a second `build.mjs` reproduces both
files byte for byte.

**The diff is confined to the 94 treads.** Verified element by element against
the authored world:

- surfaces **253 -> 333** (**+80**), surface triangles **502 -> 662** (**+160**),
  wall triangles **+0**.
- **80 apron surfaces added, 80/80 matching the proven quad exactly.**
- **0 of the 80 civic tread tops changed** — byte-identical, `walkable:true`,
  spanning their full authored `[z0, z1]`.
- Everything outside the stair ids byte-identical: the other 173 surfaces, all
  1910 wall triangles, `navNodes` 591 -> 591, `routes` 19 -> 19, `spawns`,
  `objectiveZones`, `art`. Zero problems.

---

## 5. Acceptance battery — all source-only

### 5.1 Contact census — 354/354 clear, in both builds

`census_bevel.py` (frozen native records read-only; the wall collider is pinned
by **id**, because `OverheadSide<n>` shifts by +160 whenever surfaces are added).

| profile | accepted civic | accepted wall | candidate civic | candidate roof |
|---|---|---|---|---|
| exploration r.35 | **0/170 over 46**, max **40.030259** | 2/2 | **0/170 over 46** | **0/14 over 46** |
| x native r.41 | 0/170, max 40.030259 | 2/2 | 0/170 | 0/14 |
| game envelope r.42 | 0/170, max 40.030259 | 2/2 | 0/170 | 0/14 |

- **368 records, 356 contact entries, 354 tread + 2 non-tread — unchanged.**
- The analytic worst over the full 0–0.40 m approach sweep, at 0.5 mm
  resolution: **40.107 deg** (r.35 and r.42), against **48.8141 deg** unbeveled.
  The 45 degree chamfer's 45.7619 deg is gone, so the proposal's r.35 figure is
  no longer an approximation.
- **The 2 `central-row-16-45` wall contacts persist, 2/2**, byte-identical
  triangles, ~100–107 deg. Out of scope for a stair edge, as before.
- The candidate's 14 roof contacts now clear too, because the candidate chain is
  rebuilt (section 5.4). On the previous branch they were still 2/14 over.

### 5.2 Height audit — 765 points, 0 losses, 3 raises quantified

`floor_column_height` mirrors `terrainSupportAt` exactly: highest admissible
walkable surface in the column, **no reference filter, no fallback**. (The
pre-existing `support_height` filter is right for asking what plane a resting
capsule stands on and wrong for asking what the level's query returns, so using
it here would have hidden every raise.)

| result | value |
|---|---|
| audited points | **765** |
| support **losses** | **0** |
| support **raises** | **6 rows = 3 distinct locations**, max **+0.111818182 m** |
| capsule support preserved | **true** (all) |
| strict-ray changes on the capsule metric | 0 |
| seam ambiguity (`on_boundary`) | 0 — `navNode[493]` now resolves to 17.4 identically, because the tops were never moved |

| point | z | authored | built | delta |
|---|---|---|---|---|
| `navNode[490]` / `contact:accepted-nav-490` | 30.909090909 | 13.8 | 13.873636363636363 | **+0.073636364** |
| `navNode[494]` / `contact:accepted-nav-494` | 46.363636364 | 18.45 | 18.485454545454550 | +0.035454545 |
| `navNode[497]` / `contact:accepted-nav-497` | 57.954545455 | 21.9 | 22.011818181818178 | **+0.111818182** |

**nav490 is not bit-identical and is not claimed to be.**
`13.8` (bits `402b99999999999a`) -> **`13.873636363636354`** (bits
`402bbf4d43f4d43a`), delta **+0.073636364 m**. The tread plane itself is still
the authored `13.8`; the foot now lands on the apron in front of it. Flagged,
quantified, not waived — see section 6 for why no smaller number is available.

The rejected alternatives still behave as documented: naive ramp 13.772727
(−0.027273 m), tread-faithful ramp 13.900568 (+0.100568 m), descent-edge bevel
`preserved: false`.

### 5.3 navConnectivity and the production mover

| | authored | 45 deg chamfer | apron |
|---|---|---|---|
| base recipe navConnectivity | 591/591 | 582/591 | **591/591** |
| `floorAt` null samples over the run (5 mm, 3 lanes) | 0 | 1920 | **0** |
| `node movement.mjs` | exit 0 | **throws** | **exit 0** |
| trials / required | 80 / 60 | 80 / 60 | 80 / 60 |
| required fully clean | 60 | **40** | **60** |
| blocked frames | 0 | 0 | **0** |
| airborne frames | **0** | **2275** | **0** |
| max per-frame rise | 0.15 m | 0.15 m | **0.15 m** |
| total frames | 27930 | — | **27930** |

`movement.mjs` runs the actual production `moveActor` at 60 Hz with `RULES`, so
this is behaviour, not geometry inspection. The frame count matching the authored
baseline exactly is a good sign that the profile is unchanged: the apron is
walked at the same cadence.

### 5.4 Candidate chain — rebuilds for the first time

| gate | authored | 45 deg chamfer | apron |
|---|---|---|---|
| `urban-v2/variety-source-check.mjs` | exit 0, 857/857 | **exit 1**, 5 audit failures, 810/857 | **exit 0, 857/857, 0 physical-route failures** |
| `botanical-correction/generate.mjs` | — | not runnable | **exit 0**, regenerates `urban-v3`; helix and parallax byte-identical |

The roof run was the hardest case, because its steps float: nothing sits
underneath, so on the previous branch the chamfer band was a genuine hole
(`support(18, 54.75) = null`) rather than a 0.15 m step back onto the tread below.
The apron is support-visible, so the band is floor there too.

### 5.5 Tests

| suite | authored | 45 deg chamfer | apron |
|---|---|---|---|
| `test_stair_clearance` + `test_stair_clearance_patch` | 59 pass | 68 pass | **71 pass, 0 fail** |
| `test_census_bevel` | — | 6 pass | **7 pass, 0 fail** |
| `tests/builder-leg-literal.test.mjs` | 11 pass | 11 pass | **11 pass, 0 fail** |
| `movement.test.mjs` | 2 pass | **1 pass, 1 fail** | **2 pass, 0 fail** |
| `urban-v2/variety.test.mjs` | 6 pass | **5 pass, 1 fail** | **6 pass, 0 fail** |
| `map_variety/repair.test.mjs` | 7 pass | **6 pass, 1 fail** | **7 pass, 0 fail** |
| `botanical-correction/correction.test.mjs` | 5 pass | 5 pass | **5 pass, 0 fail** |
| `game/*.test.mjs` (2399) | 2312 pass / 78 file fails / 9 skip | identical set | **identical set** |
| whole `botanical-post-x` directory | 72 pass / 0 red | 84 pass / 3 red | **87 pass / 4 red** |

`repair.test.mjs` is green again: its 1 ulp failure came from the moved tread
tops, and the tops were not moved. `movement.test.mjs` and `variety.test.mjs`
were red on the previous branch and are now green, for the same reason.

The three still red, all identity/drift guards against the pre-rebuild world,
none patched around (4 rows: 3 failures + 1 error):

1. `test_contacts.test_all_184_original_failures_have_exact_source_geometry` —
   **2 of 356** entries mismatch, down from 172. All 354 tread entries now match
   the frozen native record *exactly*, triangles and recomputed capsule distance.
   The 2 that differ are the wall contacts: `WorldMap.build` derives
   `OverheadSide<n>` from a running triangle count, so adding 80 surfaces shifts
   every wall index by +160 and the name now denotes a different wall.
   `census_bevel.py` resolves those by id for exactly this reason.
2. `test_art_binding` (1 failure + 1 error) and `test_native_fixture` (1 failure)
   — they require the accepted authority to match the **native-run GLB's**
   recipe identity. The GLB predates every rebuild and cannot be regenerated
   without Blender.

### 5.6 `game/*.mjs` untouched

`git diff --stat HEAD -- game/` is **empty**. Confirmed byte-identical to both
`e3e268ba` and the authored `f38d4a7d`. The entire change is authored geometry
plus the analysis tools that measure it.

---

## 6. Why +73.6 mm at nav490 is the floor

Any support-visible face covering the civic rise needs a run of
`W = rise/tan θ`, and nav490's foot sits 0.090909 m before the riser at z = 31.0.
Its support therefore becomes

```
nav490 = 13.8 + 0.15 - 0.090909 * tan θ
```

which is **monotonically decreasing in θ**, so the *steepest* admissible angle
minimises the raise. The largest admissible `tan θ` is `tan(0.7) = 0.8422884`:

| θ | nav490 | delta |
|---|---|---|
| 46 deg (the guard limit, not admissible) | 13.8559 | +0.0559 |
| 40.107001667 deg (the support limit) | **13.8734281** | **+0.0734281** — the theoretical floor |
| 40.030259 deg (shipped) | 13.8736364 | +0.0736364 — **0.2 mm worse** |
| authored, no treatment | 13.8 | 0 |

So no admissible treatment can leave nav490 bit-identical, and the shipped value
is within 0.2 mm of the provable optimum. This is pinned by
`AppliedApron.test_the_applied_leg_is_the_proven_minimum_nav490_cost`.

The three raises are the same phenomenon at three points; the maximum,
+0.111818 m at `navNode[497]`, is `0.15 - 0.038182 * tan θ` at the same θ.

**This is the contract question the user has to answer.** It is not a bug and it
is not hidden: three audited locations, one of them the documented nav490 pin,
move **up** by 35–112 mm onto a 40 degree apron instead of a flat tread. The
alternative framings are (a) raise `terrain.maxSlope` under the locked-contract
discipline — which does **not** help, since the budget binds at 73 deg and even
the 46 deg guard limit only reaches 31 % of the rise — or (b) a controller
step-up, out of scope per the plan.

---

## 7. Open items

1. **nav490 + 73.6 mm and two further audited raises need sign-off.** Section 6
   shows this is the floor for any admissible geometry. If the post-X README's
   nav490 pin is a hard contract rather than a regression marker, this treatment
   is not acceptable and the only remaining lever is a controller step-up, which
   the plan explicitly excludes.
2. **The 2 `central-row-16-45` wall contacts persist**, byte-identical,
   ~100–107 deg. Unchanged and still out of scope for a stair edge; they are a
   roof-terrace wall question needing their own proposal if the native batch
   fails there.
3. **`OverheadSide<n>` shifts by +160.** Any surface addition renames wall
   colliders positionally. `census_bevel.py` pins by id; `diagnose_contacts.py`
   and `test_contacts.py` do not, which is the 2-entry mismatch. Worth fixing in
   the tool rather than in the test.
4. **Map-finish identity chain** still binds the pre-rebuild `geometryHash`:
   `dressing/profile.gd`, `dressing/profiles/vesper-viaduct.json` and
   `art/worlds/vesper-viaduct.glb`. Needs a Blender master rebuild; out of scope.
5. **Receipts and promotion pending, out of scope.** No receipt changed. The
   native 60-journey batch has still not run against this geometry; nothing here
   is a native claim, and static geometry analysis is not movement — in
   particular the guard's other predicates (collider identity,
   `colliderVelocity`, contact Y vs `landingY`, the no-slide branch) are still
   unevaluated.
6. **Three red identity/drift guards** re-based once the Blender rebuild lands.

---

## 8. Reproducing

```bash
cd tools/godot-multiplayer/new-maps/botanical-post-x
export COCS_BOTANICAL_X_FIXTURE_ROOT=<a read-only checkout holding the frozen X-03 fixtures>
python3 stair_clearance.py                                  # rewrites stair-clearance-evidence.json
python3 census_bevel.py                                     # writes census-bevel-evidence.json
python3 -m unittest test_stair_clearance test_stair_clearance_patch test_census_bevel
node tests/builder-leg-literal.test.mjs
node movement.mjs

cd ../../vesper-viaduct
node build.mjs && node build.mjs --check
node revisions/urban-v2/variety-source-check.mjs            # exit 0
cd ../../../botanical-correction && node generate.mjs       # regenerates urban-v3
```

Deterministic, no engine, no Blender, no network. The census reads only the
frozen X-03 fixtures and the two pinned source worlds, and writes only its own
evidence file.