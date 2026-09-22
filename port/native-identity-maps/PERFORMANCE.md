# Performance — collision cost fixed, materials/effects delivered, hardware still unproven

Pinned Godot 4.5.2.stable.official.6ce3de25a; Compatibility/OpenGL 4.5, Mesa 25.2.8,
**llvmpipe (LLVM 20.1.8, 256 bits) — software rasteriser, no `/dev/dri` device in this
environment**. Every cadence number below is llvmpipe. None of it is GPU, packaged-build or
60 Hz acceptance. The owner-side hardware gate is still OPEN.

## 1. Deliverable 1 — cold Match construction

The prototype passed one collision wall per visible art triangle through the source
wall-segment mover, which is a linear scan per obstruction query. Measured cold
`createIdentityMatch` on this host before this pass (retained in
`evidence/graybox-final-fixed.log`): **6,059.3 / 2,950.3 / 14,827.7 ms**.

Now (`node port/native-identity-maps/perf.mjs`, fresh process, one map per load):

| Map | Cold Match ms | Warm Match ms | Prototype cold ms | Speed-up | `navigation()` ms | Wall entries | Wall segments | Art triangles | Collision triangles |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Lacuna Court | 27.4 | 5.6 | 6,059.3 | 221× | 16.7 | 20 | 40 | 5,464 | 34 |
| Vermilion Fold | 19.4 | 7.0 | 2,950.3 | 152× | 5.8 | 0 | 0 | 7,980 | 2 |
| Nacre Engine | 39.2 | 7.1 | 14,827.7 | 378× | 32.9 | 168 | 504 | 8,112 | 254 |

Target was ≤1,500 ms with a 3,000 ms hard ceiling: **met with roughly 40× margin**. `graybox.test.mjs`
now asserts the ceiling, a 2,000-segment budget and "at least 10× better than the prototype" per map on
every run (36,989 checks, 0 failures).

How, without touching locked source and without invisible support:

1. **Everything ground-level is an exact box.** Boundary walls, spawn pockets, dividers, resonator
   masses, pavilion retainers, the Nacre housing and its service organs are `arena.blocks`, which the
   source answers through its own BVH — no wall scan at all.
2. **Authored coarse wall polygons** replace triangle soup: planar face quads, end trapezoids, caps
   and two-point movement fences. Each entry is authored from the same parameters as the visible mass
   it stands for, and `artNotes[]` in each recipe records, per form, why it has no collision of its
   own (for example: the Lacuna resonator arcs stand on a 5×9×4.5 m exact block and the visible band
   above it is above every reachable eye).
3. **`arena.nextGen` = true** (the existing source navigation mode, the same one the native DM
   arenas use): spatial-grid edges plus largest-component pruning. Vermilion needs no walls at all —
   every one of its visible forms is above 3.7 m, and a standing eye is 1.45 m with a jump apex of
   1.50 m.
4. **Render geometry is never simplified.** `recipe.art[]` holds the exact triangles; `map.gd`
   renders it without giving it physics, and builds Godot colliders from blocks, floors and the same
   authored walls the source answers rays with.

Residual, bounded and declared:

* Nacre's vault feet are leaned proxies that follow the ellipse within 5 cm, and the rib above
  4.5 m is not collision (1.5 m above the highest reachable eye).
* Lacuna's resonator band is covered 4.45–6.0 m above the plinth top by two coarse quads per
  resonator; the arch opening and everything above 6 m are intentionally open.
* Vermilion's folded sheets are deliberately non-collidable: measured lowest visible vertex 3.7 m
  (ivory tension foot) against a 2.97 m reachable eye ceiling. The prototype's exact-triangle walls
  did block them; that is a *documented, declared* removal of cover from decoration, not an
  accident, and the audit below proves no reachable eye ray changes verdict.

## 2. Parity evidence for the simplification (deliverable 1's acceptance)

`ray-oracle.mjs` now audits two different questions and writes both to evidence:

* **source vs prototype-exact** (`exactArena()` rebuilds one-wall-per-art-triangle from the same
  visible triangles): blocked/unblocked must agree. Result over 19,976 rays: **0 classification
  mismatches, 0 `visible()` mismatches, 0 reachable-visible-mass probe misses**, with 448 knife-edge
  rays flagged (they flip verdict under a 4 mm / 0.03° perturbation) and their 104 implementation
  divergences counted separately rather than hidden.
* **source vs Godot physics** (`godot/tests/identity_maps/rays.gd`): distance parity at 2 cm for
  cover faces and route floors, classification parity for sightlines/eye grid. Result:
  **19,976 checks, 0 failures, max hit delta 2.1e-6 m**, 448 grazing rays reported.

Group detail (source-verified): block-cover 86 rays, wall-face 276, route-floor 231, sightline
1,543, eye-grid 17,840 over the three maps.

## 3. Render cost and cadence (llvmpipe, static inspection cameras)

Five fixed cameras per map, 12 warm-up frames and 40 cadence samples each, one shadowed directional
key, glow off, no actors and no HUD. Medians are sample 20 and p95 is nearest-rank 37. Filled from
`evidence/render-final-1790085699477045605/` (15 PNGs per size, all dimensions asserted) and
`evidence/render-glow-1790085839420647575/`.

| Map | Triangles | Material cells | Build ms | Median ms 960×640 | Median ms 1280×800 | Median ms 1920×1080 | Max draw calls | Texture bytes |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Lacuna Court | 5,714 | 71 | 21–24 | 23.2–32.7 | 28.2–42.9 | 39.5–71.9 | 323 | 106,496 |
| Vermilion Fold | 8,150 | 66 | 23–25 | 24.4–31.4 | 28.4–42.9 | 38.6–61.3 | 291 | 100,352 |
| Nacre Engine | 8,498 | 94 | 28–31 | 33.2–37.6 | 39.0–45.3 | 59.7–69.6 | 430 | 99,328 |

p95 at 1920×1080 is 43.6–75.4 ms across all fifteen cameras. Compare with the prototype's flat
five-material pass, which reported 1920×1080 p95 15.7–22.5 (Lacuna), 14.6–24.7 (Vermilion) and
26.3–52.6 (Nacre): this pass is **2–3× heavier on the software rasteriser**, which is the honest
cost of triplanar Moth textures, a real sky with linear fog, a render-only horizon and the bounded
effect pools. llvmpipe is CPU rasterisation and is disproportionately sensitive to texture sampling,
fog and alpha blending, so the ratio will not transfer to a discrete GPU unchanged — but it has not
been measured there and is not claimed.

Texture bytes are the unique Moth tiles a map references (48–64 px each), counted once per resource
by `contract.gd`: three orders of magnitude under the 32 MiB budget. Honest texel density: with
`repeat_scale` 0.3–0.8 the triplanar coordinates repeat every 1.25–3.3 m, i.e. **19–51 texels per
metre** of surface — enough for a 64 px tile to read as material, never enough to read as text or
fidelity detail.

**Real existing-playable-map baseline under the same harness**
(`godot/tests/identity_maps/baseline.gd`, same 12+40 sampling, same resolutions, each map's own
builder and atmosphere; 10 PNGs per size with asserted dimensions):

| Map | Median ms 960×640 | Median ms 1280×800 | Draw calls | Primitives |
|---|---:|---:|---:|---:|
| cinder-array (shipped native DM) | 20.6–23.3 | 31.4–35.3 | 250–353 | 62.8k–68.4k |
| prism-foundry (shipped native DM) | 84.4–110.8 | 94.9–166.7 | 368–627 | 173.6k–195.7k |
| identity maps (this lane) | 23.2–37.6 | 28.2–45.3 | 176–430 | 22.4k–45.5k |

So the three new maps sit between the two shipped maps on the software rasteriser: heavier than
cinder-array by roughly 5–15 ms, and 2–4× lighter than prism-foundry. That is a cadence comparison,
not a 60 Hz claim: llvmpipe is CPU rasterisation and no discrete GPU was used.

**Glow A/B** (`--glow`, 960×640, all three maps): enabling `Environment.glow_enabled` adds 1.0–3.0 ms
to each camera (roughly 5–10 %). Every delivered image is glow-off and the composition is authored to
read without it; glow remains an optional quality setting, never a requirement.

## 4. Signature effects (deliverable 3)

One bounded GPUParticles3D pool per map, one shared draw shader and draw material per map, one
process material per emitter, fixed seeds, `visibility_aabb`, a throttled (4 Hz) camera distance
gate, focus-loss and tree-pause suspension, `reset()` for round boundaries, zero textures, zero
per-frame allocation and zero gameplay authority (`signature_fx.gd`).

| Map | Emitters | High allocation | Low allocation | Budget | Effect |
|---|---:|---:|---:|---:|---|
| Lacuna Court | 6 | 2,560 | 700 | 32,768 / 8,192 | copper seam shimmer on both resonators, localised dust in the four quiet lanes |
| Vermilion Fold | 6 | 650 | 190 | 32,768 / 8,192 | light sheets drifting inside the opaque crown/fan/pleat volumes (all ≥6 m), faint tension breathe |
| Nacre Engine | 7 | 2,450 | 690 | 32,768 / 8,192 | sparse suspended vault motes, two bounded one-shot pressure pulses around the drum |

`contract.gd` re-checks the Low/High budgets, the emitter bound and `gameplay_authority == false` on
every run. Nothing is a ground ring, beacon, projectile or pickup silhouette: motes are ≤0.1 m, the
sheets live inside opaque ribbons, the pulses are one-shot bursts 8–11 m above the drum, and no
emitter sits at ground level on an objective point.

## 5. Still OPEN (not proven here)

* No hardware GPU, no packaged Windows build, no driver timings; llvmpipe only.
* No actor/particle concurrency at peak Horde load, no boss/endless frame test.
* Cold shader stalls are not isolated; `build_ms` is map construction, not first-frame compilation.
* Frame cadence numbers come from static inspection cameras, not live play with operators/HUD/audio.
* Lightmap baking, occlusion and LOD comparisons remain unproven; no bake was attempted.
* The baseline comparison covers two shipped DM maps at one or two resolutions, not the whole
  catalog, and camera poses are derived fixtures rather than the shipped camera set.
