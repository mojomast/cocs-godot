# Botanical test-only production lane

Source foundation: parent `32eba401155856e50e31698b41d132f6ded0a50c`, including
reviewed shared `bce5b834` and R5 `7ae3f2f5`. Exact identities and output paths are
in `godot/tests/new_maps/botanical_stage/source-manifest.json`; its null export
hashes deliberately mean **unbuilt**, not acceptance. The 150,000-triangle total
is advisory. Evaluated/source-export congruence, channels and valid geometry are
strict. Helix retains 5 modes, Parallax 6, Vesper 6; no new catalog registration.

## Source preparation/checks (no engine)

From the repository root:

```sh
python3 -B tools/godot-multiplayer/new-maps/botanical-stage/prepare_stage.py --source
python3 -B tools/godot-multiplayer/new-maps/botanical-stage/test_stage.py
node --test tools/godot-multiplayer/new-maps/botanical-stage/probes.test.mjs
python3 -B tools/godot-multiplayer/new-maps/map_variety/test_repair.py
python3 -B tools/godot-multiplayer/new-maps/map_variety/test_review_corrections.py
python3 -B tools/godot-multiplayer/new-maps/map_variety/test_kit_source.py
```

`prepare_stage.py --source` runs all three actual `asset_author.py` plan functions
and cross-checks their intended master/GLB paths. Direct plan commands:

```sh
python3 -B tools/godot-multiplayer/new-maps/helix-conservatory/asset_author.py plan
python3 -B tools/godot-multiplayer/new-maps/parallax-observatory/revisions/districts-v3/asset_author.py plan
python3 -B tools/godot-multiplayer/new-maps/vesper-viaduct/revisions/urban-v2/asset_author.py plan
```

The source handoff has 7 Python harness tests and 1 Node layer-preservation test.
GDScript parsing, actual builds, import and native reports are **pending** at this
source checkpoint. No generated UID/import cache or acceptance report is supplied.

## Presentation contract

`staged.gd` calls real WorldMap for candidate JSON physics, then removes its old
art and visible authority meshes and attaches the **complete new GLB**. This is
essential for Parallax's candidate floor union/dishes and Vesper's single slate
deck. JSON colliders remain intact. Only inherited light nodes survive old art
removal. Legacy architecture, labels, water and glass are already in the new
builder output; no second legacy full-art tree is loaded over it.

The post-export profile preserves **actual scene-used imported materials**,
retains accepted Binder panels/signs/pockets, and copies the production closed
schema with exactly the three candidate identities. Vesper has no accepted
Binder profile: its empty placement profile is explicit, with GLB clock/labels
retained. Every material filter copy is instance-owned. Negative identity/schema
cases and Off/Low/Full plus Weather restoration are native gates.

All displayed art, Binder placements and lights live under a test-only
`StagedPresentation` node. Production Weather binds that complete visual subtree;
the 27k Helix collider/shape nodes stay as WorldMap siblings. This avoids sending
physics-only nodes through Weather's 16k visual traversal cap without changing
the cap or omitting displayed surfaces. This test integration is not runtime
promotion. Parallax uses the exact static light/environment settings from its
production `presentation.gd`; hosted UI is outside this harness.

## Geometry and cameras

- `probes.mjs` retains authored Y and resolves old default nav/route Y against
  **accepted** support. Dense old/new corridors are sampled every 25 cm. Native
  radius .41 m / height 1.7 m capsules check each probe; tiny center-ray seams
  require all four 5 mm neighboring rays and are reported, not silently passed.
- `blender_proof.py` fresh-reopens the packed master, compares raw component
  world positions/faces to the same actual Kit capture, saves supported native
  cameras into that master, reopens/exports and dumps evaluated geometry.
- `verify_export.py` reads real scene-referenced GLB transforms/accessors and
  matches evaluated triangles with winding, material and multiplicity. It also
  matches **all compiled floor-union triangles**, checks component bounds and
  closed-shell volume, and compares actual GLB/source rays near solid upper
  faces, relief, roof and portal apertures. Numeric match tolerance is 0.1 mm;
  deliberate modifier envelope and visual-vs-authority rays are bounded to
  **4 cm**. Native layer-2 imported-GLB rays are checked against layer-1 JSON;
  transient visual ray shapes never enter gameplay capsule queries.
- There are 8 / 10 / 9 camera pairs. Original source coordinates are retained in
  camera lineage. Helix botanical shifts .71 m to avoid a rim, greenhouse lowers
  to actual support. Parallax new well/court has no accepted ground there, so
  those before eyes explicitly move to the old polar crosslink. Vesper roof
  height changes are labelled. Same coordinates/FOV/target are used where valid.
- Native before means accepted WorldMap art + actual accepted Binder finish;
  after means exact candidate art + staged production services. No flat palette
  replacement. These are static runtime presentation proofs, not hosted mode or
  team-actor gameplay acceptance. Inspect the actual images before handoff.

## Authorized production commands — U only

User granted `MOTH-BLENDER-20261003-U` after T's release. Finish/commit source
checks first. Start the foreground lifetime supervisor in a background tool job:

```sh
python3 -B tools/godot-multiplayer/new-maps/botanical-stage/grant.py serve
```

It acquires `/tmp/opencode/cocs-finish-acceptance.lock` **nonwaitingly** and reuses
the SHA-pinned reviewed R5 PGID/kernel-start-tick supervisor with U-local paths.
No pre-existing viewer/Xvfb process is owned or cleaned. LP_NUM_THREADS=1 and
OMP_NUM_THREADS=1 are set for every child. Exact executables:

- `/home/mojo/.tmp-on-disk/cocs-blender-toolchain/blender-4.5.14-linux-x64/blender`
- `/tmp/opencode/cocs-horde-e353522a-package/toolchain/Godot_v4.5.2-stable_linux.x86_64`

Run **one map at a time**, Helix, then Parallax, then Vesper. Replace MAP with its
exact ID (`helix-conservatory`, `parallax-observatory`, `vesper-viaduct`):

```sh
python3 -B tools/godot-multiplayer/new-maps/botanical-stage/produce.py MAP build
python3 -B tools/godot-multiplayer/new-maps/botanical-stage/produce.py MAP native
python3 -B tools/godot-multiplayer/new-maps/botanical-stage/produce.py MAP capture
python3 -B tools/godot-multiplayer/new-maps/botanical-stage/collect.py MAP
```

Build runs pinned Blender `-b -t 1 --python-exit-code 1`, then the fresh reopen
proof, then `prepare_stage.py --map MAP`. The latter refuses missing/stale
artifacts and writes readiness **last**, with actual authority/export/master/
profile/schema/script byte hashes. Build is bounded to 1800 s, reopen and import
900 s, proof/staging 180 s, native import lifecycle 120 s, physics 180 s, all
camera pairs/map 300 s. A timeout is a retained failure to characterize, not a
passing result. No full 142-test matrix. Failed engine/parser attempts stay in
timestamped supervisor logs.

Candidate paths remain those in each author plan. Native staging is exclusively
`godot/tests/new_maps/botanical_stage/artifacts/MAP/`; no accepted GLB/profile/
authority is overwritten. `archive.py MAP` archives a previous native stage;
`archive.py MAP --all-outputs` explicitly archives candidate master/export and
its reports before rebuilding. Archives are candidate-local and hash-inventoried.

`collect.py` requires all three actual native reports and every expected image,
verifies bytes, 1280×720 decoded PNGs and genuine before/after pixel differences.
Its report includes renderer/memory/static frame timings, actual measured
triangle advisory, support counts and pending hosted/manual scope. Captures and
reports are initially ignored so unfinished artifacts cannot be mistaken for
committed acceptance; force-add only reviewed candidate outputs at handoff.

Finally `grant.py release` performs three timestamped empty **owned-group**
audits, records sidecars and releases the lock. Verify nonwaiting lock availability
and record the U release receipt before handoff. Preserve all pre-existing
sidecars; only provably new, untracked, unrelated U-generated sidecars may be
removed with a before/after hash receipt. Packaging policy is not changed here;
the parent must explicitly inventory any later promotion transaction.
