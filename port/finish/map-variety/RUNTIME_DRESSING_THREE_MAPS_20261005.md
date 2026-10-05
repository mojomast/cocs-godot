# Runtime Moth dressing for the three undressed new maps

**Lane:** populate the newer maps with Moth assets (source dressing pass)
**Date:** 2026-10-05
**Branch:** `spacebunny/dressing-20261005` (from `feature/relay-campaign` @ `91b0b801`)
**Claim:** source-only. No native capture, no Blender export, no rendered frame.
Visual and native acceptance are **not** claimed anywhere in this document.

> **Superseded in part.** A second pass on
> `spacebunny/dressing-richer-20261005` raised all three profiles toward the
> `profile.gd` caps (panels 94/93/95, signs 24, motes 95/90/92, pockets 12/12/12)
> and extended the tooling with a negative suite. The counts and verification
> blocks below describe the first pass and are kept as the baseline; see
> `RUNTIME_DRESSING_RICHER_20261005.md` for current numbers and for the plate
> orientation finding it raised.

---

## 1. Problem

`godot/multiplayer_worlds/dressing/binder.gd` gates every map on
`Profile.IDENTITIES`. Three of the six new authored maps had no entry and no
profile, so `Dressing.apply()` returned immediately with
`status: "ineligible"` and no Moth surface, panel, sign or mote was ever built
for them:

| map | geometry hash (`generated/<map>.json`) | before | after |
| --- | --- | --- | --- |
| vesper-viaduct | `27c71cc8895eab2ca3a0b5cae3c2b8f96ed9afd75db3deec4a5c96bd2f395ea7` | ineligible | `ready` (predicted, see §6) |
| abyssal-pressureworks | `32366a6c3df7f95f8d89281c5f83b24d9583cefeb4c0099790303d15349b53be` | ineligible | `ready` (predicted, see §6) |
| stormglass-causeway | `6afb8a36ee954ff9457a5522a7412c809191fb070eb7fe9eda4d379753acce48` | ineligible | `ready` (predicted, see §6) |

All three hashes were read out of the generated world JSONs and match the values
handed to the lane byte for byte.

## 2. Files added / changed

Added:

- `godot/multiplayer_worlds/dressing/profiles/vesper-viaduct.json`
- `godot/multiplayer_worlds/dressing/profiles/abyssal-pressureworks.json`
- `godot/multiplayer_worlds/dressing/profiles/stormglass-causeway.json`
- `tools/godot-multiplayer/new-maps/runtime-dressing/author.mjs` — authored source of
  truth for all three profiles; `--write` / `--check`.
- `tools/godot-multiplayer/new-maps/runtime-dressing/check.mjs` — independent Node
  verifier for `profile.gd`'s closed schema, budgets and selector coverage.
- `tools/godot-multiplayer/new-maps/runtime-dressing/validate_profiles.gd` — headless
  Godot validator that calls the real `Profile.validate()`.
- `tools/godot-multiplayer/new-maps/runtime-dressing/README.md` — how to run all three.
- `port/finish/map-variety/RUNTIME_DRESSING_THREE_MAPS_20261005.md` — this file.

Changed (three added lines, existing entries byte-identical):

- `godot/multiplayer_worlds/dressing/profile.gd` — `IDENTITIES` gains the three maps.

No other file was touched. No production receipt, requirement or unrelated file was
modified.

## 3. Selector and surface coverage

The binder keys on the imported glTF material `resource_name`, so the honest source
of selectors is the map's own art GLB, not the recipe's material strings. Selector
names below were read from the `materials[]` array of each GLB's glTF JSON chunk.

### vesper-viaduct — 11 GLB materials, 8 dressed + 3 preserved

`art/worlds/vesper-viaduct.glb`: quay, cobbles, asphalt, sandstone, brick, iron,
slate, plaster, glass, water, letter.

| selector | family / variant | tint | why this family |
| --- | --- | --- | --- |
| `sandstone` | `pearl-ceramic` / `cast` | `bb9370` | 34 cornice/window art pieces, 80 terrace surfaces and every hand-cut trim cube (sills, headers, jambs, quoins, dado) are sandstone. `cast` binds `weathered_concrete`. |
| `brick` | `pearl-ceramic` / `worn` | `984e36` | Bay buttresses, row-block parapets and 71 terrace surfaces. `worn` binds `weathered_concrete-worn`. |
| `plaster` | `enamel-glaze` / `stucco` | `b1816b` | 18 rendered-plaster surfaces, y 20.5–43. `stucco` binds `rough_stucco-weathered`. |
| `slate` | `pearl-ceramic` / `polished` | `293449` | Roof slate, y 9–70. Dark, faintly sheened stone. |
| `quay` | `regolith` / `scoured` | `535969` | The canal quay deck (`city-grade--104--140`, `far-quay`). `regolith` owns built ground per the family story. |
| `cobbles` | `regolith` / `scoured` | `77605b` | The two `city-grade` cobble grades ramping y 0→12. |
| `asphalt` | `pearl-ceramic` / `worn` | `3e424c` | The three upper-deck road grades at y 12–24. |
| `iron` | `brushed-alloy` / `default` | `252d37` | Tram rails, roof trusses, tiebeams, clock hands, ticket dividers. Authored metallic 0.65, so `metallic: 0.6`. |
| `glass` | **preserved** | — | Transparent window glazing; a triplanar finish would turn it opaque. |
| `letter` | **preserved** | — | Baked Blender FONT faces. `binder.gd:_collect` documents why: font triangles must keep their one-sided material, or the triplanar finish exposes mirrored glyph backs. |
| `water` | **preserved** | — | The canal surface (roughness 0.36 in the authored palette). |

Panels (37): 8 `brushed_metal` parcel-bay label plates (the authored 3 × 0.7 × 0.3
sandstone plates on the four non-ticket halls), 7 `brushed_metal` ticket-desk
dividers, 6 `hazard_stripes` stair nosings on the real 80-riser run at x≈32,
9 `weathered_concrete-worn` + `weathered_concrete` wear-masked quay coping and
ramp footings, 1 `circuit_board-etch` clock movement behind the civic dial,
3 `metal_grating` tram covers, 3 `metal_grating` canal-crossing grates.

Signs (18): 6 terrace-level markers (`LEVEL 0/1/2`), 2 clock-square faces, 4
parcel/dock signs on the elevations that do **not** carry baked lettering, 4 station
portal signs on the portico lintels, 2 canal-crossing signs. All `#e8e2d2` on
`#2a2f3a`.

Pockets (6, 44 motes): 2 canal mist, 2 cobble/clock dust, 2 hall vents.

### abyssal-pressureworks — 7 GLB materials, 6 dressed + 1 preserved

`art/worlds/abyssal-pressureworks.glb`: navy, ivory, amber, coral, copper, cyan, glass.

| selector | family / variant | tint | why this family |
| --- | --- | --- | --- |
| `navy` | `brushed-alloy` / `default` | `6d8b9c` | Vessel decks, crowns and splayed roof facets (154 terrain surfaces). |
| `ivory` | `pearl-ceramic` / `cast` | `cdd6c8` | Bay canopies, overhead ribs and workstation benches (96 surfaces + 32 art pieces). |
| `copper` | `oxidised-copper` / `default` | `9d7051` | 68 port-seal boxes plus the `pressure-equalizer-core` column at (44, 20, 8). |
| `coral` | `bioluminescent-membrane` / `veined` | `ac655c` | 40 bay screens/workstations and the nine reef columns. The living surface of the habitat. |
| `cyan` | `polar-ice` / `glazed` | `57c4cf` | 24 instrument strips. Glazed, faintly self-lit readout glass. |
| `amber` | `hazard-industrial` / `default` | `dca45e` | The two `core-pressure-cap-*` plates at y 30/32. The one family whose accent is masked to baked yellow: a warning plate. |
| `glass` | **preserved** | — | `art.windows` observation glazing is `transparent`, `blocksShots: false`. |

Panels (37): 12 `metal-oxide` + wear-masked verdigris plates on real copper port
seals (one per port, positioned from the recipe's `ports` centres), 8
`holographic_grid` readouts on the cyan instrument strips, 6 `hex_paneling` canopy
lamps, 2 `hazard_stripes` core-cap plates, 5 `weathered_concrete-damp` wear-masked
reef skirts, 4 `metal_grating` pump-spine grates.

Signs (15): 12 vessel identity signs (one per vessel, above its named port, using
the recipe's `name`/`district`), 3 objective signs (`REEF LAB`, `EQUALIZER`,
`OPERATIONS` at the recipe's objective zones). All `#dbe7e4` on `#1d2f38`.

Pockets (9, 50 motes): 4 observation-glazing mist, 1 equalizer-core vent, 3 reef-top
dust, 1 pump-cathedral dust.

### stormglass-causeway — 9 GLB materials, 7 dressed + 2 preserved

`art/worlds/stormglass-causeway.glb`: asphalt, concrete, salt, amber, teal, glass,
steel, brick, ocean.

| selector | family / variant | tint | why this family |
| --- | --- | --- | --- |
| `asphalt` | `pearl-ceramic` / `worn` | `849095` | The 21 `road-*` circuit segments at y 0. |
| `concrete` | `pearl-ceramic` / `cast` | `c4cbcb` | 21 `barrier-sea-*` walls, gate buttresses, freight vaults, quay foundations. |
| `salt` | `polar-ice` / `default` | `e2e7e2` | 5382 pieces: the salt crust on every cornice, sill, pier and reflector. Crystalline, `lut_gain: 0` keeps it non-emissive. |
| `amber` | `hazard-industrial` / `default` | `f8ce6f` | 1476 pieces: the gate counterweight masses. |
| `teal` | `enamel-glaze` / `crackle` | `69adb1` | Terminal and workshop bodies plus the raised gate leaves. `crackle` binds `ice-cracked` — literally storm glass. |
| `steel` | `brushed-alloy` / `plate` | `93a4a8` | Gate gantries, pistons, roof machinery. Authored metallic 0.5. |
| `brick` | `pearl-ceramic` / `worn` | `b89381` | The 22 quay-workshop bodies. |
| `glass` | **preserved** | — | 1728 window panes. |
| `ocean` | **preserved** | — | The sea plane (authored roughness 0.25). |

Panels (34): 6 `circuit_board-etch` gate status boards on the raised leaves,
6 `hazard_stripes` warning plates on the gate counterweights, 6 `brushed_metal`
service hatches on terminal plinths, 10 `weathered_concrete-worn` wear-masked salt
blooms on sea-wall segments, 6 `metal_grating` shoulder drains.

Signs (21): 6 barrier-gate faces (3 gates × 2 elevations), 10 observatory-terminal
signs, 5 quay-workshop signs, 1 start/finish line. All `#e2ecea` on `#20363a`.

Pockets (12, 75 motes): 4 seawall spray, 3 gate vents, 5 road-grit volumes.

## 4. Budgets

`profile.gd` hard caps are `material_variants ≤ 32`, `panels ≤ 96`, `signs ≤ 24`,
`motes ≤ 96`, plus per-group array caps (`materials`/`preserve_materials` ≤ 32,
`pockets` ≤ 12) and the per-profile `budgets` object.

| map | materials | panels | signs | motes | pockets | preserved |
| --- | --- | --- | --- | --- | --- | --- |
| vesper-viaduct | 8 / 8 | 37 / 48 | 18 / 20 | 44 / 64 | 6 / 12 | 3 |
| abyssal-pressureworks | 6 / 6 | 37 / 48 | 15 / 20 | 50 / 56 | 9 / 12 | 1 |
| stormglass-causeway | 7 / 7 | 34 / 48 | 21 / 24 | 75 / 80 | 12 / 12 | 2 |

Every `options` object stays inside `Language.BOUNDS`, `Profile.WEAR_BOUNDS`,
`Profile.VARIATION_BOUNDS` and `Profile.VARIATION_MODES`. Following the three
already-accepted profiles, every material sets `lut_gain: 0`, `pulse_speed: 0` and
`pulse_depth: 0` — none of these maps' authored materials are emissive
(`blender_export.py` and `author_blender.py` set no emission), so no accent or
phase pulse was invented. Private macro/wear/variation uniforms are left at their
defaults, which keeps every surface on the shared `family.gdshader` path.

## 5. Verification

All commands were run from the worktree root
`/home/mojo/.tmp-on-disk/cocs-coastal-blender-T-20261003`.

### 5.1 Authoring is reproducible

```
$ node tools/godot-multiplayer/new-maps/runtime-dressing/author.mjs --check
OK vesper-viaduct: materials=8 panels=37 signs=18 pockets=6 motes=44 preserve=3
OK abyssal-pressureworks: materials=6 panels=37 signs=15 pockets=9 motes=50 preserve=1
OK stormglass-causeway: materials=7 panels=34 signs=21 pockets=12 motes=75 preserve=2
```

The committed JSON is byte-identical to what `author.mjs` emits.

### 5.2 Node checker (`check.mjs`)

```
$ node tools/godot-multiplayer/new-maps/runtime-dressing/check.mjs
PASS vesper-viaduct: materials=8/8 panels=37/48 signs=18/20 motes=44/64 preserve=3 placements=61
PASS abyssal-pressureworks: materials=6/6 panels=37/48 signs=15/20 motes=50/56 preserve=1 placements=61
PASS stormglass-causeway: materials=7/7 panels=34/48 signs=21/24 motes=75/80 preserve=2 placements=67
resources resolved: 57
```

Controls — the same checker must also accept the three already-shipped maps, which
proves it is not tuned to the new files:

```
$ node tools/godot-multiplayer/new-maps/runtime-dressing/check.mjs \
    helix-conservatory gravemill-foundry parallax-observatory
PASS helix-conservatory: materials=9/12 panels=46/64 signs=13/20 motes=48/72 preserve=1 placements=63
PASS gravemill-foundry: materials=7/8 panels=37/64 signs=20/20 motes=32/64 preserve=1 placements=60
PASS parallax-observatory: materials=6/6 panels=26/64 signs=10/24 motes=32/40 preserve=1 placements=41
resources resolved: 41
```

What `check.mjs` enforces, all read from the real sources (`profile.gd`,
`godot/material_language/{families,library}.gd`, `godot/moth/{generated,derived}/manifest.json`,
each `art/**/*.glb`):

- `IDENTITIES` membership and `geometry_hash` agreement with both `profile.gd` and
  `generated/<map>.json`;
- the closed key set at profile, `budgets`, `options` and every placement level;
- budget integers within `CAPS`, group lengths within the hard caps and within the
  declared budget, total motes within `budgets.motes`;
- family and variant existence, and every option inside its bounds table;
- wear intervals non-empty when `wear_strength > 0`;
- Moth panel texture / `wear_mask` / normal keys resolve to a real PNG whose IHDR
  matches the manifest (57 distinct resources across the three maps);
- sign text length, ASCII-only text and ≥ 4.5:1 contrast;
- pocket kind, colour, count and per-axis size;
- **bidirectional selector coverage against the GLB** — every art material is
  dressed or preserved, and every selector exists in the art. This is what keeps
  `binder.gd` off `status: "incomplete_coverage"`.

Negative testing: 24 deliberate corruptions were injected into a copy of
`vesper-viaduct.json` and every one was rejected — unused selector, unmatched art
material, budget overflow, out-of-bounds option, unknown panel texture /
`wear_mask` / normal, wear control without `wear_mask`, low-contrast sign,
non-integer budget, pocket kind/size/count, duplicate placement id, bad colour,
out-of-bounds position, bad `variation_mode`, unknown family, unknown top-level key,
unknown pocket kind, empty wear interval, and a corrupted `geometry_hash`.

### 5.3 Headless Godot, using `profile.gd`'s own validator

The worktree is a sparse checkout that skips `godot/material_language/**`,
`godot/moth_scenery/**` and every autoload target in `godot/project.godot`, so
`--path godot` cannot boot there. A throwaway sandbox was built in
`/tmp/opencode/dressing-godot` that symlinks only the `res://` paths the validator
needs, with `material_language` extracted from `HEAD` via `git archive` (full recipe
in `tools/godot-multiplayer/new-maps/runtime-dressing/README.md`). Nothing was
written back into the worktree and `--import` was never passed.

```
$ /tmp/opencode/cocs-horde-e353522a-package/toolchain/Godot_v4.5.2-stable_linux.x86_64 \
    --headless --path /tmp/opencode/dressing-godot --script res://validate_profiles.gd
Godot Engine v4.5.2.stable.official.6ce3de25a
PASS helix-conservatory: materials=9/12 panels=46/64 signs=13/20 motes=48/72 preserve=1
PASS gravemill-foundry: materials=7/8 panels=37/64 signs=20/20 motes=32/64 preserve=1
PASS parallax-observatory: materials=6/6 panels=26/64 signs=10/24 motes=32/40 preserve=1
PASS vesper-viaduct: materials=8/8 panels=37/48 signs=18/20 motes=44/64 preserve=3
PASS abyssal-pressureworks: materials=6/6 panels=37/48 signs=15/20 motes=50/56 preserve=1
PASS stormglass-causeway: materials=7/7 panels=34/48 signs=21/24 motes=75/80 preserve=2
DRESSING_HEADLESS_FAILURES=0
```

This is the strongest result available here: it calls `Profile.validate()` itself,
the same authority `binder.gd` calls at map load. A negative control (sign contrast
dropped to 1.6:1) made it fail correctly:

```
FAIL vesper-viaduct: sign contrast below 4.5:1
DRESSING_HEADLESS_FAILURES=1
```

## 6. Known gaps and deliberate omissions

1. **Nothing is visually accepted.** `Profile.validate()` returning clean means the
   binder will not report `invalid_profile` or `unresolved_resources`. It does
   **not** prove `status: "ready"`: `binder.gd:_collect` can still append
   `<selector> (instance override)` if any GLB node carries a `material_override`,
   and `_sign` can still append `sign text too small to read`. Neither is
   reachable from a source-only check. A native load of each map is required to
   confirm `ready`, and that was out of scope.
2. **Placement coordinates are derived, not rendered-verified.** Every position
   comes from the recipe's own structures/ports/gates/labels and from the GLB mesh
   centroids. They are correct by construction against the source, but no capture
   has confirmed that a panel is not occluded or floating.
3. **Preserved materials are left undressed on purpose**, with the reason recorded
   above rather than hidden: `vesper-viaduct` glass/letter/water,
   `abyssal-pressureworks` glass, `stormglass-causeway` glass/ocean. These are the
   transmissive surfaces and the baked font faces; a triplanar architectural finish
   would destroy them. `abyssal-pressureworks` already carries a bespoke
   `abyssal_presentation.gd` light rig, which the dressing does not touch.
4. **Deliberately restrained coverage.** `stormglass-causeway` has 9682 recipe
   meshes and 21 circuit districts, but only 3 gates, 10 terminals and 22
   workshops received signs — enough to read at a glance, far short of one sign
   per district. Panels skip the 1728 glass panes and the 5382 salt pieces entirely.
   The honest gap is the interior of each district, which is not dressed.
5. **Budget headroom is thin on stormglass.** 75/80 motes and 12/12 pockets means a
   future pocket there needs a profile edit, not just an addition.
6. **`godot/material_language/**` is not materialised in this worktree.** Both
   verifiers read it from `git show HEAD:<path>` / `git archive HEAD`, so a change
   to `families.gd` or `library.gd` outside this branch would not be reflected until
   the sparse worktree is widened.
7. **Not run:** no native map capture, no Blender, no `--import` in the worktree, no
   frame timing, no VRAM/draw-call measurement.

## 7. Reproduction

```sh
cd /home/mojo/.tmp-on-disk/cocs-coastal-blender-T-20261003
git checkout spacebunny/dressing-20261005
node tools/godot-multiplayer/new-maps/runtime-dressing/author.mjs --check
node tools/godot-multiplayer/new-maps/runtime-dressing/check.mjs
node tools/godot-multiplayer/new-maps/runtime-dressing/check.mjs \
  helix-conservatory gravemill-foundry parallax-observatory
# headless Godot: see README.md in the same directory
```