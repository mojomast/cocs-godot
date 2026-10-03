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
      "<exact GLB material name>": {"role": "surface", "texture": "<key in Moth manifest textures>", "tilesPerMeter": 1.2, "normal": "<key in Moth manifest normals>"},
      "<exact team material name>": {"role": "team", "texture": "<key>", "tilesPerMeter": 1.2, "normal": false, "teamColorSource": "COLOR_0"},
      "<exact glass/water/emissive name>": {"role": "preserve"}
    },
    "art": {"blend": "<editable .blend>", "blendSha256": "<sha256>", "glb": "<exported .glb>", "glbSha256": "<sha256>", "maxPrimitives": 32, "report": "<builder JSON>", "reportSha256": "<sha256>"}
  }]
}
```

The Moth manifest must contain `provenance.source`/`source_sha256`, and each referenced color/normal must contain a `res://moth/...` path and its exact `png_sha256`. This accepts new texture keys without guessing roles from names or depending on the pinned `moth_finish.py` registry. The map-level role registry and UV density are reviewed inputs to the **new** Blender adapter, not claims that this receipt applied the material. Built inspection checks GLB 2.0, material-to-texture-to-image indices, positive bounded buffer-backed accessor counts/shapes, normals/UV0, tangent accessors for normal-mapped primitives, COLOR_0 for team primitives and actual embedded image byte hashes. This is a bounded structural inspection, not a full glTF validator or proof of rendered appearance.

The hashed builder JSON must provide `id`, `geometryHash`, `mothManifestSha256`, `glbSha256`, and `materials` with **every exact material name**. For each non-preserved name supply `sourceColorSha256`, `sourceNormalSha256` (null for `normal:false`), `embeddedColorSha256`, `embeddedNormalSha256` (null if absent), `tilesPerMeter` and `teamColorSource` (null for ordinary surfaces, `COLOR_0` for team). The receipt compares the source hashes to real Moth PNG bytes, resolves the GLB slots to actual embedded bytes and compares those to the builder evidence. This lineage remains builder-reported; independently verify pixel derivation, BRDF response and tangent handedness in a later Blender/native review.

For each candidate, author separate versioned authority/layout files only after the layout owners deliver a validated revision. Record the new `geometryHash` and JSON-byte SHA here, then make the art/collision/route congruence tests and all registered map-mode pairs pass on that revision. The existing `map.gd` constructs collision exclusively from `arena.blocks`, `arena.terrain.surfaces` and `arena.terrain.walls`; a raised playable terrace, bridge or obstacle requires matching JSON authority and navigation/route checks. Flush decals and nonwalkable overhead geometry may remain visual-only. GLBs cannot grant gameplay collision.

`blender_kit.py` provides a reusable **source-only** Blender 4.5 modeling kit: real beveled portal bays with a clear arch/flat opening and perimeter reveals, annular vaulted ribs, bent manifold pipes, linked prop instances, local UVs and sector/material export batches. It does not generate a map by itself. Coordinates are Blender Z-up metres: map owners must convert the authority's Y-up coordinates at their builder boundary (as the existing world exporter does), place these inside separately reviewed authority/collision envelopes and pass exact reviewed Blender materials/tiles-per-metre; they own per-map hero forms and layout. Portal `height` is outside height and arch spring height is `height-width/2`; source-only geometric ray tests confirm center and side clearance below the head. The pipe helper rejects near-U-turn cusps, which need separately modeled elbows. For Blender 4.5.14 production: run one map per process (`-b -t 1 --python-exit-code 1`), link identical master mesh datablocks for repeated props, use bounded local material/sector batches rather than one mesh per instance or one global cull-defeating batch, save `.blend` with source **and** export collections, then export only the export collection. Linked instances are rigid/unit scale to retain their reviewed UV density; generate a new master for a different size. The kit rejects negative-determinant/mirrored transforms; apply and check handedness before construction. Explicitly generate/test smooth normals and tangents where using normal maps. Preserve COLOR_0/team identity, metallic/roughness and emissive/glass intent. Inspect at player height after import for cull, occlusion, silhouette, team distinction and normal-map handedness.

Keep disk footprint bounded: no duplicate full asset worktree or bulk import; write one `.blend`/GLB per map into the designated revision, capture hashes/size before starting the next, and defer engine/server/encoding and broad rebakes until the parent explicitly schedules those stages. Receipt output says `nativeAcceptance: pending` even for built assets: native gameplay, material appearance and coverage require later independent evidence.
