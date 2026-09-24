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

## The second pass: silhouette first

The first detail pass dressed every weapon with the same vocabulary (a rail kit, a
muzzle sleeve, heat louvres, side plates) and differentiated them mainly by trim
colour. Review found the ten weapons still read as one family. This pass keeps the
six channels but rewrites each weapon around **one dominant mass, one dominant
projection and one dominant terminator**, so the *outline* separates first and the
greebles only reinforce it. Concretely, per weapon:

| # | weapon | dominant silhouette idea |
|---|---|---|
| 0 | Pulse Rifle | the *slender* one: long perforated barrel shroud around a thin bore, low dorsal spine, skeleton stock, slim magazine |
| 1 | Rocket Launcher | the *fat tube*: trumpet blast-deflector bell at the muzzle and a flared venturi bell at the shoulder |
| 2 | Rail Lance | the *long sled*: twin rails run the whole barrel and fork forward past the muzzle, battery slab below, boxy scope base |
| 3 | Scattergun | the *wide one*: ventilated top rib over twin bores, selection lever, wide fore-end, barrel band |
| 4 | Plasma Driver | the *round one*: two turned bulbs on the bore axis in a slab cradle, round flank heat exchangers, three-prong focus cage |
| 5 | Grenade Launcher | the *squat drum*: top strap over a flared, slatted drum with legs each side of the cylinder |
| 6 | Shock Beam | the *fork*: twin forward prongs with discharge tips and a tuning bridge, square dorsal capacitor comb, rear insulator stack |
| 7 | Flak Cannon | the *boxy one*: reinforced breech with trunnion discs, left-flank carry handle, heavy flared bell |
| 8 | Marksman Rifle | the *long precision* one: under-receiver chassis spine, big optic, folded bipod forward, monopod at the butt |
| 9 | Submachine Gun | the *stub with the oversized magazine*: a quad-stack body hanging far below a short receiver, wire stock, flank rear drum |

## Status

| weapon | role | mechanism | tone family |
|---|---|---|---|
| 0 Pulse Rifle | starter carbine, hitscan, infinite ammo | kinetic, box magazine | cyan service grey |
| 1 Rocket Launcher | dumb-fire splash launcher | launcher, breech latch / tube | drab green tube paint |
| 2 Rail Lance | charge-up piercing beam, ×3.6 optic | energy, cell | violet-grey anodised |
| 3 Scattergun | twin-breech break action, 8 pellets | break, breech block | olive with brass |
| 4 Plasma Driver | fast blue orbs, splash | energy, cell | cold steel blue |
| 5 Grenade Launcher | arcing bouncy drum launcher | drum, revolver feed | oxblood parkerised |
| 6 Shock Beam | instant lightning hose, fork emitter | energy, cell | ice cyan |
| 7 Flak Cannon | 12-shard close-range wall | breech, ammunition box | amber ochre |
| 8 Marksman Rifle | hard-hitting semi-auto, ×3.0 optic | kinetic, box magazine | light desert tan |
| 9 Submachine Gun | fast spray, telescoping stock | kinetic, box magazine | dark green phosphated |

## The six channels

Every weapon gets exactly one deliberate choice in each channel. Channel 1 is the
dominant silhouette idea; channels 2–5 follow the real source mechanism (never an
invented one); channel 6 is the shared detail vocabulary plus the weapon's own
surface finish. `verify.mjs` asserts all six channels hold ten distinct values, so
"the weapons look different" is a checked property, not a claim. The manifest
carries the same strings per weapon (`identity`), and
`godot/tests/first_person/detail.gd` re-checks distinctness from the imported
asset.

| id | 1. receiver massing | 2. feed identity | 3. muzzle device | 4. stock & grip | 5. sight family | 6. accent + greeble |
|---|---|---|---|---|---|---|
| 0 Pulse Rifle | slender carbine: slim dorsal spine, squared front trunnion, long perforated barrel shroud | box magazine: magwell flare, witness slot, floorplate lip, ambi catch | slotted flash hider: six-port sleeve with crown ring | skeleton stock: two rails and a slotted comb, grip palm swell | iron notch/post, toothed optic rail with a bolted front-sight base block | cyan trim, emissive charge conduit on the left flank, perforated handguard shroud |
| 1 Rocket Launcher | fat launch tube: flared rear venturi bell, trumpet blast-deflector muzzle, heavy forward collars | breech latch: hinged loading gate, latch handle, seal stripe | trumpet blast deflector with an eight-port crown ring | shoulder tube, folding support strut, thick butt pad, vertical foregrip | iron, plus a folded launcher leaf ladder on the left flank | orange trim, emissive venturi dot ring, exposed venturi ribs and strap loops |
| 2 Rail Lance | long low twin-rail sled: rails run the muzzle and fork forward, rear battery slab | energy cell: housing, charge window, retaining clips, discharge lead | twin forked rail prongs with a coaxial accelerator ring behind them | skeleton stock with cheek piece, angled grip | integrated x3.6 scope with a single elevation turret on the sled | violet trim, emissive rail tips and accelerator coils, exposed coil rings |
| 3 Scattergun | wide break-action block: ventilated top rib, barrel-selector bar, twin chamber collars | break-action breech: extractor knuckles, twin chamber faces | twin ported choke sleeves with slanted ports | wood-tone shoulder stock, comb, squared grip, barrel band | iron with a brass bead on the top rib | cream/brass trim, emissive chamber witness, brass rib rail |
| 4 Plasma Driver | bulbous orb chamber clamped in a slab cradle, slab power pack below | energy cell: twin cell tubes, windows, heavy latch | three-prong plasma focus cage closing on a front core ring | short stock with heat-shield plate, grip fin stack | iron notch/post on a bolted base block over the vented chamber | blue trim, emissive orb windows and cell windows, ribbed heat sink |
| 5 Grenade Launcher | chunky revolver frame: top strap over a flared drum, legs each side of the cylinder | revolver drum: fluted rims, indexer yoke, hinge, index marks | heavy bored muzzle, four lateral ports, flared front collar | shoulder stock, recoil pad, thumb rest | iron, plus a folded launcher ladder and quadrant on the left flank | red-orange trim, emissive drum index window, angled slats |
| 6 Shock Beam | open fork emitter frame: twin forward prongs, flank capacitor plates, C-yoke barrel | energy cell: capacitor plates, coil leads, cell housing | twin emitter prongs with discharge tips and a tuning bridge | insulated cheek plate on the stock, coil-wrapped grip | iron on an insulated sight rib | ice-blue trim, emissive discharge tips, exposed coils and insulator discs |
| 7 Flak Cannon | massive reinforced breech: trunnion discs, left-flank carry handle, heavy flared bell | ammunition box: lid, latch, belt run into the breech | heavy flared bell with eight radial ports | heavy stock with recoil buffer, sturdy grip | iron with a side range drum below the sight line | amber trim, emissive arming indicator, belt run and shell loops |
| 8 Marksman Rifle | slim precision rifle: long under-receiver chassis spine, folded bipod, rear monopod | box magazine: witness slot, baseplate, funnel magwell | slim multi-baffle brake with a heat band behind it | chassis stock, adjustable cheek riser, rear monopod stub | integrated ×3.0 scope with paired elevation and windage turrets | tan trim, emissive heat band, ribbed barrel flutes |
| 9 Submachine Gun | stamped SMG: stub receiver, oversized quad-stack magazine, wire stock | box magazine: oversized quad-stack body, coupling clamp, witness slot | short ported sleeve with a thread collar | telescoping wire stock with butt plate, light trigger housing | iron on a stamped rib with a rear drum | green trim, emissive chamber-port witness, stamped ribs and oversized magazine |

## Silhouette measure (checked, not claimed)

`tools/godot-weapons/silhouette.mjs` rasterises every exported triangle into a
fixed weapon-space orthographic bit mask (2 cm cells, covering the longest muzzle
to the rear-most bell), and `verify.mjs` compares the ten masks pairwise by
intersection-over-union:

| view | what it is | before | after | gate |
|---|---|---|---|---|
| `side` | whole weapon seen along +X: the hip/aim outline | max **0.823** (4 vs 6), mean 0.612 | max **0.744** (4 vs 6), mean 0.594 | max ≤ 0.78 |
| `top` | whole weapon seen from above (receiver width, bores, side hardware) | max 0.794 (0 vs 8) | max 0.821 (0 vs 8) | reported |
| `detailSide` | the authored detail pass alone | max 0.305, mean 0.175 | max **0.284**, mean 0.175 | max ≤ 0.40 |

The authored detail now covers **2,120** mask cells across the arsenal (was
1,520, +39%) while its own pairwise IoU stayed flat — the identity pass added
outline where it is visible and did not converge on one shape. The `top` view is
reported rather than gated: it is dominated by the locked receiver width, and the
player reads the side (hip) and rear (ADS) views instead. The full-model `side`
numbers are bounded by the locked source chassis — every weapon is a receiver,
a barrel and a feed in the same envelope — so the gate is set at the measured
separation of this pass with margin, and any future change that merges two
silhouettes trips it.

## Locality rule (non-negotiable)

Detail sits where the mechanic actually is:

* vents and heat hardware around the authored `HeatZone` (barrel assembly),
* rails and risers where the optic actually mounts (sight rail, below the bore line),
* an ejection-port treatment at the authored `Ejection` station (weapons 0, 3, 4,
  5, 7, 8, 9 — the mechanisms whose handling profile has a casing port),
* magazine / cell / drum / breech detail on the moving `Feed` group only,
* handguard detail where the hands actually hold (`GripSupport`),
* nothing in the sight corridor (the front-sight base block tops out below the
  rail; measured minimum clearance from the sight line is 154 mm), and nothing
  inside the hand capsules (measured minimum 47 mm; the exporter refuses to
  export a weapon that violates either bound),
* flank or rear-only signature hardware is allowed (round heat exchangers, the
  square capacitor comb, the flak carry handle, the SMG rear drum): those sit
  outside the `|x| < 46 mm` sight corridor, so the sight picture is untouched,
* **the reload hand travels**: a feed that hinges, drops or rotates carries the
  reload station with it, so detail near the source breech keeps the whole swept
  path clear. `godot/tests/first_person/detail.gd` re-measures this in the live
  pose; the exporter's own clearance check is rest-pose only.

## Material policy (shared)

Base palette is the source palette: `dark` `#222f37`, `light` `#73848a`, and the
per-weapon `glow` (the weapon's own `data.mjs` colour, emissive).

Two **shared materials** are added by the first-person exporter and reused by every
weapon (the third-person lane mirrors the same names/roles at its own budget):

| material | colour | role |
|---|---|---|
| `detail-trim` | `#c6ced2` machined steel | reciprocating action hardware (bolt carrier, serrations, charging knob, case guide) — the arsenal's common "moving parts are polished" signature |
| `detail-cavity` | `#0d1519` recess | recessed vents, port mouths, muzzle sleeves, shadow gaps, so detail reads at viewmodel distance |

### Per-weapon metal tones (second pass)

The two shared materials stay byte-identical on every weapon; the weapon's *own*
`dark`/`light` instances no longer are. Each weapon's tones are a mix of the
source palette toward that weapon's `data.mjs` colour, finished with a
mechanism-family surface recipe. This costs **zero** draw calls — a batch is
`(assembly × role)`, and the role set is unchanged — and it is what stops ten
grey receivers from reading as one grey gun:

| # | dark | light | finish (metalness/roughness, dark / light) |
|---|---|---|---|
| 0 | `#24393a` | `#6d9391` | 0.52/0.40 · 0.46/0.34 standard service |
| 1 | `#2d3327` | `#757f66` | 0.30/0.58 · 0.26/0.52 painted tube |
| 2 | `#2b2a3d` | `#86829c` | 0.48/0.30 · 0.58/0.24 anodised precision |
| 3 | `#333a24` | `#8f8f60` | 0.38/0.52 · 0.30/0.46 blued steel and brass |
| 4 | `#20344a` | `#6486a8` | 0.58/0.26 · 0.66/0.20 polished alloy |
| 5 | `#3a2a26` | `#7e6862` | 0.42/0.56 · 0.36/0.50 matte parkerised |
| 6 | `#24404a` | `#89adb3` | 0.34/0.36 · 0.30/0.30 passivated ice-steel |
| 7 | `#3b2f1b` | `#a87f4a` | 0.26/0.62 · 0.22/0.56 cast armour paint |
| 8 | `#3f3a2f` | `#b1a68d` | 0.55/0.26 · 0.62/0.22 lapped match finish |
| 9 | `#1c352c` | `#5b7f75` | 0.28/0.54 · 0.24/0.48 stamped and phosphated |

`verify.mjs` gates the palette: every pair of `light` tones must differ by at
least 20 (Euclidean RGB; measured minimum 25.0) and every pair of `dark` tones by
at least 9 (measured minimum 10.5), and no two weapons may share a full
(dark, light, finish) recipe. Values are explicit hex in `detail.mjs` (`TONES`,
`FINISH`) so the export stays deterministic and reviewable.

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
  goes to real detail instead.
* **Weapon 2's single barrel collar ring** generates **12 segments**: that weapon
  sits against the documented 6,500-triangle ceiling because of its locked twin
  rails and integrated optic, and the identity pass needs the 48 triangles. Shape,
  radius and position are unchanged.

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
3. Hands and grips never intersect new geometry, in the rest pose and through
   the whole live reload motion (measured minimum 47 mm).
4. Hip framing keeps the 48×48 px reticle region clear at 960×640 and 1280×800.
5. Exactly eight material batches per weapon (one surface each), and the ten
   tone/finish recipes are distinct under the palette gate above.
6. Triangles stay inside the documented band (3,000–6,000 for seven weapons;
   weapons 2 and 8 sit at 6.43k/5.94k and weapon 4 at 5.97k because their locked
   source construction already spends 5.2–6.1k — all inside the 6,500 gate).
7. Silhouette identity holds: pairwise mask IoU ≤ 0.78 (side) and ≤ 0.40
   (authored detail), with every weapon's detail covering ≥ 110 mask cells.
8. Re-export is byte-identical (`node tools/godot-weapons/verify.mjs`).
9. All first-person ADS / handling / weapon-effects / combat-integration gates
   stay green.
