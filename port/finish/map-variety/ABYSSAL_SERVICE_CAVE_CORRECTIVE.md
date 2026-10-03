# Abyssal service-cave P1 · source-only corrective candidate

The T-grant Abyssal candidate `5fea4aada721903cea26897fb6a17befaf146c576c095dc712feebef626adfa2`
is **blocked**. Its genuine 4.5.14 Blender master, GLB, packed-image report,
reopen receipt, and Godot images in `native-T-20261003/` remain immutable
historical evidence, not corrected native acceptance. Stormglass retains its
independently reviewed staged-integration status and its exact T artifacts.

## Reproduced defect and new source identity

`test_service_cave_contacts.py` reads the archived 229,620-triangle T GLB,
verifies its report SHA-256, and reproduces the review's exact world-space rays:

| Segment | Historical GLB | Historical authority |
|---|---|---|
| `(-106,7.2,-97) → (-106,7.2,-100)` | two SW fin faces at `z=-98.35/-98.65` | no barrier |
| `(-94,10,-98.5) → (-94,5,-98.5)` | SW ledge `y=8.6/8.2`, then floor `y=6` | floor `y=6` only |
| `(91,4,-92.5) → (91,-1,-92.5)` | SE ledge `y=2.6/2.2`, then floor `y=0` | floor `y=0` only |

The corrected source lives in **`revision2-corrective/`**, leaving the original
`revision2/` candidate JSON and its T hash untouched. Its new geometry hash is
`ee979520743dd4c73ac0d825774a2c99b5a8d85800a6eead5170f261abe61bea`.
The corrective directory's generated `arena.json`, `candidate.json`, and
`probes.json` correspond only to that identity; the old GLB/master/captures
cannot be paired with it as native evidence.

`revision2-corrective/service_cave.json` is the common authority/art descriptor. The two
real solid ledges and all twelve capped, outward-wound fins remain, but sit on
the **exterior** sides of the SW south and SE east retaining walls. The SW
south wall now spans the entire 36 m deck edge rather than leaving its western
half open. No floor, box, or blocker was added across either observation bay or
the SE pocket ramp. Top ledge caps remain visible just above the retaining
wall; fins attach beneath them on the exterior. No stacked walkable floor was
introduced under the runtime's highest-floor query.

The pure-geometry source check compares each of the fourteen complete solid
footprints against **every upward walkable authority triangle**, with a
0.52 m capsule radius plus bevel and margin. The nearest distances are 0.90 m
(SW ledge), 1.15 m (all fins), and 1.20 m (SE ledge). It verifies full wall
coverage, old-ray absence in new cave art, authority floor hits, and face caps.
The runtime-source checks retain a connected 501-node nav graph, all six
registered modes' anchors, single-height deck semantics, and finite-radius
clearance along both terraces, the utility ramp, all spawns/team flags, and
objectives. Stormglass source remains byte-identical to the T integration.

## Next authorized heavy stage (future grant only)

1. Run the Abyssal author under a **new** exclusive Blender grant, outputting
   a new namespaced `native-<grant>/abyssal-pressureworks/` master, GLB, report,
   and bounded attempt receipts. Do not overwrite T outputs. The T
   `run_native.py` currently hardcodes its T path: supply new paths via its
   versioned successor or invoke the author with explicit `--blend`, `--glb`,
   `--report` arguments under the shared nonwaiting lock and bounded PGID.
2. Reopen that exact new `.blend`; prove packed images, source/derived pixel
   lineage (sRGB colour, linear normals, ORM green roughness), primitive/triangle
   accounting, and all signs. Do **not** claim master-to-GLB reproducibility
   from a reopen that only checks file identity and packed images.
3. Import the exact new GLB with the **new** candidate JSON in an isolated
   Godot stage with a hash-matched test-only profile. Raycast actual imported
   world-space ledge top/underside and fin front/back against its authoritative
   colliders and shield wall. Prove both historic P1 rays are now free where
   the player can stand, plus finite-radius sweeps, spawns/objectives, and
   representative hosted mode outcomes. Capture genuine paired images at
   player/overview positions and inspect aesthetics; retain any failed attempts.
4. Parent reviews native evidence and performs any promotion. The T evidence
   remains a frozen historical record of the rejected candidate.

Suggested **future-grant commands**, run serially only after acquiring the
shared nonwaiting acceptance lock inside an owned bounded process-group
supervisor (the T `run_native.py` defaults to frozen T paths and is unsuitable
without a versioned output override). Substitute the new grant name and repo
absolute path, then preserve each failed attempt in its own output directory:

```sh
BLENDER=/home/mojo/.tmp-on-disk/cocs-blender-toolchain/blender-4.5.14-linux-x64/blender
ROOT=/absolute/path/to/the/corrective-worktree
OUT="$ROOT/port/finish/map-variety/native-NEW-GRANT/abyssal-pressureworks/attempt-1"
mkdir -p "$OUT"
"$BLENDER" -b -t 1 --python-exit-code 1 --python "$ROOT/tools/godot-multiplayer/new-maps/abyssal-pressureworks/revision2-corrective/author.py" -- --root "$ROOT" --blend "$OUT/abyssal-pressureworks-corrective.blend" --glb "$OUT/abyssal-pressureworks-corrective.glb" --report "$OUT/material-report.json"
"$BLENDER" -b -t 1 --python-exit-code 1 --python "$ROOT/tools/map-variety-support/verify_master.py" -- --blend "$OUT/abyssal-pressureworks-corrective.blend" --report "$OUT/material-report.json"
```

These are recipe commands, **not** evidence of execution, and require a
future grant's timeout, PGID/start-tick receipts, log SHA-256, and isolated
Godot staged candidate-import/capture step. Never place the corrected GLB in
the accepted art basename or reuse an old T report/hash for it.

No Blender, Godot, importer, renderer, server, or native capture ran during
this corrective source stage.
