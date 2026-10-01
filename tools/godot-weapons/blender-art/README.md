# Native weapon art · reviewed Blender layer

Ten mechanically distinct player weapons, modeled as editable Blender 4.5
hard-surface masters (`masters/weapon-0.blend` … `weapon-9.blend`), with matching
low-poly world masters. `export.py` produces `godot/first_person/art/weapon-N.glb`
and `world-N.glb` from the **read-only** source-export anchor catalog. The
canonical `generated/` first-person and world exports remain byte-for-byte
unchanged. `art_adapter.gd` mounts this explicitly reviewed override on their
original assembly hierarchy: source sight/muzzle/grip/heat/ejection stations and
magazine/bolt/barrel pivot animation retain their original transforms. Neither
gameplay metadata nor ammo, weapon IDs, projectiles, handling values or FOV is
modified. No hand rig is replaced.

| ID | Weapon | Recognizable authored assembly |
|---:|---|---|
| 0 | Pulse Rifle | floating vented handguard, open collars, skeleton stock |
| 1 | Rocket Launcher | massive circular launch tube, side-loading canister, exhaust rings |
| 2 | Rail Lance | parallel accelerator rails, exposed center channel, optic |
| 3 | Scattergun | separate twin bores on moving barrel pivot, break-action receiver |
| 4 | Plasma Driver | opposed ceramic radiator blades, reactor and energy aperture |
| 5 | Grenade Launcher | shell-width muzzle, cylinder drum, squared shoulder stock |
| 6 | Shock Beam | twin long capacitor prongs around recessed shock emitter |
| 7 | Flak Cannon | broad armour hood, heat-port array and heavy barrel |
| 8 | Marksman Rifle | pencil barrel, triangulated stock, hollow optical tube |
| 9 | Submachine Gun | compact action, vertical foregrip, folding side stock |

The camera-facing breech/stock cap is also class-specific, so mechanical
identity reads in the actual hip-fire framing as well as at world-model angles.

Palette roles `dark`, `light`, `glow` retain native finish bindings in both
first-person and on remote operators. `trim`,
`cavity`, `rubber`, `ceramic` remain stable functional contrast. Smooth machined
edges are modeled (two bevel segments); the world LOD omits bevels and reduces
round cross-sections. One native batch per moving assembly and material role.

Rebuild (one Blender thread):

```sh
LP_NUM_THREADS=1 blender -b -t 1 --python tools/godot-weapons/blender-art/export.py
python3 tools/godot-weapons/blender-art/verify.py
```

The static audit reads actual GLB vertex positions and projected silhouettes,
checks both canonical SHA-256 manifests, material slots, group topology, Blender
masters and triangle/batch budgets. Across all ten: first-person **3,284–6,268**
triangles and **8–12** batches each; world **508–1,028** triangles and **8–12**
batches each. Largest actual vertex-profile IoU is **0.382** side and **0.329**
top. `godot/tests/first_person/art_override.gd` checks the live adapter,
moving feed, source anchors and separate first-person/world layers.

Native checks (Godot 4.5.2): reviewed art integration (10/10), original source
detail, lifecycle, finishes, handling, muzzle geometry, ADS and source-world
grips/weapons; rendered framing has a clear central 48×48px area at both
960×640 and 1280×800, rendered ADS has 910 checks, and handling captures have
482 checks. Matched baseline/override normal, ADS and world screenshots for all
ten IDs plus an engine-animated switch/reload/recoil clip:
`/home/mojo/.tmp-on-disk/cocs-campaign-evidence-20260930/blender-weapons/`.
