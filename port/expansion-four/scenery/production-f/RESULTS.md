# Scenery grant F — actual production results

Asset/source commit: **`b320c270`**, following initial production checkpoint
`46249c57` and canonical parent `1f129ab2`.

## Produced and verified

- **12 editable Blender masters**, outside Godot; **314 named components**.
- **24 authored LOD GLBs**, **13,924 triangles** total against the unchanged
  108,000 triangle cap; 85 m automatic LOD switch and reduced-detail control.
- **118 texture PNGs and 118 import sidecars**, matching the actual GLB images.
- Recipe SHA-256:
  `f46577afcc7fd0c57086cbcb624454787df4f903f62e70cad8bba296fe22f90d`.
- Producer source fingerprint:
  `376c5c392bf54a94e16ec93cb39a973e1311a7d1bb4b75be20e411aeaf0f41b1`.
- Exact source/master/export/texture hashes: [final-assets.json](final-assets.json).
  Exact current package-input snapshot: [generic-receipt.json](generic-receipt.json).

Pinned Blender **4.5.14** and Godot **4.5.2**, serial nonwaiting stage lock,
`LP_NUM_THREADS=1`. All failed attempts and complete post-exit logs are retained.

## Actual checks

Build, both independent reopen stages, GLB reimport, generic receipt and all
**24 native imported-geometry comparisons passed**. The comparison consumes
every triangle using actual surface vertex/index arrays, with 1e-6 local-unit
vertex tolerance; it does not use Godot's snapped `get_faces()` representation.
Scenery import presets disable mesh compression.

All four chapters passed imported texture/color/tangent and material lifecycle
checks using the production weather binder: independent instance materials,
unchanged cached textures, exact dry restoration, clear/rebuild while leased and
clean teardown. Actual exported albedo averages match authored swatches within
**0.784 RGB levels**. UV streams are finite and noncollapsed; textures are nonflat;
normal maps remain selective. The scenery-local sRGB correction leaves the common
finisher and normal-map bytes untouched.

The explicitly **injected** negative atomic/lifecycle fixture passed separately.
It is not artwork proof. Actual absent-resource optional fallback was checked for
all four chapters before the first build.

Final source contracts: **6/6 geometry/clearance tests plus 4/4 journey contracts**.
The revised art preserves **8,337 route sweeps**, **2,827 clear route points**,
**10,117 visible approach rays**, and **eight reviewed shot windows**. Original
chapter hashes, placement bounds/IDs, facade bytes, terrain hook, robot visual
source, authority/core and shared production/package tooling remain unchanged.
The six Emberline robot props were counted, captured and checked for unchanged
instance identity/transforms across scenery lifecycle operations.

## Final native journeys

These use the real campaign scene, keyboard/mouse events, unchanged authority,
public ACKs and actual player-shot/workshop-completion events. No actor pose,
health, score, source clock or checkpoint state is written by the driver.

| Chapter/profile | Player shots | Final ACK | Clear samples | Workshops |
|---|---:|---:|---:|---|
| Rootfall wide | 80 | 10474 | 921 | nursery, canopy |
| Siltwake wide | 131 | 12385 | 1083 | waterwheel, ferry |
| Emberline wide | 106 | 16090 | 1399 | condenser, foundry |
| Crown wide | 98 | 10847 | 943 | choir, garden |
| Rootfall compact/UI150 | 91 | 10424 | 898 | nursery, canopy |

**5/5 passed**, zero blocked samples, all returned to the starting point, all
campaign and subsequent Home native processes exited 0 without forced termination
or detected resource leaks. [Exact summary](journeys-final/summary.json) and each
profile's complete logs, public witness, source poses, captures and hash manifest
are retained under `journeys-final/`.

### Rendering limitation

The renderer is **Mesa llvmpipe**, not a hardware GPU. Continuous full-resolution
inspection median frame times were **0.226–0.486 s**, with a maximum **0.528 s**.
Continuous interactive attempts exceeded the unchanged **250 ms input TTL**;
their failures and traces are retained. Final gameplay verification therefore
uses **capture-paced rendering**: the normal native input/transport and authority
continue in real time, with explicit draws at timestamped gameplay captures.
This proves the tested ordinary-input journeys, not continuous rendered
playability, GPU performance or human feel. Those remain review gates.

## Visual review evidence

The normal-render-loop inspection completed **164 captures** covering all four
chapters, wide/compact, approach/eye, scenery off/full/reduced, return-camera and
all six Emberline prop contexts. Full hashes/timings and retained source paths:
[inspection-final/manifest.json](inspection-final/manifest.json).

An additional **40 front-facing architecture captures** passed with clean native
exits. Viewpoints were selected from supported authored routes; these are staged
art views, not authority pose changes. All twelve full-detail assembly views and
the complete capture manifest are retained under `architecture-final/`.

| Chapter | Full detail | Original comparison | Reduced detail |
|---|---|---|---|
| Rootfall | [Full](inspection-final/rootfall-verge-after.png) | [Off](inspection-final/rootfall-verge-before.png) | [Reduced](inspection-final/rootfall-verge-reduced.png) |
| Siltwake | [Full](inspection-final/siltwake-crossing-after.png) | [Off](inspection-final/siltwake-crossing-before.png) | [Reduced](inspection-final/siltwake-crossing-reduced.png) |
| Emberline | [Full](inspection-final/emberline-ascent-after.png) | [Off](inspection-final/emberline-ascent-before.png) | [Reduced](inspection-final/emberline-ascent-reduced.png) |
| Crown | [Full](inspection-final/crown-array-after.png) | [Off](inspection-final/crown-array-before.png) | [Reduced](inspection-final/crown-array-reduced.png) |

The first builds exposed enclosed relief, coplanar layers and incorrect packed
albedo transfer. Those failures are documented in [README.md](README.md).
Corrections were rebuilt and independently reverified. Current relief stays within
the original collision envelopes, with separate material-depth bands; original
facades and workshop/route geometry remain intact.

## Parent handoff

Receipts remain **`accepted:false`**. Parent owns visual review, package promotion
and release acceptance. No requirements or validation gates were relaxed. The
current generic receipt binds **107 package inputs**; the additional complete
texture/import inventory is in `final-assets.json` for the package owner's closure
work. If that inventory contract changes, regenerate the input snapshot from the
actual files before refreshing the fixed receipt.

The actual fixed receipt was generated successfully at
`tools/godot-package/production_receipts/scenery.json`, SHA-256
`a2f0b0fe538e536724d10759f670a5fd50fbae6235cc61218e73f6b1d8ac935c`.
Runtime hooks bind `godot/campaign/terrain.gd` and
`godot/biomes/expansion/scenery_pack.gd`; promotion was not changed.

The global queue's original scenery triangle estimate (13,452) is now historical;
the actual revised total is 13,924. Global queue metadata was left parent-owned.
The explicit grant release and owned-process audit are recorded separately in
`HEAVY_GRANT_RELEASE.json` once all remaining owned stages have closed.
