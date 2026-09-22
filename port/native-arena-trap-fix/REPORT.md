# Native arena trap fix (trap-fix lane)

Lane paths: `tools/godot-native-arenas/compile.mjs` (movement-wall compiler),
`godot/native_arenas/maps/{prism-foundry,aurora-basin}.gd`, `godot/tests/native_arenas/geometry/{probe.gd,capture.gd}`,
regenerated `godot/native_arenas/generated/*.json`, refreshed
`port/native-arena-geometry/**` evidence, and this new report directory.

Input: the High-severity defect in `port/native-arena-review/REPORT.md` §2 —
a live prism bot landed 0.06 m inside the west ramp edge at `(-8.96, 3.42,
-8.40)` and stayed immobile for 71 s (`maxRadius 0.00`, hopping in place),
mirrored at `(9.0, 3.6)` on the east ramp; cinder showed brief 1.5–5 s
windows; Meridian (locked source) and Aurora showed none in the reviewed runs.

## 1. Reproduction before the fix

`node port/native-arena-review/trap-min.mjs` (kept as
`logs/trap-min-before.json`) on the reviewed asset (`9ba6d451…`):

| Trial from `(-8.96, 3.42, -8.4)` | max horizontal displacement |
| --- | ---: |
| `+x`, `-x`, `+z`, `-z` | 0.000 m each |
| jump held, `+x` | 0.000 m |

`obstructed(..., r)` at the spot was `true` for r = 0.06, 0.2, 0.3, 0.42 and
0.5: the bot stood inside the union of the ramp skirt band (top ±0.23 m above
the local ramp surface, because bands are emitted per 0.6 m piece with the
piece maximum as top) and the ramp guard rail band. Source `moveActor` refuses
each axis step whose destination is inside the 0.42 m contact radius and
zeroes that axis velocity, so no sub-centimetre step can leave the band.

## 2. Fix

Two layers, both in lane ownership; the locked source simulation (`game/**`)
is untouched.

**Compiler rules (`tools/godot-native-arenas/compile.mjs`, movement bands
only — rays keep the full collider mesh):**

1. *One-sided burial*: drop a band piece whose top is within the source 30 cm
   step limit of the lowest walkable support found inside the contact reach of
   either side (perpendicular samples at 0.15/0.30/0.42 m, plus 0.45 m past
   both piece ends). The ramp/causeway **skirt** class disappears: an actor on
   the slope can no longer be blocked by the wall it stands on, while the
   lower side stays blocked by the band and the step limit.
2. *Terrace handling*: where a walkable surface sits at the band's own top
   level just behind it (service banks, crown buttresses), raise the band's
   bottom to the lower standing level + 1.85 m. The band still blocks jumps
   and the sealed-volume interior probes, but a standing actor on the lower
   floor is no longer refused.
3. *Overhang skirt*: a band whose bottom hangs within a body height of a lower
   walkable floor is raised the same way, so landing under a floating edge
   cannot trap.
4. *Walkable-topped short barriers / caps*: drop bands whose own midpoint (or
   ±0.15 m grid probe) is walkable support within 0.3 m of the top and whose
   height is ≤ 2.2 m. The source step limit refuses crossing such a kerb/cap,
   so the band was redundant; this is what removes the adapted guard-rail
   bands. Flat-topped sealed volumes (taller, probed by the delivery gate) are
   excluded by the height guard.

**Authored guards:** prism's ramp, mezzanine and observation deck rails and
aurora's skywalk/vista guard lines now carry `dm_walkable` on their collision
shape, so their caps are real walkable support and rule 4 removes their
movement bands. The rail's visible geometry, height and full ray/projectile
collision are unchanged; the source step limit (1.28–1.32 m cap) refuses
walking across them, and the cap is standable if an actor lands on it. Cinder's
safety walls keep their original collision: marking their caps walkable broke
`navigation` connectivity in the delivery gate (16 isolated cap nodes), so
Cinder relies on rules 1–3 only.

**Why this cannot reintroduce the band:** rule 1 only removes bands whose top
is flush with a standable surface on that side; rules 2–3 raise a band's
bottom above a lower actor's head; rule 4 only removes bands whose own cap is
walkable support (the step limit then blocks the crossing that the band used
to block). None of them removes a movement barrier whose crossing would still
be legal.

## 3. Reproduction after the fix

`node port/native-arena-review/trap-min.mjs` on the delivered asset
(`1901d0ae…`, `logs/trap-min-after.json`): `obstructed` at the spot is `false`
at r = 0.06 and r = 0.42, and

| Trial | max horizontal displacement |
| --- | ---: |
| `-x`, `+z`, `-z` | 4.227 m / 16.735 m / 8.829 m (escaped) |
| jump held, `+x` | 16.089 m (escaped) |
| plain `+x` | 0.024 m — *blocked by the guard rail*, which is the intended guard at the ramp edge |

An independent static scan (`logs/band-scan-*.json`) and the reviewer's
`geometry-analysis` mirror (`logs/geometry-analysis-*.json`) confirm the
delivered bands stay near collider geometry (`walkableRayBlocked = 0` on all
three maps; the only retained analysis issue is the pre-existing
`movement-barrier-without-boundary: 1` per map, unchanged from the reviewed
revision).

## 4. Geometry hashes (changed — lead re-acceptance requested)

| Map | Reviewed hash | Delivered hash |
| --- | --- | --- |
| prism-foundry | `9ba6d451e7acb61847d1b5726ec52385c019e32bbc0805731f14396aca336572` | `1901d0aed12c5cfb3be5b7a62519bce108d1f0d51f79a726f4e14620544ae91b` |
| aurora-basin | `2a8c06ba5b3a893135a3a6aef906a36f016107b5153fe5ec3b8a9efbfee66c86` | `8457812f7845475378e0f99616ca91b3dac3aa4bff3a396a9e6739e9b8917a21` |
| cinder-array | `e4b7763a5dae391cfcc0e9a13b5202a054cdfd9761c449cf6a4bf2fd4765ab8c` | `2d5e5cfa445383db4f6a3009a0f7500e423ec17dfe800d35cafa2fd8272da4f2` |

Wall-band counts moved 1081→590 (prism), 7398→4849 (aurora), 1588→848
(cinder); navigation is one connected component on all three maps
(427/311/372 nodes; the reviewer measured 378/303/369 on the reviewed
revision — the prism/aurora node counts changed with the band set, as the nav
bake samples walkable support).

## 5. Gates run after the fix

| Gate | Result | Log |
| --- | --- | --- |
| `rebuild.mjs --check-determinism` | exit 0, byte-identical hashes | `logs/rebuild-determinism.log` |
| `node --test port/native-arenas/tests/actual-maps.mjs` | 3/3 pass | `logs/tests-actual-maps.log` |
| `tools/godot-native-arenas/movers.mjs` | all routes finished, 0 errors | `logs/movers.log` |
| `tools/godot-native-arenas/verify.mjs` | all parity checks pass (255/313/181 floor, 1276/1566/906 ray) | `logs/` + `port/native-arena-geometry/verification.json` |
| launcher smoke `--experience=native-dm --map=<id> --smoke` | 3/3 `NATIVE_DM_SMOKE_OK` with the new hashes | `logs/launcher-*-smoke.log` |
| reviewer harness mirror (`review/trap-repro.mjs`, `review/analyze-geometry.mjs`) | longest window 2.5 s (was 71 s); no new analysis issue kind | `logs/review-trap-repro-*.out`, `logs/geometry-analysis-*.json` |
| trap audit `trap-audit.mjs` (1 human + 7 bots, 180 s) | prism 0 locks / 0 inside-band windows at 3 seeds; aurora 0 at 2 seeds; cinder 0 at seed 777, 3 landed locks at seed 20260922 on natural caldera terrain | `logs/trap-audit-*.json` |

The audit's stricter detector requires the actor to be immobile (>1.5 s,
<0.25 m), refused by movement at its own position (r = 0.42) and standing on a
surface. With the pre-fix asset the same detector found Cinder seed 777
windows of 30.75/29/16/6.5 s; the delivered asset has none there.

## 6. Evidence refresh

- `evidence/final/` now carries the delivered hashes: Aurora at 960×640,
  1280×720, 1280×800 and 1920×1080; Prism at 1280×720 and 1920×1080 (the
  1920×1080 Prism pass that previously aborted now completes); Cinder
  re-captured at 1280×720/1920×1080 since its hash also changed.
- Real PNG dimensions are asserted by `capture-evidence.mjs` and each log
  line states `first_person:true`, `msaa:"disabled"`, `rendering_method:
  gl_compatibility`, `video_adapter: llvmpipe (LLVM 20.1.8, 256 bits)` and
  `software_renderer: llvmpipe under Xvfb`.
- The stale pre-navigation Aurora set (old hash `909daa29…`) plus its log was
  moved to `evidence/pre-navigation-fix/`, and
  `evidence/final/README.md` maps every image to its hash instead of silently
  overwriting meaning. `evidence/final/actual-source-maps.log` and
  `deterministic-rebuild.log` were regenerated with the delivered hashes.

## 7. Residuals / not proven

- **Cinder natural terrain.** Three landed locks (97.5 s, 22 s, ≤2 s) remain at
  Cinder seed 20260922 on non-walkable caldera steps; the same class exists in
  the pre-fix asset (four windows up to 30.75 s at another seed) and in the
  reviewed revision. The authored DM geometry on Cinder (sloped causeways,
  platforms, safety walls) no longer produces landed locks in these runs, but
  the terrain step class needs either source depenetration (locked) or terrain
  reshaping, which is outside this defect's surgery.
- **General source-model limit.** Any obstacle that keeps a movement band over
  walkable ground can trap a landing actor whose jump apex (≈1.34 m) is below
  the band top. Ground-standing solids such as the atrium piers, the outer
  walls and the reactor plinth still have such bands; the scanner quantifies
  the remaining supported contact strips in `logs/band-scan-*.json`. Full
  elimination requires source depenetration or removing the obstacle.
- **Gate fixture change.** `probe.gd`'s prism sealed-volume ray now starts at
  `(-12, 3.0, 4)` instead of `(-12, 1.5, 4)`: the old origin hit the DM ramp
  guard rail first, so the assertion exercised the ramp skirt (now walkable)
  rather than the west service bank the probe is named for. The movement
  assertion itself is unchanged; this is flagged for the lead.
- Performance and rendering claims remain Linux GL Compatibility/llvmpipe, not
  Windows/GPU.
