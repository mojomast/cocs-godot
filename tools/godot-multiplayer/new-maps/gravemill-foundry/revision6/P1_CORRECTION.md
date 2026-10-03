# R6 source review P1 correction

Prior source attempt: `54caaed94b2babdd13d942d69f11107c1d18c591`.
Its `finish-plan.json`, bindings, source reports/runs/manifest and stage sources
remain unchanged. Those records describe the prior attempt, not this correction.
R5 art, master, authority and evidence also remain unchanged.

## Shared dependency

Merged parent **`55f9ba37fcceea517f142c12337c233f3b5d27e7`** as
`6441c7b68aa9beb249a78b9696031f9935d75dd5`. This brings in the parent's corrected
botanical validator (`32eba401`) and shipping policy (`96bc9758`) along with their
already-integrated source/documentation dependencies. The merge has no conflict
resolution edits. The corrective commit itself modifies only Foundry R6 files.

New direct code dependency:
`tools/godot-multiplayer/new-maps/map_variety/glb_geometry.py`, specifically
`EmbeddedGlb` and `item`. No shared validator or botanical files are edited or
copied. This uses the geometry/container layer, not botanical material/export
policy; the preserved orange material is not required to supply PBR textures.

## Gate before inventory

`glb_contract.py` delegates the complete GLB container, embedded buffer/view,
accessor, default-scene traversal, orphan mesh, cycle/instance, reference, finite
stream and actual index checks to that shared validator. Foundry's adapter adds
its existing narrower contract: baked transforms, indexed POSITION/NORMAL/
TANGENT/TEXCOORD_0, all nodes reachable, and valid backing for retained unused
accessors. No duplicate bounds decoder or general glTF loader is introduced.

`finish.glb_parts`, `finish.primitives` and the public `finish.access` now gate
their inputs. Mutable document/binary pairs are revalidated rather than trusted
through an object-identity cache. Primitive enumeration follows the validated
default scene. `compose` gates the final serialized bytes; `verify` gates before
its existing per-corner role/UV/multiplicity and material checks. The intermediate
material library uses shared container/image validation, since its geometry is
deliberately unused and a test library may contain only materials/images.

There is no triangle ceiling. The shared validator's existing 64-primitive
producer limit remains a technical constraint; this candidate uses 32.

## Source-only regressions

Command:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tools/godot-multiplayer/new-maps/gravemill-foundry/revision6 -p 'test_*.py' -v
```

**Nine tests passed.** `test_contract.py` composes the real immutable R5 GLB and
unchanged finish plan with an in-memory seven-material library constructed from
the reviewed pack's actual images. The valid composition passes all 87,566
triangles / 32 primitives, retained materials, expected UVs and exact original
POSITION/NORMAL/TANGENT stream bytes. This is synthetic-library regression
evidence, not a Blender export, native material result, or built R6 receipt.

Exact review mutations are applied to that real-R5-derived composition:

| Mutation | Rejection before inventory |
|---|---|
| Default scene `nodes=[]` | `Scene has no root nodes` |
| Remove one root mesh node | `Orphan meshes are outside the exported scene` |
| Used index bufferView `byteLength=1` | `index accessor exceeds bufferView bytes` |

Each is tested through actual-art `verify` and the public primitive reader.
Small adapter fixtures also reject invalid node/mesh/accessor references, an
undersized stride, out-of-range index, cycle/repeated node, nonfinite position,
incorrect declared BIN length and truncated container. Existing serializer
regressions still pass, updated only to provide valid scene/range/container
metadata now required by the gate.

No actual R6 GLB, PNG, art identity or native receipt is written by these tests.
No engines, imports, renders, servers or children were started. S remains
released; Coastal T remains the sole heavy owner. Native visual/manual acceptance
and public promotion remain pending. Material directions and UV policy are unchanged.
