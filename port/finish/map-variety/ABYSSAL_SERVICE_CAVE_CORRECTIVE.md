# Abyssal service-cave P1 · source-only corrective candidate

The T-grant Abyssal candidate `5fea4aada721903cea26897fb6a17befaf146c576c095dc712feebef626adfa2`
is **blocked**. Its genuine 4.5.14 Blender master, GLB, packed-image report,
reopen receipt, and Godot images remain in the frozen T producer worktree at
`port/finish/map-variety/native-T-20261003/`. They are **not** included in this
parent-based source integration and are not corrected native acceptance. Stormglass retains its
independently reviewed staged-integration status and its exact T artifacts.

## Reproduced defect and new source identity

The separate `verify_archived_service_cave.py` command reads the explicitly
provided archived 229,620-triangle T GLB, verifies **both** its own SHA-256 and
the immutable material-report SHA-256 *before parsing geometry*, and reproduces
the review's exact world-space rays:

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

## Portable tests versus pinned historical fixture

The parent-based source branch contains only the four byte-identical reviewed
coastal builder prerequisites (`build_entry.py`, `composition.py`,
`verify_master.py`, `test_preserved.py`) and `revision2-corrective/` source. It
does **not** copy any rejected Abyssal T master, GLB, report, screenshot, or
frozen native runner. The pure geometry tests run in a source-only CI checkout:

```sh
python3 -m unittest discover -s tools/map-variety-support -p 'test_*.py'
python3 -m unittest discover -s tools/godot-multiplayer/new-maps/abyssal-pressureworks/revision2-corrective -p 'test_*.py'
node --test tools/godot-multiplayer/new-maps/abyssal-pressureworks/revision2-corrective/source.test.mjs
node tools/godot-multiplayer/new-maps/abyssal-pressureworks/revision2-corrective/build.mjs --check
```

These pass **7 shared Python, 16 corrective Python, 9 corrective Node** tests,
and the deterministic `--check` without any Blender, Godot, or GLB read. The
archival P1 reproduction is a **separate, explicit** read-only invocation:

```sh
python3 tools/godot-multiplayer/new-maps/abyssal-pressureworks/revision2-corrective/verify_archived_service_cave.py --fixture-root /home/mojo/.tmp-on-disk/cocs-coastal-blender-T-20261003/port/finish/map-variety/native-T-20261003/abyssal-pressureworks
```

`COCS_ABYSSAL_T_FIXTURE_ROOT` can supply the same exact directory instead of
the flag. Missing input is an error; no fixture is searched, downloaded, or
silently skipped. The pinned historical GLB SHA-256 is
`925883eff465b7d470a36e215107420228ca8f537a08f2e3a7a879231668bfe7`;
the material-report SHA-256 is
`293a4d6b9561ef29d23274e02430d234bc6f13c686361e6ee82e2c67503e0066`.
The deliberate missing-file and wrong-GLB-hash cases also failed before any
large geometry parse. This historical reproduction is **not** native closure
for the corrected candidate.

## Next authorized heavy stage (future grant only)

1. After U's botanical heavy slot is released and a **new explicit corrective
   grant** is assigned, run the Abyssal author, outputting
   a new namespaced `native-<grant>/abyssal-pressureworks/` master, GLB, report,
   and bounded attempt receipts. Do not overwrite T outputs. The T
   `run_native.py` in frozen T history hardcodes its T path and was deliberately
   not integrated here: supply a new namespaced wrapper or invoke the author with explicit `--blend`, `--glb`,
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
