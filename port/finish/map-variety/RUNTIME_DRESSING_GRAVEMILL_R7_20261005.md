# Foundry R7 dressing gap, and the two inverted plate families

**Lane:** close the gravemill-foundry dressing coverage gap left by the reviewed
Foundry R7 art promotion, then settle the orientation finding the previous pass
flagged
**Date:** 2026-10-05
**Branch:** `spacebunny/dressing-gravemill-20261005` (from `feature/relay-campaign` @ `84624da1`)
**Prior reports:** `RUNTIME_DRESSING_THREE_MAPS_20261005.md` and
`RUNTIME_DRESSING_RICHER_20261005.md` (same directory)
**Claim:** source-only. No native capture, no Blender export, no committed frame.
The renders in §7 were produced in a throwaway `/tmp` sandbox to answer facing and
coverage questions; they are diagnostic evidence, not a delivery capture, and
**no native or visual acceptance is claimed** anywhere in this document.

---

## 1. Root cause of the gap

`e7e330ae` promoted the reviewed Foundry R7/Y art into the runtime world path.
`godot/multiplayer_worlds/art/worlds/gravemill-foundry.glb` is now 15,012,592 bytes,
sha256 `6325fdf0003813c5cb5a59aca3626f6756998fb53f8aaa143d9f3043f3caa44f`, with
**18 materials** where the old GLB had 8, and 36 embedded images. Ten of those are
finish-role batches the dressing profile had never seen:

`R6 / machine`, `R6 / roof`, `R6 / wall`, `R6 / plinth`, `R6 / refractory`,
`R6 / ore-shell`, `R6 / ground`, `G4 / ribbed`, `G4 / grating`, `G4 / timber`.

So the binder's report went from `ready` to `incomplete_coverage`, matching only
the seven `GM / …` selectors.

The reason nobody noticed for a full promotion cycle is that the profile could not
be regenerated. Its authoring source was `port/map-finish/gravemill-foundry/author.py`,
which pins the accepted GLB byte-for-byte:

```python
assert hash(GLB.read_bytes()) == '46bf1648...'   # pre-R7
assert len(glb['materials']) == 8 and not glb.get('textures')
```

Both asserts fire the moment the art changes, so the script fails closed before it
writes anything. That is the correct behaviour for a hash-pinned author, but it
means the map had **no working authoring path**, and a coverage gap in the runtime
could not be repaired by re-running it.

**Decision.** `author.mjs` becomes the source of truth for `gravemill-foundry` too,
alongside the three maps it already owned, and `check.mjs`'s byte-drift check
extends to it. The alternative — patching `author.py`'s hash and material count —
would leave two authoring sources for one file in two languages with different
float formatting. `author.py` is left untouched and still fails closed; it is now
superseded, and §9 says what a reader should do with it.

## 2. Where the new material readings come from

Each new selector's family and variant is read out of that role's own authored
resource, not chosen by eye. The bindings are in
`tools/godot-multiplayer/new-maps/gravemill-foundry/revision6/bindings.json` and
`revision6/build-report.json` (`R6` roles) and `revision5/material-lineage.json`
(`G4` roles):

| selector | authored resource | metallic | tile m | family / variant | why |
| --- | --- | ---: | ---: | --- | --- |
| `R6 / machine` | forge-steel | 0.48 | 2 | `brushed-alloy / plate` | machined housings; `plate` binds `diamond_plate`, the chequer read for working metal |
| `R6 / roof` | ribbed-steel | 0.40 | 2 | `hazard-industrial / corrugated` | ribbed sheet; `corrugated` binds `corrugated_metal` |
| `R6 / wall` | aggregate | 0 | 4 | `pearl-ceramic / cast` | cast aggregate wall; `cast` binds `weathered_concrete` |
| `R6 / plinth` | cast-seams | 0 | 4 | `pearl-ceramic / cast` | same family, cooler and darker tint; roles are necessarily shared |
| `R6 / refractory` | terracotta | 0 | 2 | `pearl-ceramic / worn` | fired clay lining |
| `R6 / ore-shell` | oxidized-iron | 0.25 | 2 | `oxidised-copper / pitted` | oxidised iron shell |
| `R6 / ground` | aggregate | 0 | 4 | `regolith / scoured` | built foundry floor; same rule the other maps use for ground |
| `G4 / ribbed` | ribbed-steel | — | 2 | `brushed-alloy / plate` | structural rails |
| `G4 / grating` | iron-grate | — | 1 | `brushed-alloy / grating` | `grating` binds `metal_grating`, the literal read |
| `G4 / timber` | timber-weather | — | 2 | `regolith / verdant` | the only wood-adjacent read in the library, at low texture strength |

`R6 / roof` is the one `hazard-industrial` entry. Its accent LUT is masked to the
baked hazard yellow and is not wanted on a roof, so `lut_gain` is 0 — the family
supplies the corrugated base and nothing else. Every other entry also carries
`lut_gain: 0`, `pulse_speed: 0`, `pulse_depth: 0`, so no R6/G4 surface invents an
emission the authored art does not have. Manufactured roles get
`variation_mode: "manufactured"`, mineral and timber roles keep `"organic"`, which
matches the split the other three maps already use.

`GM / orange` stays in `preserve_materials`: it is the authored luminaire batch
(`emissiveFactor [1, 0.2375, 0.03125]`, `emissiveStrength 1.6`, 328 triangles in
one primitive), and a triplanar finish would disable culling and expose the
mirrored backs of those lamp housings.

`material_variants` rises 8 → 17, exactly the number of dressed selectors, still
far under the 32 cap.

## 3. New placements, and what they stand on

46 panels, 4 signs and 6 pockets were added. Each is anchored to an axis-aligned
face read out of the promoted GLB itself, not to a world-JSON surface, so the
geometry the plate lands on is the geometry the art actually ships:

| family | count | anchor in the R7 GLB |
| --- | ---: | --- |
| `tap-catwalk-plate-*` | 8 | `G4 / grating` catwalk deck, `y+ 7.07..7.33`, x −100..101, z −110..−8 |
| `grain-deck-board-*` | 5 | `G4 / timber` deck, `y+ 8.8`, x 46..88, z −30..−26 |
| `kiln-refractory-heat/hazard-*` | 6 | `R6 / refractory` kiln fronts, `z− −29.47`, x 45..57, y 0..11 |
| `kiln-arch-crown-*` | 2 | `R6 / refractory` arch crown, `y+ 5.02` |
| `nave-pier-soot-*` | 8 | `R6 / plinth` nave roof piers, `y+ 20`, the four piers × two rows |
| `ore-shell-collar-*` | 5 | `R6 / ore-shell` surge-shell mouths on the five bunker rows |
| `machine-access-*` | 3 | `R6 / machine` crusher drum flanks (`x− −88.97..−87.65`) and the assay platform edge |
| `crossrail-mark-*` | 4 | `G4 / ribbed` headframe crossrails, `z± −36.98 / −34.98` |
| `ground-scuff-*` | 5 | `R6 / ground` approach terraces, `y+ 8` and `y+ 5.33` |
| `tap-caution-*`, `kiln-heat-board-*` | 4 signs | on the catwalk deck and the two hottest kiln fronts |
| pockets | 6 | mote volumes over the catwalk, ore shells, nave plinth and kiln arch |

Signs stop at 24 because that is the `profile.gd` hard cap: 20 accepted + 4 new.
The four are the tap catwalk's two ends and the two hottest kiln faces, chosen to
name roles no existing board already names.

## 4. Before / after

Counts are `emitted / budget`. `placements` is panels + signs + pockets. "Before"
is `84624da1`.

### gravemill-foundry

| metric | before | after | cap |
| --- | --- | --- | --- |
| materials | 7 / 8 | **17 / 17** | 32 |
| panels | 37 / 64 | **83 / 96** | 96 |
| signs | 20 / 20 | **24 / 24** | 24 |
| motes | 32 / 64 | **77 / 96** | 96 |
| pockets | 3 / 12 | **9 / 12** | 12 |
| placements | 60 | **116** | — |

Budgets before `{material_variants: 8, panels: 64, signs: 20, motes: 64}`, after
`{material_variants: 17, panels: 96, signs: 24, motes: 96}`.

Runtime status, from `binder.gd`'s own report on the real `WorldMap`:

| | before | after |
| --- | --- | --- |
| `status` | `incomplete_coverage` | **`ready`** |
| matched | 7 | **17** |
| unmatched | 10 | **0** |
| unused selectors | 0 | 0 |
| errors | 0 | 0 |
| surfaces | 10 | **31** |
| batches | 60 | **116** |

The three richer maps are unchanged in count; their only change is the orientation
fix in §6.

### Every profile after this pass

| map | materials | panels | signs | motes | pockets | placements | status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| vesper-viaduct | 8 / 8 | 94 / 96 | 24 / 24 | 95 / 96 | 12 / 12 | 130 | ready |
| abyssal-pressureworks | 6 / 6 | 93 / 96 | 24 / 24 | 90 / 96 | 12 / 12 | 129 | ready |
| stormglass-causeway | 7 / 7 | 95 / 96 | 24 / 24 | 92 / 96 | 12 / 12 | 131 | ready |
| gravemill-foundry | 17 / 17 | 83 / 96 | 24 / 24 | 77 / 96 | 9 / 12 | 116 | ready |

## 5. The pass is additive

The 37 panels, 20 signs and 3 pockets the shipped profile already carried are
carried into `author.mjs` as literal row tables and re-emitted unchanged. A
canonically-keyed comparison against `84624da1` finds:

```
legacy placements with a real value change: []
legacy placements removed: []
```

Two of the seven `GM / …` materials needed a small change to survive the port:
`base()` in `author.mjs` spreads its `response` argument *before* the private
variation defaults, so `variation_mode` and `variation_strength` set inside
`response` are silently overwritten. `base()` gained a sixth argument for the
variation override, which is what lets `GM / brass` keep its authored
`manufactured / 0.12` while the other six keep `organic / 0.3`. The same trap
caught the ten new entries on the first run — they all came out `organic` — and is
now commented at both call sites.

## 6. The orientation finding: fixed, with proof

The previous pass flagged two first-pass families as probably invisible under
`cull_back` and left them byte-identical pending visual evidence. Both turned out to
be wrong, in different ways.

**`vesper-viaduct` `parcel-plate-*` (8 plates).** A plate is offset 0.18 m off the
elevation it dresses, so it must face *away* from that wall. `side -1` is the −Z
elevation and needs yaw 180; `side +1` is the +Z elevation and needs yaw 0. The
first pass emitted the inverted pair. Positions were already correct, so this is a
yaw-only swap:

```
before  parcel-plate-bonded-warehouse-n  [-66, 0.7, -98.18]  [0,   0, 0]
after   parcel-plate-bonded-warehouse-n  [-66, 0.7, -98.18]  [0, 180, 0]
```

**`stormglass-causeway` `gate-readout-*` (6 plates).** This one was not a yaw bug
but a placement bug. The boards sat at `gate.z ± 0.6`, i.e. **inside the raised
leaf's own volume**, yawed 0/180 so they faced each other 1.2 m apart. The leaf
spans 32 m across the road and only 8.8 m along it, so ±Z is its *thickness*, not
its face. The boards were buried and facing each other regardless of yaw.

A raised leaf lies across the road, so the two elevations a driver reads are the
leaf faces perpendicular to travel — and that axis is **per gate**:

| gate | road runs | leaf spans | readable faces |
| --- | --- | --- | --- |
| gate-1 | mostly X | x 8.85, z 32.0 | ±X |
| gate-14 | mostly Z | x 31.97, z 9.22 | ±Z |
| gate-18 | mostly Z | x 30.37, z 15.97 | ±Z |

So the boards moved onto those faces, 0.18 m off, each facing away:

```
after  gate-readout-gate-1-low    [-14.603, 12, -122.5]  [0, -90, 0]
after  gate-readout-gate-14-low   [-200, 12, 50.211]   [0, 180, 0]
after  gate-readout-gate-18-high  [-77.5, 12, -34.334]  [0, 0, 0]
```

**Proof, in-engine.** A facing probe reads each plate node's own basis after the
binder has built it, and compares its facing direction (local +Z) against the
direction to a chosen eye. A dot near +1 means `cull_back` keeps the plate; near −1
means it is culled. The probe also raycasts plate → eye against the world, so
"occluded" and "culled" are told apart:

```
before (84624da1 profiles)
parcel-plate-bonded-warehouse-n    yaw   0  dot -0.976  culled   ray <clear>
parcel-plate-canal-service-n      yaw   0  dot -0.976  culled   ray <clear>
parcel-plate-bonded-warehouse-s   yaw 180  dot -0.973  culled   ray <clear>
parcel-plate-west-courtyard-n     yaw   0  dot -0.995  culled   ray <clear>
parcel-plate-east-post-office-s   yaw 180  dot -0.995  culled   ray <clear>
gate-readout-gate-1-n             yaw   0  dot -1.000  culled   ray OverheadSide634
gate-readout-gate-14-n            yaw   0  dot -1.000  culled   ray OverheadSide670
gate-readout-gate-14-s            yaw 180  dot -1.000  culled   ray OverheadSide666
gate-readout-gate-18-n            yaw   0  dot -1.000  culled   ray OverheadSide702
gate-readout-gate-18-s            yaw 180  dot -1.000  culled   ray OverheadSide698

after (this branch)
parcel-plate-bonded-warehouse-n    yaw 180  dot +0.976  visible  ray <clear>
parcel-plate-canal-service-n      yaw 180  dot +0.976  visible  ray <clear>
parcel-plate-bonded-warehouse-s   yaw   0  dot +0.973  visible  ray <clear>
parcel-plate-west-courtyard-n     yaw 180  dot +0.995  visible  ray <clear>
parcel-plate-east-post-office-s   yaw   0  dot +0.995  visible  ray <clear>
gate-readout-gate-1-low           yaw -90  dot +1.000  visible  ray <clear>
gate-readout-gate-1-high          yaw  90  dot +1.000  visible  ray <clear>
gate-readout-gate-14-low          yaw 180  dot +1.000  visible  ray <clear>
gate-readout-gate-14-high         yaw   0  dot +1.000  visible  ray <clear>
gate-readout-gate-18-low          yaw 180  dot +1.000  visible  ray <clear>
gate-readout-gate-18-high         yaw   0  dot +1.000  visible  ray <clear>
```

All fourteen are now visible from the side they face, with clear rays.

**Proof, in pixels.** The identical eye/target list was rendered through both
profile revisions and diffed. An inverted plate differs by its whole silhouette,
not a few edge pixels:

```
vesper-viaduct-bonded-n          54388 px differ, bbox x[165,1114] y[320,401]
vesper-viaduct-canal-service-n   54393 px differ, bbox x[165,1114] y[320,401]
vesper-viaduct-bonded-s           4190 px differ, bbox x[522,757]  y[348,371]
vesper-viaduct-courtyard-n        3564 px differ, bbox x[550,729]  y[319,368]
vesper-viaduct-courtyard-s        4120 px differ, bbox x[537,742]  y[350,369]
vesper-viaduct-post-office-n       3564 px differ, bbox x[550,729]  y[319,368]
vesper-viaduct-post-office-s       4120 px differ, bbox x[537,742]  y[350,369]
vesper-viaduct-canal-service-s     4186 px differ, bbox x[522,757]  y[348,371]
stormglass-causeway-gate1-low      6175 px differ, bbox x[256,687]  y[328,712]
stormglass-causeway-gate1-high     6178 px differ, bbox x[592,1164] y[328,711]
stormglass-causeway-gate14-low     5710 px differ, bbox x[594,732]  y[329,682]
stormglass-causeway-gate14-high    5707 px differ, bbox x[538,719]  y[329,700]
stormglass-causeway-gate18-low     5535 px differ, bbox x[594,928]  y[7,638]
stormglass-causeway-gate18-high    5550 px differ, bbox x[168,711]  y[3,714]
```

Views that do not contain one of the fixed plates are `IDENTICAL`, which is the
control working: `vesper arcade`, `street-covers` and `stormglass centre-line`
match byte for byte across revisions.

`check.mjs` cannot catch this class of error — an inverted yaw is schema-valid, in
budget and in bounds, and `author.mjs --check` only proves the file matches its
table. The README now says so, and the rendering recipe is written down next to the
placement convention.

## 7. Verification

Every command below was run from the worktree. Outputs are verbatim.

### `author.mjs --check` ×3 — authoring is byte-reproducible

```
OK vesper-viaduct: materials=8 panels=94 signs=24 pockets=12 motes=95 preserve=3
OK abyssal-pressureworks: materials=6 panels=93 signs=24 pockets=12 motes=90 preserve=1
OK stormglass-causeway: materials=7 panels=95 signs=24 pockets=12 motes=92 preserve=2
OK gravemill-foundry: materials=17 panels=83 signs=24 pockets=9 motes=77 preserve=1
```

Clean on all three runs.

### `check.mjs` — four authored maps, gravemill now included

```
PASS vesper-viaduct: materials=8/8 panels=94/96 signs=24/24 motes=95/96 preserve=3 placements=130
PASS abyssal-pressureworks: materials=6/6 panels=93/96 signs=24/24 motes=90/96 preserve=1 placements=129
PASS stormglass-causeway: materials=7/7 panels=95/96 signs=24/24 motes=92/96 preserve=2 placements=131
PASS gravemill-foundry: materials=17/17 panels=83/96 signs=24/24 motes=77/96 preserve=1 placements=116
resources resolved: 69
```

`materials=17/17` is gravemill's own line against the promoted R7 art: all 17
dressed selectors matched, and the bidirectional rule held in both directions — no
unmatched art material and no unused selector. Resources rose 57 → 60 → 69 as the
ten new roles pulled in their base, derived and normal maps.

### `check.mjs` — the two remaining controls

```
PASS helix-conservatory: materials=9/12 panels=46/64 signs=13/20 motes=48/72 preserve=1 placements=63
PASS parallax-observatory: materials=6/6 panels=26/64 signs=10/24 motes=32/40 preserve=1 placements=41
resources resolved: 36
```

gravemill moved out of this list because it is now byte-checked as an authored
map. `helix-conservatory` is deliberately still under its material budget (9/12) —
it has art materials it does not dress, which `check.mjs` accepts for a control but
would reject for an authored map.

### `negative.mjs` — the verifier must also reject

```
PASS rejected: a plate outside the map world bounds
PASS rejected: two placements on one point
PASS rejected: a panel budget below its own placement count
PASS rejected: a thirteenth mote pocket
PASS rejected: a mote total above its budget
PASS rejected: a sign below the 4.5:1 contrast floor
PASS rejected: an art material the profile never dresses
PASS rejected: a selector the map art does not contain
PASS rejected: a Moth texture that is not in the manifest
negative cases: 9/9 rejected as expected
```

### Headless `validate_profiles.gd`, all six maps

README recipe, sandbox profiles symlinked to the worktree:

```
PASS helix-conservatory: materials=9/12 panels=46/64 signs=13/20 motes=48/72 preserve=1
PASS gravemill-foundry: materials=17/17 panels=83/96 signs=24/24 motes=77/96 preserve=1
PASS parallax-observatory: materials=6/6 panels=26/64 signs=10/24 motes=32/40 preserve=1
PASS vesper-viaduct: materials=8/8 panels=94/96 signs=24/24 motes=95/96 preserve=3
PASS abyssal-pressureworks: materials=6/6 panels=93/96 signs=24/24 motes=90/96 preserve=1
PASS stormglass-causeway: materials=7/7 panels=95/96 signs=24/24 motes=92/96 preserve=2
DRESSING_HEADLESS_FAILURES=0
```

This calls the real `Profile.validate()`, i.e. the same authority `binder.gd` calls.
`materials=17/17` for gravemill here too.

Two negative controls against the validator, run in a **copy** of the profiles
directory rather than a symlink, so the corruption lands on the sandbox:

```
control 1  pristine copy                     -> DRESSING_HEADLESS_FAILURES=0
control 2  duplicate one panel id            -> FAIL gravemill-foundry: invalid/duplicate placement id
                                                DRESSING_HEADLESS_FAILURES=1
control 3  sign background = its foreground  -> FAIL gravemill-foundry: sign contrast below 4.5:1
                                                DRESSING_HEADLESS_FAILURES=1
```

The worktree profile was re-checked afterwards with `author.mjs --check` and is
clean, confirming the controls did not touch it.

### The in-engine gold standard

`godot/tests/new_maps/gravemill_foundry/inspection.gd`, run through the real
`WorldMap` + binder path, dressing block:

```json
{
  "map_id": "gravemill-foundry",
  "status": "ready",
  "matched_count": 17,
  "unmatched": [],
  "unused_selectors": [],
  "preserved": ["GM / orange"],
  "errors": [],
  "surfaces": 31,
  "panels": 83,
  "signs": 24,
  "motes": 77,
  "batches": 116,
  "detail": 2,
  "resources_count": 45
}
```

The binder no longer reports `incomplete_coverage`, `unmatched` is empty, and there
are no errors. All 12 inspection views rendered.

## 8. Render evidence and draw calls

Godot 4.5.2 on Xvfb `:77`, `gl_compatibility`, llvmpipe software renderer, 1280×720.
Sandbox symlinks one worktree commit's `moth` and `multiplayer_worlds`, with
`moth_scenery` and `material_language` exported from that commit's `git archive`.

```
/tmp/opencode/dressing-richer-shots/
  <map>-<view>.png                  25 frames, one per view
  <map>-capture-report.json         binder report + per-view draw calls
  capture-report.json               combined
  sheets/<map>-contact-sheet.png    labelled contact sheet per map
  sheets/contact-sheet-all.png      combined 25-tile sheet
```

Per-map draw calls, `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME` after the frame
is drawn, and the same views against the pre-fix profiles:

| map | view | draw before | draw after |
| --- | --- | ---: | ---: |
| vesper-viaduct | overview | 153 | 153 |
| | canal | 46 | 46 |
| | parcel-bays | 80 | 80 |
| | arcade | 58 | 58 |
| | street-covers | 73 | 73 |
| | far-quay | 35 | 35 |
| abyssal-pressureworks | overview | 154 | 154 |
| | reef-window | 43 | 43 |
| | equalizer | 40 | 40 |
| | canopy-troughs | 57 | 57 |
| | crown-hatches | 48 | 48 |
| | port-thresholds | 47 | 47 |
| stormglass-causeway | overview | 174 | 174 |
| | return-gate | 94 | 94 |
| | gate14 | 74 | 74 |
| | centre-line | 146 | 146 |
| | freight-bore | 68 | 68 |
| | quay-chicane | 100 | 100 |
| gravemill-foundry | overview | 109 | 163 |
| | crusher-eye | 226 | 265 |
| | tap-catwalk | 151 | 155 |
| | kiln-face | 161 | 177 |
| | cooling-nave | 202 | 235 |
| | grain-deck | 166 | 183 |
| | assay-eye | 168 | 168 |

**Read this carefully.** The first three maps show *zero* delta, and that is the
expected result, not a measurement failure: their placement counts did not change
in this pass. The only change to them is 14 plates becoming visible instead of
culled, and `cull_back` discards a back-facing plate in the rasteriser without ever
counting a draw call — so the count is identical while the pixels differ (the
`vesper parcel-bays` view changes by 4078 px, `stormglass return-gate` by 5005 px,
`stormglass gate14` by 4429 px). Draw calls are therefore the wrong instrument for
the orientation fix; the facing probe and the pixel diff are the right ones.

Gravemill is the only map whose *count* grew, and its deltas are the real cost of
the enrichment: **+54 draw calls** on the overview (109 → 163), up to **+39** on
the crusher eye, **+33** in the cooling nave. The per-map totals are now
**116 batches for gravemill**, 130 vesper, 129 abyssal, 131 stormglass, against
60 for gravemill before. These are not free: roughly 130 placements per map is
130 extra draw calls in the worst case. Nothing here is instanced or batched —
`binder.gd:_plate` creates one `MeshInstance3D` with its own `QuadMesh` per
placement. If draw calls become a problem the fix is to instance the plates in
`binder.gd`, not to thin the profiles.

Render adapter for every frame: `llvmpipe (LLVM 20.1.8, 256 bits)`. Software
rasterisation, so these numbers are not representative of GPU hardware and the
frames are not colour-accurate.

**A caveat worth recording.** The first orientation run was invalid and had to be
discarded. Its sandbox symlinked `generated/` from the *main checkout*, which has
since advanced to `8509ac9b` with a different vesper geometry hash. The binder
returned `identity_mismatch`, never built a dressing node, and every vesper view
rendered undressed — which is why two views first came back `IDENTICAL`. The
README now says to symlink the whole `multiplayer_worlds` directory so `generated/`,
`art/` and `dressing/` cannot come from different commits, and the pair capture
refuses to run unless the binder reports `ready` for the map first.

## 9. What is not done

- **`port/map-finish/gravemill-foundry/author.py` is superseded but not removed.**
  It still pins the pre-R7 GLB hash and the 8-material assertion, so it fails
  closed. Leaving it as a landmine is worse than saying so, but deleting another
  lane's authoring script is not mine to do. Its README and the two docs that
  instruct readers to run it (`port/surface-refinement/maps/README.md`,
  `EMISSION_FOLLOWUP.md`) still point at it and are now wrong about which file is
  authoritative. **This needs a decision from the owner of that lane.**
- **No native acceptance.** No map was loaded in a hosted session, no play-through,
  no multiplayer proof. The frames in §8 are diagnostic renders in a `/tmp`
  sandbox and are not committed.
- **13 panels of headroom are left on gravemill** and 19 motes. The obvious
  candidates are the R7 districts that have no walkable surface in the recipe's own
  terrain — the `G4 / ribbed` headframe crown above y 48, and the five
  `G4.bunker.*` surge shells at z ≈ −107, which sit below the playable grade.
  Placing plates there would dress geometry no player can reach.
- **`helix-conservatory` still dresses 9 of its 12 art materials.** It is a control
  map, so this pass left it alone, but by the rule the authored maps are held to it
  would be `incomplete_coverage`.

## 10. Files changed

| File | Change |
| --- | --- |
| `tools/godot-multiplayer/new-maps/runtime-dressing/author.mjs` | gravemill as a fourth authored map: 7 legacy material rows, 37/20/3 legacy placement rows, 10 R7 roles, 46 new panels, 4 signs, 6 pockets; the two orientation fixes; `base()` gains a variation-override argument |
| `tools/godot-multiplayer/new-maps/runtime-dressing/check.mjs` | gravemill added to the byte-drift list |
| `tools/godot-multiplayer/new-maps/runtime-dressing/README.md` | gravemill's promotion story, the rendering recipe, and why a yaw inversion is invisible to both checkers |
| `godot/multiplayer_worlds/dressing/profiles/gravemill-foundry.json` | re-emitted |
| `godot/multiplayer_worlds/dressing/profiles/vesper-viaduct.json` | re-emitted (8 yaw changes) |
| `godot/multiplayer_worlds/dressing/profiles/stormglass-causeway.json` | re-emitted (6 placements moved) |
| `port/finish/map-variety/RUNTIME_DRESSING_GRAVEMILL_R7_20261005.md` | this report |

`godot/multiplayer_worlds/dressing/profile.gd` is the schema authority and is
**unmodified**: no cap moved, no validation rule relaxed.