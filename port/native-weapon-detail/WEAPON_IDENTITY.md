# Weapon identity framework (shared)

**Single source of truth for weapon differentiation across both weapon-detail lanes.**
First-person lane owns this file (`port/native-weapon-detail/**`); the third-person
lane (`tools/godot-operators/world-weapons.mjs`,
`godot/source_operators/generated/world_weapons/**`) reads it and matches the
channels below at its own polygon/scale budget.

Sources of truth this document derives from — never invented:

| input | file |
|---|---|
| name, role, damage feel, weapon colour | `game/data.mjs` (`WEAPONS`) |
| chassis envelope, feed/barrel/sight construction | `game/weapon-models/chassis.mjs` (`CHASSIS`, `buildChassis`) |
| sight family, ADS alignment solver | `game/sights.mjs`, `game/reticle.mjs` (`BUILTIN_SIGHT`, `BUILTIN_MAGNIFICATION`) |
| ADS enter/exit rates | `game/weapon-ads.mjs` (`ADS_PROFILES`) |
| muzzle/impact effect profile | `godot/weapon_effects/profiles.gd` (`ITEMS`) |
| handling mechanism family | `tools/godot-weapons/handling.mjs` (`FAMILY`) |

`game/**` is locked and read-only for both lanes. Detail geometry is authored in
the exporter (`tools/godot-weapons/export.mjs` + `tools/godot-weapons/detail.mjs`)
and attached to the *existing* source assemblies; source geometry is never moved,
scaled, removed or regenerated. `game/data.mjs`, `game/weapon-models/*.mjs`,
`game/sights.mjs`, `game/weapon-ads.mjs` and `game/model-geometry.mjs` are hashed
into the manifest and re-checked by `tools/godot-weapons/verify.mjs`.

## Status

| weapon | role | mechanism | colour |
|---|---|---|---|
| 0 Pulse Rifle | starter carbine, hitscan, infinite ammo | kinetic, box magazine | `#70ffe6` |
| 1 Rocket Launcher | dumb-fire splash launcher | launcher, breech latch / tube | `#ffad61` |
| 2 Rail Lance | charge-up piercing beam, ×3.6 optic | energy, cell | `#bb9aff` |
| 3 Scattergun | twin-breech break action, 8 pellets | break, breech block | `#ffde87` |
| 4 Plasma Driver | fast blue orbs, splash | energy, cell | `#72cfff` |
| 5 Grenade Launcher | arcing bouncy drum launcher | drum, revolver feed | `#ff806b` |
| 6 Shock Beam | instant lightning hose, fork emitter | energy, cell | `#8ce8ff` |
| 7 Flak Cannon | 12-shard close-range wall | breech, ammunition box | `#ffd166` |
| 8 Marksman Rifle | hard-hitting semi-auto, ×3.0 optic | kinetic, box magazine | `#ffd27a` |
| 9 Submachine Gun | fast spray, telescoping stock | kinetic, box magazine | `#8affc1` |

## The six channels

Every weapon gets exactly one deliberate choice in each channel. Channel 1 is the
dominant silhouette idea; channels 2–5 follow the real source mechanism (never an
invented one); channel 6 is the shared detail vocabulary. `verify.mjs` asserts all
six channels hold ten distinct values, so "the weapons look different" is a checked
property, not a claim. The manifest carries the same strings per weapon
(`identity`), and `godot/tests/first_person/detail.gd` re-checks distinctness from
the imported asset.

| id | 1. receiver massing | 2. feed identity | 3. muzzle device | 4. stock & grip | 5. sight family | 6. accent + greeble |
|---|---|---|---|---|---|---|
| 0 Pulse Rifle | slender carbine receiver, dorsal spine, squared front trunnion, paired side plates | box magazine: magwell flare, witness slot, floorplate lip, ambi catch | slotted flash hider: six-port sleeve with crown ring | polymer stock with cheek riser and sling slot, grip palm swell | iron notch/post, toothed optic rail with a bolted front-sight base block | cyan trim, emissive charge conduit on the left flank, **perforated handguard shroud** |
| 1 Rocket Launcher | fat launch tube, flared rear venturi, heavy forward collars | breech latch: hinged loading gate, latch handle, seal stripe | belted bore with a blast-deflector crown ring and radial ports | shoulder tube, folding support strut, thick butt pad, vertical foregrip | iron, plus a folded launcher leaf ladder on the left flank | orange trim, emissive venturi dot ring, **exposed venturi ribs and strap loops** |
| 2 Rail Lance | long low twin-rail sled with staggered side plates | energy cell: housing, charge window, retaining clips, discharge lead | twin accelerator rings with standoff prongs | skeleton stock with cheek piece, angled grip | integrated ×3.6 scope with a single elevation turret on the sled | violet trim, emissive accelerator coils, **exposed coil rings** |
| 3 Scattergun | wide breech block, barrel-selector bar, twin chamber collars | break-action breech: extractor knuckles, twin chamber faces | twin ported choke sleeves with slanted ports | wood-tone shoulder stock, comb, squared grip, barrel band | iron with a brass bead on the top rib | cream/brass trim, emissive chamber witness, **brass rib rail** |
| 4 Plasma Driver | bulbous vented chamber in a cradle frame, slab power pack | energy cell: twin cell tubes, windows, heavy latch | three-prong plasma focus cage with a front core ring | short stock with heat-shield plate, grip fin stack | iron notch/post on a bolted base block over the vented chamber | blue trim, emissive chamber window and cell windows, **ribbed heat sink** |
| 5 Grenade Launcher | chunky revolver frame with a top strap over the drum | revolver drum: flutes, indexer yoke, hinge, index marks | heavy bored muzzle, four lateral ports, front collar | shoulder stock, recoil pad, thumb rest | iron, plus a folded launcher ladder and quadrant on the left flank | red-orange trim, emissive drum index window, **angled slats** |
| 6 Shock Beam | open fork/yoke emitter frame with flank capacitor plates | energy cell: capacitor plates, coil leads, cell housing | twin emitter prongs with discharge tips and a tuning bridge | insulated cheek plate on the stock, coil-wrapped grip | iron on an insulated sight rib | ice-blue trim, emissive discharge tips, **exposed coils and insulator discs** |
| 7 Flak Cannon | massive reinforced breech with a trunnion and top carry handle | ammunition box: lid, latch, belt run into the breech | heavy flared muzzle with eight radial ports | heavy stock with recoil buffer, sturdy grip | iron with a side range drum below the sight line | amber trim, emissive arming indicator, **belt run and shell loops** |
| 8 Marksman Rifle | slim precision receiver with a chassis spine | box magazine: witness slot, baseplate, funnel magwell | slim multi-baffle brake with a heat band behind it | chassis stock, adjustable cheek riser, rear monopod stub | integrated ×3.0 scope with paired elevation and windage turrets | tan trim, emissive heat band, **ribbed barrel flutes** |
| 9 Submachine Gun | stamped receiver with a rib pattern and flared magwell | box magazine: stamped ribs, witness slot, floorplate | short ported sleeve with a thread collar | telescoping wire stock with butt plate, light trigger housing | iron on a stamped rib with a rear drum | green trim, emissive chamber port witness, **stamped ribs and vented shroud** |

### Locality rule (non-negotiable)

Detail sits where the mechanic actually is:

* vents and heat hardware around the authored `HeatZone` (barrel assembly),
* rails and risers where the optic actually mounts (sight rail, below the bore line),
* an ejection-port treatment at the authored `Ejection` station (weapons 0, 3, 4,
  5, 7, 8, 9 — the mechanisms whose handling profile has a casing port),
* magazine / cell / drum / breech detail on the moving `Feed` group only,
* handguard detail where the hands actually hold (`GripSupport`),
* nothing in the sight corridor (the front-sight base block tops out below the
  rail; measured minimum clearance from the sight line is 122 mm), and nothing
  inside the hand capsules (measured minimum 47 mm; the exporter refuses to
  export a weapon that violates either bound).

## Material policy (shared)

Base palette is the source palette: `dark` `#222f37`, `light` `#73848a`, and the
per-weapon `glow` (the weapon's own `data.mjs` colour, emissive).

Two **shared materials** are added by the first-person exporter and reused by every
weapon (the third-person lane mirrors the same names/roles at its own budget):

| material | colour | role |
|---|---|---|
| `detail-trim` | `#c6ced2` machined steel | reciprocating action hardware (bolt carrier, serrations, charging knob, case guide) — the arsenal's common "moving parts are polished" signature |
| `detail-cavity` | `#0d1519` recess | recessed vents, port mouths, muzzle sleeves, shadow gaps, so detail reads at viewmodel distance |

**Batch budget (first person): exactly 8 material batches per weapon.** A bucket is
`(moving assembly × material slot)`, i.e. one draw call and one `MeshInstance3D`.
Allocation used by every weapon:

| assembly | slots | materials |
|---|---|---|
| body (receiver, stock, handguard, sight assembly) | 3 | `dark`, `light`, `glow`\* |
| feed (magazine / cell / drum / breech) | 2 | `light` + `glow` (cell weapons 2/4), `light` (weapon 6), else `dark` + `light` |
| bolt (reciprocating carrier + charging hardware) | 1 | `detail-trim` |
| barrel (bore, rails, muzzle device) | 2–3 | `detail-cavity` + `light` (+ `glow` on 2/6 source strips, the 6 flash strips and the new 8 heat band) |

\* weapons 2 and 8 mount integrated scopes, so their body has no source glow tip
and uses 2 body slots; the freed slot is spent on the barrel's energy signature.
Weapon 6's barrel carries the source glow rail strips, so its cell bar and strip
join the cell body tone (`light`) and the barrel holds three slots
(`detail-cavity`, `light`, `glow`) instead.

Small, explicit source-material remaps are required to hold eight batches without
touching geometry (`tools/godot-weapons/detail.mjs` `remapFor`):

* the reciprocating carrier and charging hardware move to the shared `detail-trim`
  tone on all ten weapons (motion legibility),
* the barrel's blued hardware moves to the shared `detail-cavity` tone (deeper
  recesses) except on weapon 6, whose collars join `light`,
* the energy cell's retaining bar joins the cell body tone on weapons 2, 4 and 6.

No source mesh is moved, resized, deleted or re-shaped. The only tessellation
choice is at the procedural ring primitive:

* **Rings attached to the sight assembly** (the optic tube rings and mount clamp
  rings, plus a rear aperture) keep the author's **32 tubular segments** exactly —
  they fill the ADS frame at magnification and are part of the sight picture.
* **Barrel and chassis collar rings** generate **16 segments** (20 for the two
  largest, radius ≥ 0.09 m). They are 1–9 cm rings seen at 0.4–1.5 m; at 960×640
  and 1280×800 the silhouette delta is about one pixel, and the recovered budget
  goes to real detail instead. Measured per-weapon savings are in `README.md`.

## Presentation motion (first person only)

* **Idle sway character** is per weapon family, from `presentation.sway` in the
  manifest (rate 0.42–3.4 rad/s, ≤2.2 mm, ≤0.0032 rad). It is multiplied by
  `(1 - aim_weight)` in `rig.gd`, so it is exactly zero at a settled cheek weld,
  and it is disabled under reduced motion. The launcher breathes slowly and
  heavily, the marksman rifle is near-still, the SMG jitters fast and tight.
* **Bolt/shroud motion** keeps the authoritative stroke from the handling profile;
  only the *visible* carrier hardware travels (bright trim geometry, serrations,
  knob) plus a bounded rattle rotation (≤0.02 rad at full stroke) that is exactly
  zero at rest.
* **Magazine handling flourish** is a pure function of the authoritative reload
  progress inside its window, at rest at both ends, per family in
  `tools/godot-weapons/handling.mjs` (`RELOAD[*].flourish`: magazine seat rock,
  cell spin, drum twist, breech slam).

Nothing in this framework reads or writes recoil, spread, ammo or reload timing.

## Invariants (both lanes)

1. Every existing anchor keeps its weapon-space position exactly (measured drift
   0.0 versus the previous export) and stays a child of the same moving assembly.
2. Settled ADS: sight axis error 0.0 px, rear/front anchor error 0.0 px, and
   `0` opaque pixels in the 4×4 px target gap above the front post.
3. Hands and grips never intersect new geometry (measured minimum 47 mm).
4. Hip framing keeps the 48×48 px reticle region clear at 960×640 and 1280×800.
5. Exactly eight material batches per weapon (one surface each).
6. Triangles stay inside the documented band (3,000–6,000 for eight weapons;
   weapons 2 and 8 sit at 6.47k/6.0k because their locked source construction
   already spends 5.2–6.1k — both stay inside the 6,500 gate).
7. Re-export is byte-identical (`node tools/godot-weapons/verify.mjs`).
8. All first-person ADS / handling / weapon-effects / combat-integration gates
   stay green.
