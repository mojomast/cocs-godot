# Grant F actual scenery production

Explicit grant: `SCENERY-ASSET-PRODUCTION-20261003-F`, following vehicle E release
at `2026-10-03T00:49:06.525631Z`. Canonical `1f129ab2` merged before production.
This directory retains complete bounded-stage logs and process receipts, including
failed attempts. No nested agents or other unit production is involved.

## Corrections discovered in actual execution

- Initial whole-project editor import completed imports but crashed on shutdown;
  the subsequent scenery import exited cleanly. The crash log is retained.
- The actual absent-assets optional fallback passed for all four chapters before
  the first build. The injected atomic/lifecycle fixture also passed; its synthetic
  scenes are not artwork evidence.
- Representative Rootfall canopy export was inspected before bulk production:
  three textured surfaces, bound UVs and geometric normals, selective normal maps
  on bark/copper, no normal map on moss. Embedded images were extracted for review.
- All twelve assemblies / twenty-four authored LODs were produced. Blender masters
  retain named components. Both original and generic independent reopen ran.
- Native comparison exposed two sources of precision loss: default mesh compression
  and `ArrayMesh.get_faces()`'s TriangleMesh snapping. The scenery builder now
  writes `meshes/force_disable_compression=true`; all assets were rebuilt/imported.
  The native oracle reads the real surface vertex/index arrays and performs a
  one-to-one triangle comparison at 0.000001 local-unit vertex tolerance. All 24
  exports passed. Bounds, topology and source recipes were not changed.
- Rendered inspection explicitly uses Dummy audio because this host has no ALSA
  output device. The earlier fallback-to-dummy error run is retained as a failure.
- Rendering is Mesa llvmpipe software OpenGL, not a hardware GPU benchmark.

## Outstanding visual issue

Initial Rootfall approach/eye views show the preserved original facade enclosing
most of the authored additions. This is not a visual acceptance pass. Original
facades, story/workshop nodes and colliders remain intact. Review of placement
bounds may be required before enclosed architectural details can become visible.
No collision/authority change or unreviewed placement enlargement was made.

Process grant remains held until an explicit release record is written. No
package promotion or human-feel acceptance is implied by build/import success.
