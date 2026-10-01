# Horde expansion intake contract (branch `expansion/horde-robots`)

## Route registration for integrator

- New map ID: `blackwater-reclamation`, mode `horde`, display name **Blackwater Reclamation**.
- Client scene: `res://horde_maps/blackwater_demo.tscn` with mandatory
  `--map=blackwater-reclamation --endpoint=ws://127.0.0.1:PORT --waves=1..30`.
- Native local authority: `port/native-horde/authority.mjs`, `HORDE_MAPS` now
  allowlists the ID. It loads only `godot/horde_maps/generated/blackwater-reclamation.json`
  and returns `hordeMapContract:{version:1,geometryHash,planHash}`. Client refuses
  mismatched geometry/plan hashes on each snapshot.
- Package closure additions: `port/native-horde/robot-roles.mjs`,
  `port/native-horde/blackwater-schema.mjs`, `port/native-horde/blackwater-director.mjs`,
  `godot/horde/ground_tells.gd`,
  `godot/horde_maps/blackwater_catalog.gd`, `blackwater.gd`,
  `blackwater_demo.gd`, `blackwater_demo.tscn`, generated JSON and
  `godot/horde_maps/art/blackwater-reclamation.glb`.
  Include editable Blender master `tools/godot-horde/masters/blackwater-reclamation.blend`
  and `blackwater_blender.py`, `blackwater.py`, `check_assets.py` under `tools/godot-horde/` in source
  distribution. Integrator owns shared launchers, package manifests, map menus
  and route discovery; no shared files are modified in this branch.

## Gameplay and provenance

The existing three source Horde maps, Nacre Engine and Cinderwake share the
same Horde demo factory: only snapshot NPCs with `isNpc===true` and a mapped
`npcType` receive one of the six campaign Blender robots. `npcType`, roles,
attacks, telegraphs, source hit geometry, upgrades, score, death events and
input protocol remain source-owned. Operators remain source operator visuals.
The Horde-only adapter adds `npcModel` on **outgoing snapshots and results**;
it does not mutate source modules. Its source `Match` subclass uses the existing
`hitScale` field for NPC chassis-sized hits (players remain at source hitScale
1), and on bounded wave ten uses source `spawnGroup` to field exactly one Warden
with genuine AI, attack phases, health, damage and death IDs. Existing
Harbinger champion timing is unchanged. The final easy live count is 13: the
source cap of 12 plus the one authored boss.

Blackwater uses the existing frozen-source `hordeArena` constructor intake and
Horde stage gates. Authored bounds are 440 × 380 source units. The server-side
director adds north/south feeder arming, a repair hold, and a relief valve;
progress, objective dependency, cache opening and notices are included in each
snapshot. Pump and valve completion call the source's real `resupplyHorde` for
health/armor/ammo and run-upgrade reapplication. Horde wave 3 and 6 transit
gates are still wholly source-driven.
This local Horde transport supports one human seat; no coop claim or simulated
team contribution is made. Standard maps remain wave-survival without story
objectives.

## Pending engine verification after explicit parent resource grant

The generator and JS-only contracts can run without Blender/Godot:
`python3 tools/godot-horde/blackwater.py` then
`python3 tools/godot-horde/check_assets.py` and
`node --test port/native-horde/blackwater.test.mjs port/native-horde/robot-roles.test.mjs port/native-horde/robot-authority.test.mjs`.
Asset counts: five batched Blender materials/meshes, 13,548 triangles,
616,176-byte GLB, 1,035,139-byte editable master; source recipe owns 213
collision blocks, 30 walkable surfaces, and 184 focused navigation hints. All
three stage anchor pools and four interaction stations are source-graph reachable
under closed, first-open and both-open floodgate masks. Real Match authority
steps cover the objective chain under a **controlled intermission fixture**;
this is not proof of natural combat completion.
The scene, all-Horde live NPC visual census, natural-play objective route,
all mission beats, late join/restart, screenshots and gameplay clip require the
reserved export/import/render slot. Do not treat static tests as live evidence.
