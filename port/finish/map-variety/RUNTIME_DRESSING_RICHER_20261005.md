# Richer runtime dressing on the three new maps — addendum

**Lane:** enrich the runtime Moth dressing profiles the user reviewed and found thin
**Date:** 2026-10-05
**Branch:** `spacebunny/dressing-richer-20261005` (from `feature/relay-campaign` @ `25c189bd`)
**Base report:** `RUNTIME_DRESSING_THREE_MAPS_20261005.md` (same directory)
**Claim:** source-only. No native capture, no Blender export, no rendered frame.
Visual and native acceptance are **not** claimed anywhere in this document.

---

## 1. What was asked and what was done

The first pass gave the three maps a valid, `Profile.validate()`-clean profile, but
left most of each budget on the table (Vesper used 37 of 48 panels and 44 of 64
motes; Abyssal 37/48 and 50/56; Stormglass 34/48 and 75/80). This pass raises
every budget toward the `profile.gd` hard caps and fills it with placements that
are read off the maps' own geometry, then re-verifies all three maps plus the three
already-shipped controls.

The three profile JSONs are re-emitted from `author.mjs`, which is the authored
source of truth; nothing was hand-edited in JSON. **The profile JSONs are not
receipt package inputs** — they are game data consumed by
`godot/multiplayer_worlds/dressing/binder.gd` at map load, they are not read by the
receipt tooling, and no receipt advance is claimed or required here. See §8.

## 2. Before / after

Counts are `emitted / budget`. `placements` is panels + signs + pockets.

### vesper-viaduct

| metric | before | after | cap |
| --- | --- | --- | --- |
| materials | 8 / 8 | 8 / 8 | 32 |
| panels | 37 / 48 | **94 / 96** | 96 |
| signs | 18 / 20 | **24 / 24** | 24 |
| motes | 44 / 64 | **95 / 96** | 96 |
| pockets | 6 / 12 | **12 / 12** | 12 |
| placements | 61 | **130** | — |

### abyssal-pressureworks

| metric | before | after | cap |
| --- | --- | --- | --- |
| materials | 6 / 6 | 6 / 6 | 32 |
| panels | 37 / 48 | **93 / 96** | 96 |
| signs | 15 / 20 | **24 / 24** | 24 |
| motes | 50 / 56 | **90 / 96** | 96 |
| pockets | 9 / 12 | **12 / 12** | 12 |
| placements | 61 | **129** | — |

### stormglass-causeway

| metric | before | after | cap |
| --- | --- | --- | --- |
| materials | 7 / 7 | 7 / 7 | 32 |
| panels | 34 / 48 | **95 / 96** | 96 |
| signs | 21 / 24 | **24 / 24** | 24 |
| motes | 75 / 80 | **92 / 96** | 96 |
| pockets | 12 / 12 | 12 / 12 | 12 |
| placements | 67 | **131** | — |

`materials` did not move on any map: the GLB material lists are 11 / 7 / 9 names
and every one of them was already either dressed or preserved, so the only way to
raise that number would be a selector the art does not contain, which
`check.mjs` rejects in both directions. Preserved sets are unchanged
(`glass`/`letter`/`water`, `glass`, `glass`/`ocean`).

## 3. Budgets

`profile.gd` hard caps are `material_variants ≤ 32`, `panels ≤ 96`, `signs ≤ 24`,
`motes ≤ 96`, plus fixed per-group array caps (`materials` and
`preserve_materials` ≤ 32, `pockets` ≤ 12). Per-profile budgets were raised to
`panels 96`, `signs 24`, `motes 96` on all three maps.

**The pocket cap cannot move.** `profile.gd:50` applies `12 if group ==
"pockets"` as a hard cap with no `budgets` key behind it, so there is no
per-profile knob to raise for that group, and the cap itself is the system's
schema authority rather than this branch's to change. Stormglass was already at
12/12, so its extra density went into mote counts and pocket volumes instead
(spray 8→10 motes and 2.4 m→4 m deep, gate vents 6→9 motes and 6 m→8 m wide,
road grit volumes 1.2 m→2.4 m tall); Vesper and Abyssal were below the cap and
took 6 and 3 more pockets respectively to reach it.

## 4. What was added, and where each family is anchored

Every new placement family is anchored to a named surface in
`port/native-multiplayer-worlds/worlds/<map>.json`. No selector was added and no
selector was removed: the bidirectional GLB coverage check is unchanged and still
passes for all six maps.

### vesper-viaduct (+57 panels, +6 signs, +6 pockets)

| family | n | anchored to |
| --- | --- | --- |
| `street-cover-hatch-*` | 12 | the twelve iron `street-cover-cap` plates, three per terrace level (y 1.6 / 13.6 / 25.6) |
| `quay-rail-walk-*` | 8 | the six `quay-rail-cap` runs on both quay lips (z -104 and z -116); the 188 m centre run carries two |
| `bridge-parapet-band-*` | 4 | the four `bridge-parapet-cap` tops at x ±94 / ±106 |
| `chimney-cap-soot-*` | 10 | the ten `chimney-cap` tops on the mid terrace block (z 45), the band that flanks the arcade |
| `terrace-cap-membrane-*` | 10 | the ten mid-band terrace `row-*-cap` roofs (8 × 22 m) |
| `arcade-pier-band-*` | 10 | all ten `arcade-pier-cap` tops either side of the clock square |
| `hall-roof-hatch-*` | 3 | the slate roof ridges of the three ticket halls |
| signs | 6 | `objective-west-steps` / `objective-east-steps` above the terrace retaining walls, two arcade fascias under `arcade-ceiling-±66`, two terrace-row fascias on the housing bands |
| pockets | 6 | far quay, both ticket-hall roofs, the civic stair mid-flight, a mid-block flue, under the west arcade |

Existing pocket counts were also raised (canal mist 10→12, hall vents 6→8, dust
6→7) and volumes grew (2 m→3 m tall mist, 3×2×2 m→4×3×4 m vents).

### abyssal-pressureworks (+56 panels, +9 signs, +3 pockets)

| family | n | anchored to |
| --- | --- | --- |
| `canopy-trough-*` | 24 | the 24 ivory bay canopies, two per vessel at (x ± 11, z + 10, deck + 5.8 m); one down-facing light trough per canopy |
| `crown-hatch-*` | 12 | the twelve `*-crown` octagons that cap every vessel roof (25–32 m across on labs/pump, 13 m on the residential four) |
| `port-threshold-*` | 12 | the deck plate at each vessel port mouth, turned to run with the opening (6 m on 10 m ports, 8 m on 14 m ports) |
| `observation-bay-*` | 4 | the coral observation sills of the only four vessels that have glazing (labs 0-0 … 0-3) |
| `reef-silt-*` | +4 | the reef family now covers all nine coral columns instead of five |
| signs | 9 | one wayfinding board per link gallery, hung under the deck ceiling of each of the three maintenance bypasses, three pump spines and three operations galleries, named after the vessels they connect |
| pockets | 3 | two more reef-top dust volumes and one on the central operations gallery |

### stormglass-causeway (+61 panels, +3 signs)

| family | n | anchored to |
| --- | --- | --- |
| `city-wall-salt-bloom-*` | 21 | all 21 inner `barrier-city-*` walls, one per circuit straight; yaw derived from each wall's own outward perpendicular, signed towards its `barrier-sea-*` twin, so every bloom faces the road |
| `centre-line-*` | 21 | one centre-line dash per asphalt `road-*` segment, yaw from the segment's own long edge |
| `terminal-glazing-*` | 10 | the circuit-facing elevation of all ten observatory terminals, including `district-1-2`, which had no dressing entry at all until now |
| `buttress-hazard-*` | 6 | the two buttress faces per gate that look down the racing line |
| `gantry-walk-*` | 3 | the top of each steel gate gantry (y 22–24) |
| signs | 3 | the three named `districts[]` the circuit runs through — Glazed Weather Terminal, Arched Freight Bore, Stepped Quay |

The terminals are rotated off axis, so "the face the racing line sees" was chosen
by nearest approach to `race.centerline` (17.8 m) rather than by a fixed ±z rule;
the rejected alternative face is 21–25 m away on every terminal.

## 5. Placement convention (new entries)

`binder.gd:_plate` builds every panel and sign as a `QuadMesh`, whose front face
is its local `+Z`; both `panel.gdshader` and `wear_panel.gdshader` declare
`cull_back`; and `panel.gdshader` describes itself as "an opaque plate mounted
32 mm off an existing solid". So a yaw of 0 faces `+Z`, 90 faces `+X`, 180 faces
`-Z`, -90 faces `-X`, and a plate is offset along the direction it faces. This is
the rule `abyssal-pressureworks` already followed in the first pass (every one of
its 37 panels offsets along its own facing). New entries follow it everywhere, and
horizontal dressing uses pitch instead: `-90` faces up (floors, decks, cap tops),
`+90` faces down (canopy soffits). `author.mjs` exposes this as `FACE_UP`,
`FACE_DOWN` and `faceYaw(fx, fz)`, documented in the tooling README.

**Finding for visual acceptance, not fixed here.** Two first-pass families appear
to invert that rule and are therefore likely to be invisible from the outside
until they are confirmed on screen: the eight vesper `parcel-plate-*` plates
(offset along `-side` but yawed as if along `+side`) and the six stormglass
`gate-readout-*` boards on the raised leaves (two mirrored boards 1.2 m apart,
facing each other). They were left byte-identical so this pass's diff is purely
additive and the before/after metrics above are not muddied by a fix. The
remaining ambiguous case is `leaf-warning-*`, two banners under each gantry that
face inward, which may well be intentional.

## 6. Verification

All commands were run from the worktree root
`/home/mojo/.tmp-on-disk/cocs-coastal-blender-T-20261003`.

### 6.1 Authoring is reproducible — `author.mjs --check`, three runs

```
$ for i in 1 2 3; do node tools/godot-multiplayer/new-maps/runtime-dressing/author.mjs --check; done
OK vesper-viaduct: materials=8 panels=94 signs=24 pockets=12 motes=95 preserve=3
OK abyssal-pressureworks: materials=6 panels=93 signs=24 pockets=12 motes=90 preserve=1
OK stormglass-causeway: materials=7 panels=95 signs=24 pockets=12 motes=92 preserve=2
OK vesper-viaduct: materials=8 panels=94 signs=24 pockets=12 motes=95 preserve=3
OK abyssal-pressureworks: materials=6 panels=93 signs=24 pockets=12 motes=90 preserve=1
OK stormglass-causeway: materials=7 panels=95 signs=24 pockets=12 motes=92 preserve=2
OK vesper-viaduct: materials=8 panels=94 signs=24 pockets=12 motes=95 preserve=3
OK abyssal-pressureworks: materials=6 panels=93 signs=24 pockets=12 motes=90 preserve=1
OK stormglass-causeway: materials=7 panels=95 signs=24 pockets=12 motes=92 preserve=2
```

Three runs, three identical clean exits: the committed JSON is byte-identical to
what `author.mjs` emits, and `check.mjs` re-checks that byte equality for these
three maps on every run.

### 6.2 Node checker — the three new maps

```
$ node tools/godot-multiplayer/new-maps/runtime-dressing/check.mjs
PASS vesper-viaduct: materials=8/8 panels=94/96 signs=24/24 motes=95/96 preserve=3 placements=130
PASS abyssal-pressureworks: materials=6/6 panels=93/96 signs=24/24 motes=90/96 preserve=1 placements=129
PASS stormglass-causeway: materials=7/7 panels=95/96 signs=24/24 motes=92/96 preserve=2 placements=131
resources resolved: 60
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

Moth resources resolved rose from 57 to 60 across the three maps: the new passes
pull in `diamond_plate`, `riveted_armor-scorched` and `rough_stucco` (+ the
`rough_stucco` wear mask), all already in `godot/moth/generated/manifest.json`.
Every referenced PNG's IHDR was compared against the manifest.

### 6.3 Negative suite — the checker must also reject

`tools/godot-multiplayer/new-maps/runtime-dressing/negative.mjs` breaks one rule
at a time in a throwaway copy of a control profile and asserts `check.mjs` exits
non-zero with the expected message:

```
$ node tools/godot-multiplayer/new-maps/runtime-dressing/negative.mjs
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

Two of these are new rules added in this pass, because nothing enforced them
before and both failure modes are invisible to the old checks:

- **placement containment.** `profile.gd` only bounds a position to ±512 m, far
  wider than any map, so a plate authored at the wrong coordinate passed
  everything and would float in the void. Placements are now compared against the
  map's own declared `bounds`, grown by 12 m (the abyssal coral reef shelf sits
  6 m past its declared `minZ`). All six accepted maps pass.
- **no coincident placements.** Two plates on one point is always an authoring
  slip. All six accepted maps pass.

`check.mjs` reads the world JSON with the same `readFileSync` / `git show HEAD:`
fallback it already used for `material_language`, so it still runs in a sparse
worktree. It now honours `DRESSING_PROFILE_DIR` so the negative suite can point
it at broken copies without touching the repository.

### 6.4 Headless Godot, calling `profile.gd`'s own validator

Same sandbox recipe as the base report, in `/tmp/opencode/dressing-godot-richer`
(`material_language` extracted from `HEAD` via `git archive`, Moth PNGs imported
into the sandbox's own `.godot/`, nothing written back into the worktree, no
`--import`).

All six maps, which is every entry in `Profile.IDENTITIES`:

```
$ Godot_v4.5.2-stable_linux.x86_64 --headless --path /tmp/opencode/dressing-godot-richer \
    --script res://validate_profiles.gd
Godot Engine v4.5.2.stable.official.6ce3de25a - https://godotengine.org

PASS helix-conservatory: materials=9/12 panels=46/64 signs=13/20 motes=48/72 preserve=1
PASS gravemill-foundry: materials=7/8 panels=37/64 signs=20/20 motes=32/64 preserve=1
PASS parallax-observatory: materials=6/6 panels=26/64 signs=10/24 motes=32/40 preserve=1
PASS vesper-viaduct: materials=8/8 panels=94/96 signs=24/24 motes=95/96 preserve=3
PASS abyssal-pressureworks: materials=6/6 panels=93/96 signs=24/24 motes=90/96 preserve=1
PASS stormglass-causeway: materials=7/7 panels=95/96 signs=24/24 motes=92/96 preserve=2
DRESSING_HEADLESS_FAILURES=0
```

The three new maps named explicitly:

```
$ Godot_v4.5.2-stable_linux.x86_64 --headless --path /tmp/opencode/dressing-godot-richer \
    --script res://validate_profiles.gd -- vesper-viaduct abyssal-pressureworks stormglass-causeway
PASS vesper-viaduct: materials=8/8 panels=94/96 signs=24/24 motes=95/96 preserve=3
PASS abyssal-pressureworks: materials=6/6 panels=93/96 signs=24/24 motes=90/96 preserve=1
PASS stormglass-causeway: materials=7/7 panels=95/96 signs=24/24 motes=92/96 preserve=2
DRESSING_HEADLESS_FAILURES=0
```

Negative controls against the real validator, run in a second sandbox that
**copies** the profile directory instead of symlinking it (the base report's
recipe symlinks it, so an edit there lands on the worktree file — this is now
called out in the tooling README):

```
FAIL vesper-viaduct: sign contrast below 4.5:1
DRESSING_HEADLESS_FAILURES=1

FAIL vesper-viaduct: pockets exceeds hard cap, motes exceed budget
DRESSING_HEADLESS_FAILURES=1
```

The worktree profiles were confirmed unchanged after both controls
(`author.mjs --check` clean, `git status` showing only this branch's three
modified profile JSONs).

## 7. Files changed

- `godot/multiplayer_worlds/dressing/profiles/vesper-viaduct.json` — re-emitted
- `godot/multiplayer_worlds/dressing/profiles/abyssal-pressureworks.json` — re-emitted
- `godot/multiplayer_worlds/dressing/profiles/stormglass-causeway.json` — re-emitted
- `tools/godot-multiplayer/new-maps/runtime-dressing/author.mjs` — new tables and
  families, raised budgets, documented placement convention
- `tools/godot-multiplayer/new-maps/runtime-dressing/check.mjs` — placement
  containment and no-coincident-placement rules, `DRESSING_PROFILE_DIR` override
- `tools/godot-multiplayer/new-maps/runtime-dressing/negative.mjs` — **new**
- `tools/godot-multiplayer/new-maps/runtime-dressing/README.md` — negative suite,
  placement convention, sandbox symlink caveat
- `port/finish/map-variety/RUNTIME_DRESSING_RICHER_20261005.md` — **new**, this file

`profile.gd` was not touched. No receipt, requirement, generated world JSON, art
GLB or unrelated file was modified.

## 8. Receipt and acceptance status

- **Not a receipt package input.** The three profile JSONs are runtime game data
  loaded by `godot/multiplayer_worlds/dressing/binder.gd`; the receipt pipeline
  does not read them, so this pass advances no receipt, closes no receipt
  requirement and needs no receipt regeneration. If a receipt package happens to
  hash the dressing directory, that hash moves and is the integrator's to
  recompute — no receipt artefact was produced or edited here.
- **Native acceptance still pending.** `Profile.validate()` returning clean proves
  the binder will not report `invalid_profile` or `unresolved_resources`. It does
  **not** prove `status: "ready"`: `binder.gd:_collect` can still append
  `<selector> (instance override)` for any GLB node carrying a `material_override`,
  and `_sign` can still append `sign text too small to read`. Neither is reachable
  from a source-only check. A native load of each map is still required.
- **Visual acceptance still pending.** No capture was taken, so "richer" here means
  more placements over more of each map's real geometry, not "looks better". In
  particular the §5 orientation finding needs a screenshot to settle.
- **Not run:** no native map capture, no Blender, no `--import` in the worktree, no
  frame timing, no draw-call or VRAM measurement. Note that 130/129/131 placements
  per map is a much larger batch than the first pass; `binder.gd` emits one
  `MeshInstance3D` per plate, so the draw-call cost of these maps is now worth
  measuring before they are accepted.

## 9. What could not be enriched, and why

1. **`materials` on all three maps.** Every art material is already dressed or
   preserved, and `check.mjs` rejects both an unmatched art material and an unused
   selector, so the count cannot rise without adding a selector the GLB does not
   contain. 8/32, 6/32, 7/32 is the ceiling these maps' art allows.
2. **`signs` is now at the hard cap of 24 on all three maps.** Further sign coverage
   needs a change to `profile.gd`, which is out of scope here.
3. **`pockets` is at the 12 cap on all three maps**, and for Stormglass it was
   already there before this pass. The cap is hard-coded in `profile.gd` with no
   per-profile budget behind it, so it cannot be raised from a profile; raising it
   would be a schema change, not a dressing change. Motes and pocket volumes took
   the density instead.
4. **Abyssal's twelve vessel deck plates and six gallery deck grates were dropped
   rather than emitted.** Both are real walkable geometry (the `*-deck` octagons
   and the link-gallery ramps), but with the crown hatches, 24 canopy troughs, 12
   port thresholds and 4 observation bays the panel group is at 93 of 96, and a
   crown hatch on a roof reads from further away than a plate in a deck corner.
   `author.mjs` says so in a comment at the end of `abyssalPanels()`.
5. **Stormglass interiors are still undressed.** The 21 quay workshops get no new
   panel or sign (they were not in the top 61 slots); the 1728 glass panes and 5382
   salt pieces are still untouched by design, as are all three maps' preserved
   transmissive materials.
6. **Vesper's remaining 20 terrace row caps and 20 chimney caps** (the z -47 and
   z 112 bands) are undressed; only the z 45 band that flanks the arcade was
   affordable inside the 96-panel cap.
7. **`godot/material_language/**` is not materialised in this worktree.** Both
   verifiers read it from `git show HEAD:<path>` / `git archive HEAD`, so a change
   to `families.gd` or `library.gd` outside this branch would not be reflected
   until the sparse worktree is widened.

## 10. Reproduction

```sh
cd /home/mojo/.tmp-on-disk/cocs-coastal-blender-T-20261003
git checkout spacebunny/dressing-richer-20261005
node tools/godot-multiplayer/new-maps/runtime-dressing/author.mjs --check
node tools/godot-multiplayer/new-maps/runtime-dressing/check.mjs
node tools/godot-multiplayer/new-maps/runtime-dressing/check.mjs \
  helix-conservatory gravemill-foundry parallax-observatory
node tools/godot-multiplayer/new-maps/runtime-dressing/negative.mjs
# headless Godot: see README.md in the same directory
```