# Independent Meridian occlusion reproduction

Executed on primary at `70e9075dfb93a5cc25be8229d362d0e9f9a66835`:

```sh
python3 port/tools/meridian_visual_review/test_owned_process.py \
  --evidence /tmp/opencode/meridian-independent-cleanup.json
python3 port/tools/meridian_visual_review/run.py \
  --output /tmp/opencode/meridian-independent-render
python3 port/tools/meridian_visual_review/analyze.py \
  /tmp/opencode/meridian-independent-render \
  --glb godot/content/probes/meridian-exchange/world.glb \
  --original-image port/reports/meridian-glb.png
```

All exited 0. Four real ownership/cleanup tests pass, including a TERM-resistant
descendant timeout under private Xvfb and an unaffected unrelated sentinel.
All four graphical cases exited 0 with owned process groups absent. Their raw
logs, inventories, screenshots and provenance are losslessly archived here.

The new baseline PNG is byte-identical to the historical blank screenshot.
Numerical analysis confirms 2,976 outward sky triangles, 127 imported meshes,
camera distance 217.543 m outside the 185 m sky, unchanged inventories and a
single material culling change in the causal case. The lead directly inspected
the new `source-cull-only.png`: map buildings/ground/trees become visible, while
haze/sky boundaries remain visibly incorrect. This independently confirms the
source `BackSide` export-loss diagnosis, not production parity or a shipped fix.

The appropriate correction is in the export-only transformation described in
`port/meridian-visual-review/README.md`. Reserved exporter/preview work remains
pending; no camera workaround or source game change was introduced.

`index.json` records every archived file's SHA-256; extract into a fresh private
directory to inspect the complete experiment. `cleanup-tests.json` retains the
independent timeout/normal-exit test outcomes separately.
