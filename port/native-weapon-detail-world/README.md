# Third-person world-weapon detail lane

**Lane:** THIRD-PERSON world-weapon detail (owned paths: `tools/godot-operators/world-weapons.mjs`,
`godot/source_operators/generated/world_weapons/**`, `godot/tests/source_operators/**`,
`port/native-weapon-detail-world/**`). First-person viewmodels are the parallel lane
(`port/native-weapon-detail/**`, `tools/godot-weapons/**`, `godot/first_person/**`) and own
`port/native-weapon-detail/WEAPON_IDENTITY.md`, the single source of truth for what each weapon
looks like.

## What this lane did

`tools/godot-operators/world-weapons.mjs` still constructs the **actual source
`simpleWeaponModel`** for all ten `WEAPONS` entries at source scale and still writes the same
`Muzzle` / `WeaponGripLeft` / `WeaponGripRight` chassis contacts. On top of that it now builds a
detail kit in the source's own vocabulary (`beveledBox`, turned/placed joins, mirrored slats)
answering the same six identity channels the first-person viewmodel uses, and merges it into the
source batches. Source geometry is never moved, scaled or removed: detail is purely additive, and
`game/**` stays locked and unread.

```
node tools/godot-operators/world-weapons.mjs      # export (deterministic, byte-identical re-run)
python3 tools/godot-operators/check.py            # private staged project: check/weapons/grips/presentation
DETAIL_EVIDENCE=port/native-weapon-detail-world/evidence/verify.json \
  node port/native-weapon-detail-world/tools/verify-detail.mjs    # contracts, hand clearance, hidden-detail audit
DETAIL_SHEETS=close,silhouette-10m python3 port/native-weapon-detail-world/tools/render.py   # Xvfb review captures
python3 tools/godot-operators/live.py --output port/native-weapon-detail-world/evidence/live-<stamp>
```

The detail kit answers `port/native-weapon-detail/WEAPON_IDENTITY.md` (the first-person lane's
document, hashed in the evidence section) channel by channel: `WEAPON_IDENTITY_WORLD.md` is the
transcription table plus the differences that the third-person contract forces, so the two lanes
can be compared line by line instead of by eye.

## Before / after

| # | weapon | tris before | tris after | detail tris | draws before | draws after | bytes before | bytes after | flush/embedded tris |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | Pulse Rifle | 612 | 1696 | 1084 | 2 | 4 | 21764 | 91204 | 58 |
| 1 | Rocket Launcher | 612 | 1860 | 1248 | 2 | 4 | 21696 | 80800 | 32 |
| 2 | Rail Lance | 612 | 2204 | 1592 | 2 | 4 | 21728 | 102352 | 36 |
| 3 | Scattergun | 792 | 1928 | 1136 | 2 | 4 | 26312 | 89864 | 36 |
| 4 | Plasma Driver | 612 | 2108 | 1496 | 2 | 4 | 21696 | 98468 | 76 |
| 5 | Grenade Launcher | 552 | 1872 | 1320 | 2 | 4 | 20036 | 95812 | 96 |
| 6 | Shock Beam | 612 | 1920 | 1308 | 2 | 4 | 21696 | 95356 | 16 |
| 7 | Flak Cannon | 612 | 2336 | 1724 | 2 | 4 | 21692 | 107272 | 68 |
| 8 | Marksman Rifle | 612 | 2060 | 1448 | 2 | 4 | 21712 | 98400 | 32 |
| 9 | Submachine Gun | 612 | 1656 | 1044 | 2 | 4 | 21728 | 90928 | 46 |
| | **ten weapons** | **6240** | **19640** | **13400** | **20** | **40** | **220 KB** | **928 KB** | **496** |

"flush/embedded" is the hidden-detail audit in `evidence/verify.json`: triangles whose
three vertices sit inside a source envelope. They are the deliberate flush mounts
(port plates, rail base, scope base, sight support base, drum hub caps, magazine-side
slats), 12–24 triangles of muzzle-bore emissive core that is visible through the open
bore, and nothing else; the audit is a wasted-triangle report, not a correctness claim.

Every weapon is inside the lane's 1,200–2,500 triangle target and at the 4-batch ceiling
(3 source-free batches at most: source `dark` polymer, source `accent` weapon colour, plus
`detail-trim` machined steel and the per-weapon emissive accent, which the identity document
gives to all ten weapons).

### Roster cost (32 actors, one weapon each)

* draws: 2 → 4 per weapon; 32 actors add **+64 draw calls** (weapon draws 64 → 128). The roster the
  lead measured at ~1,650 draws for 32 actors therefore rises by ~3.9%, and every weapon costs the
  same bounded 4 draws regardless of type.
* triangles: 6,240 → 19,652 across the ten loaded types; a mixed 32-actor roster carries roughly
  +43 k triangles of weapon geometry (about 1.4 k per actor on average), all inside the existing
  single weapon LOD (no new LOD tier, no shadow-pass change).
* bytes: 220 KB → 929 KB of GLB for the ten weapon scenes (still small next to the 12.0 MiB
  operator roster).

## Contracts

| contract | result | evidence |
|---|---|---|
| `Muzzle` / `WeaponGripLeft` / `WeaponGripRight` unchanged | **0.0 m** drift vs the pre-detail manifest (`anchors-before.json`, commit `84dbae73`); test gate is 1e-4 | `weapons.json`, `verify.json` |
| `HandGrips.align` still reaches the contacts | 450 source fixture cases, max grip world error **3.77e-7 m**, reported contact error 2.60e-7 m, reach-clamp excess 3.60e-7 m (all at the pre-detail residual) | `grips.json` |
| `catalog.gd` / `manifest.json` schema | `file`, `anchors`, `bounds`, `sha256`, `triangles`, `draws` kept and consistent with the imported GLBs; `detail.{triangles,zones,materials,identity}` and `detailVocabulary` added | `weapons.gd` |
| deterministic re-export | two consecutive exports produce identical per-file SHA-256 (checked for all ten; `verify.json.matchesManifest` true) | `verify.json` |
| node/batch hygiene | one material surface per batch; every imported node released (object count returns to baseline) | `weapons.json` |
| hands never intersect added detail | **0** triangle contacts in either hand across all ten weapons; nearest added-detail approach 9.5e-6 m (the pre-detail source body itself sits 1.8e-6 m from the same palm surfaces) | `verify.json` |
| no triangles hidden inside source meshes | reported per zone; the remainder are flush mount bases, hub caps, magazine faces and the deliberate muzzle-bore emissive core (all listed in `verify.json.hiddenDetailTriangles`) | `verify.json` |

## Identity channels (world side)

`WEAPON_IDENTITY_WORLD.md` transcribes the shared document's six channels per weapon, records the
reconciliation and lists, weapon by weapon, the sub-features the shared document names that this
budget deliberately leaves out. Summary of the world-side read:

* receiver massing — rail/riser, carry handle or fork frame per weapon, plus a real ejection port
  treatment (kinetic deflector and carrier race, or louvred vents on the energy weapons);
* feed identity — box magazine (floorplate, witness slots, body ribs, catch), six-flute revolver
  drum with hub caps and index marks, energy cell (twin tubes or capacitor plates, emissive
  window), ammunition box (lid, hinge, belt window with three rounds), break-action extractor and
  right-side shell carrier;
* muzzle device — slotted flash hider, launch-tube mouth with collar stack, twin accelerator rings
  with prongs, twin ported chokes and muzzle clamp, plasma focus cage with a glowing core, heavy
  bored muzzle with lateral ports, twin fork prongs with an arc bar, heavy brake with heat-sink
  collars, three-baffle precision brake, compact ported compensator;
* stock and grip treatment — cheek riser / recoil pad / shoulder rest / vented frame / telescoping
  rods / thumb rest / monopod stub / shell loops / recoil springs, plus grip floor cap, lanyard loop
  and trigger group outside the palm;
* sight family — source iron sights with ear wings, hooded front post and a real support post, or
  the source scope proportions with objective bell, ocular, mount posts and elevation/windage
  turrets; the launcher and grenade weapons keep their canted ladder leaves;
* accent and signature greeble — the weapon's own `data.mjs` colour as the emissive accent (charge
  conduit, venturi dots, coil rings, chamber witness, focus core, drum index window, discharge arc,
  arming indicator, heat band, port witness), plus the per-weapon motif (stepped fins, chevrons,
  coils, shell carrier, plasma window, drum flutes, fork prongs, belt window, range dial, charging
  handle).

## Evidence

Authority reconciled: `port/native-weapon-detail/WEAPON_IDENTITY.md`, SHA-256
`57e82256ab3a2f1a871f425ed672e3dcf7e38ac38ce313ad0997f95b46c21528` (read from the
first-person lane; the world-side transcription and reconciliation notes are in
`WEAPON_IDENTITY_WORLD.md`).

| file | what it shows |
|---|---|
| `evidence/close-1280x800.png`, `evidence/close-960x640.png` (+ `-crop-`) | all ten weapons, one per cell, identical 3/4 front-right camera at 1.45 m, FOV 50, hands attached |
| `evidence/detail-line-1280x800.png`, `detail-line-960x640.png` | the ten-weapon family in one real-viewport frame at 7 m (both sizes) |
| `evidence/detail-left-1280x800.png`, `detail-right-1280x800.png` | left receiver face (feed, handguard, grips) and right receiver face (port, rail, hardware) at 1.6 m |
| `evidence/detail-hands-1280x800.png` | 2.3 m close-up on weapons 3, 4 and 7 with both hands on the weapon |
| `evidence/silhouette-10m-*.png`, `silhouette-25m-*.png` (+ `-crop-`) | one weapon per cell at 10 m and 25 m, FOV 75 (native gameplay FOV), plus a 2x central crop of the same frames; 1280x800 and 960x640 |
| `evidence/grip-*.png` (+ `-crop-`) | 0.95 m cells aimed at the left grip contact |
| `evidence/feed-*.png` (+ `-crop-`) | 0.62 m cells aimed at the feed mass |
| `evidence/verify.json` | contracts, anchor drift, exact hand clearance, hidden-detail audit, per-weapon triangles/draws/zones |
| `evidence/live-<stamp>/` | production session: two remote authority bots walking, firing and reloading with the mounted world weapons, grips attached, both viewport sizes, results and restart |

All captures are private-Xvfb Compatibility renders (llvmpipe), 960x640 or 1280x800, from the
pinned Godot 4.5.2 binary; captures are genuine renders and are not retouched. The
source glove material (`#18262c`) is close in value to the source weapon polymer
(`#222f37`), so the gripping hands read as dark shapes on dark receivers in these
captures — that is the source finish, not a rendering artefact.

## Open / unproven

* Rendered captures are the software rasteriser; no hardware-GPU capture was taken in this lane.
* The 25 m sheet is small by construction: at the native gameplay FOV an actor subtends a few dozen
  pixels, so it demonstrates silhouettes, not detail legibility.
* Weapon detail is a single LOD; this lane did not add a distance LOD or impostor for the weapons.
* The `detail-cavity` role from the shared document is folded into the source dark batch (the
  third-person budget is four batches); recesses are geometric insets rather than a separate
  material, so their albedo is the source polymer.
* The rocket launcher's left-hand contact is on the receiver face (the source world body has no
  vertical foregrip and `HandGrips.align` places the palm flush against that face), so the world
  model answers the shared document's foregrip channel with a flush handguard instead of a
  standalone grip; adding one would intersect the palm.
* `python3 tools/godot-operators/check.py` writes its reports into the host lane's
  `port/native-source-operators/evidence/{check,weapons,grips,presentation}.json` (that path is
  fixed inside `check.py`, which is not owned by this lane). Those four report files were rewritten
  while verifying and are left uncommitted for the lead; only this lane's own paths are committed.
* The measured roster cost is analytical (4 draws × actors) plus the imported per-weapon triangle
  counts; no 32-bot rendered frame-timing run was taken by this lane. The existing source-operator
  performance lane's numbers are unaffected by import counts alone.
