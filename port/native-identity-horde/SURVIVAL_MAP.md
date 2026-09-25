# Nacre Engine — Horde survival layout

Nacre Engine is a 60 × 52 m, source-authoritative **solo Horde** map. The survivor
starts in a southern service bay, with a short-range weapon nearby. The memory
housing divides the playable floor into west and east loops. Both connect to a
northern yard: an exposed resupply area for later heavy weapons and the champion
wave. The whole circuit remains walkable; the progression is **where the player
is encouraged to fight and resupply**, not surprise collision doors appearing in
the middle of a wave.

## References and design choices

- [Treyarch's Black Ops 6 Zombies design overview](https://blog.playstation.com/2024/08/08/black-ops-6-zombies-and-the-terminus-launch-map-full-details-revealed/)
  describes round-based escalation, wall weapons, and weapon improvements from
  distinct map stations. Here, clearly marked caches give spatial progression;
  the existing Horde upgrade offer still grants run upgrades after clearing waves.
- [Gears of War: E-Day's Horde Siege overview](https://www.gearsofwar.com/en-us/news/multiplayer/)
  emphasizes defending cover, pushing through higher-risk territory, and longer
  sightlines for ranged roles. The service bay is a safe-looking first hold,
  baffles break sightlines in the wings, and the northern yard trades exposure
  for rockets, flak, and a megahealth pickup.

These are layout patterns, not transplanted economy rules: Nacre uses the
project's existing pickups, 12–15-second pickup respawns, full between-wave
resupply, 3/4/5-wave upgrade-offer cadence, and source NPC/spawn/navigation rules.
No currency, purchasable doors, or new combat systems are required.

## Plan, viewed from above (north = negative Z)

```text
                 NORTH YARD  z -20  [FLAK W9] [MEGA] [ROCKET W7]
           west breakwater      open crossing      east breakwater
    west ring x -23      +----------------+         east ring x +23
 [ARMOR] [PLASMA W3]    | MEMORY HOUSING |     [SHOCK W5] [ARMOR]
    workshop baffle     |  overhead drum |      condenser baffle
    west pocket         +----------------+         east pocket
              service-bay wing   low cover   service-bay wing
                    [HEALTH]   START    [SCATTER W1] [AMMO]
                                  z +20
```

- Team-0 starts: `(-3,20)`, `(3,20)`; team-1 approaches from seven outer
  markers on **both** flanks and the north yard. Source spawn scoring selects
  safe actual placements; no NPC teleports into a new room or into the player.
- The outer ring is continuous and has two directions of retreat. The housing
  blocks centre-line fire but not the two cross-links. Short service walls and
  waist-high bay cover give readable holds without closing enemy routes.
- The route list includes the outer circuit, an inner rotation, both supply
  wings, and the boss yard. The generated arena is shared with identity
  Deathmatch; the cache timeline runs only in the local Horde authority.

| Wave | Area / authoritative pickup | Why go there? |
| --- | --- | --- |
| 1 | South service bay: Scattergun `(3,16)`, health `(-2,19)`, ammo `(6,20)` | Learn the bay exits and control a close approach. |
| 3 | West workshop: Plasma `(-22,11)`, health `(-23,7)`, armor `(-22,-3)` | A second rotation for the artillery wave; a continuing run receives its first upgrade offer after this clear. |
| 5 | East condenser: Shock `(22,8)`, armor `(22,-3)`, health `(21,-12)` | Ranged answer for the growing heavy/mortar composition. |
| 7 | North yard: Rocket `(12,-20)` | Indirect/ranged pressure makes the exposed yard worth a deliberate dash. |
| 9 | North yard: Flak `(-12,-20)` with megahealth `(0,-20)` | Risky close-range option against the champion and reinforcements. |

Only the **five weapon** entries are wave-gated. Health, armor, ammo, and
megahealth use their ordinary source pickup behavior. At the start of each
listed wave the local authority releases the matching pickup once, with a
`horde-cache-open` event; afterwards its normal pickup cooldown applies. Before
release it is absent from the visible pickup meshes and cannot be collected.
On-map labels show the weapon, location, and live `WAVE / READY / REFILLING`
state; the Horde strip points to the next locked cache. Render-only amber floor
inlays and service-panel trim make the wings and supply stations recognizable
without inventing collision or extra lights.

## Verification boundary

The generator is `tools/godot-identity-maps/compile.mjs`; the shipped envelope
is `godot/identity_maps/generated/nacre-engine.json`. The same arena hash is
checked before constructing a source `Match`, and source team spawn pools, floor,
navigation, pickups and damage are authoritative. The identity graybox route
gate covers both loops and all three supply branches. The local authority test
advances ten real source wave transitions with **test-only accelerated kills**
to prove cache timing; it is not evidence of ten waves of natural combat.
The [rendered three-wave run](evidence/2026-09-25T04-01-12-761Z-waves/validation.json)
won naturally with 12 kills, showed the wave-3 Plasma opening and restarted
cleanly. The [startup capture](evidence/2026-09-25T03-56-36-266Z-startup/gameplay-wave1.png)
shows the service bay and first cache marker. A natural ten-wave run and owner
playtest are still needed for final late-wave balance and feel. No Extreme or
hardware-FPS claim follows from software rendering.
