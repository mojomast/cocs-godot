# Abyssal + Stormglass map-variety revision 2 — source handoff (Sol repair)

**Owner:** coastal repair source lane. **Branch:**
`sol/map-variety-coastal-repair` from `7a7ce64e` (base authority `190fa2a2`).
**Scope:** source-only. No engine, Blender, import, render, server or API call ran.
The actual editable `.blend` and material-batched GLB are **pending Sol's serial
heavy execution**; nothing here claims a built asset or native acceptance.

Accepted masters, GLBs, base recipes, runtime authority JSON and profiles are
unmodified (`git diff` vs `190fa2a2` is empty for every tracked file). P `89/22/31`
and Q `190fa2a2` identities are untouched. The shared `blender_kit.py` and Sol's
material adapter are **not** edited; this lane adds its own helpers under
`tools/map-variety-support/`.

## Corrective fixes (parent review of `6675a2ce`)

| # | Defect | Fix |
|---|---|---|
| 1 | `layout._z` returned `(x, z, -y)`, breaking `export_yup=True` | Source Y-up → Blender is now `(x, -z, y)` in `tools/map-variety-support/geometry.py`, so Blender → glTF (`(x,z,-y)`) round-trips to the source exactly. Explicit basis + signed-height tests. |
| 2 | Stormglass `_box` faces held 3D coordinates, not indices | All boxes are built through `geometry.box_mesh_src`, producing outward-wound **index** faces; tests assert integer in-range indices, nonzero area and outward normals. |
| 3 | Abyssal `_poly8` scale used the Y ordinate as Z | Fixed to `(px, py, pz)` with centre and W:D preserved; tested via footprint centre/bounds. |
| 4 | hab-vent arch 3.2×3.0 invalid for `Kit.framed_bay` | `framed_bay`/`curved_rib` are no longer used for authored forms; bays/arches/rings are explicit source meshes with valid dimensions. Every layout spec is dispatched through real pure geometry validation. |
| 5 | author emitted only new props, not the map | `tools/map-variety-support/composition.py` emits the **complete revised authority** (every retained deck, ramp, ceiling, wall, equipment piece, glazing, building mesh), accepted author-only fittings, signs, escarpment beds and all nine branched source reefs, plus new classes; removed roofs have substitutes. |
| 6 | Cameras used a flat Euler ignoring target height | Blender cameras use `(target−eye).to_track_quat('-Z','Y')` on converted eye/target; a pure basis test proves the source forward points at the target with real vertical component. |
| 7 | Prism sizes/orientations (vertical "wheels") | Prism size is converted source `(X,Z,Y)` → Blender `(X,Y,Z)`; rings are horizontal (source XZ plane, Y thickness) and arches are vertical (rise in source +Y, span across heading). Orientation tests assert each. |

## Sol source repairs after independent review of `7a7ce64e`

- Stormglass scenery is oriented in the actual centerline tangent/across frame. Whole-form placement checks **all authority road triangles**, including intersection by an edge or a triangle enclosing the road without an interior vertex, with 4 m low-height camera/barrier margin; the gate arches stay overhead at their original gate anchors while their low columns stand beyond the road. Camera eyes are checked against new mesh volumes.
- `art.meshes` is the canonical visual representation of Stormglass road and walls; covered terrain triangles are not rendered twice. The candidate collision, road, race and profile files remain untouched. The 21 original route signs and 12 Abyssal district signs are converted to UV-bearing, exact-amber source meshes **before** Kit batches. Only completed export batches are selected for GLB; the batch and actual GLB triangle/primitive counts are recorded when native execution becomes available.
- Correct upward caps and radial outward winding for Abyssal frusta, roofs and reef buttresses; retain the distinct ceramic vault crown and give the ribbed pressure vessel a continuous full-height shell. The nine accepted branched reefs and eight escarpment beds, original machine fittings, ribbing and wayfinding are restored with traceable source IDs and original material assignments.
- Original Moth PNG channels remain immutable and linear (including source albedo). The adapter must supply derived **sRGB** glTF base colour; the report identifies source hash and embedded-derived hash independently, without requiring them to be equal.

## Files and runnable entry points

| Map | Directory | Authority build | Blender composition author |
|---|---|---|---|
| Abyssal | `tools/godot-multiplayer/new-maps/abyssal-pressureworks/revision2/` | `build.mjs` (`--check`) → `arena.json`, `candidate.json`, `probes.json` | `author.py` → `build_entry.run` |
| Stormglass | `tools/godot-multiplayer/new-maps/stormglass-causeway/revision2/` | `build.mjs` (`--check`) | `author.py` → `build_entry.run` |

Shared source modules: `tools/map-variety-support/{manifest,geometry,composition,road,preserved,build_entry}.py`.

Bounded source tests (no engine):

```sh
node --test tools/godot-multiplayer/new-maps/abyssal-pressureworks/revision2/source.test.mjs
node --test tools/godot-multiplayer/new-maps/stormglass-causeway/revision2/source.test.mjs
python3 -m unittest discover -s tools/godot-multiplayer/new-maps/abyssal-pressureworks/revision2 -p test_layout.py
python3 -m unittest discover -s tools/godot-multiplayer/new-maps/stormglass-causeway/revision2 -p test_layout.py
python3 -m unittest discover -s tools/map-variety-support -p test_preserved.py
```

Current results: Abyssal 8 Node + 13 Python pass; Stormglass 6 Node + 16 Python
pass, plus 6 preservation/export-source Python checks (14 Node + 35 Python total). Source identity:

- Abyssal `geometryHash` `5fea4aada721903cea26897fb6a17befaf146c576c095dc712feebef626adfa2`
  (base runtime `32366a6c…` untouched), 204 surfaces / 808 walls / 501 nav.
- Stormglass `geometryHash` `560ffcf7f1e247482278cf5036d073dad5858bdf5073f485928efb6d705de8f0`
  (base runtime `6afb8a36…` untouched), terrain/walls/race byte-identical.

## Prerequisites for Sol's heavy run

1. Reviewed R commit `6ff4079e` must land first: its
   `tools/map-variety-pipeline/material_adapter.py` exposes
   `load_materials(root, pack_bindings, *, output_dir, with_report=True) ->
   (materials, density, proof)`. Only explicit `surface|team` bindings are sent;
   the actual adapter rejects preserved roles. `preserved.py` authors every exact
   accepted glass/emissive palette entry with its authored UV density. Missing,
   unknown or incomplete roles fail closed; no pinned `moth_finish.py` fallback.
2. One map per process:
   `blender -b -t 1 --python-exit-code 1 --python <author.py> -- --root <repo>`
   (Abyssal, then Stormglass; capture hashes before the next).
3. `blender_kit.Kit` unmodified.

## Material hooks (new, outside the pinned `moth_finish.py` contract)

- Pack: `assets/moth/map-variety-20261003/candidate-v2/manifest.json` (181 PNG)
  + `candidate-v3/manifest.json` (20-PNG overlay). `manifest.load_pack(root=None)`
  takes an explicit repository root and hashes every resolved channel.
- `materials.bindings.json` maps exact GLB name → `{role, material, normal,
  teamColorSource}` (role `surface|team|preserve`). Repeat density comes from the
  reviewed `tileMeters`.
- Base authority material names are now bound too: Abyssal `navy/ivory/coral/
  copper` (→ quay-damp-horizontal / ceramic-enamel / terracotta / copper-patina)
  and `amber/cyan/glass` preserved; Stormglass `asphalt/concrete/salt/teal/brick/
  steel` (→ viaduct-asphalt / quay-damp-horizontal / salt-limestone /
  ceramic-enamel / terracotta / oxidized-iron) and `amber/glass/ocean` preserved.
- All channels are linear (albedo Non-Color); normals OpenGL +Y; the adapter must
  convert glTF base-colour to sRGB in a derived payload. `author.py` writes `material-report.json`
  (independent immutable-source vs derived-embedded hashes, `tilesPerMeter`, `teamColorSource`) and exports
  `export_tangents=True`.
- When a native GLB exists, `build_entry.py` compares decoded embedded base-colour
  pixel channels with the independently computed linear→sRGB conversion from
  immutable source bytes, and normal pixels with immutable linear source. Roughness
  pixel proof remains a later native-receipt check. It checks adapter manifest
  provenance/derived hash; every GLB primitive must be indexed triangles, with
  total triangles matching evaluated export batches and primitive count within
  `--max-batches`. The total target defaults to **150,000 triangles**; pure source
  estimates before modifiers/signs are 33,892 Abyssal and 21,488 Stormglass.
  An evaluated overage is recorded as `triangleTargetExceeded`, not accepted or
  failed without native review. The editable collection remains accessible but
  hidden in the saved master viewport/render; export batches alone render there.
  `bpy.ops.file.pack_all()` precedes the master save; its packed-image inventory,
  master SHA-256 and bytes are recorded. Under a *later* serial Blender grant, run
  `tools/map-variety-support/verify_master.py -- --blend <master.blend> --report
  <material-report.json>` with Blender `-b -t 1 --python-exit-code 1 --python` to
  reopen and require all file-backed images packed (no external worktree images).
  These checks are pending native execution, not source-verified results.

## Authored content

**Abyssal** (7 classes): three distinct district pressure vaults (splayed
observation vault, tall ribbed vessel, low faceted habitat) replacing six cloned
roofs; manifold valve trees; wet service cave; pipe bridges above galleries;
observation blisters; equalizer crown; irregular reef buttresses. Authority adds
two bounded dry-service terraces and one sunken utility pocket (walkable,
XZ-disjoint, single height), opened through the row-0 observation bays by
removing only the low sill panels. Six modes keep supported spawns, anchors and
corridors; nav is one component and ordinary `moveActor` traverses both terraces
and the ramp.

**Stormglass** (7 classes): five seawall heights, terrace grandstands, cliff-stair
switchbacks, three distinct checkpoint arches, lighthouse, three quay cranes and
varied terminal facades. All scenery is art-only (`arena.art.revision2`),
explicitly `nontraversal`; full low-altitude meshes clear the actual road and camera corridor. **Zero drivable relief retained
truthfully**; `game/race.mjs` and `game/vehicles.mjs` untouched; exactly
`puma-race` registered.

## Handoff

Parent owns merge and any native grant. Sol runs the serial Blender build against
the adapter above. No engine/render/import/native claim is made here.
# Parent source-integration checkpoint

Sol corrective commit `42e6cab4` was independently reviewed and merged as
`18201a06`. Parent reproduced 14 Node, 29 Python and three shared-Kit source
checks, plus both authority generation `--check` commands. The previous rejected
deliveries and their findings remain historical; the corrected source is queued
for actual production, not promoted into runtime.

Actual Blender execution still requires the injected shared material adapter and
the next exclusive heavy grant. Verify exported base-color pixels, source/derived
image lineage, complete evaluated triangle/primitive budgets, signage inclusion,
master/reopen visibility and player-height native captures. R currently remains
scoped to Foundry. No coastal `.blend`, GLB, rendered acceptance or new runtime
package is claimed by this source-integration checkpoint.
