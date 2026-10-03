# Parallax Observatory tangent successor — source-only production contract

**Prepared only; artifact/master identity null, native work not run.** Parent
baseline `33afe0ec` already contains reviewed post-X triangle proposal and
approved actual X Parallax/Foundry R7 histories. This directory is a separate
future revision, not a rewrite of X, an art approval, or a runtime promotion.
`queue.json` is informational and never starts work. Vesper post-X files remain
under Astra's ownership.

| Dependency | Exact SHA-256 |
| --- | --- |
| X GLB `botanical-correction/runs/x-03/parallax-observatory/parallax-observatory.glb` | `6356cf895c65cec181e1c6c077118b98f3ee80cb567955b37835433971342422` |
| X packed editable master `.../masters/parallax-observatory.blend` | `9957ca8cc3e4e7f2bca00f7b82a48ed88d031e9e3949259ebf5603f584141051` |
| Geometry authority, unchanged by the bounded patch | `3a5800e89876ebcc741381802def24415d5050651c0d3b831ea8b9ec3b77b4f9` |

## Exact change and gates

`contract.py` pins the input, original scene inventory (39 mesh primitives,
155,553 triangles, 14 materials), normal-mapped `saltstone` mesh
`art.accepted-craft.saltstone.001`, primitive 0, accessor 48, indexed face
11823, exclusive vertices **24049–24051**, and identity transform on that
mesh. The actual +X U / +Z V derivative on its +Y normal requires tangent
`[1,0,0,-1]` at **all three** corners. Vertex 24049 was zero; 24050/24051
had incorrect `w=+1`. Source-side validation proves one nondegenerate incident
face per vertex, 48 allowed entry bytes, exactly **five** changed BIN bytes,
no changed alias to another accessor/image, and exact whole-BIN equality
outside those entries. New asset/node revision metadata distinguishes the
successor. Everything else—including material images, indices and authority
streams—keeps the pinned X bytes. A different wholesale tangent regeneration
is outside this contract.

`editable.py` audits an actual future exported master against **every oriented
face** in world coordinates (including the X wayfinding TRS nodes), material
role, position/normal/UV, and triangle multiplicity. It imports the **frozen R7
`material_contract.py`** to compare decoded image channels, sampler wrap/filter,
normal/roughness, metallic, alpha and emissive semantics instead of equating
texture indices. A semantically equivalent resource-index remap can pass; an
actual saltstone clamp or optics emissive mutation fails. Source tests use
actual pinned X bytes solely in memory, with no candidate GLB written.

Under a **new exclusive grant**, `production.py` opens the pinned editable X
master in Blender 4.5.14 with one thread, embeds the exact recipe and compiler
as packed master text, saves a **new** master under `native/`, exports all 39
editable meshes to an intermediate GLB, audits that export, and *only then*
emits the canonical successor from pinned X bytes. Plain Blender glTF loop
tangents are an intermediate and cannot silently replace the approved repair.
A **separate fresh process** reopens the new master, verifies packed recipe and
compiler hashes/text, repeats the editable export audit and demands byte-exact
canonical GLB equality. Build/reopen reports and output hash belong to that
future authorized attempt. An invalid grant or missing dependency fails closed.

The future isolated `godot/tests/new_maps/parallax_tangent/` stage must copy
the new GLB and exact X authority/profile into test-only paths, pin the **new**
art hash, preserve the import sidecar UID with compression/LODs disabled, and
never bind the public catalog. `import.gd` records all native mesh surface
arrays and decoded material PNGs; `native.py` compares every oriented corner
and all three repaired corners to the exact output, enforces **zero** undefined
tangent waivers, checks R7-equivalent 14 material field sets (Godot 4.5.2 Color
precision), and compares decoded PBR channels. Import/field/pixel checks do
not alone assert native sampler equivalence: that is the editable source gate.
Native acceptance remains pending until the actual stage and report pass.

The subsequent grant should capture matched **X staged Parallax before** versus
**new tangent successor after**, using the same WorldMap/Binder/WeatherService
and production Weather lifecycle in an isolated stage, not the accepted legacy
runtime as before. Include a close saltstone view of the affected face plus
selected X cameras (arrival, archive, cistern, well; optionally all ten), and
label static llvmpipe frame cadence separately from gameplay FPS. Fresh targeted
aperture rays may recheck the unchanged geometry, while the 13,587 X capsule
placements remain **historical X evidence**, not a new run. A close-up may show
only subtle shading; native basis proof is the decisive technical gate. Manual
art review, hosted mode outcomes and any parent package decision remain later
steps.

Source-only check:

```sh
python3 -B -m unittest discover -s tools/godot-multiplayer/new-maps/parallax-observatory/revisions/districts-v4-tangent -p 'test_*.py' -v
```
