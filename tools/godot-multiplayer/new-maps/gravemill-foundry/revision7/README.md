# Foundry R7 — seven-entry tangent-only source successor

Base: parent `9c5eca6d`. Isolated branch `astra/foundry-tangent-r7-source`.
**Source only. No Blender, Godot, import, render, server, child agent, actual R7
GLB/master, or native receipt has been produced. No heavy work is scheduled.**
X remains the sole heavy owner; W and its qualified staged artifacts remain frozen.

R6 source artifact is pinned to
`945978699f7b7ee4519f6078b68a508177a75905541f463c1777bf10f5efc47c`.
The successor retains **87,566 triangles / 32 primitives**, all materials and image
payloads, and authority
`61bf7574860285223dd110fec9a8a3ec239b1b3d7102887020009e24d4ae0879`.
Expected **actual R7 art identity remains null** until a separately authorized build.

## Exact scope and incident mapping

Zero-based indices below refer to the immutable R6 GLB. Complete positions, normals,
UVs, triangle vertices, Jacobians, corner angles and repaired float32 values are in
`source-report.json`. These are real nondegenerate surfaces with nonzero UV Jacobians.

| Node / primitive / material | Face | Corner | Vertex | TANGENT accessor |
|---|---:|---:|---:|---:|
| Gravemill / mineral, 1, R6 / ground | 682 | 0 | 3244 | 48 |
| Gravemill / copper, 0, GM / copper | 2283 | 0 | 5151 | 53 |
| Gravemill / copper, 0, GM / copper | 2284 | 2 | 5186 | 53 |
| Gravemill / copper, 0, GM / copper | 2285 | 0 | 5155 | 53 |
| Gravemill / copper, 0, GM / copper | 2303 | 0 | 5207 | 53 |
| Gravemill / copper, 0, GM / copper | 2304 | 2 | 5242 | 53 |
| Gravemill / copper, 0, GM / copper | 2305 | 0 | 5211 | 53 |

Each physical accessor/vertex entry has exactly one used incident corner in the
actual R6 artifact. The copper triangles are approximately 14.7825 m² each; the
ground triangle is approximately 0.012753 m². They are not font or degenerate
geometry. Their R6 Godot fallback is not a valid UV basis.

The replacement contract permits modifications only within these seven **16-byte
TANGENT records** (112 permitted byte positions; some values remain equal). All
other BIN bytes—including unused backing, valid tangents, positions, normals,
UVs, indices, embedded images—must match R6 exactly. No topology or vertex split is
needed. JSON changes only declare visual revision 7 and its tangent predecessor;
meshes, accessors, views, materials, textures and scene topology remain identical.
This narrowly supersedes W's exact-R5-tangent rule for the seven listed entries only.

## Derivation, shared vertices, and handedness

`tangents.py` derives `dP/du` and `dP/dv` from each incident triangle's existing
positions and UV Jacobian. It accumulates normalized face derivatives with the
corner-angle weighting used by Mikk-style smoothing, projects against the normalized
stored normal, normalizes the result, and derives `w` from
`sign(dot(cross(N,T), accumulated dP/dv))`.

This is a bounded invalid-entry repair, **not a new general MikkTSpace implementation**.
Shared entries are supported only where normals, handedness and projected tangent
directions agree. The solver uses every incident corner and rejects a conflicting
UV seam/direction explicitly; it does not pick the first face or silently split
vertices. Source identity, unknown extra invalid entries, aliasing repair storage,
zero geometry/UV Jacobians and nonfinite values fail closed.

Corrected float32 directions are unit and orthogonal within `1e-6`; UV orientation
is checked independently per incident corner. The sign stored with an old **zero**
direction is not reliable and is not preserved by assumption. With glTF's stored UVs,
the ground repair has `w=-1`; copper faces 2283/2303 have `w=+1`; the other four copper
faces have `w=-1`. Reflected-U, reflected-V, both-reflected and reversed-winding
fixtures establish the convention rather than copying Godot's previous `w=+1`.

The common authoritative gate is the existing R6 `glb_contract` adapter over the
parent shared `map_variety/glb_geometry.py`. Both actual input and in-memory output
pass it. Strict scene/backing/index checks remain in front of inventory. There is
no new triangle ceiling; the shared producer primitive limit is unchanged.

## Editable-master production recipe (future grant only)

Blender loop tangents are derived/read-only; setting arbitrary custom loop tangents
in a `.blend` would not be a truthful persistence contract. `production.py` instead:

1. Opens the pinned actual R6 packed master, retaining its editable polygons, UVs,
   material graphs and hidden geometry references.
2. Stores a scene recipe, a `R7_TANGENT_RECIPE.json` Text block and the exact repair
   source in `R7_TANGENT_REPAIR.py`; records source artifact/master and compiler hashes.
3. Saves a new R7 master, then exports an **intermediate** glTF from its actual
   editable export meshes.
4. Verifies intermediate per-corner oriented triangle coverage, positions, normals,
   UVs and material roles against canonical R6; checks all material pixels and
   PBR/emission fields. Bounded float32 exporter tolerances are position/UV `1e-5`,
   normal `1e-4`, material scalar `1e-6`.
5. Uses R6's canonical streams (avoiding round-trip drift in valid entries) plus
   the deterministic seven-entry repair to emit the new artifact. All output bytes
   outside those records **within the BIN chunk** retain exact R6 identity,
   independently of exporter rounding. Exactly 59 BIN bytes differ within 112
   permitted byte positions (seven 16-byte records). JSON asset/node successor
   metadata and the enclosing container length legitimately change.
6. A **fresh process with `--reopen`** repeats the editable export audit, validates
   embedded recipe/source, and requires canonical output byte equality with the
   actual R7 GLB. Plain Blender UI glTF export is only an intermediate, not the final
   artifact. Baseline canonical GLB and repository compiler remain explicit dependencies.

No engine command above has been run now. `queue.json` is an informational sequence,
with null grant, null actual art identity and `autoStart:false`.

## Native requirements (future, no waiver)

After actual build, `prepare_native.py` creates an R7-only stage from frozen R6
sources. It retains the same authority, profiles, lights and production Binder/
WeatherService behavior while requiring the new exact R7 art hash. It generates
matched **R6-before / R7-after** capture sources and fresh import readback sources.

Pin only the newly generated R7 sidecar to full-precision positions and no generated
LODs, preserving its Godot-generated UID. `native_check.py` verifies the actual R7
artifact, compares every native position, oriented triangle, UV, normal, tangent
direction **and w**, and checks fresh material-channel image readbacks. Native
direction error tolerance remains `0.0002` for the engine's direction encoding;
positions and UVs must be exact. **There is no zero-tangent exception.** A fixture
explicitly substitutes the former Godot fallback and proves rejection.

R6 W's 51 pixel comparisons and native geometry/render receipts remain historical
R6 evidence. They are not new R7 proof. Native import, packed-master build/reopen,
material readback, lifecycle/capture evidence, manual visual acceptance and shipping
review all remain pending. No materials, geometry, art direction or package policy
is changed in this source task.

## Source checks

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tools/godot-multiplayer/new-maps/gravemill-foundry/revision7 -p test_tangents.py -v
```

Tests compose only in memory. They cover the exact real-R6 seven-corner inventory,
all-other-byte identity, unit/orthogonal/UV-consistent repairs, reflections and
winding, all-incident shared vertices, conflicting handedness/directions, unknown
additional zeros, strict scene/buffer-view rejection, valid-tangent mutation and
native fallback rejection. `source-report.json` and `source-tests.json` record the
executed source results and preservation of all 226 W manifest file hashes.

## P1 material-equivalence correction

Original `source-report.json` and `source-tests.json` remain frozen historical
receipts from `9fb0172e`; they do not establish the corrected material gate.
`corrective-validation.json` records the new source-only tests and preservation
checks. Run both suites with `-p 'test_*.py'` in the discovery command above.

The editable-export audit now compares effective texture bindings by decoded
channel pixels, UV selection and sampler semantics, independently of image,
texture or sampler indices. Wrap defaults are REPEAT (10497). Missing filters
remain implementation-defined and are never equated with an explicit filter.
Only valid glTF filter/wrap enums are allowed. Core base-color, metallic/roughness,
normal, occlusion and emissive bindings are covered, including presence, normal
scale, occlusion strength, alpha mode/cutoff, double-sided state, emission and the
baseline's legitimate `KHR_materials_emissive_strength`. Unrecognized meaningful
material/texture fields and extensions fail closed; names/extras remain metadata.
Texture transforms and unavailable UV sets remain rejected.

The real R6 ground clamp-to-edge mutation and orange emissive-texture addition
must fail the full editable audit. Equivalent remapped resource indices and
explicit default wrap/UV values must pass. No geometry/UV matching tolerance changes.

The native checker also compares every scalar/color/emission field actually
recorded by the frozen import probe. Godot 4.5.2 serializes Color as four-decimal
sRGB strings: linear glTF RGB is converted to sRGB, alpha is retained, and the
comparison tolerance is `5.1e-5` for that formatting. Numeric float32 fields use
`1e-6`; emission-enabled and roughness-channel values are exact. Emission energy
is the recorded `emission_energy_multiplier`, not a guessed physical unit.
The historical R6 native report supplies a schema/representation regression
fixture only; no fresh R7 native acceptance is claimed. The probe does not record
native sampler/alpha/occlusion settings, so these are source semantic proofs,
not additional native readback claims.
