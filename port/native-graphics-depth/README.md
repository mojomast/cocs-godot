# Moth semantic depth priority — graphical correction

## Finding and classification

**Confirmed inherited priority-sign bug, corrected with a one-character shader change.**
In Godot **4.5.2 stable (`6ce3de25a`) Compatibility**, the actual coplanar raster
winner with the old subtraction is base priority **1**, regardless of surface
submission order. With addition, authored priority **2** wins in both orders.
This empirically supports the reviewer's reversed-depth sign concern; the test
does not claim to instrument the GL depth comparison function itself.

`godot/moth/surface.gdshader` changes only:

```diff
- DEPTH = FRAGCOORD.z - (vertex_tint ? UV.x * 0.000001 : 0.0);
+ DEPTH = FRAGCOORD.z + (vertex_tint ? UV.x * 0.000001 : 0.0);
```

Shader handoff: the positive bias is toward the camera for the pinned renderer;
higher authored UV priority must win exact coplanar overlaps. Preserve this sign
unless real raster evidence for the target renderer demonstrates otherwise.

The entire before shader is byte-identical to its introducing commit `a95f856`
(`feat(moth): restore baked assets and native triplanar surface runtime`), with
SHA-256 `75fa5655a520de2f1bfcc0bbcbff451935c8b45ce21ce36c8d430c5a63c281c1`.
The corrected shader SHA-256 is
`fc933e10c752395959a3d5da74c8d13b5b351ab44942ca0b2974df067985532a`.
Thus this is inherited behavior, not a regression introduced by the concurrent
graphics work. The evidence is a deliberate overlap fixture; it establishes no
observed overlap defect or visible improvement in the nine shipped maps. The
reviewer's prior nine-map centroid inspection reportedly found no such overlaps;
this lane did not repeat that survey.

## Real raster test

`godot/tests/graphics_depth/capture.gd` loads the **actual production shader**.
It uses the same relevant semantic vertex representation as
`godot/world/viewer.gd`: `SurfaceTool`, explicit source normals, `[2, 1, 0]`
triangle winding conversion, display-space `COLOR`, and `UV = (priority, 0)`.
Each paired surface has exactly the same positions and normals. The only layer
differences are known red/green vertex colors and UV priorities 1/2. Both surfaces
share one material, avoiding material sorting as a hidden priority mechanism.
Shadow casting is disabled, matching the viewer's semantic camera pass.

The six views combine distances **4, 40, 160** with plane slopes **0°, 35°** and
their corresponding explicit normals. Camera FOV is 60°, near/far 0.05/500.
Plane extent scales with distance to keep sufficient measurable pixels; depth
is genuinely evaluated at each stated camera distance. Default Moth texturing,
normal-map and LUT features are off, allowing unambiguous layer identification.
White ambient illumination is held constant.

Each resolution renders six modes:

1. Low-only red reference.
2. High-only green reference.
3. Low then high, priorities 1/2.
4. High then low, priorities 2/1.
5. Low then high, **both priorities 1**.
6. High then low, **both priorities 1**.

The last two are draw-order controls: the winner must change when order reverses.
The screenshots' general color legend names the normal authored roles; in these
explicitly named `equal-*` controls the green layer also carries UV priority 1.
Each overlap is checked at 81 interior pixels against independently rendered
single-layer references, also requiring the expected dominant color channel.
This is an image-based regression, not a mirror of the shader's arithmetic.

## Results and image acceptance

Tested with private Xvfb, OpenGL 4.5 Core / Mesa 25.2.8 /
llvmpipe LLVM 20.1.8 (256 bits), pinned Godot Compatibility renderer.

| Shader | Resolution | Priority-2 overlap cases | High / low sample pixels | Order controls | Exit |
|---|---|---:|---:|---|---:|
| Before, subtraction | 960×640 | 0/12 pass | 0 / 972 | pass | 1 |
| Before, subtraction | 1280×800 | 0/12 pass | 0 / 972 | pass | 1 |
| After, addition | 960×640 | 12/12 pass | 972 / 0 | pass | 0 |
| After, addition | 1280×800 | 12/12 pass | 972 / 0 | pass | 0 |

All before overlap centers are RGB8 **(229, 16, 4)**, matching low-only red.
All after overlap centers are RGB8 **(4, 216, 28)**, matching high-only green.
Equal-priority low-high is green and equal-priority high-low is red for every
distance/slope combination, before and after. Submission order really changes
the tie winner, but cannot mask the observed priority-sign result.

Directly inspected **all eight** before/after overlap screenshots (both orders at
both resolutions): before planes are consistently red; after planes are
consistently green, including the sloped row, with stable silhouettes and no
visible mixed-color overlap. Also directly inspected the after 960×640 equal
controls, confirming their red/green reversal. Pixel checks cover every saved
overlap/control image. Screenshots are native-size root viewport captures with
six graphical SubViewports, not resized images or complete game-map captures.

Representative evidence:

- [960×640 before, low-high](evidence/before/960x640/low-high.png)
- [960×640 after, low-high](evidence/after/960x640/low-high.png)
- [1280×800 before, high-low](evidence/before/1280x800/high-low.png)
- [1280×800 after, high-low](evidence/after/1280x800/high-low.png)
- [960×640 equal low-high](evidence/after/960x640/equal-low-high.png)
- [960×640 equal high-low](evidence/after/960x640/equal-high-low.png)

Every phase/resolution directory retains six PNGs, `results.json` (engine,
renderer, adapter, shader hash and per-case pixel counts), and `godot.log` with
the exact command and exit status. Expected before failures are preserved.
`evidence/setup-failure*/` additionally preserves two initial fixture parse-error
attempts caused by nonexistent Environment enum names, subsequently removed.
These setup failures produced no raster evidence. The successful graphical runs
only report the expected Xvfb VSync warning.

## Reproduction / aggregate-gate handoff

From repository root:

```sh
python3 port/native-graphics-depth/run.py verification --output /tmp/opencode/depth-verification
```

This runs both resolutions and returns nonzero if either raster test fails.
Use a fresh output directory to retain previous evidence. The recorded commands
were `python3 port/native-graphics-depth/run.py before` with the original shader,
then `python3 port/native-graphics-depth/run.py after` after the sign-only patch.
The phase label is descriptive; it never swaps or modifies the shader.

The runner uses the pinned binary at
`/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64`,
private `Xvfb -displayfd ... -screen 0 1280x800x24 -nolisten tcp -nolisten unix`,
isolated HOME and all XDG directories, dummy audio, and software GL. Xvfb uses
its private Linux abstract X11 socket. Temporary HOME/XDG files are cleaned on
exit. No project copy or worktree is required; checked-in evidence is about 1 MB.

This can be an **automated graphical gate under Xvfb**, but cannot be a meaningful
Godot `--headless` renderer regression: the fixture explicitly rejects headless
display mode. Do not substitute arithmetic assertions or a headless parse check
for these pixel results. Lead-owned aggregate gate integration is external to
this lane.

Acceptance is bounded to exact coplanarity, these normals/distances and the
specified Linux Compatibility stack. Hardware GL, other rendering backends,
near/far clipping extremes, subpixel edges, normal textures, nearly coplanar but
distinct geometry, shadows and complete map gameplay were not evaluated here.
