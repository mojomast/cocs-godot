# Abyssal + Stormglass map-variety revision 2 — source handoff

**Owner:** map-variety (Abyssal + Stormglass) source lane. **Branch:**
`finish/map-variety-abyssal-coast` at parent `190fa2a2`.
**Scope:** source-only. No engine, Blender, import, render, server or API call ran.
The actual editable `.blend` and material-batched GLB are **pending Sol's serial
heavy execution** after this delivery; nothing here claims a built asset or
native acceptance.

Frozen identity is preserved: the accepted masters, GLBs, base recipes, runtime
authority JSON and `godot/multiplayer_worlds/generated/*` are unmodified
(`git diff` against `190fa2a2` is empty for every tracked file). The P ledger
(89/22/31) and Q `190fa2a2` identities are untouched.

## Files and runnable entry points

| Map | Directory | Authority build | Blender author |
|---|---|---|---|
| Abyssal | `tools/godot-multiplayer/new-maps/abyssal-pressureworks/revision2/` | `build.mjs` (`--check`) → `arena.json`, `candidate.json`, `probes.json` | `author.py` |
| Stormglass | `tools/godot-multiplayer/new-maps/stormglass-causeway/revision2/` | `build.mjs` (`--check`) | `author.py` |

Shared source-only material resolver: `tools/map-variety-support/manifest.py`
(read-only over the reviewed packs; unknown material/channel/path/hash is a
hard error with no fallback).

Bounded source tests (no engine):

```sh
node --test tools/godot-multiplayer/new-maps/abyssal-pressureworks/revision2/source.test.mjs
python3 -m unittest tools/godot-multiplayer/new-maps/abyssal-pressureworks/revision2/test_layout.py
node --test tools/godot-multiplayer/new-maps/stormglass-causeway/revision2/source.test.mjs
python3 -m unittest tools/godot-multiplayer/new-maps/stormglass-causeway/revision2/test_layout.py
```

Current results: Abyssal 8 Node + 8 Python pass; Stormglass 6 Node + 8 Python
pass. Generated candidates (source identity):

- Abyssal `geometryHash` `5fea4aada721903cea26897fb6a17befaf146c576c095dc712feebef626adfa2`
  (base runtime `32366a6c…` untouched), 204 surfaces / 808 walls / 501 nav.
- Stormglass `geometryHash` `560ffcf7f1e247482278cf5036d073dad5858bdf5073f485928efb6d705de8f0`
  (base runtime `6afb8a36…` untouched), terrain/walls/race byte-identical.

## Prerequisites for Sol's heavy run

1. The shared material adapter exists as
   `tools/map-variety-pipeline/material_adapter.py` (owned by Sol) exposing
   `load_materials(root, bindings) -> (materials: dict[str, bpy.Material],
   density: dict[str, float])`, keyed by the **exact GLB material names** in each
   `materials.bindings.json`. Unknown names must raise; no legacy
   `moth_finish.py` registry fallback.
2. Run one map per process:
   `blender -b -t 1 --python-exit-code 1 --python <author.py> -- --root <repo>`
   (Abyssal first, then Stormglass; capture hashes before starting the next).
3. `blender_kit.Kit` is used unmodified from `tools/map-variety-pipeline/`.

## Material hooks (new, outside the pinned `moth_finish.py` contract)

- Pack: `assets/moth/map-variety-20261003/candidate-v2/manifest.json` (181 PNG
  base) + `candidate-v3/manifest.json` (20-PNG additive overlay). `manifest.py`
  verifies the overlay `basePack.sha256` and hashes every channel it resolves.
- `materials.bindings.json` maps exact GLB material name → `{role, material,
  normal, teamColorSource}`; role is `surface | team | preserve`. Repeat density
  comes from the reviewed `tileMeters` (never duplicated in the file).
- All five channels are **linear, including albedo**: the adapter must set
  Blender image colour space to Non-Color and convert the glTF base-colour
  encoding to sRGB on export. Normals are tangent-space OpenGL +Y.
- Abyssal binds `copper-patina`, `copper-heat-oxide`, `cast-seams`,
  `ceramic-enamel`, `oxidized-iron`, `basalt-strata`, `deep-silt`,
  `salt-limestone` (+ preserved `observation-glass`, `equalizer-emissive`).
- Stormglass binds `salt-limestone`, `basalt-strata`, `quay-damp-horizontal`,
  `timber-weather`, `moss-warm-weather`, `oxidized-iron`, `ceramic-enamel`,
  `viaduct-asphalt`, `cobble-sett`, `slate-shingle`, `sea-flow` (+ preserved
  `harbour-glass`).
- `author.py` writes `material-report.json` with source vs embedded channel
  hashes, `tilesPerMeter` and `teamColorSource`, and `export_tangents=True` for
  normal-mapped primitives.

## Authored content

**Abyssal** (`layout.py`, 7 classes): three distinct district pressure vaults
(splayed observation vault, tall ribbed vessel, low faceted habitat) replacing
six cloned roofs; manifold valve trees; wet service cave; pipe bridges above
galleries; observation blisters; equalizer crown; irregular reef buttresses.
Authority revision adds two bounded **dry-service terraces** and one **sunken
utility pocket** (walkable, XZ-disjoint, single height each), opened through the
existing row-0 observation bays by removing only the low sill panels. Six
registered modes keep supported spawns, anchors and corridors; nav stays one
component and ordinary `moveActor` traverses both terraces and the ramp.

**Stormglass** (`layout.py`, 7 classes): five seawall heights, terrace
grandstands, cliff-stair switchbacks, three distinct checkpoint arches,
lighthouse, three quay cranes and varied terminal facades. All scenery is
art-only (`arena.art.revision2`), explicitly `nontraversal`, placed at
|lateral| ≥ 16 m so the 28 m road and 14 m barriers are untouched. **Zero
drivable relief is retained truthfully**; `game/race.mjs` and `game/vehicles.mjs`
are not touched and exactly `puma-race` stays registered.

## Handoff

Parent owns merge and any subsequent native grant. Sol runs the serial Blender
build against the adapter above. This delivery makes no engine, render, import
or native-acceptance claim.
