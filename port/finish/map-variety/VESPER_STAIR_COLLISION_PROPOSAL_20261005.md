# Vesper stair collision proposal — height-preserving bevel (2026-10-05)

**Status: proposal only.** Source analysis and tooling on branch
`spacebunny/vesper-stair-proposal-20261005` (from `feature/relay-campaign`).
No runtime world data, generated JSON, recipe, builder, receipt or artifact was
modified. No engine, Blender or native run was executed. This document makes
**no native claim**, and the **184 static contacts remain failed** until a
future grant rebuilds and re-verifies.

Prepared as queue item Q4 of `port/finish/map-variety/BLOCKERS_EFFICIENCY_20261005.md`
§1: a review-ready ramp/bevel fallback in case the prepared 60-journey native
batch shows real stalls. **The batch has not run, and no stall is claimed.**

---

## 1. Root cause (proved in existing source, cited)

- `godot/exploration/walker.gd:21` `capsule.radius = 0.35`; `:34`
  `floor_snap_length = 0.3`; `:35` `floor_max_angle = deg_to_rad(46.0)`; `:37`
  `safe_margin = 0.02`.
- **No step logic.** `step()` at `walker.gd:87` calls `move_and_slide()` at
  `:98` and nothing else. There is no ray/shape step-up.
- Godot 4 `CharacterBody3D` has no built-in step climbing (proposal #2751, not
  in 4.5). A 90° tread face is therefore a **wall**.
- `response_guard.gd:44` rejects final support when
  `normal.dot(Vector3.UP) < cos(body.floor_max_angle)`, i.e. above 46°.

The capsule rests on tread *i*; the next tread's ascent (−Z) edge sits `rise`
higher and `gap` further along. The contact is a convex corner, so the normal
points from the corner to the capsule axis: `atan2(gap, radius − rise)`. As
`gap` grows the angle steepens past 46° and the guard fails.

**Independent analytic reproduction.** This tool computes the contact angle from
geometry alone and lands in the same band the reviewed documents report:

| profile | radius | run | rise | analytic worst angle |
|---|---|---|---|---|
| exploration `walker.gd` | 0.35 | civic | 0.15 m | **51.34°** |
| exploration `walker.gd` | 0.35 | roof | 2/14 m | **50.36°** |
| game envelope `data.mjs:61` | 0.42 | civic | 0.15 m | **48.01°** |
| game envelope `data.mjs:61` | 0.42 | roof | 2/14 m | **47.27°** |

Documented band (`BLOCKERS_EFFICIENCY_20261005.md` §1, post-X README): ~47.5–51.3°.
This is an analytic reproduction of the same geometry, **not** the native
measurement and not a substitute for it.

## 2. Implicated stair runs and treads

All **354** tread contacts in the pinned evidence are **ascent (−Z) edge**
contacts. This is verified in the test suite, not assumed: for every tread
contact the triangle minimum Y is flat and `min(Z) == tread.z0` exactly.

| run | treads | footprint | rise | going | grade | ascent edges | in accepted runtime JSON |
|---|---|---|---|---|---|---|---|
| civic | `civic-stair-0` … `civic-stair-79` (80) | X 30–34, Z 25–65 | 0.15 m | 0.5 m | 16.699° | 80 | **yes** |
| roof | `roof-ramp-step-0` … `roof-ramp-step-13` (14) | X 16–20, Z 53–65 | 2/14 m | 12/14 m | 9.462° | 14 | **no (candidate-only)** |

Source: `vesper-viaduct/recipe.mjs:15` (`z=25+i*.5, y=12+(i+1)*.15`) and
`revisions/urban-v2/recipe-v2.mjs:127` (`z0=53+i*12/14, y=22+(i+1)*2/14`). The
civic treads are cross-checked against all 80 `civic-stair-*` surfaces in
`godot/multiplayer_worlds/generated/vesper-viaduct.json`.

**The roof run is not in the accepted runtime world JSON.** Its only in-repo
geometry is the pinned evidence triangles plus the recipe formula; both agree.
A future grant must confirm it against a built candidate world.

Contact ledger: 368 records → 356 contact entries → **354 tread ascent-edge
contacts** + **2 non-tread** contacts. The 2 non-tread contacts are
`central-row-16-45-1602/1603` wall triangles at the roof terrace
(`candidate-route:roof-access-ramp:2:35`, the accepted-side `OverheadSide2104/2105`
counterexample from the post-X README). **A stair bevel cannot address those**;
they are a wall-body question and are listed as out of scope in §7.

## 3. Options

| option | contact normal | height-preserving | verdict |
|---|---|---|---|
| **(a) 45° edge bevel**, leg ≈ 0.0434 m | exactly 45.0°, position-independent | **yes**, proven | **recommended** |
| (b) thin ramp overlay | 16.699° (civic) / 9.462° (roof) | **no** — proven below | rejected |
| (c) controller step-up routine | n/a (code, not geometry) | n/a | out of scope per plan §1.3 |

### Why the brief's 0.02 m suggestion is not sufficient

A bevel only works if the capsule rests on the bevel **face**, not its lower
edge. The perpendicular foot lands on the face only when the axis clears the
bevel's lower vertex by `radius·cos(45°)`:

```
separation + radius − rise + leg  ≥  radius·cos(45°)
```

For the 0.35 exploration capsule on the 0.15 m civic rise this needs
**leg ≥ 0.0414 m**. At leg = 0.02–0.04 m the capsule catches the bevel's
**lower edge** instead, and the normal stays edge-steep: 48.65° at 0.02 m,
47.39° at 0.03 m, 46.17° at 0.04 m — all still above 46°. This is recorded as a
test (`test_too_small_a_bevel_does_not_reach_the_face`), not buried.

### Why a thin ramp fails on height preservation

The post-X README's nav490 caveat is reproduced exactly by the tool:

| candidate | nav490 support Y | delta from 13.8 |
|---|---|---|
| current / beveled | **13.8** (bit-identical) | **0** |
| naive continuous 12→24 grade | 13.772727272727272 | **−0.027273 m** |
| tread-faithful 12.15→24 grade | 13.9005676 | **+0.100568 m** |

The naive ramp reproduces the documented value to 1e−12, which validates the
model. Both ramps change a route support height, so both are rejected. The
treads are the contract.

## 4. Recommended parameters

A **45° chamfer of leg 0.0434 m** on the **ascent (−Z) face only** of all 94
treads (80 civic + 14 roof).

The leg is the **midpoint of the admissible window**, not a hand-picked value:

| bound | value | source |
|---|---|---|
| floor | 0.041422 m | 46° guard limit for the 0.35 capsule (bisected) |
| ceiling | 0.045455 m | `navNode[489]` clearance to `civic-stair-4`'s ascent edge |
| going | 0.5 m | must not consume the tread |
| **chosen** | **0.043438 m** | midpoint, 1.0° guard margin |

Result: contact normal **45.0°**, a **1.0° margin** under the 46° guard
(`cos` margin 0.0124, ~62× the guard's own numeric budget `safe_margin/100`).
Because the bevel face is planar, the normal is position-independent — the
worst case over the whole 0–0.40 m approach sweep equals the best case.

**Ascent face only.** Dropping off the descent (+Z) face is a fall, not a
contact-normal problem: a resting capsule's lowest point *is* its standing plane
and the next tread down is `rise` lower. Beveling the descent face is also
**not** height-preserving (`descentEdgeRejected.preserved == false`), so the
ascent-only recommendation is both minimal and necessary.

## 5. Expected effect

**On the 184 records / 356 entries:** the 354 tread ascent-edge contacts move
from 47.3–51.3° to 45.0°. The 2 roof-terrace wall contacts are untouched — they
are wall bodies, not stair geometry.

**On the 46° guard:** statically, all 354 tread contacts come within tolerance.
The guard's other predicates (collider identity, `colliderVelocity`, contact
Y vs `landingY`, no-slide branch) are **not** evaluated here and remain
unproven; this proposal addresses the normal-angle predicate only.

## 6. Height-preservation proof outline

Method (`stair_clearance.py`): for every audited point, resolve the highest
walkable tread top at or below its reference height **before and after** the
bevel, and compare with **bit-exact float identity** (`struct.pack(">d")`).
Two metrics are reported, never conflated:

- **strict** — zero-radius vertical ray. Sensitive to exact tread seams.
- **capsule** — the 0.35 m capsule footprint, the physical metric.

Audited: **765 points** — 591 `navNodes`, 168 route points, 6 spawns, 3
objective zones, plus the 99 pinned contact foot positions.

| result | value |
|---|---|
| genuine support losses | **0** |
| capsule support preserved | **true** (all) |
| strict ray changed | **1** (`navNode[493]`, classified `on_boundary`) |
| **nav490 support** | **13.8, bit-identical** |

**The one flagged case.** `navNode[493]` sits at exactly `z = 42.5`, the seam
between `civic-stair-34` (y 17.25) and `civic-stair-35` (y 17.4). Its strict ray
shifts 17.4 → 17.25 under *any* positive bevel, because a zero-width ray at a
seam already depends on which tread it resolves to. This is **pre-existing
seam ambiguity, not a new defect**: the capsule-resolved support is 17.4 both
before and after, and the −0.15 m figure is a full riser drop, not a bevel
artifact. It is reported as `seamAmbiguityOnly`, not suppressed.

Also verified: `navNode[489]` (0.045455 m clearance) is why the window has a
ceiling; a leg at or beyond it *does* lose real support, proven by
`test_a_leg_beyond_the_window_does_lose_support`.

**Geometry diff.** 188 → 376 faces: each of the 94 treads keeps its top plane
bit-identical and gains exactly 2 chamfer triangles. No other collider changes.
Overhead clearance is unaffected by construction (a bevel only subtracts), and
an exact triangle/box separating-axis test over all 80 wedges against every
authority triangle reports **0 clashes**.

## 7. Rebuild and verification steps (for a future grant)

Not executed here. In order:

1. **Apply the reviewed builder patch** (§8) — a reviewer must apply it; this
   branch does not touch the live recipe.
2. **Rebuild** the Vesper world from source; confirm `geometryHash` changes and
   inspect the diff is exactly 94 treads × 2 added chamfer triangles.
3. **Re-run the static contact census**:
   `python3 diagnose_contacts.py` in this directory, then compare against
   `contacts-evidence.json`. Expect the 354 tread contacts to clear; the 2
   `central-row-16-45` wall contacts are **expected to persist**.
4. **Re-run the prepared 60-journey batch** via `controller_journey.gd`
   commands in `NATIVE_BINDING_FOLLOWUP.md`, groups `accepted-civic-r035`,
   `accepted-civic-r042`, `candidate-civic-r035`, `candidate-civic-r042`,
   `candidate-roof-r035`, `candidate-roof-r042`, with the continue-and-triage
   wrapper (plan §1.1). Run it **first**, before this patch, to establish
   whether stalls are real at all.
5. **Re-run** `python3 -m unittest test_stair_clearance test_stair_clearance_patch`
   and `node tests/builder-leg-literal.test.mjs` after any geometry change.

### Risks

- **Overhead collision** — none geometrically; a bevel only subtracts, and 0
  wedge/collider clashes were found. Native re-verification still required.
- **Roof run** — candidate-only, absent from the accepted runtime JSON. Its
  geometry rests on evidence + recipe agreement, not on a built world. Highest
  residual risk; verify against a built candidate before trusting it.
- **Water/roof steps** — the 2 remaining contacts are roof-terrace wall
  triangles, out of scope for a stair bevel. If the native batch still fails
  there, that is a **separate** roof-terrace wall proposal.
- **Route resampling** — navNodes were authored at exact tread seams
  (`navNode[493]`). A bevel does not require resampling, but the seam
  ambiguity should be noted by any future resampling change.
- **Marginal window** — the admissible window is 0.0040 m wide. Parameters must
  be read from the report, not retyped.

## 8. Builder patch (proposed, NOT applied)

`stair_clearance.bevel_triangles()` emits the exact replacement geometry. A
concrete patch is provided **for review only** as
`vesper-stair-bevel-20261005.patch`. It is a patch file, not applied to any
live recipe:

```
tools/godot-multiplayer/new-maps/vesper-viaduct/recipe.mjs
tools/godot-multiplayer/new-maps/vesper-viaduct/revisions/urban-v2/recipe-v2.mjs
```

Both need the same helper: for each authored tread, pull the walkable top face
back by `leg` at its −Z edge and add a 45° chamfer quad. **Applying it requires
a new grant.** Nothing in this branch edits those files.

## 9. Scope statement

- Proposal and analysis tooling only. No runtime or artifact change.
- No native run, no engine invocation, no Blender, no network.
- No claim that Vesper passes, or that the 184 contacts are resolved.
- The **184 static contacts remain failed.** Static geometry analysis cannot
  substitute for the native movement batch.
- Static contact analysis is not movement: the post-X README's own position is
  that the production mover already traverses both runs, and only the native
  batch can confirm that for the exploration `CharacterBody3D`.
- Controller profile (46° / 0.3 / 0.02) is **unchanged**, per plan §1.3.
- Roof-run claims are the weakest here; see §7.

## 10. Reproducing

```bash
cd tools/godot-multiplayer/new-maps/botanical-post-x
python3 stair_clearance.py                                   # writes the evidence file
python3 -m unittest test_stair_clearance test_stair_clearance_patch -v
node tests/builder-leg-literal.test.mjs                       # pins the patch's leg literal
```

59 Python tests + 11 Node checks, deterministic, no engine. Reads only the
accepted runtime world JSON and the pinned evidence; writes only its own
evidence file.

Current output:

```
civic run: 80 treads, 80 ascent edges, rise 0.15 m, going 0.5 m, grade 16.699244 deg
roof run:  14 treads, 14 ascent edges, rise 0.142857 m, going 0.857143 m, grade 9.462322 deg
unbeveled analytic band 47.27-51.34 deg vs documented 47.5-51.3 deg
admissible leg window: [0.041422, 0.045455] m
recommended: leg 0.043438 m, 45.0 deg chamfer, margin 1.0 deg
height preservation: True over 765 audited points; genuine support losses 0
nav490: civic-stair-11 support 13.8 bit-identical=True
         naive ramp 13.772727 (delta -0.027273 m)
contacts: 354 tread ascent-edge addressed, 2 non-tread untouched
```