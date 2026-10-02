# Interiors v2 — READY FOR BOUNDED VISUAL PASS

**Production follow-up completed under grant C:** actual build, fresh master
reopen/re-export, native collision, Full/Off images and hosted-input evidence are
recorded in `port/new-maps/parallax-observatory/production-c.json` and
`PRODUCTION-C.md`. The revised master is committed under `output/` and the runtime
GLB is promoted. Original source-check and candidate identity below remain the
historical source-only record; these initial grant instructions are superseded by
the production ledger. Parent chooses final visual/package acceptance.

**Source-only candidate. No Blender, Godot, import, render or encoding job has
been run for this revision. Helix holds the heavy slot.** Accepted checkpoint
`9a6372b4` + `277f379e`, its master/GLB, source geometry and evidence are untouched.

## Bounded visual change

The parent identified the archive and pump room as essentially the same long
box/panel-grid interior. This candidate changes their internal equipment anatomy,
not the map routes, polar hall, exterior massing, palette or gameplay rules.

- **Plate archive:** one wall has seven full-height, two-tier storage racks with
  84 individual plate cassettes, exposed spines and index tabs. The opposite wall
  has three wide retrieval machines: vertical guides, moving crossheads,
  carriage/gripper jaws, winches/cables and transfer drawers. Existing console
  footprints become five-drawer folio/index cabinets. A three-run recessed Warren
  truss/strip-light ceiling replaces the repeated transverse beam grid.
- **Tidal pump room:** two walls hold three asymmetric pump stations each:
  vertical risers, suction connections, return pipes, sectional flanges, volute
  covers with bolted faces, bearing caps, bulkhead guards, gauges and continuous
  discharge/return headers. Existing console footprints become guarded reducer/
  finned motor housings. Two unequal recessed duct trunks, intake louvers, collars
  and cross-manifolds replace the archive-like ceiling rhythm.
- Removed accepted decorations: the repeated wall panel/slot grids, thin datum
  tiles, original pipe-and-dial repetitions, low ceiling beam/coffer repetitions,
  common lamps and console rib trim in these two interiors only. Exterior roof
  lanterns and portal framing remain.

## Authority, clearance and limits

**Gameplay geometry and recipe hashes are unchanged.** New revision identity is
in `source-check.json`; it binds the actual generated mesh payload, accepted
source/author/assets and revision code. `candidate-meshes.json` contains actual
vertices and triangles, not a render description or claimed screenshot.

All new triangle vertices are checked against **10 named existing convex source
volumes**: four side walls, four console bodies and two ceiling slabs. Convexity
means the entire triangle, not just its centroid, is inside the existing volume.
Degenerate/nonfinite triangles fail. No added triangle enters corridor or portal
air. Ceiling hardware is at or above the existing 16.8/4.8 m undersides; nothing
new hangs into standing head clearance.

The old visual wall box/ceiling underside is replaced with a sealed backing,
front boundary framing and shallow recessed machinery. Native collision remains
at the original convex wall/cabinet/slab front plane. These sub-metre solid-backed
equipment recesses are **not enterable alcoves**; ray contact may precede a visible
recessed surface by up to the existing wall depth (0.8 m). This is deliberate
reuse of the parent's permitted blocked envelope, not new corridor collision.

The source check conservatively adds every candidate triangle to the accepted
148,239 triangles **without crediting removed geometry**. It must remain below
160,000; actual exported bytes/triangles/materials are still unmeasured. Retain
the accepted limits of 16,000,000 GLB bytes and seven materials. Geometry count
is a cost gate, not proof that the interiors look sufficiently different.

The first source-only mesh check rejected 12,620 added triangles against the
11,000 addition cap. Plate storage was reduced to six cassettes per rack tier and
index tabs changed to two-triangle plaques, preserving retrieval/storage anatomy.
No mode oracles were repeated: no authoritative geometry changed.

## Source-only checks (safe now)

From the assigned worktree:

```sh
REV="$PWD/tools/godot-multiplayer/new-maps/parallax-observatory/revisions/interiors-v2"
python3 "$REV/build_recipe.py"
python3 "$REV/author_candidate.py" --prepare-only
python3 "$REV/prepare_native.py"
node --check "$REV/output/audit-art.mjs"
```

Preparation compiles the Python adapter, verifies accepted input hashes and
writes prospective scripts only. `output/` is isolated, ignored and outside
Godot. The adapter never edits the accepted author or its destinations.

## Exact later production commands — explicit grant required

Run serially **only after a new parent grant**, following the source checks above:

```sh
set -e
REV="$PWD/tools/godot-multiplayer/new-maps/parallax-observatory/revisions/interiors-v2"
BLENDER=/home/mojo/.tmp-on-disk/cocs-blender-toolchain/blender-4.5.14-linux-x64/blender
GODOT=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
LP_NUM_THREADS=1 "$BLENDER" -b -t 1 --python-exit-code 1 \
  --python "$REV/author_candidate.py" -- --slot-granted --render \
  > "$REV/output/build.log" 2>&1
LP_NUM_THREADS=1 "$BLENDER" -b "$REV/output/parallax-observatory.blend" -t 1 \
  --python-exit-code 1 --python "$REV/reopen_candidate.py" -- --slot-granted \
  > "$REV/output/reopen.log" 2>&1
node "$REV/output/audit-art.mjs" > "$REV/output/art-check.json"
LP_NUM_THREADS=1 "$GODOT" --headless --single-threaded-scene --path "$PWD/godot" \
  --script "$REV/output/physics.gd" > "$REV/output/physics.log" 2>&1
LP_NUM_THREADS=1 LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a "$GODOT" \
  --single-threaded-scene --path "$PWD/godot" --audio-driver Dummy \
  --script "$REV/output/inspection.gd" > "$REV/output/inspection.log" 2>&1
```

The candidate native probes reuse the production source collider builder and
replace **only its art instance** with the candidate via `GLTFDocument`. No accepted
GLB is overwritten and no Godot editor import is needed. Candidate probes inherit
the accepted block/ray/capsule/wall/ceiling tests and compare the candidate's actual
triangle count/hash. They are prepared source, **not yet parsed or executed in
Godot**. All logs are revision-local; retain failures before retrying.

Inspect `output/blender-review/` and `output/native-review/`: at minimum overview,
`archive-interior.png`, `pump-interior.png`, both portal approaches and unchanged
polar hall. Judge cassette/retrieval anatomy versus connected hydraulic machinery,
silhouette, sightlines, head clearance and material readability at human eye height.
Native probing and images remain pending; no improved-art acceptance is claimed.
Promotion into accepted asset paths is a separate parent-approved step after
review. No new integration hooks or six-mode rerun are proposed absent geometry
changes or a discovered gameplay regression.
