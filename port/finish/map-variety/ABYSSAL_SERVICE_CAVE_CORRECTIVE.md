# Abyssal service-cave P1 · source-only corrective candidate

## Current disposition — V successor staged-integrated

Independent review approved V successor `b010a076…9ee3aa86` and closed the
demonstrated T interior terrace-contact mismatch. Complete delivery `03b3db50`
is integrated as **`873ad2ac`**. This does not approve the earlier `ee979520…`
attempts. Full qualified review: `ABYSSAL_V_REVIEW.md`. The historical source-only
checkpoints below remain a record of the preceding stages.

**Parent integration:** `a8b3fe6b`, comprising four reviewed source prerequisites,
the corrected authority/art sources and explicit archive verification. Parent
reproduced 33 source/shipping checks, both old/corrective authority checks and the
three historical T contact rays. No corrective native build or P1 artifact closure
is claimed; botanical U retains sole heavy ownership at this checkpoint.

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

## V grant corrective-native harness (new, separate from the frozen T source stage)

The parent-based V branch adds `revision2-corrective/native_harness.py`,
`reexport_master.py`, `audit_corrective.py`, source guard tests, and the
test-only `godot/tests/new_maps/abyssal_pressureworks/corrective/world_check.gd`.
Under **MOTH-BLENDER-20261003-V**, the actual command is:

```sh
LP_NUM_THREADS=1 OMP_NUM_THREADS=1 python3 tools/godot-multiplayer/new-maps/abyssal-pressureworks/revision2-corrective/native_harness.py \
  --grant MOTH-BLENDER-20261003-V \
  --output-root /tmp/opencode/abyssal-corrective-V-20261003-attempt-1 \
  --blender /home/mojo/.tmp-on-disk/cocs-blender-toolchain/blender-4.5.14-linux-x64/blender \
  --godot /home/mojo/.tmp-on-disk/opencode/cocs-graphics-windows-final/toolchain/Godot_v4.5.2-stable_linux.x86_64 run
```

The new directory must not exist beforehand. A failed attempt keeps its
`inputs.json`, ordered logs and receipts; a repair gets a new attempt root.
The exclusive shared lock is nonwaiting; each child uses its own bounded
session group with kernel start ticks and three empty owned-group audits.
Builder verifies immutable color, normal and roughness pixels; the saved master
is reopened, then exported again and compared across **all** triangles, named
surfaces and decoded PBR pixels. The standalone full-scene embedded GLB validator
enforces the 64-primitive bound, actual index count and declared POSITION bounds;
150k triangles is advisory. The staged Godot project is a **copy** within the
attempt root and hashes the exact corrective JSON and new GLB. Its Binder uses
a candidate-only copy-local identity/profile preserving the imported PBR
materials. WeatherService exists in the parent but is excluded from this isolated
stage; its project does not install the production autoload configuration. The
baseline has no eligible Abyssal Binder profile. This is not production-weather
acceptance.
Actual visual capture, outside-wall traversal, hosted modes and final finish
remain explicit review gates until their own measured evidence is recorded.

### V native-discovered route endpoint successor

The V grant did build and independently reexport the original corrective
`ee979520…` source as an immutable historical V attempt, then native testing of
all 501 source nav points found the last southwest service-loop sample at
`(-76, 6, -96)` **on** its preserved east retaining wall. The original
`revision2-corrective/` source and V attempts remain as failure receipts.
`revision2-corrective-v/` is a new candidate identity
`b010a0764e3754b9d1e6ff3839e7c319d871336cf5b242a36cd512dd9ee3aa86`:
the route endpoint moves to `(-77.5, -96)`, 1.5 m inside that wall, preserving
every floor, wall, block, spawn, objective and art class; six interpolated nav
points move with it, leaving the nav count at 501. The source tests assert
that bounded diff. **Old V native art cannot certify this new identity**; a
fresh namespaced master/GLB and stage are required, even if exported triangles
later happen to match.

### V grant result and review scope

The successor was built **fresh**, under the exclusive V grant, to
`/tmp/opencode/abyssal-corrective-v2-V-20261003-attempt-1` and selectively
packaged at `native-V-20261003/abyssal-pressureworks/` for parent review.
The master SHA-256 is `16e244942c84c810802fa56ec37efca5b39b95f2872d373175d68cc94e48d93f`;
the GLB SHA-256 is `770c8622f6e9dc401fb6dc5cce4225efc5b930c1a88f29f9f0c324170db07f87`.
The saved master reopened with **30 packed images** and independently exported
a **byte-identical** GLB: **47** scene-backed primitives, **229,620** indexed
triangles, 12 labels, no global hard triangle cap. Export report verifies
immutable color, normal and roughness pixels and separately authored preserves.
Actual GLB/source normals agree at all fourteen cave solids.

Native `WorldMap` imported the exact new authority/GLB pair with **no art-owned
physics**, passed the three historical P1 ray spans, **78** wall jump/body-band
contacts, **four** clear wall-end crossings and **518** body-clearance samples.
Nine ramp-adjacent samples used only a measured **0.15 m** lift; all others
cleared at authored height. Eight paired camera views produced **16** original
1280×720 PNGs with hash and backend receipts. The rendered stage uses the
production Binder with a **copy-local candidate preserve-PBR profile** and
`abyssal_presentation.gd`. WeatherService exists in the parent but is excluded
from this isolated stage, and the baseline has no eligible Abyssal Binder profile.
These are neutral stage captures, not
production-weather approval. See the review gallery and `evidence-hashes.json`
under the V artifact folder. Old `ee979520…` V attempts 1–5 retain their logs,
receipts and failure reports there without copying their rejected master/GLB
into this selective parent artifact set.

Native **P1 inside playable wall/floor contact closure** is supported by the
new actual GLB + imported-physics probes. Exterior fall/special traversal,
swept chase camera, hosted journeys and all six final mode outcomes remain
separate acceptance gates. Parent retains promotion and package inventory.
Grant V was explicitly released after a nonwaiting lock check and three
timestamped audits with no surviving V-owned process groups; see
`grant-release.json`. No heavy process is queued.
