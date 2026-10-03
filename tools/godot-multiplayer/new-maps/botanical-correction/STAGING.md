# Successor-native bridge — source prepared, heavy execution pending

This bridge consumes the independently approved successor authority bytes and
material bindings at parent `6e1d4b1e` (isolated source commits f358e497,
3002a9ba, da2e53eb, 4136bb4a). It does not require rejected U assets, an archive
environment variable, or a merge of U artifact ancestry. Existing source helper
imports and approved U GDScript templates are required. All three geometry,
recipe and authority-byte hashes are closed constants in `stage_config.py`;
binding hashes and U templates are pinned too. No authority is regenerated.

## Source checks — safe now

```sh
python3 -B tools/godot-multiplayer/new-maps/botanical-correction/test_stage_bridge.py
```

These tests create uniquely named **source-only** scratch attempts, then remove
only their own fixtures. They test all three source setups, exact identities,
path bounds, refusal to reuse attempts, source drift, failure before any ready
manifest on missing builds, U-template adaptation, probe coverage and bounded
command specifications. They do not run Blender, Godot, imports, renderers,
servers, supervisors or subagents. GDScript parsing remains pending.

## Two exclusive attempt namespaces

`ATTEMPT` is 3–48 lowercase letters/digits/hyphens, starting with a letter. It
must be fresh; existing attempts and symlinked paths are rejected.

- Build/master/evaluated receipts:
  `tools/godot-multiplayer/new-maps/botanical-correction/runs/ATTEMPT/MAP/`
- Generated native fixture/artifact/capture paths:
  `godot/tests/new_maps/botanical_correction/ATTEMPT/MAP/`

`source` writes source snapshots, adapted scripts and pending probes. Its
`source.json` retains null artifact hashes. There is **no ready manifest**.
Every script/dependency/source snapshot is hashed. Changing these bytes after
setup rejects the attempt. Retry with a new attempt ID; retain failed attempts
and their supervisor logs. Build/reopen/measurement receipts and native reports
are write-once. This bridge never submits jobs or acquires a heavy lock.

```sh
ATTEMPT=botanical-next-01
MAP=helix-conservatory
python3 -B tools/godot-multiplayer/new-maps/botanical-correction/stage_bridge.py source "$ATTEMPT" "$MAP"
python3 -B tools/godot-multiplayer/new-maps/botanical-correction/stage_commands.py "$ATTEMPT" "$MAP"
```

The second command prints JSON argv/environment/cwd/timeout specifications only;
it does **not** execute or queue them. Use the same attempt ID for different maps
serially, or distinct IDs. MAP is exactly helix-conservatory,
parallax-observatory or vesper-viaduct. Source fixtures may be prepared before a
grant, but none of the following heavy steps may run until explicit authorization.

## Future grant commands (NOT run)

The parent must first provide the new grant's owned PGID/start-tick supervisor.
`OWNED_RUNNER` below is that supervisor's Python entrypoint with the reviewed
`run SECONDS ARGV...` interface, **not** U's released `grant.py`. It must acquire
the shared lock nonwaitingly, set LP_NUM_THREADS=1 and OMP_NUM_THREADS=1, retain
timestamped failures and audit its Xvfb descendants. The bridge does not invent
a grant identifier or renew U. **Grant X (MOTH-BLENDER-20261003-X) is now
authorized after W's release.** Finish source checks/checkpoint before acquiring
the lock; no engine was run during bridge source preparation.

For each map, serially:

```sh
BLENDER=/home/mojo/.tmp-on-disk/cocs-blender-toolchain/blender-4.5.14-linux-x64/blender
OWNED_RUNNER=tools/godot-multiplayer/new-maps/botanical-correction/x_grant.py
GODOT=/tmp/opencode/cocs-horde-e353522a-package/toolchain/Godot_v4.5.2-stable_linux.x86_64
BRIDGE=tools/godot-multiplayer/new-maps/botanical-correction
NATIVE="res://tests/new_maps/botanical_correction/$ATTEMPT/$MAP"

python3 -B "$OWNED_RUNNER" run 1800 "$BLENDER" -b -t 1 --python-exit-code 1 --python "$BRIDGE/attempt_job.py" -- build "$ATTEMPT" "$MAP"
python3 -B "$OWNED_RUNNER" run 900 "$BLENDER" -b -t 1 --python-exit-code 1 --python "$BRIDGE/attempt_job.py" -- reopen-export "$ATTEMPT" "$MAP"
python3 -B "$OWNED_RUNNER" run 900 "$BLENDER" -b -t 1 --python-exit-code 1 --python "$BRIDGE/attempt_job.py" -- measure "$ATTEMPT" "$MAP"
python3 -B "$OWNED_RUNNER" run 180 python3 -B "$BRIDGE/stage_bridge.py" stage "$ATTEMPT" "$MAP"
python3 -B "$OWNED_RUNNER" run 900 "$GODOT" --headless --single-threaded-scene --path godot --editor --import --quit
python3 -B "$OWNED_RUNNER" run 60 python3 -B "$BRIDGE/stage_bridge.py" pin-import "$ATTEMPT" "$MAP"
python3 -B "$OWNED_RUNNER" run 900 "$GODOT" --headless --single-threaded-scene --path godot --editor --import --quit
python3 -B "$OWNED_RUNNER" run 120 "$GODOT" --headless --path godot --script "$NATIVE/import.gd" -- --map="$MAP"
python3 -B "$OWNED_RUNNER" run 180 "$GODOT" --headless --path godot --script "$NATIVE/physics.gd" -- --map="$MAP"
python3 -B "$OWNED_RUNNER" run 300 python3 -B "$BRIDGE/stage_capture.py" "$ATTEMPT" "$MAP"
python3 -B "$OWNED_RUNNER" run 180 python3 -B "$BRIDGE/stage_collect.py" "$ATTEMPT" "$MAP"
```

Actual master and export paths are redirected in memory in the new adapter,
without editing approved author/measurement/verification helpers. A build never
writes the canonical source revision's master/GLB paths or any U file. Import
requires a real Godot-generated sidecar; pinning preserves its UID and disables
geometry compression/LOD substitution exactly as U. Import can generate unrelated
project sidecars; the future supervisor must inventory pre-existing bytes and
clean only provably new owned sidecars using the reviewed release procedure.
Do not delete unrelated processes or files. End the future grant with three
empty owned-group audits, a nonwaiting lock check and an explicit release.

## Gates and coverage

`stage` requires actual build, fresh reopen and evaluated proof, invokes
`verify_future` against the attempt's real bytes, then checks embedded PBR
channels, expected materials/counts and visual-vs-authority rays. Full compiled
authority shell coverage includes all 54 retained canonical parapets; Helix's
named ten-bearing attachment graph is checked against actual measured components
matched to GLB triangles. Missing/failed proof creates no native ready manifest.
The manifest is written last from actual file hashes, never null placeholders.

- Source setup produces **32,763 / 13,587 / 20,157** points and **8 / 10 / 9**
  camera pairs for Helix / Parallax / Vesper. All old/new routes and original
  mode spawn/team/objective support points reuse approved U height policy.
- Parallax adds 1,302 full-width bidirectional aperture capsule points, 618
  bidirectional grade points and 372 full-height/full-width aperture rays.
  Native successor aperture/grade capsules are .42m radius / 1.8m height;
  other points retain U's .41m / 1.7m dimensions. Ground separation remains 5cm,
  sufficient for the approved grade's exact capsule-plane contact offset.
- Vesper adds 324 named retained-parapet boundary rays and the original failing
  ray. Helix adds 60 post rays. All maps retain U portal rays and get rays for
  every solid Kit component, including the new frame.
- Actual source/GLB/native ray comparison retains **0.1mm numeric precision**
  and **4cm maximum** visual/collision difference. The only ground-seam fallback
  remains all four diagonal 5mm neighbors, reported explicitly.
- Helix greenhouse target points at the grounded successor spring/crown while
  retaining the same supported before/after eye. Other U supported camera pairs
  and honest reposition labels are retained. X player eyes are explicitly
  **1.45m above support** in both variants, replacing U's 1.65m inspection eye.
  No route endpoints are moved.

The adapter reuses SHA-pinned U production WorldMap + Binder + Weather lifecycle,
complete imported-material preservation (Helix's 18 materials if the actual
approved complete export retains them), RGBA8 channel readback and restoration.
It removes duplicate old rendered architecture while retaining JSON colliders.
Dry Weather/static presentation scope and accepted-runtime before finish remain
explicit. Native code contains write-once receipt/image guards. Actual reports
must match the ready manifest; collection verifies all 1280×720 pairs and their
bytes and records static-backend timings, not gameplay FPS.

Hosted-mode journeys, gameplay dynamics, final manual/art review, performance
acceptance and public promotion remain pending. Original 5/6/6 mode support is
preserved. No full 142-case matrix and no 150k-triangle acceptance ceiling.
