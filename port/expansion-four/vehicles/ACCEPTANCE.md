# Acceptance — source checkpoint, 2026-10-02

**READY FOR BLENDER. No heavy execution has occurred.** Parallax still owns the
slot. Native GDScript parsing, import, rendering and asset quality are unverified.

## Actual checks

- Node: **66/66 passed**, zero failures. Ten new asset-source oracles plus 56
  existing vehicle/gameplay/seat/ram regressions.
- Python: `ast.parse` passed for `tools/godot-vehicle-assets/build.py`; `bpy` was
  neither imported nor executed.
- Nine deterministic JSON authoring recipes were written under ignored
  `tools/godot-vehicle-assets/generated/`. These are not generated art assets.
- Current procedural fallback retains its code and has source guard checks;
  **native fallback execution is pending**, not claimed by the Node test.

| Recipe | LOD0 parts / triangles | LOD1 triangles | LOD2 triangles |
|---|---:|---:|---:|
| Puma | 223 / 15,576 | 7,064 | 1,908 |
| Titan | 436 / 26,440 | 13,032 | 3,272 |
| Scout | 207 / 14,588 | 6,364 | 1,704 |

Counts precede Blender modifiers. No material, draw-call, frame-time, GLB-size,
native capture cadence or GPU measurement is claimed.

Evidence directory:
`/home/mojo/.tmp-on-disk/cocs-expansion-four-vehicles-evidence-20261002/`

- `source-first-failure.log`: preserved failures (two-coordinate chassis panels,
  excessive hub protrusion, unnecessary Titan tread recipe cost). Coordinates
  now reject malformed vectors immediately; hubs fit existing tire width;
  Titan uses authored track shoes rather than redundant road-wheel tread studs.
- `source-accepted.log`: accepted 66-test run and per-LOD bounds/counts.

## Reproduce source checks (no slot needed)

```sh
node --test godot/tests/vehicle_assets/source.test.mjs game/vehicles.test.mjs game/vehicle-seats.test.mjs game/vehicle-ram.test.mjs game/vehicle-gameplay.test.mjs
python3 -c "import ast,pathlib; ast.parse(pathlib.Path('tools/godot-vehicle-assets/build.py').read_text()); print('PASS Python AST')"
node tools/godot-vehicle-assets/write-recipes.mjs
```

## After an explicit slot grant — sequential commands

First execute the missing-assets fixture before generation (shared hooks applied):

```sh
LP_NUM_THREADS=1 /home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 --headless --path godot --script res://tests/vehicle_assets/native.gd
```

Then generate, reopen and inspect each editable master. Build command:

```sh
LP_NUM_THREADS=1 /home/mojo/.tmp-on-disk/cocs-blender-toolchain/blender-4.5.14-linux-x64/blender --background --threads 1 --python tools/godot-vehicle-assets/build.py -- "$PWD"
```

Masters/reports: `tools/godot-vehicle-assets/masters/`. Art exports:
`godot/vehicle_assets/generated/`. Check tool existence before using the commands.
Preserve failures, reopen each master, verify mesh normals/finite data, material
names and source marker dimensions; hash exports and record Blender version.

```sh
LP_NUM_THREADS=1 /home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 --headless --path godot --editor --import
LP_NUM_THREADS=1 /home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 --headless --path godot --script res://tests/vehicle_assets/native.gd -- --require-assets
```

Prepared native fixture checks rigid LOD installation, finite imported geometry,
actual transform composition at hull bend, procedural fallback, team channels
and the existing weather clone/restore path. It is not a hosted input journey.

## Required graphical/connected completion gates

1. Inspect chassis/cage/seat clearances, wheel arches, track ends, turret loader
   and barrel bores at close eye level, plus 24/65 m LOD boundaries. Revise art
   based on actual images; triangle counts are not acceptance.
2. Connect to real source authority. For all three real identities: mount,
   source-wire drive/reverse/bend/boost, turn turret/fire from each legal seat,
   passenger use/dismount, repair, destruction and source respawn. Confirm no
   camera/chase/carrier-stow changes and signed wheel roll/reduced motion.
3. At source positions compare actual barrel mouths, source muzzle traces, crew
   feet, contact circle and yaw OBB cover rays. Review correction of the offset
   turret mount, Scout's inherited 1 cm sidewall discrepancy and tilted cage
   clearance explicitly. Do not label open cage spaces bullet openings.
4. Rain/wetness on/off, team changes while wet, round/reconnect cleanup and 64
   vehicle stress. Measure actual surfaces, materials, shadows, GLB size and LOD
   budgets; inspect repaired/wreck events at their existing source positions.
5. Capture actual native clips and screenshots at 1280×800 and 760×520/UI150.
   Record captured cadence and distinguish controlled setup from ordinary source
   input. No staged repair/wreck image is proof of a connected source event.

Parent owns shared-hook review, package/catalog closure, canonical regression,
final build and publication. No final registration was edited in this lane.
