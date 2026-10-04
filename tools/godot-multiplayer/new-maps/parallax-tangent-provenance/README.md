# Parallax AA: inherited UV / tangent / normal-map provenance (source-only)

Base `5916bc68`, branch `sol/parallax-tangent-provenance`. This traces the
**broader raw source census**, separately from Astra's `8f166beb` analysis of
the 16 singular wayfinding vertices. No artifact, engine, import, shader,
material, acceptance gate or original receipt was changed. All observations
below use pinned X `6356cf895c65cec181e1c6c077118b98f3ee80cb567955b37835433971342422`
and AA `95e9da98a45565ca2aae90858a9e5027d9123e4ffd1347da98d5de8573141cd5`.

## Finding

**High-confidence source-convention mismatch:** the X/AA glTF `TEXCOORD_0`
uses Blender's exported `v_glTF = 1 - v_Blender`, while exported `TANGENT.w`
is Blender's `bitangent_sign`, with no corresponding negation on the unskinned
export path. A V-axis reversal changes the sign of `dP/dv` and the handedness
of `(N,T,dP/dv)` but leaves `dP/du` unchanged. This predicts the near-universal
*sign-only* disagreement in Astra's raw census. It does **not** predict the
16 singular-glyph native conversion failures, the five opposite-U tangents,
or 4,745 nonorthogonal records; those require distinct treatment. Nor is a
raw derivative sign alone proof that every pixel looks wrong: illumination,
normal scale, texture samples, visibility, smoothing and inherited artistic
choices matter. The normals are explicitly authored as **OpenGL +Y with UV V
up**, so a green-channel inversion is not an evidenced compensation.

### Original author -> X -> AA chain

1. `revisions/districts-v3/asset_author.py:57-61` invokes
   `tools/godot-multiplayer/new-maps/map_variety/kit_build.py`. Its `:239,291`
   exports GLB with `export_yup=True`, `export_normals=True`,
   `export_tangents=True`. `tools/map-variety-pipeline/blender_kit.py:70-101`
   creates `MothLocal` planar UVs using local coordinates; `map_variety/kit_build.py:115-141`
   assigns `MothLocal` to converted wayfinding letters and removes competing UV
   layers. This is a Blender export, **not a handwritten glTF vertex exporter**.
2. `revisions/districts-v3/variety_bindings.json:5-24` selects the pinned Moth
   base/overlay packs and explicitly marks sea as untextured/preserved and 13
   other roles as surface. `tools/godot-multiplayer/new-maps/map_variety/map_materials.py:49-83`
   passes `normal=True` to the adapter, sets reviewed normal strengths and UV
   repeat densities. `tools/map-variety-pipeline/material_pack.py:149-167`
   binds the **unmodified Non-Color** normal image through a Blender
   `ShaderNodeNormalMap` with `uv_map='MothLocal'`; no green negation is wired.
   `tools/map-variety-support/manifest.py:8-10` and
   `assets/moth/map-variety-20261003/candidate-v2/manifest.json` declare
   `OpenGL +Y; image rows down, UV v up`. The binding's normal `scale` survives
   as a glTF normalTexture scale. `map_variety/export_audit.py:152-160` requires
   decoded source/export normal pixels to match, without a green flip.
3. The **installed 4.5.14 Blender exporter source**, SHA-256
   `884ba7f2691f1c69874c148a3058791b0621740dc5c7123799f6785fc3c87fa7`,
   `io_scene_gltf2/blender/exp/primitive_extract.py:1413-1425`, writes
   `uvs[:,1] *= -1; uvs[:,1] += 1`. Its `:1494-1522` writes XYZ from Blender
   loop tangents and W from `loops.bitangent_sign`. Its `:1523-1535` only
   negates that sign for a negative **skinning/object** transform determinant;
   the comment explicitly says no change for Z-up -> Y-up. No UV-flip sign
   adjustment appears on this path. glTF 2.0 Specification
   [§3.7.2](https://github.com/KhronosGroup/glTF/blob/main/specification/2.0/Specification.adoc)
   defines `TANGENT.w` as basis handedness (around lines 1602/1640) and
   [§3.9](https://github.com/KhronosGroup/glTF/blob/main/specification/2.0/Specification.adoc)
   defines (0,0) at image upper left (line 2267). Do not confuse the proper
   Z-up/Y-up axis rotation with the separate UV V reflection.
4. X source GLB stores the resulting UVs/T/W; AA's approved compiler changes
   only five BIN bytes in the three exclusive saltstone tangent records.
   Astra `8f166beb:.../botanical-parallax-aa-diagnosis/{source-census.json,summary.json}`
   measures **150,686** nonzero-area/full-rank UV faces (= 452,058 corner
   occurrences): **452,050** stored W signs disagree with the glTF UV-derived
   basis; **452,048** stored `cross(N,T)*w` binormals oppose increasing glTF V.
   Five tangents oppose increasing U; **4,867** faces have undefined UV rank
   for this calculation. X has 452,053 sign disagreements; AA removes three
   on face 11823. The census does not compare the entire source to Blender
   shading nor establish a MikkTSpace solution at every smoothing seam.
5. Godot `4.5.2-stable` [glTF importer](https://github.com/godotengine/godot/blob/4.5.2-stable/modules/gltf/gltf_document.cpp#L4905-L4913)
   sets the normal texture and scale on `BaseMaterial3D`, with no explicit
   green inversion there. Its [material shader generator](https://github.com/godotengine/godot/blob/4.5.2-stable/scene/resources/material.cpp#L1740-L1747)
   assigns sampled RGB directly to `NORMAL_MAP`. Both [GLES3 compatibility](https://github.com/godotengine/godot/blob/4.5.2-stable/drivers/gles3/shaders/scene.glsl#L1950-L1955)
   and [RD forward](https://github.com/godotengine/godot/blob/4.5.2-stable/servers/rendering/renderer_rd/shaders/forward_clustered/scene_forward_clustered.glsl#L1358-L1367)
   decode `normal_map.xy = normal_map.xy*2-1` and apply **positive**
   `binormal * normal_map.y`; both reconstruct the binormal from N/T and the
   sign (GLES3 `:531-546`, RD `:698-726`). No compensating shader green
   inversion is present in those cited paths. This is a source-code prediction
   of the direction of the perturbation, **not an AA render measurement**.

### Small actual-source examples (mesh-local, not new native claims)

For each example below, `w_d` is the sign computed from its actual glTF
positions, normals and TEXCOORD_0; `w_s` is the X stored sign. Faces have
nonzero area and UV determinant; `dot(T,projected dP/du)` is approximately +1.
All but sea bind a nonflat normal texture on UV0. Mesh index/face number are
zero-based. This intentionally spans kit/accepted-craft, curved/flat and
untextured cases, without rerunning the full census.

| Role | Mesh:face | `w_s / w_d` | `dot(Bstored,dP/dv)` | glTF normal scale |
| --- | ---: | --- | ---: | ---: |
| parallax.etch | 0:10 | -1 / +1 | -0.9991 | 0.25 |
| metal | 2:0 | -1 / +1 | -1 | 0.30 |
| ochre | 4:0 | -1 / +1 | -1 | 0.30 |
| paving | 7:4 | +1 / -1 | -1 | 0.45 |
| saltstone | 9:0 | +1 / -1 | -1 | 0.40 |
| sea (no normalTexture) | 10:0 | -1 / +1 | -1 | n/a |

Saltstone face **11823**, `N=(0,+1,0)`, `dP/du=(+1,0,0)`,
`dP/dv=(0,0,+1)`, has `UVdet=-0.04529086293041473`. X records
`[(0,0,0,+1),(+1,0,0,+1),(+1,0,0,+1)]`; AA records
`[(+1,0,0,-1)]×3`. `cross(N,T)` is **-Z**, so X's two usable `w=+1`
corners pointed green toward -Z, while AA's three `w=-1` point it toward
increasing glTF V (+Z). This *local* math validates the approved three-corner
derivation; it does not prove all surrounding pixels' authored appearance.

The saltstone X embedded normal PNG is decoded-pixel **identical** to Moth
`candidate-v2/textures/salt-limestone-normal.png` (source SHA-256
`203df36b390f61ce7e7a7801c1677637da1ce44ddd61ed4246572a7acf9593b6`).
Of its 512×512 green samples, 131,154 are <128, 109,931 are >128 and 21,059
equal 128 (range 48–209); normal scale is 0.4. Thus the mismatch acts on
nonconstant green data; equal pixels **exclude a silent exported G inversion**,
but not lighting-dependent concealment. Ochre's same-sized normal has green
range 104–149 and scale 0.3; sea has no normal texture, so the same UV/T sign
metric is not a normal-map appearance claim for sea.

## Boundaries and next review question

The AA03/AA04 imported arrays are byte-identical to each other. Astra's
node-scoped census finds 155,521/155,553 strictly equivalent native faces and
32 faces / 16 unique wayfinding records affected by **singular N-parallel-T
conversion**. The near-global glTF V/handedness discrepancy is **already in
X**, mostly preserved by Godot, and is not the AA strict-native failure.
`ensure_tangents=false` cannot correct those source bytes. The approved
three-corner saltstone edit is not revoked or broadened by this investigation.
The 4,745 records with `abs(dot(N,T))>.001`, 16 remaining parallel records,
five reversed-U corners and UV-rank failures are separately scoped; a uniform
flip of W cannot make them a valid tangent field.

**Preferred next scope:** independently review a *source-only* cross-application
normal-map/basis convention contract before authorizing any wider repair. Pin a
minimal full-rank normal-mapped fixture through Blender's exported UV/T and
Godot's shader math; compare source Blender shading semantics to glTF +Y and
decide whether to preserve the existing visual design or re-author both basis
and textures under a new identity. Require per-role/per-node bounds, Mikk/seam
handling, singular/orthogonality policy and a distinct native/render review.
A green inversion would mathematically counter a binormal reversal for some
full-rank surfaces, but contradicts the documented pack convention and would
change immutable material channels. A wholesale W flip likewise breaks the
already-correct AA face and undefined/degenerate cases. Neither is proposed
here. Do not make a new artifact, weaken native acceptance or promote X/AA on
this source-only report.

Read-only pinned Godot source SHA-256: importer
`be5cd97ad0530eef4597240daa9012eed23847b39d8ebc8cc5333161ccb6951e`,
material generator `d3a2778650924f51f1b228f4a61f2b0fce7e177784f2ac5b32a2ce2bc66c7c9f`,
GLES3 scene `2c35e86c547cacc463c8835621430256aabc05d46c1a3f1783312e7a71d47141`,
RD scene `0e485aba3d4ac488f4f9778075d09dcda2679c700adb51a86975734e446d9d05`.
These URLs were read as source; no Godot or Blender process was started.
