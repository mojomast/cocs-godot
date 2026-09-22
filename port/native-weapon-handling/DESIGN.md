# Weapon handling design

Presentation-only. No damage, spread, recoil or ammo authority is read or
written; every channel is either local cosmetic state or a pure function of the
source snapshot (`reloading`, `reloadTimer`, `reloadDuration`, the local shot
event stream, focus/lifecycle gates already enforced by `rig.gd`).

## Where the values come from

`tools/godot-weapons/handling.mjs` is the single authored table. It is written
against the same source data the exported GLBs come from:

- `game/weapon-models/chassis.mjs` authors, for every weapon, one `bolt` group
  (carrier + charging paddle, x = w/2 + .013 / .032, z = -len*.45 / -.38), one
  `feed` group (box magazine, drum, cell or breech latch) and one barrel group
  (`barrel-assembly`, `shock-emitter`, `flak-barrel`).
- `game/model-geometry.mjs` / `game/data.mjs` `feel.kick[2]` is the source
  recovery rate; the carrier interval is `min(0.12, 0.88 / kick[2])` so automatic
  weapons cycle visibly faster than heavy ones.
- `CHASSIS[id]` gives width/height/length/barrel radius, from which the ejection
  port (right receiver wall), feed station (magazine/cell/drum/latch centre) and
  heat station (lower barrel surface, 30% back from the muzzle) are derived.

Anchors are exported by the existing `anchor(name, weaponPosition, owner)`
helper, so they are rebased into the *actual moving assembly* object the merger
produced. `manifest.json`/`catalog.gd` gain an `anchors` entry per station plus a
`handling` profile (mechanism, cycle, stroke, charge, reload, heat, eject).

## Anchor map

| anchor | parent assembly | purpose |
|---|---|---|
| `Bolt` | `bolt` group | carrier station; travels with every cycle |
| `Charging` | `bolt` group | charging paddle station (same rigid group) |
| `Ejection` | receiver (`weapon`) | casing port consumed by `weapon_effects/controller.gd` |
| `Magazine` / `Cell` / `Drum` / `Feed` | `feed` group | feed-body station, distinct from the `GripReload` hand contact |
| `HeatZone` | barrel group | barrel heat/haze/smoke origin, below the sight line |

## Channels

**Carrier cycle.** `handling.fire()` starts a cycle; `advance()` moves the `bolt`
group `+Z` (toward the stock) by the authored `stroke`, shaped `smoothstep` out
over 32% of the cycle and eased back over the remaining 68%. The travel is
capped at the authored stroke and the group returns to the exact imported rest
`Transform3D`. The cycle cannot stack: a new shot restarts the single in-flight
cycle, which is shorter than the weapon's own source interval.

**Charging handle.** The source authors the paddle on the same rigid group, so
the channel shares the stroke but not the timing: `fire()` starts a slow
pull-hold-release (0.28 s) only when more than `max(0.35, 4 * cycle)` seconds
have passed since the previous shot. During an authoritative reload the handle
racks inside progress 0.60-0.96 (after the fresh magazine is seated).

**Feed handling.** The `feed` group motion is a pure function of
`reload_progress` (`1 - reloadTimer / reloadDuration`) and the `reloading` flag:
out over 0.05-0.36, seated over 0.58-0.86 with a damped dip past rest as the
magazine locks in. At progress 0.0 and 1.0 the curve is exactly zero, and with
`reloading == false` the group is written back to its rest transform, so the
animation can never lead or lag the authoritative window. The break-action
Scattergun additionally hinges its `barrel-assembly` group by 0.30 rad at
mid-window (its feed body does not translate).

**Heat.** Each accepted local shot adds `gain` heat up to the cap; heat decays
at `cool` per second when idle. Heat drives:

- a barrel emissive glow (`energy = level^2 * 0.9`, weapon tint) on the barrel
  group's per-rig duplicated materials only, disabled again at rest;
- a heat-haze quad at `HeatZone` (alpha `0.16 * level`) and a pool of three
  smoke puffs (0.4 s life, rising at most ~16 mm, alpha `0.26 * level`), emitted
  while `level > 0.22` at 0.14-0.055 s intervals.

The whole micro-effect scales by `clamp(1 - aim_weight / 0.55, 0, 1)` and is
zero from 55% ADS onwards, so the settled sight picture is byte-identical to the
cold one (asserted: `haze_alpha == puff_alpha == 0` and an open target gap with
zero opaque pixels). In hip the quad sizes are bounded (`billboard_keep_scale`
is required, otherwise a 1 m card renders) and the authored station plus plume
budget clears the reticle corridor at the live FOV for all ten weapons.

**Lifecycle.** `handling.clear()` is called from `rig._clear_motion()`, which
runs on weapon switch, eligibility loss (death, spectator, vehicle), stale
snapshot/focus-loss gates, and `reset()` on results/round restart/disconnect. It
reseats the carrier, feed and barrel, zeroes heat, hides the haze and retires
every puff. The FX nodes live under one `WeaponHandlingFx` root inside the
isolated viewport, are created once per rig and never allocated while running
(four `MeshInstance3D` nodes total).

## Why this cannot touch authority

`rig.gd` remains a consumer of snapshots/events; the new code only writes local
node transforms, local material emission and local quad alpha. It reads
`reloading`, `reload_progress`, `aim_weight` and the accepted-shot gate that
already existed for recoil, and adds no new authority reads or writes. Recoil,
spread, ammo and damage are untouched; `godot/tests/first_person/lifecycle.gd`,
`ads_contract.gd`, `ads.gd`, `framing.gd` and the other lane's
`weapon_effects/rig_integration.gd` and `combat_integration` contracts stay green.
