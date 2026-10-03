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

## Visual correction after initial review

Initial Rootfall approach/eye views showed the preserved original facade enclosing
most of the authored additions. That revision is retained in `46249c57` and was
not treated as visual acceptance. Inspection of the original structure builder
showed the main closed walls sit inside the existing collision envelope. The same
named relief profiles are now seated in local depth ±0.475–0.495, within the
unchanged ±0.5 block boundary. Central through-components have front/back mounts;
the affine depth reflection preserves winding. Original facades, story/workshop
nodes, colliders, material roles, placement origins/scales and all chapter source
hashes remain unchanged. No authority change or placement enlargement was made.

Revised recipe: `e1cf8f039e1e6f33deee535bbfb34a652cafccde25835f7366f65d6f4d7a8c57`.
Final export count: 24; actual triangles across both LODs: **13,924** / 108,000 cap.
Rebuild, import, all 24 native comparisons, both independent reopen stages, generic
material receipt and injected lifecycle fixture passed for this revised recipe.

## Connected journey rendering limitation

Continuous llvmpipe rendering took roughly 0.225–0.554 seconds per inspection
frame. Actual Rootfall interactive attempts hit the untouched 250 ms input TTL:
public native traces showed source-epoch cancellation and pointer release after
fresh ordinary key input. Lower internal 3D resolution did not resolve it.
These failed runs are retained. The bounded journey now disables automatic
rendering **only**, continuing normal real-client processing/input/transport and
the untouched real-time authority. It explicitly draws at timestamped captures.
This is capture-paced gameplay proof, **not continuous rendered playability or
human/GPU feel acceptance**. Full-resolution art inspection remains a separate
normal render-loop run.

The first capture-paced Rootfall run (pre-relief correction) passed with 97 player
shot events, both nursery/canopy completion events, ACK 10438, 905 supported/clear
source position samples, zero blocked samples, return to start and clean native
campaign/Home exits. Final-asset runs are recorded separately.

## Follow-up prepared after the first exterior review

The initial exterior placement used the same front plane for every component.
That exposed coplanar stone/wheel faces in Siltwake. The next revision assigns
separate shallow material-depth bands while retaining the same authored X/Y
profiles, named components, topology and original block bounds. Its generated
recipe SHA is `f46577afcc7fd0c57086cbcb624454787df4f903f62e70cad8bba296fe22f90d`.

Actual exported PNG inspection also found linear palette values packed as sRGB:
Rootfall bark averaged RGB 21/17/10 instead of authored 81/74/56. A scenery-local
builder transfer encodes generated albedo to sRGB before packing. Normal maps
and the shared helper are untouched. `inspect_export.py --require-colors` checks
real exported nonflat PNGs against the authored swatches; the imported-material
lifecycle fixture checks actual Godot texture pixels, private material ownership,
wet/dry restoration, repeated clear and rebuild. These follow-up commands must
pass after rebuilding before the final handoff; earlier results do not substitute.

Process grant remains held until an explicit release record is written. No
package promotion or human-feel acceptance is implied by build/import success.
