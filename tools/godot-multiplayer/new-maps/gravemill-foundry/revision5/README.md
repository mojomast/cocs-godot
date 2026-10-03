# Foundry R5 — Astra corrective production, grant S

**Staged corrective candidate, not public promotion or hosted/manual acceptance.**
R4 / `6ff4079e` remains rejected evidence. This namespace supersedes its candidate
art; it does not amend R4's source, master, screenshots, or receipts.

## Actual artifacts

- Editable packed master: `gravemill-foundry-revision5.blend` — 270 source parts,
  hidden source collection and visible export collection, 30 packed images.
- Native art: `godot/multiplayer_worlds/art/revisions/gravemill-foundry-r5.glb`.
- Authority: `godot/multiplayer_worlds/generated/revisions/gravemill-foundry-r5.json`.
- **87,566 evaluated/exported triangles; 16 batches; 12,394,520 bytes; 10 PBR
  materials plus the exact accepted emissive material; 30 embedded PNG images.**
- Actual geometry hash:
  `61bf7574860285223dd110fec9a8a3ec239b1b3d7102887020009e24d4ae0879`.
- `production-report.json`, `material-lineage.json`, `pack-receipt.json`, and
  `reopen-report.json` identify the actual bytes and acceptance scope.
- `evidence/native/`: **22 untouched native PNGs**, 11 matched camera pairs at
  1280×720. `evidence/image-manifest.json` identifies every hash and decoded-pixel
  comparison. `accepted-finish-before` is the genuine accepted runtime finish;
  `candidate-runtime-r5` is the explicitly staged R5 presentation.

## Corrections and probes

1. `shapes.py` generates closed, outward shared shells in game coordinates.
   Struts use local-zero vertices and a rigid basis/world midpoint in Blender.
   All source vertices/endpoints are checked during authoring and fresh reopen.
   Exported triangles are matched with multiplicity against per-component
   evaluated topology, then measured from the GLB itself: bounds, positive signed
   volume, and all drum cap/side face and corner-normal directions.
2. Eight headframe shoes/legs anchor to interpolated **actual crusher roof
   triangles**, all inside the roof footprint. No hardcoded y=32 feet.
3. Vertical and both horizontal drum axes use right-handed bases. X-running
   conveyor rollers run horizontally across Z; belts follow the `.14*x` plan
   shear. Bunkers include body/cap collision; tipples retain genuinely empty
   portals. The same shape polygons supply source collision and Blender meshes.
4. Eight targeted actual-GLB/source/native ray comparisons close the review's
   bunker, jamb and conveyor counterexamples and prove both portal apertures.
5. **3,849 native finite-capsule samples** cover 1,026 nav points, dense routes,
   spawn/team pools, objectives, and all eight player-height cameras. One exact
   centre ray hits a float32 floor seam: all four 5 mm neighboring support rays
   and the actual capsule pass, explicitly recorded rather than hidden.
6. Accepted walking surfaces/routes remain byte-equivalent as source values.
   Authority walls are **2,320 accepted → 2,368 rejected R4 → 4,666 R5 polygons**;
   the R5 additions contain 5,840 wall triangles. Polygons consolidate identical
   collision triangles into fewer native bodies; they do not fill portal holes.
7. Accepted `GM / orange` PBR/emission fields are retained within float32 export
   tolerance. Native lifecycle checks preserve its emission/color/energy/mapping
   through Off/Low/Full dressing and weather binding/restoration.

## Runtime finish and visual scope

`godot/tests/new_maps/gravemill_foundry/revision5/staged.gd` is an explicit test-only
integration. It validates the exact candidate identity and hashes, uses a
versioned schema/profile, instantiates the real WorldMap authority and candidate
GLB, and invokes production Binder resources and WeatherService. Accepted
production identities/profiles are unchanged; an old or arbitrary hash is not
accepted by the staged schema.

The stage preserves the imported PBR materials while retaining accepted authored
panels, signs and particles. Legacy architectural soot receives the pale
lime-plaster role used by the accepted finish; new steel remains forge-steel.
Mineral normal relief is .35 with unchanged source normal pixels. Anisotropic
mipmap filtering is instance-owned. Four bounded lights attach below actual
accepted cooling fixtures, recorded in `lights.json`; these are part of the
staged presentation, not per-camera render tricks. No operator/team palette
assets or global postprocessing are changed.

The production weather service selects **clear** at the authored seed/time in
these stills. Weather material/environment ownership is exercised and traversal
is uncapped; this is not an all-weather, actor-readability, or hosted-mode matrix.

## Performance / design guidelines

The user permits useful detail above the 150k triangle guideline. Neither that
guideline nor 7 MB is a silent hard approval ceiling. The final GLB contains
3,337,233 bytes of lossless embedded PNGs and 9,030,516 non-image buffer bytes
(full float32 vertex/normal/UV/tangent streams, hard-edge and UV splits).
No lossy texture conversion or geometry quantization was introduced to chase
the byte target.

Final captures record eight-frame static-view timing, video/static memory and
draw calls on **Mesa llvmpipe / Godot 4.5.2 Compatibility**, with a warmed isolated
import cache. See the measured ranges in `production-report.json`; these are
not dedicated-GPU performance or hosted movement FPS claims. Six existing modes
remain source-registered; hosted six-mode journeys and manual player review are
**pending**.

## Retained attempts and release

`evidence/attempts/` retains timestamped commands, return codes, input source
hashes, pinned tool versions in logs, exact process-group identities and kernel
start ticks, failed checks, superseded artifacts, and superseded screenshots.
The first GLB component checker incorrectly welded adjacent portal shells;
it was replaced by multiplicity-preserving actual triangle matching. Native
testing found a 16 cm guide obstruction, corrected to a 5 mm flush guide.
Runtime capture found and corrected a null-material diagnostic guard and a
weather traversal cap caused by unnecessarily split collider nodes.

Sidecar inventories are captured before import, before cleanup, and after.
Only absent-before, untracked, S-generated unrelated sidecars are removed, with
every removed hash recorded. No baseline/R4 sidecar is restamped or restored.

`evidence/release-receipt.json` records three timestamped empty **owned** group
audits and nonwaiting lock availability after release. The unrelated environment
viewer PID 2598700 / PGID 2598689 is explicitly excluded and left intact.

## Reproduction and parent integration

Heavy reproduction requires a newly authorized exclusive grant. `grant.py serve`
acquires `/tmp/opencode/cocs-finish-acceptance.lock` nonwaitingly; requests use
`grant.py run SECONDS COMMAND...`. `produce.py build` is the serial corrective
build/reopen/import/physics sequence. `owned_capture.py` inventories renderer
children and stops only an exactly owned Godot on script failure. The capture
script supports `-- --view=tipple-player` for targeted recapture. Collect with
`collect.py`, release with `grant.py release`, then run `release_verify.py`.

This branch descends from the rejected R4 commit to preserve ancestry. Parent
integration should select the new correction commits and reviewed shared
prerequisites, **not merge rejected R4 wholesale**. Required R-era source support:
`tools/map-variety-pipeline/material_pack.py`, the pack-v2 `receipt.py` support,
and the reviewed `blender_kit.py` curved-rib fix. Shared receipt commit
`77d3d16c` fixes `normal:false` with real enabled/disabled PNG lineage tests.
`material_adapter.py` remains intentionally preserve-rejecting; the separate
Coastal owner handles its builder handshake. No Coastal files are changed here.

`integration-shared-support.patch` is the cumulative **source-only** support
delta from `190fa2a2`, including `77d3d16c` and its tests. It includes no R4
map/art/receipts. Apply that prerequisite bundle once before selecting the R5
artifact commit on a parent that has not integrated the shared support; do not
also apply the same receipt fix twice. Review against any newer parent edits.

R4's immutable export report incorrectly says authority change was "none".
The actual R4 change was +48 wall triangles across six bunker feet. This README
and the R5 authority receipts correct that historical claim without rewriting
the rejected evidence.
