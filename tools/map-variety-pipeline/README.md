# Candidate map art production boundary

`receipt.py` is a source-only gate for a **new revision**. It neither builds nor imports assets and never edits the frozen runtime or source authority. Run after Astra has delivered a reviewed Moth manifest; in `--built` mode run after serial Blender generation and before native import:

```sh
python3 tools/map-variety-pipeline/receipt.py port/map-variety/revision-1/candidate.json
python3 tools/map-variety-pipeline/receipt.py port/map-variety/revision-1/candidate.json --built
```

The candidate contract (paths relative to repository root) is:

```json
{
  "schemaVersion": 1,
  "moth": {"manifest": "godot/moth/generated/manifest.json", "sha256": "<sha256 of manifest bytes>"},
  "maps": [{
    "id": "<registered map id>",
    "authority": {"path": "godot/multiplayer_worlds/generated/<id>.json", "sha256": "<sha256 of JSON bytes>", "geometryHash": "<geometryHash in JSON>"},
    "materials": {
      "<exact GLB material name>": {"role": "surface", "texture": "<key in Moth manifest textures>", "tilesPerMeter": 1.2, "normal": true},
      "<exact team material name>": {"role": "team", "texture": "<key>", "tilesPerMeter": 1.2, "normal": false, "teamColorSource": "COLOR_0"},
      "<exact glass/water/emissive name>": {"role": "preserve"}
    },
    "art": {"blend": "<editable .blend>", "blendSha256": "<sha256>", "glb": "<exported .glb>", "glbSha256": "<sha256>", "maxPrimitives": 32}
  }]
}
```

The Moth manifest must contain `provenance.source`/`source_sha256`, and each referenced texture must contain a `res://moth/...` path and its exact `png_sha256`. This accepts new texture keys without guessing roles from names or depending on the pinned `moth_finish.py` registry. The map-level role registry and UV density are reviewed inputs to the **new** Blender adapter, not claims that this receipt applied the material. Built inspection asserts GLB 2.0, named used materials, triangle primitives with positions/normals/UV0, tangent accessors for normal-mapped primitives, embedded image byte hashes, and exported color/normal slots. Source-to-export transformation must additionally be documented by a Blender build report listing source PNG hashes, the generated/packed image hashes and per-material UV/BRDF mappings; the GLB inspection cannot prove those pixels came from Moth without that independent builder evidence. Compare its embedded image hashes with the report before native acceptance.

For each candidate, author separate versioned authority/layout files only after the layout owners deliver a validated revision. Record the new `geometryHash` and JSON-byte SHA here, then make the art/collision/route congruence tests and all registered map-mode pairs pass on that revision. The existing `map.gd` constructs collision exclusively from `arena.blocks`, `arena.terrain.surfaces` and `arena.terrain.walls`; a raised playable terrace, bridge or obstacle requires matching JSON authority and navigation/route checks. Flush decals and nonwalkable overhead geometry may remain visual-only. GLBs cannot grant gameplay collision.

For Blender 4.5.14 production: run one map per process (`-b -t 1 --python-exit-code 1`), construct named editable modular source collections with bevels/weighted normals and distinct hero silhouettes, link identical master mesh datablocks for repeated props, and export bounded, local material/sector batches rather than one mesh per instance or one global cull-defeating batch. Keep source collection and export collection separate, save `.blend` before selecting export objects, apply negative determinant/mirror transforms before export, and explicitly generate/test smooth normals and tangents where using normal maps. Use local repeat UVs at fixed tiles/metre; preserve COLOR_0/team identity, metal/roughness and emissive/glass intent. Inspect at player height after import for cull, occlusion, silhouette, team distinction and normal-map handedness.

Keep disk footprint bounded: no duplicate full asset worktree or bulk import; write one `.blend`/GLB per map into the designated revision, capture hashes/size before starting the next, and defer engine/server/encoding and broad rebakes until the parent explicitly schedules those stages. Receipt output says `nativeAcceptance: pending` even for built assets: native gameplay, material appearance and coverage require later independent evidence.
