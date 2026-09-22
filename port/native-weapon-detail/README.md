# First-person weapon detail and differentiation

Pre-release lane on `port/godot-destinations`. Scope: real detail geometry and a
deliberate identity for all ten first-person weapons, presentation-only handling
motion, and rendered evidence that both read. Owned paths:
`tools/godot-weapons/**`, `godot/first_person/**`, `godot/tests/first_person/**`,
`port/native-weapon-detail/**`.

`game/**` is locked source: this lane only *augments* it. Every model is still
built by `game/weapon-models/**` with an unmodified construction; the exporter
bolts detail onto the same assemblies, rebases the authored anchors exactly as
before, and bakes one mesh per (assembly, material slot).

**`WEAPON_IDENTITY.md` is the shared single source of truth**: six channels per
weapon, the material/batch policy, the locality rules and the invariants. The
third-person lane
(`tools/godot-operators/world-weapons.mjs`) matches the same channels at its own
budget.

## Delivered

1. **Detail augmentation in the exporter** (`tools/godot-weapons/detail.mjs`,
   wired in `tools/godot-weapons/export.mjs`): 519 small hard-surface primitives
   (chamfered slots, open tubes, rings, cones, discs, fins) that add **+9,280
   triangles** across the arsenal, attached to the *existing* moving assemblies —
   rail hardware and a bolted front-sight base, handguard shrouds with ports,
   ejection-port treatments at the authored `Ejection` station, heat louvres
   around `HeatZone`, muzzle devices (hider/brake/choke/focus/accelerator/ports),
   feed dressing on the moving `Feed` group only, stock/grip treatments clear of
   the right hand, and the per-weapon emissive signature.
2. **Identity framework** (`port/native-weapon-detail/WEAPON_IDENTITY.md`, data
   in the manifest `identity` block): six distinct channels per weapon, all
   machine-checked for distinctness by `tools/godot-weapons/verify.mjs` and by
   `godot/tests/first_person/detail.gd`.
3. **Eight material batches per weapon** (down from 8–11; one surface each):
   `bolt` is a single shared `detail-trim` slot, the barrel moves its blued
   hardware to the shared `detail-cavity` tone, and the body/feed keep the source
   `dark`/`light`/`glow` roles. Two new shared materials are used
   (`#c6ced2` machined trim, `#0d1519` recess) and no textures were added.
4. **Presentation motion** (`tools/godot-weapons/handling.mjs` `presentationProfile`
   + `RELOAD[*].flourish`, consumed by `rig.gd` and `handling.gd`): per-weapon idle
   sway character (rate 0.42–3.4 rad/s, ≤2.2 mm, ≤0.0032 rad, exactly zero at a
   settled cheek weld and under reduced motion), action-hardware legibility with a
   bounded rattle that is exactly zero at rest, and a per-family magazine
   seat/spin/twist flourish that is a pure function of the authoritative reload
   progress and exactly at rest at both window ends. No authority is read or
   written; recoil, spread, ammo and reload timing are untouched.
5. **Renders**: 280 full-resolution captures at 960×640 and 1280×800 (hip, ADS,
   firing, reload, heat, hot-ADS), contact sheets, and full-resolution stills in
   `evidence/`. Inspected by the lane; see the measurement tables below.

## Before / after (measured, `godot/first_person/generated/manifest.json`)

| # | weapon | batches | triangles | detail added | primitives | ring re-tessellation saved | hand clearance | GLB bytes |
|---|---|---|---|---|---|---|---|---|
| 0 | Pulse Rifle | 9 → **8** | 3704 → **4484** | +972 | 71 | 192 | 60 mm | 438,908 |
| 1 | Rocket Launcher | 8 → **8** | 4340 → **5204** | +1152 | 61 | 288 | 66 mm | 507,936 |
| 2 | Rail Lance | 10 → **8** | 6284 → **6472** | +380 | 16 | 192 | 113 mm | 629,664 |
| 3 | Scattergun | 8 → **8** | 4304 → **4752** | +832 | 47 | 384 | 67 mm | 464,796 |
| 4 | Plasma Driver | 10 → **8** | 5792 → **5992** | +968 | 53 | 768 | 61 mm | 583,656 |
| 5 | Grenade Launcher | 9 → **8** | 4124 → **5152** | +1172 | 61 | 144 | 77 mm | 503,032 |
| 6 | Shock Beam | 11 → **8** | 4640 → **5640** | +1192 | 51 | 192 | 89 mm | 549,788 |
| 7 | Flak Cannon | 8 → **8** | 3956 → **4828** | +1016 | 59 | 144 | 50 mm | 471,900 |
| 8 | Marksman Rifle | 8 → **8** | 5420 → **5996** | +768 | 41 | 192 | 67 mm | 584,152 |
| 9 | Submachine Gun | 9 → **8** | 3812 → **4448** | +828 | 59 | 192 | 47 mm | 435,472 |
| — | **total** | 90 → **80** | 46,376 → **52,968** | **+9,280** | **519** | 2,688 | — | 5,169,304 |

Eight of ten weapons sit inside the 3,000–6,000 triangle target. Weapons 2 and 8
carry integrated optics and their *locked source construction alone* spends
6,092 / 5,228 triangles; they land at 6,472 / 5,996, both inside the 6,500 gate
(`tools/godot-weapons/verify.mjs` asserts the per-weapon ceiling, which is 6,000
normally and 6,480 for those two). No source geometry was decimated to reach it —
the only tessellation change is the ring primitive described in
`WEAPON_IDENTITY.md`: sight-assembly rings keep the author's 32 tubular segments
(so the optic sight picture is pixel-identical to the baseline), while barrel and
chassis collar rings use 16 (20 for the two largest), which is the 2,688 triangles
that pay for the new detail.

## Invariants (all measured, all green)

| invariant | measurement | evidence |
|---|---|---|
| anchors within 1e-4 of previous weapon-space positions | **0.0** drift on all 123 anchors; identical parents and muzzle tables | `script` comparison versus `HEAD:manifest.json`; `logs/handling.log` rest error ≤ 1.2e-7 m |
| settled sight alignment | rear **0.0 px**, front **0.0 px**, axis **0.0°** | `logs/ads.log` (910 checks, 160 measurements) |
| target gap open | **0** opaque pixels in the 4×4 px gap above the front post, both sizes, all ten weapons | `logs/ads.log`, `logs/handling-capture.log` |
| muzzle reprojection | max error **8.6e-5 px** | `logs/ads.log` |
| grip stations | wrists at the anchors, max error **8.9e-8 m**; support hand follows the moving feed | `logs/ads.log` |
| hands clear of new geometry | min **47 mm** over all 519 detail boxes × 3 stations × (settled, reload 0.5, reload 0.94), measured through the live animated assemblies | `logs/detail.log` (345 checks) |
| sight line clear of new geometry | min **122 mm** | `logs/detail.log` |
| hip framing clear | centre 48×48 px empty at 960×640 and 1280×800 | `logs/framing.log` |
| moving anchors | `Bolt`/`Charging` ride the carrier, `HeatZone` the barrel, feed stations the feed; carrier travel ≤ authored stroke and exactly back to rest | `logs/handling.log` (5,295 checks) |
| weapon-effects + combat integration | real-rig flash count 10/10 weapons, max tracer projection error 1.2e-5 px; combat integration 1,013 + 12 checks | `logs/weapon-effects-rig.log`, `logs/combat-contracts.log`, `logs/combat-combined.log` |
| byte-identical re-export | true (sources hashed, GLBs, manifest and catalog byte-identical after re-running the exporter) | `logs/verify.log` |

## Reproduce

```sh
node tools/godot-weapons/export.mjs
node tools/godot-weapons/verify.mjs
GODOT=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
# Godot must re-import the changed GLBs before any runtime gate reads them.
"$GODOT" --headless --path godot --editor --import
"$GODOT" --headless --path godot --script res://tests/first_person/lifecycle.gd
"$GODOT" --headless --path godot --script res://tests/first_person/ads_contract.gd
"$GODOT" --headless --path godot --script res://tests/first_person/handling.gd
"$GODOT" --headless --path godot --script res://tests/first_person/detail.gd
"$GODOT" --headless --path godot --script res://tests/weapon_effects/lifecycle.gd
"$GODOT" --headless --path godot --script res://tests/weapon_effects/rig_integration.gd
"$GODOT" --headless --path godot --script res://tests/combat_integration/contracts.gd
"$GODOT" --headless --path godot --script res://tests/combat_integration/combined_adapter.gd
# Display gates (the binding gate needs a real pointer mode):
python3 tools/godot-dev/xvfb_run.py "$GODOT" --path godot --rendering-method gl_compatibility \
  --audio-driver Dummy --script res://tests/first_person/binding.gd
python3 tools/godot-dev/xvfb_run.py "$GODOT" --path godot --rendering-method gl_compatibility \
  --audio-driver Dummy --script res://tests/first_person/framing.gd -- --evidence-out=<dir>
python3 tools/godot-dev/xvfb_run.py "$GODOT" --path godot --rendering-method gl_compatibility \
  --audio-driver Dummy --script res://tests/first_person/ads.gd -- --evidence-out=<dir>
python3 tools/godot-dev/xvfb_run.py "$GODOT" --path godot --rendering-method gl_compatibility \
  --audio-driver Dummy --script res://tests/first_person/handling_capture.gd -- --evidence-out=<dir>
node tools/godot-weapons/ads-contact-sheets.mjs <dir>
node tools/godot-weapons/handling-contact-sheets.mjs <dir>
```

## Evidence

- `evidence/logs/` — all fifteen gate logs from the final sweep (exit code 0
  each), including the new `detail.gd`.
- `evidence/metrics/` — the 160 ADS measurements, 140 rendered handling
  measurements and the framing metrics from that sweep.
- `evidence/sheets/` — contact sheets: hip/ADS/animated poses, and one sheet per
  handling pose at both sizes (all ten weapons side by side).
- `evidence/fixtures/` — full-resolution stills (960×640 and 1280×800) for the
  poses that show the new detail: hip and ADS for all ten weapons, plus firing,
  reload and hot-barrel captures per family.

## Gaps and notes (nothing below was worked around silently)

- **Weapons 2 and 8 exceed the 6,000-triangle soft target** (6,472 / 5,996) because
  their locked source construction plus author-tessellated optic rings is already
  5.2–6.1k. They stay inside the 6,500 gate; no source geometry was decimated, and
  the optic rings keep the author's 32 segments so the magnified sight picture is
  unchanged. If the release wants a hard 6,000 cap on those two, the only honest
  lever left is the source optic construction in `game/weapons-models/chassis.mjs`,
  which is locked.
- **Ring collar re-tessellation** (16/20 tubular segments for barrel/chassis
  collars) is a primitive-level choice, not a geometry edit: radius, position,
  cross-section and count are unchanged. Sight-assembly rings are untouched. If a
  reviewer wants zero tessellation changes, the 2,688 recovered triangles must come
  from somewhere else — there is no other source-free budget lever inside the gate.
- **The Rail Lance carries the leanest detail** (16 primitives, +380 triangles)
  purely because of its source budget; its identity still lands through twin
  accelerator rings, coil rings, receiver plates and action hardware.
- **`Hammer` and `Slide` anchors still do not exist** (no source chassis authors
  them); unchanged from `port/native-weapon-handling`.
- **New gate to register (release owner owns `tools/godot-dev/**`):**
  `res://tests/first_person/detail.gd` (headless, 345 checks) — the machine-checked
  the detail contract (batches, triangle band, identity distinctness, hand and
  sight-line clearance through the animated assemblies, distinct idle sway).
- **Not proven here**: no live network session was re-run, no GPU/hardware timing
  and no human visual review beyond this lane's own inspection of the captures;
  rendering was verified on llvmpipe only.
