# Exported world-weapon silhouette baseline

`before.json` measures the **ten actual third-person GLBs** in
`godot/source_operators/generated/world_weapons/`, before subsequent exporter
identity changes. `before.svg` is the corresponding fixed-scale side/top sheet.
The script reads the manifest only for file names and display labels; geometry
and SHA-256 hashes come from the GLB bytes. It does not export or regenerate
anything.

From the repository root, to reproduce the baseline (overwriting only these
two files):

```sh
node port/native-world-weapon-identity/silhouette-report.mjs \
  --output port/native-world-weapon-identity/before.json \
  --svg port/native-world-weapon-identity/before.svg
```

After an exporter change, write a separate comparison report:

```sh
node port/native-world-weapon-identity/silhouette-report.mjs \
  --output port/native-world-weapon-identity/after.json \
  --svg port/native-world-weapon-identity/after.svg
```

The script needs Node.js only (no rendering engine or color sampling). It
parses each GLB's embedded mesh POSITION and triangle indices in all scene
nodes, applies node transforms, and fills projected triangle unions at pixel
centers. Side projects `(z,y)` along X; top projects `(z,x)` along Y; stock is
+Z and muzzle is -Z. Both views use a **fixed 0.01-world-unit cell**, same
origin and resolution for every weapon (220×120 side, 220×110 top). Geometry
outside this grid raises an error rather than being silently clipped. Masks
include every material batch, and ignore material, color, and texture. The
`pixelExtents` coordinates are `[minInclusive, maxExclusive]` in the mask grid;
`bounds` are transformed 3D vertex extents, while `areaWorldSquared` is
projected covered-cell area. Empty and unsupported GLBs raise errors.

Every one of the 45 unordered pairs has side and top `iou`, `differentPixels`,
`differingFractionOfGrid` (XOR / total canvas pixels), and
`differingFractionOfUnion` (XOR / either silhouette). A high IoU indicates
similar geometry. The minimum grid difference measures the least visibly
changed coverage at the fixed scale, including weapon size. The union
fraction is `1 - IoU` (up to rounding). Transparent gaps inside the projected
meshes remain gaps; this is a shape comparison rather than a material or
shading comparison. World-distance readability is a separate measurement.

Baseline (45 pairs):

| View | Mean IoU | Maximum IoU (closest pair) | Minimum changed pixels / canvas | Minimum XOR / union |
| --- | ---: | ---: | ---: | ---: |
| Side | 0.604606 | 0.819627 (Rail Lance / Marksman Rifle) | 454 / 26,400 = 0.017197 | 0.180373 |
| Top | 0.609312 | 0.817693 (Pulse Rifle / Marksman Rifle) | 305 / 24,200 = 0.012603 | 0.182307 |

The JSON also includes per-weapon GLB SHA-256, triangle/primitive counts,
3D bounds, and mask area/extents. Changes to the exporter will alter input
hashes and, if geometry changes, the silhouette metrics.

## Delivered silhouettes and contracts

This world-side pass follows the second-pass dominant motifs in the read-only
`port/native-weapon-detail/WEAPON_IDENTITY.md`, without changing the source
weapon assemblies or their muzzle/hand contacts:

| # | Weapon | World silhouette corresponding to first-person motif |
|---|---|---|
| 0 | Pulse | Slender open/perforated shroud, low spine, skeleton-stock rails |
| 1 | Rocket | Continuous fat tube, hollow front trumpet, rear venturi |
| 2 | Rail | Long separated accelerator sled, projecting fork, underslung battery |
| 3 | Scatter | Wide fore-end and twin bores, ventilated raised rib |
| 4 | Plasma | Two rounded axial bulbs, round flank exchangers, three-prong cage |
| 5 | Grenade | Squat flared/slatted drum, broad top strap and cylinder-side supports |
| 6 | Shock | Forward tuning fork, raised bridge, square capacitor comb |
| 7 | Flak | Boxy breech with trunnion discs, flank handle, flared hollow bell |
| 8 | Marksman | Long chassis spine, larger optic, folded bipod and butt monopod |
| 9 | SMG | Stub receiver, oversized hanging magazine, extended wire stock |

After regenerating exports with `node tools/godot-operators/world-weapons.mjs`,
regenerate `after.json`/`after.svg` as above, then run
`node port/native-world-weapon-identity/check.mjs`. The gate requires all 45
pairs and ten actual GLB SHA-256 hashes to agree with the manifest, unchanged
pinned muzzle/grip anchors, 3–4 draws, 1200–2500 triangles, and improvement
over the fixed baseline by >0.02 in worst-case IoU and >100 pixels in minimum
XOR, independently for side and top. `hand-clearance.json` is the read-only
existing exact triangle-distance audit of newly added geometry against both
hands (zero intersections); the 450 pose/grip fixture cases are checked by
`godot/tests/source_operators/grips.gd`.

`rendered/close-1280x800.png` is the near camera comparison of the ten
exported meshes held by operators; `rendered/silhouette-10m-1280x800.png` and
`rendered/silhouette-25m-1280x800.png` are actual identical-camera Godot
third-person-distance views, with `*-crop-*` enlarged display crops. The
distance views are intentionally small on screen: inspect the close sheet
for hardware and the 10m sheet for gameplay-scale legibility. All images were
rendered through `port/native-weapon-detail-world/tools/render.py` using a
private GL Compatibility project and the pinned Godot 4.5.2 binary.

| Metric across 45 pairs | Before side | After side | Before top | After top |
|---|---:|---:|---:|---:|
| Maximum IoU (closest pair) | 0.819627 | 0.728070 | 0.817693 | 0.768245 |
| Mean IoU | 0.604606 | 0.583217 | 0.609312 | 0.570843 |
| Minimum different pixels | 454 / 26,400 | 682 / 26,400 | 305 / 24,200 | 507 / 24,200 |
