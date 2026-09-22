# Independently reproduced GLB material-side correction

Adapter `0149cbb` and evidence/tools `0af3c51` integrate `00191cc` / `16ef4dd`.
The lead reviewed clone isolation, winding/normals/tangents and the export hook,
then preserved the primary checkout's historical Meridian GLB before rebuilding.

```sh
python3 -B port/native-glb-side/verify.py \
  --output /tmp/opencode/lead-glb-side-independent \
  --original-glb /tmp/opencode/lead-glb-historical-baseline/world.glb \
  --chromium /tmp/opencode/cocs-native-ci-state/browsers/chromium-1187/chrome-linux/chrome
```

**PASS**. This directory retains exact command/process records, input/output
hashes, ten export reports, logical comparison, native import logs and four PNGs.

- Axis probe and all nine maps freshly exported through the integrated adapter.
- Six geometry tests, existing axis/instance import and nine native sky checks
  pass. Each map uses inward normals/triangles with ordinary back-face culling.
- **1,057 source/dependency/contract hashes unchanged** before/after.
- Meridian differs only in sky/haze index and normal accessors; positions,
  material resources, transforms, UVs and embedded images remain unchanged.
- All owned command/process groups cleaned up. Generated GLBs remain ignored.

The lead opened all four independent images. Historical before is byte-identical
to the original blank capture; historical after reveals the map under the same
camera/scene. Current stock viewer was already inside the sky and shows the map
in both cases, with the repaired interior sky/haze now visible. Hard boundaries
remain. This establishes the occlusion fix, not finished visual parity.

The export adapter changes private export clones only. Native renderer/camera
and the default procedural native skies were not changed. All prior failure
evidence remains retained. Whole-file GLB byte determinism is not claimed due
to asynchronous image-buffer ordering; logical resource comparison is explicit.

Two new combined gates exercise side geometry and the fresh Meridian import;
the all-nine side/import matrix remains in this focused report. The combined
**57-gate suite passes**. The native import fixture accepts optional
`--map=meridian-exchange` for CI (which generates that probe); its default still
checks all nine. Source rights and remaining material/fidelity findings are
unchanged by this technical repair.
