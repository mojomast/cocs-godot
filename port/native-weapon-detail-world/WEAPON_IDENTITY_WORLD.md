# World-side transcription of the weapon identity channels

Authority: `port/native-weapon-detail/WEAPON_IDENTITY.md` (first-person lane, single source of
truth). This file records how the third-person export answers each channel, so a bot's weapon reads
as the same object as the player's, and lists every place the two lanes cannot be identical
because the third-person contract differs.

Third-person budget: 1,200–2,500 triangles and at most 4 material batches per weapon. The shared
document budgets 8 batches for the viewmodel; the roles are reused, not the count.

| role | first person | third person |
|---|---|---|
| polymer | source `dark` `#222f37` | same source batch, unchanged |
| body colour | source `light` `#73848a` | source accent batch (the weapon's own `data.mjs` colour, emissive), unchanged |
| machined steel | `detail-trim` `#c6ced2` | same colour, batch `WorldDetailTrim` |
| recess | `detail-cavity` `#0d1519` | folded into the source dark batch; recesses are geometric insets |
| emissive core | per-weapon `glow` | batch `WorldDetailGlow` (`#0b1114` albedo + weapon colour, intensity 1.8) |

Every weapon uses exactly four batches: `dark`, `accent`, `detail-trim`, `glow`.

| id | receiver massing | feed identity | muzzle device | stock & grip | sight family | accent + greeble |
|---|---|---|---|---|---|---|
| 0 Pulse Rifle | source slab receiver, ribbed rail with side lips on the sight station, right-face ejection port with lip plates, stepped accent fins | box magazine: floorplate, three witness slots per face, body ribs, magazine catch | slotted flash hider tube with crown ring and side vents over a charging-handle shroud, emissive bore core | cheek riser over the source stock, sling loop and butt plate, grip floor cap, lanyard loop, trigger group | source iron sights: ear wings, hooded front post, support post from the barrel | teal emissive charge conduit on the left flank; stepped fins above the port; perforated handguard shroud with vents |
| 1 Rocket Launcher | source launch tube, top carry handle with two feet, heavy forward collar stack, flared venturi ribs | breech latch block below the tube with a sealed cell window | open tube mouth: reinforced lip ring, vertical blast deflector, accent band | shoulder rest pad, strap loop, spine strap over the tube; grip floor cap and trigger group | source iron sights (rear notch, supported front post) plus a canted launcher leaf ladder on the left flank | orange chevrons on the left wall; emissive venturi dot ring on the rear face |
| 2 Rail Lance | source slab receiver between twin accelerator rails, rail coil bars, capacitor cell | energy cell: housing, emissive violet charge window, retaining clips, cell ribs | twin accelerator rings with standoff prongs and a bridged muzzle brake | slim stock with cheek piece, counterweight and butt pad; grip floor cap | source scope: open tube, ringed objective and ocular, mount posts, elevation and windage turrets | violet emissive coil dots down the left rail; accent stripe on the right; coil rings at the muzzle |
| 3 Scattergun | source wide breech block, top rib over twin bores, breech extractor below | break-action extractor plate, right-side shell carrier with three spare rims | twin bores with muzzle clamp band, per-bore choke rings and side lugs | wide stock with recoil pad, shell loops on the left, comb block | source iron sights plus a brass bead on the top rib | amber shell rims and carrier; emissive chamber witness ring |
| 4 Plasma Driver | source rounded vented chamber, cradle side plates, power pack | energy cell: twin cell tubes, emissive plasma window, heavy latch | flared focus cone with three standoff prongs, crown ring and a glowing core | vented frame stock (two side rails per flank), heat-shield plate, butt plate; grip fins | source iron sights with a heat shroud around the front post base | blue emissive chamber window and barrel strip; ribbed heat-sink rings |
| 5 Grenade Launcher | source revolver frame with a top strap, quadrant arc on the left flank | revolver drum: six flutes proud of the drum, front and rear hub caps, index marks, charge window | heaved bored muzzle with two collars, lateral ports and a front tube | compact stock with recoil pad, thumb rest, butt plate; trigger group moved behind the drum | source iron sights with a ladder leaf and the left-flank quadrant arc | red-orange emissive drum index window; angled drum flutes |
| 6 Shock Beam | source casing with a capacitor bank and a capacitor drum above the receiver | energy cell: capacitor plates, cell housing, vent slats | twin fork prongs with discharge blocks and a tuning bridge | open frame stock, stock capacitor block, insulated cheek plate | source iron sights on a short rail | cyan emissive arc bar between the prongs, barrel strip and discharge tips; insulator rings and exposed coil discs |
| 7 Flak Cannon | source heavy breech, top carry handle, trunnion block on the right | ammunition box: lid, hinges, latch, belt window with three visible rounds | heavy muzzle with two heat-sink collars, four radial ribs, top and bottom brake ribs, side plates | heavy stock with recoil pad, twin recoil springs, shell loops, butt pad | source iron sights on the heavy rail plus a side range drum below the sight line | amber belt rounds and chevrons; emissive arming indicator |
| 8 Marksman Rifle | source slim receiver, long rail, bolt handle and range dial on the right | low-profile box magazine: floorplate, witness slots, funnel catch | three-baffle precision brake with a tapered muzzle tube | chassis stock: cheek riser, butt pad, rear monopod stub, sling slot | source scope on the long rail with objective and ocular rings, mount posts, elevation and windage turrets | warm-sand trim; emissive optic lens and heat band behind the brake; ribbed barrel ferrules and bipod stubs |
| 9 Submachine Gun | source stamped receiver with rib pattern, reciprocating charging handle and ejector port, flared magwell | box magazine: stamped ribs, witness slots, floorplate, magazine catch | compact ported compensator with a thread collar over a vented shroud | telescoping twin-rod stock with rod collars and butt plate, light trigger housing, foregrip | source iron sights on a stamped rib plus a rear drum | mint emissive charging handle and chamber port witness; light module under the barrel |

## Reconciliation notes

1. **Sight families** are taken from the source chassis (`attachScope` for 2 and 8, iron for the
   rest), which is what the first-person viewmodel builds from: identical family, world-size
   proportions.
2. **Optic turrets** were added to 2 and 8 to match the shared document's "elevation/windage
   turrets"; the third-person scope otherwise mirrors the source `attachScope` dimensions
   (tube 0.30 m, radius 0.039, objective bell, mount posts, base plate).
3. **Left-flank launcher furniture** (canted leaf ladder on 1, quadrant arc on 5) and the
   **carry handle on 7** exist in the world kit because the shared document names them; they sit
   above or beside the source envelopes and clear the palm.
4. **Emissive elements** are present on all ten weapons, so all ten use the `glow` batch. The
   third-person kit therefore lands exactly at the four-batch ceiling for every weapon.
5. **Rocket launcher foregrip**: the shared document gives weapon 1 a vertical foregrip in its
   stock/grip channel. In the third-person rig the left hand's contact is the receiver's left face
   at `z = -0.48 × receiver length` (the same chassis-derived contact the source `alignLivingCharacter`
   fallback uses), and the palm sits flush against that face; a protruding foregrip would intersect
   it (the hand/detail triangle audit in `evidence/verify.json` is a hard gate). The world model
   therefore answers the channel with the flush handguard plus the shoulder rest and strap loop and
   records the difference here rather than trading correctness for detail.
6. **Hands**: both lanes must never intersect new geometry. The third-person audit is exact, not
   sampled: the source post-pose pass pins each grip anchor to `WeaponGripLeft/Right` with the hand
   basis equal to the weapon basis, so the hand mesh occupies `anchor + (p - gripLocal)` in weapon
   space for every one of the 450 fixture cases (all nine operators share one hand geometry, which
   the verifier re-checks before relying on it). Result: 0 contacts, nearest approach 9.5e-6 m.
