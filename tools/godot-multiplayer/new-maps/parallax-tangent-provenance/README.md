# Parallax AA: inherited UV / tangent / normal-map provenance (source-only)

Base `5916bc68`, branch `sol/parallax-tangent-provenance`. This traces the
**broader raw source census**, separately from Astra's `8f166beb` analysis of
the 16 singular wayfinding vertices. No artifact, engine, import, shader,
material, acceptance gate or original receipt was changed. All observations
below use pinned X `6356cf895c65cec181e1c6c077118b98f3ee80cb567955b37835433971342422`
and AA `95e9da98a45565ca2aae90858a9e5027d9123e4ffd1347da98d5de8573141cd5`.

## Finding

**Near-global disagreement with a raw exported-UV derivative basis:** X/AA
glTF `TEXCOORD_0` uses Blender's `v_glTF = 1 - v_Blender` while exported
`TANGENT.w` retains Blender's loop `bitangent_sign` on the unskinned path.
Consequently `dP/dv_glTF = -dP/dv_Blender`, but the supplied bitangent is not
negated. This explains Astra's derivative-sign census; it does **not** prove a
source convention error or a bad normal-map appearance. Blender also reads
PNG rows into an internal *bottom-up* image buffer. `v_Blender` and
`1-v_Blender` in the respective image-coordinate systems address the **same
original PNG row**. Retaining the authored bitangent with unchanged normal-map
green therefore can retain the authored world-space +Y perturbation in Godot.
The pack declaration `OpenGL +Y; image rows down, UV v up` is compatible with
that pair of conversions. A raw UV derivative, image address and supplied
normal-map shading basis are distinct quantities. This finding does not cover
the 16 singular-glyph native failures, five opposite-U tangents or 4,745
nonorthogonal records; those need separate treatment and are not thereby
validated.

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
   adjustment appears on this path. The corresponding **Blender 4.5.14 image
   reader** [openimageio_support.cc:118-128](https://github.com/blender/blender/blob/v4.5.14/source/blender/imbuf/intern/oiio/openimageio_support.cc#L118-L128)
   begins at the last destination row and calls `read_image` with a negative
   row stride; a top-down PNG is stored bottom-up in `ImBuf`. The
   [Blender Normal Map shader](https://github.com/blender/blender/blob/v4.5.14/source/blender/gpu/shaders/material/gpu_shader_material_normal_map.glsl)
   forms `B = tangent.w * cross(N,T)` and combines
   `texnormal.x*T + texnormal.y*B + texnormal.z*N` (subject to its front-face,
   negative-object-scale and strength handling). This establishes the missing
   image/basis half of the provenance chain. glTF 2.0 Specification
   [§3.7.2](https://github.com/KhronosGroup/glTF/blob/main/specification/2.0/Specification.adoc)
   defines `TANGENT.w` as basis handedness (around lines 1602/1640) and
   [§3.9](https://github.com/KhronosGroup/glTF/blob/main/specification/2.0/Specification.adoc)
   defines (0,0) at image upper left (line 2267). For supplied glTF tangents,
   derivative alignment is not by itself a test of authored appearance. Do
   not confuse the proper Z-up/Y-up rotation with image-origin conversion.
4. X source GLB stores the resulting UVs/T/W; AA's approved compiler changes
   only five BIN bytes in the three exclusive saltstone tangent records.
   Astra `8f166beb:.../botanical-parallax-aa-diagnosis/{source-census.json,summary.json}`
   measures **150,686** nonzero-area/full-rank UV faces (= 452,058 corner
   occurrences): **452,050** stored W signs disagree with the glTF UV-derived
   basis; **452,048** stored `cross(N,T)*w` binormals oppose increasing glTF V.
   Five tangents oppose increasing U; **4,867** faces have undefined UV rank
   for this calculation. X has 452,053 sign disagreements; AA removes three
    on face 11823. **These counts compare to increasing exported V, not to
    the authored bottom-up image or its supplied shading basis.** The census
    does not compare source to Blender shading nor establish MikkTSpace at
    every smoothing seam.
5. Godot `4.5.2-stable` [glTF importer](https://github.com/godotengine/godot/blob/4.5.2-stable/modules/gltf/gltf_document.cpp#L4905-L4913)
   sets the normal texture and scale on `BaseMaterial3D`, with no explicit
   green inversion there. Its [material shader generator](https://github.com/godotengine/godot/blob/4.5.2-stable/scene/resources/material.cpp#L1740-L1747)
   assigns sampled RGB directly to `NORMAL_MAP`. Both [GLES3 compatibility](https://github.com/godotengine/godot/blob/4.5.2-stable/drivers/gles3/shaders/scene.glsl#L1950-L1955)
   and [RD forward](https://github.com/godotengine/godot/blob/4.5.2-stable/servers/rendering/renderer_rd/shaders/forward_clustered/scene_forward_clustered.glsl#L1358-L1367)
   decode `normal_map.xy = normal_map.xy*2-1` and apply **positive**
   `binormal * normal_map.y`; both reconstruct the binormal from N/T and the
   sign (GLES3 `:531-546`, RD `:698-726`). No compensating shader green
    inversion is present in those cited paths. That is **consistent with**
    Blender's retained +Y bitangent and unchanged sampled green after the
    paired UV/image-origin conversion. It is not an AA render measurement or
    proof of full renderer equivalence.

### Asymmetric image-address and shading counterexample

Consider a Blender plane `P(u,v)=(u,v,0)`, `N=+Z`, `T=+X`, `w=+1`, hence
`B=+Y`. For a top-down PNG with distinct rows, Blender's bottom-up image at
`v=(height-row-1/2)/height` reads original PNG `row`; the glTF top-down image
at `v'=1-v=(row+1/2)/height` reads **that same row**, without changing green.
An asymmetric sample with `G>128` produces a +Y world-space perturbation in
Blender. Exporting `v'` with the *supplied* `w=+1` produces +Y in the glTF /
Godot source-shader equations as well. But `dP/dv'=-Y`, so a naive derivative
test reports `w_derived=-1`; flipping **only** W would turn the same sample's
perturbation toward -Y. `test_provenance.py` checks four different rows and
three columns with nonneutral R/G, source addressing and normalized vector parity,
while rejecting either solitary flip and the wrong image row. This is an
analytic CPU/source contract, **not a Blender or Godot rendering test**.

### Small actual-source examples (mesh-local, not new native claims)

For each example below, `w_d` is the sign computed from its actual glTF
positions, normals and TEXCOORD_0; `w_s` is the X stored sign. Faces have
nonzero area and UV determinant; `dot(T,projected dP/du)` is approximately +1.
All but sea bind a nonflat normal texture on UV0. Mesh index/face number are
zero-based. This intentionally spans kit/accepted-craft, curved/flat and
untextured cases, without rerunning the full census. The table is a **raw
derivative comparison only**, not a finding of wrong authored shading.

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
corners point green toward -Z, while AA's three `w=-1` point it toward
increasing exported V (+Z). **AA matches the approved derivative-basis
policy, but its sign change also reverses the normal-map green contribution
on those corners versus the usable X basis.** No source evidence here proves
that reversal preserves the authored appearance; X's two nonzero `w=+1`
corners may have preserved the authored bitangent/texture relationship. The
approved AA patch and its native closure are historical facts, not reversed
by this source finding; appearance preservation warrants separate review.

The saltstone X embedded normal PNG is decoded-pixel **identical** to Moth
`candidate-v2/textures/salt-limestone-normal.png` (source SHA-256
`203df36b390f61ce7e7a7801c1677637da1ce44ddd61ed4246572a7acf9593b6`).
Of its 512×512 green samples, 131,154 are <128, 109,931 are >128 and 21,059
equal 128 (range 48–209); normal scale is 0.4. These are nonconstant green
data; equal pixels exclude a channel rewrite **but do not establish an
incorrect basis**, since image addressing and UV origin also change. The
local AA sign change can affect these samples when the face is visible.
Ochre's same-sized normal has green
range 104–149 and scale 0.3; sea has no normal texture, so the same UV/T sign
metric is not a normal-map appearance claim for sea.

## Boundaries and next review question

The AA03/AA04 imported arrays are byte-identical to each other. Astra's
node-scoped census finds 155,521/155,553 strictly equivalent native faces and
32 faces / 16 unique wayfinding records affected by **singular N-parallel-T
conversion**. The near-global *raw derivative* discrepancy is **already in
X**, mostly preserved by Godot, and is not the AA strict-native failure.
`ensure_tangents=false` cannot correct those source bytes. The approved
three-corner saltstone edit is not revoked or broadened by this investigation.
The 4,745 records with `abs(dot(N,T))>.001`, 16 remaining parallel records,
five reversed-U corners and UV-rank failures are separately scoped; a uniform
flip of W cannot make them a valid tangent field.

**Preferred next scope:** review a small **source-only appearance-preservation
contract**: at corresponding decoded PNG sample locations, compare authored
and supplied-basis world-space perturbations (with explicit normal strengths,
image origin, UV transforms and material selection), *before* proposing any
wider tangent or texture change. Include an asymmetric full-rank fixture,
smoothing/seams, nonorthogonal frames, and the AA face 11823 before/after; a
future controlled render would still be needed for appearance acceptance.
Keep the separately reviewed singular-glyph fallback scoped to the **actual
native-invalid N-parallel-T records**; its policy does not depend on reversing
the near-global raw derivative signs. Neither a wholesale W flip nor a green
flip follows from this census. Do not make an artifact, weaken native
acceptance, or promote X/AA on this source-only report.

Read-only pinned Godot source SHA-256: importer
`be5cd97ad0530eef4597240daa9012eed23847b39d8ebc8cc5333161ccb6951e`,
material generator `d3a2778650924f51f1b228f4a61f2b0fce7e177784f2ac5b32a2ce2bc66c7c9f`,
GLES3 scene `2c35e86c547cacc463c8835621430256aabc05d46c1a3f1783312e7a71d47141`,
RD scene `0e485aba3d4ac488f4f9778075d09dcda2679c700adb51a86975734e446d9d05`.
These URLs were read as source; no Godot or Blender process was started.
Blender image-reader SHA-256 and shader SHA-256 are pinned in
`provenance-sources.json`, along with the regression command and its scope.
