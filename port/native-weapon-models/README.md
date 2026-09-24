# First-person weapon identity pass — models, tones, silhouettes, evidence

Second pass on the first-person weapons. The first pass gave every weapon real
detail; review found they still read as one family ("they share a lot of DNA
still"). This pass makes **each weapon's outline and finish unmistakable at a
glance**, measures that property instead of claiming it, and keeps every
invariant the lane already had.

Owned paths in this lane: `tools/godot-weapons/**`,
`godot/first_person/generated/**`, `port/native-weapon-detail/**`, this
directory (`port/native-weapon-models/**`). `game/**` stays locked and
read-only: no source geometry was moved, scaled, removed or regenerated — every
change is authored detail geometry or a per-weapon material instance bolted onto
the existing assemblies.

## What changed

1. **Silhouette-first detail rewrite** (`tools/godot-weapons/detail.mjs`). Every
   weapon is rebuilt around one dominant mass, one dominant projection and one
   dominant terminator (the ten ideas are in `WEAPON_IDENTITY.md`). Large,
   cheap primitives carry the read; greebles support it. Highlights: the Rocket
   Launcher's trumpet muzzle and rear venturi bell, the Rail Lance's rails that
   fork forward past the muzzle, the Plasma Driver's twin bulbs and round flank
   exchangers against the Shock Beam's square capacitor comb and long fork, the
   Grenade Launcher's top strap over a flared drum, the Flak Cannon's carry
   handle and bell, the Marksman Rifle's under-receiver spine, folded bipod and
   monopod, and the SMG's oversized quad-stack magazine hanging far below a stub
   receiver.
2. **Per-weapon metal tones and finishes** (`detail.mjs` `TONES`/`FINISH`, wired
   in `export.mjs`). The two shared detail materials stay byte-identical; each
   weapon's own `dark`/`light` instances are mixed toward its `data.mjs` colour
   and finished with a family surface recipe. Zero draw calls added — a batch is
   `(assembly × role)` and the role set is unchanged.
3. **Measured silhouette identity** (`tools/godot-weapons/silhouette.mjs`). Every
   exported triangle is rasterised into fixed weapon-space side/top masks; the
   ten masks are compared pairwise by IoU, and the authored detail pass is
   measured separately (`detailSide`). `verify.mjs` gates the numbers.
4. **Measured rendered distinctness** (`tools/godot-weapons/rendered-distinctness.mjs`).
   Companion measure on the captured frames: mean absolute pixel difference
   inside the viewmodel crop, pairwise.
5. **Hardening** in the exporter: non-finite detail transforms are refused;
   non-finite boxes can no longer slip through the corridor or clearance
   comparisons (they compare false for NaN).

## Distinctness numbers

Analytic masks (2 cm cells, weapon-space; lower is more distinct):

| view | before (HEAD) | after | gate |
|---|---|---|---|
| side (hip outline) | max **0.823** (Plasma vs Shock), mean 0.612 | max **0.744** (same pair), mean 0.594 | ≤ 0.78 |
| top (overhead) | max 0.794 (Pulse vs Marksman) | max 0.821 (same pair) | reported |
| detailSide (authored detail only) | max 0.305, mean 0.175 | max **0.284**, mean 0.175 | ≤ 0.40 |

Detail coverage of the outline rose from 1,524 to **2,118** mask cells (+39%)
while the detail-only IoU stayed flat: the pass added visible outline without
converging the shapes. The full-model side IoU is bounded by the locked source
chassis (all ten weapons are receiver + barrel + feed in the same envelope), so
the gate is the measured separation with margin; the `top` view is dominated by
the locked receiver width and is reported, not gated.

Rendered frames (mean absolute pixel difference inside the viewmodel crop,
pairwise over the ten 1280×800 hip captures):

| | min pair | mean | max |
|---|---|---|---|
| before | 5.2 (Plasma vs Shock) | 11.3 | 15.0 |
| after | **9.6** (Pulse vs Plasma) | **14.5** | 19.0 |

Material tones: minimum pairwise Euclidean RGB distance between `light` tones is
**25.0** (gate 20), between `dark` tones **10.5** (gate 9), and no two weapons
share a (dark, light, finish) recipe.

## Budget table

| # | weapon | triangles | source | detail | prims | batches | hand clearance | detail mask cells |
|---|---|---|---|---|---|---|---|---|
| 0 | Pulse Rifle | 4,424 (was 4,484) | 3,512 | 912 | 70 | 8 | 58 mm | 223 |
| 1 | Rocket Launcher | 4,904 (was 5,204) | 4,052 | 852 | 58 | 8 | 58 mm | 269 |
| 2 | Rail Lance | 6,432 (was 6,472) | 6,044 | 388 | 27 | 8 | 78 mm | 156 |
| 3 | Scattergun | 4,720 (was 4,752) | 3,920 | 800 | 57 | 8 | 59 mm | 156 |
| 4 | Plasma Driver | 5,968 (was 5,992) | 5,024 | 944 | 51 | 8 | 47 mm | 232 |
| 5 | Grenade Launcher | 5,028 (was 5,152) | 3,980 | 1,048 | 73 | 8 | 74 mm | 217 |
| 6 | Shock Beam | 5,564 (was 5,640) | 4,448 | 1,116 | 62 | 8 | 89 mm | 181 |
| 7 | Flak Cannon | 4,848 (was 4,828) | 3,812 | 1,036 | 68 | 8 | 49 mm | 263 |
| 8 | Marksman Rifle | 5,936 (was 5,996) | 5,228 | 708 | 54 | 8 | 53 mm | 204 |
| 9 | Submachine Gun | 4,452 (was 4,448) | 3,620 | 832 | 63 | 8 | 47 mm | 217 |

Total GLB bytes went from 5,169,304 to 5,102,900. Triangles went *down* on eight
of ten weapons (larger primitives replaced clusters of small greebles) while the
detail pass got bolder; the two weapons whose locked source geometry dominates
(2, 8) stay inside the same ceilings.

## Gates (all green, logs in `evidence/logs/`)

```
"$GODOT_BIN" --headless --path godot --import                                  # exit 0
node tools/godot-weapons/verify.mjs                                            # exit 0 (byte-identical re-export, 6 channels, 8 batches, silhouette + tone gates)
"$GODOT_BIN" --headless --path godot --script res://tests/first_person/detail.gd        # 345 checks, 0 failures
"$GODOT_BIN" --headless --path godot --script res://tests/first_person/ads_contract.gd  # 0 failures
"$GODOT_BIN" --headless --path godot --script res://tests/first_person/handling.gd      # 5,295 checks, 0 failures
"$GODOT_BIN" --headless --path godot --script res://tests/first_person/lifecycle.gd     # 57 checks, 0 failures
python3 tools/godot-dev/xvfb_run.py "$GODOT_BIN" --path godot --rendering-method gl_compatibility \
  --audio-driver Dummy --script res://tests/first_person/framing.gd -- --evidence-out=<dir>   # 24 images, centre 48 px clear
python3 tools/godot-dev/xvfb_run.py ... res://tests/first_person/ads.gd -- --evidence-out=<dir>              # 910 checks, 0 failures, 120 images
python3 tools/godot-dev/xvfb_run.py ... res://tests/first_person/handling_capture.gd -- --evidence-out=<dir> # 482 checks, 0 failures, 140 images
node tools/godot-weapons/handling-contact-sheets.mjs <dir> <out>               # 14 sheets, 20 strips
```

ADS never regressed: sight axis 0.0 px, anchors 0.0 px, **0** opaque pixels in
the 4×4 px target gap for all ten weapons at both capture sizes (the `ads.gd`
gate above), and hip framing keeps the 48×48 px reticle region clear.

## Evidence (`evidence/`)

| path | contents |
|---|---|
| `evidence/before/` | 40 hip/ADS captures at 960×640 and 1280×800 from the pre-pass export (HEAD) |
| `evidence/after/` | the same 40 captures from this pass, same fixture, same camera |
| `evidence/sheets/before-after-hip.jpg` | per weapon: hip before / hip after at 1280×800 |
| `evidence/sheets/before-after-ads.jpg` | per weapon: ADS before / ADS after at 1280×800 |
| `evidence/sheets/turnaround-poses.jpg` | per weapon: hip, fire, reload, hot-ADS from the handling fixture |
| `evidence/sheets/silhouette-masks-before.png` | analytic side/top/detail masks before (cyan = detail-only) |
| `evidence/sheets/silhouette-masks-after.png` | the same masks after — the turnaround/silhouette comparison |
| `evidence/sheets/contact-*-before/after.jpg` | the lane contact sheets (hip+ADS, both sizes) |
| `evidence/sheets/sheet-*.jpg`, `strip-*.jpg` | handling contact sheets (all ten weapons, seven poses) |
| `evidence/metrics/identity-metrics.json` | budget table, six-channel table, tone table, silhouette IoU matrices before/after, RAM totals |
| `evidence/metrics/rendered-distinctness.json` | pairwise rendered frame differences, before and after |
| `evidence/logs/` | every gate log from the final run |

## Tools added by this pass

| tool | purpose |
|---|---|
| `tools/godot-weapons/silhouette.mjs` | mask rasterisation + IoU metric (imported by `export.mjs` and `verify.mjs`) |
| `tools/godot-weapons/silhouette-report.mjs` | pairwise IoU report for a manifest (`--json` for machine use) |
| `tools/godot-weapons/silhouette-map.mjs` | ASCII diagnostic of one weapon or one pair's masks |
| `tools/godot-weapons/silhouette-sheet.mjs` | the mask comparison sheets in `evidence/sheets/` |
| `tools/godot-weapons/rendered-distinctness.mjs` | pairwise rendered frame difference for a capture directory |

## Deliberately left out / follow-ups

* **Third-person world weapon models** (`tools/godot-operators/world-weapons.mjs`,
  `godot/source_operators/generated/world_weapons/**`) are *not* in this lane.
  They still read the six channels from `WEAPON_IDENTITY.md`; they do not yet
  carry the new per-weapon tones or the silhouette ideas at their own budget.
  Follow-up: mirror `TONES`/`FINISH` and the ten silhouette ideas (or a
  deliberate simplified subset) at world-model resolution and add the same
  distinctness read-out there.
* **Weapons whose source mechanism constrained the silhouette**:
  * `2 Rail Lance` and `8 Marksman Rifle` already spend 6.0k/5.2k triangles on
    locked source geometry and their integrated optics, so their detail pass is
    small (388 / 708 triangles) and their rail/fork and spine/bipod ideas are
    carried by fewer, larger primitives. The Rail Lance's single barrel collar
    ring also drops to 12 tubular segments to buy 48 triangles; shape, radius and
    position are unchanged and the sight-assembly rings keep their 32 segments.
  * `0 Pulse Rifle` and `9 Submachine Gun` are locked to the narrowest receivers
    (170 mm / 160 mm), so they differentiate forward (perforated shroud, oversized
    magazine) rather than by adding width.
  * `4 Plasma Driver` cannot put its bulbs forward of the support grip (locked
    hand station), so the second bulb sits over the receiver front and the
    forward identity is the focus cage.
* **No new materials and no texture work**: batches stay at exactly 8 per weapon,
  per the shared policy; the tone identity is per-weapon *instances* of the same
  material roles.
* **Weapon behaviour is untouched**: no recoil, spread, ammo, reload timing, ADS
  rate or handling authority was read or written.
