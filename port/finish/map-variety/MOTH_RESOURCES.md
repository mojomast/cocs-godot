# New map Moth resource pack — 2026-10-03

## Multi-engine follow-up

The first pack's single-engine choice was insufficiently compared. The complete
32-engine catalog/contract review, controlled image/field/LUT trials and successful
2/4-job concurrency experiment are documented in [MOTH_ENGINE_REVIEW.md](MOTH_ENGINE_REVIEW.md).

`candidate-v2/manifest.json` remains the immutable base pack. The small
**`candidate-v3/manifest.json` additive overlay** supplies four useful image-engine
finishes, 20 additional PNGs (~2.67 MB), based on actual Deep Fryer and Teleblur
RGB outputs. It references the exact base manifest hash; it does **not** duplicate
the base pack. Schema is `moth-map-material-overlay/v1`: resolve inherited
resources from `basePack.manifest` and local keys from the overlay's `textures`.
The overlay's provenance paths resolve against `../engine-trials`.

Additional stable IDs: `copper-heat-oxide`, `etched-coating-haze`,
`quay-damp-horizontal`, `moss-warm-weather`. Their color is provider RGB decoded
from sRGB into linear space. Their relief explicitly mixes 90% authored structure
and 10% normalized provider luminance; this keeps geometric detail stable while
the image engines alter color. It is a heuristic, not recovered physical relief.

The overlay also declares `auxiliaryResources`: two measured Qpixl coverage masks
and two exact HDR/EXR/shader LUT companion sets. These have their own semantics
and hashes; do not register LUT parameter images as ordinary tiling albedo.

Use generic mothbake `69c62d7c4bd754340623a4a7fa93bfa970e5ab73` for this overlay,
with `MOTHBAKE_IMAGE_ROOT` pointing at that checkout. Keep the original
`MOTHBAKE_ROOT`/`6de1880` pin for the v2 rebuild. Example:

```sh
export MOTHBAKE_IMAGE_ROOT=/path/to/mothbake-at-69c62d7
node assets/moth/map-variety-20261003/engine-trials/bake-overlay.mjs /tmp/opencode/image-rebake
node assets/moth/map-variety-20261003/engine-trials/verify-overlay.mjs \
  assets/moth/map-variety-20261003/candidate-v3 /tmp/opencode/image-rebake
```

Overlay checks passed: 20/20 PNGs decoded/hashed and byte-identical on fresh
offline rebuild; contacts and manifest also byte-identical. Maximum base seam
ratio 0.593409; maximum normal-length error 0.005170. One coarse-mip warning is
retained. Sixteen auxiliary files also match their hashes and fresh rebuild bytes.
The final generic tool passed 372 Node tests and three Python tests.

## Consumer contract (candidate; Blender application follows parent review)

Delivered: **30 distinct base families, 6 derived finishes, 181 lossless PNG
channels**. Selected channel bytes: **24,199,501** (~23.1 MiB), excluding sources,
previews and archived provenance. **45/45 live jobs completed**: 30 selected
results plus 15 preserved superseded experiments. Catalog estimate: **45 credits**;
actual charged credits are unavailable. The request receipt records **229 requests
minimum**, including 45 job POSTs and 45 extra exact-body result GETs; unchanged
polls are not counted by the runner log, so an exact total is not claimed.

Resource root: `assets/moth/map-variety-20261003/`.
**Selected manifest: `candidate-v2/manifest.json`**, schema
`moth-map-material-pack/v1`. `candidate/` is preserved first-pass review evidence;
its `xy` engine settings caused checkerboard artifacts in 15 families. Those
families receive separately submitted `x`-only refinements, not overwritten jobs.

The manifest has `materials[]`, keyed `textures`, `sources[]`, `roleBindings`,
`channelRules`, and `pathBases`. It is intentionally not an assumed legacy
`MOTH_BAKED.textures` registry. Parent/Sol must adapt this actual schema after
review. No consumer registration or asset application is included here.

- Material ID: `terracotta`; channel key: `terracotta.albedo`.
- Resolve `material.channels.albedo` in `manifest.textures`, then resolve its
  `path` relative to the candidate manifest directory.
- Texture descriptors include SHA-256, exact PNG bytes, 512×512 dimensions,
  RGBA8 layout, semantic and color space. All base channels are opaque.
- Provenance paths resolve against the **resource root**, one level above the
  candidate. Exact engine params excluding the values array are inline;
  `values.path` + `values.field` resolve the exact input grid.
- IDs, not array positions or file glob order, are the binding contract.

## Channels and Blender authoring

All five base PNG channels are **linear**, including albedo. Set Blender image
color space to **Non-Color** for these files. Albedo connects directly to the
shader's linear base-color input. If exporting to glTF, its base-color image
encoding must be converted to sRGB by the next-stage exporter; do not simply
embed this linear PNG under glTF's sRGB base-color semantics. Contact sheets alone
are display-sRGB previews.

| Channel | Meaning |
|---|---|
| `albedo` | Restrained authored linear palette modulated by new provider result |
| `normal` | Linear tangent-space OpenGL +Y; image rows down, UV v up; Normal Map node |
| `roughness` | Linear scalar repeated in RGB; authored synthesis, not measured PBR |
| `height` | Linear 8-bit scalar detail; amplitude is `heightMeters`; not collision authority |
| `wear` | Linear synthesized mask: 65% transformed height, 35% authored mask |
| `fern-frond.alpha` | Separate RGB coverage mask; use red for alpha clip; opaque PNG alpha |

Each material gives `tileMeters`, `texelsPerMeter`, `heightMeters`, a density tag,
and macro/micro seed frequency. Default surface tiles cover 2 m (256 px/m), terrain
tiles cover 4 m (128 px/m), detail tiles cover 1 m (512 px/m); 3 m plaster/soot
tiles are ~171 px/m. Scale UVs from meters, not object bounds. Height amplitude is
already incorporated into normals. Do not multiply normal strength by pixel size.
Use actual geometry for grates, cornices, roots and openings; these are finishing
resources, not substitutes for editable authored master construction.

## Stable material catalog

| Resource IDs | Intended reuse |
|---|---|
| `aggregate`, `cast-seams`, `terracotta`, `lime-plaster` | Botanical architecture, viaduct masonry, industrial poured concrete |
| `oxidized-iron`, `copper-patina`, `ceramic-enamel`, `anodized-brush` | Foundry/Gravemill forge, Parallax instruments, Helix greenhouse fittings |
| `iron-grate`, `wet-soot`, `ribbed-steel` | Deep industrial casing, catwalk finish, damp mechanical recesses |
| `salt-limestone`, `basalt-strata`, `dune-sand`, `deep-silt`, `road-gravel` | Coastal roads, seabed and ore aggregate; heights are decorative inspiration |
| `moss-lichen`, `bark-fibers`, `leaf-veins`, `fern-frond` | Helix roots/bark, soil beds, fern cards and living surfaces |
| `frosted-glass`, `prismatic-etch` | Astral instrument etching and glass roughness; opacity is a consumer choice |
| `viaduct-asphalt`, `slate-shingle`, `cobble-sett`, `timber-weather`, `quay-waterline` | Vesper streets/shopfront surrounds and Stormglass quay construction |
| `sea-flow` | Cosmetic water detail/flow field; no simulation or collision claim |
| `trim-wear`, `decal-stencil` | Four horizontal trim bands; 4×4 stencil cells for calibration/wear masks |

Six additional finishes explicitly reuse their named base's new API result:
`masonry-coping` ← `trim-wear`; `shopfront-opaque` ← `ceramic-enamel`;
`optical-mirror-opaque` ← `anodized-brush`; `grotto-wet-rock` ← `basalt-strata`;
`pool-scum` ← `deep-silt`; `forge-steel` ← `ribbed-steel`.
They are derived variants, not six additional remote generations.

For cornice/stringcourse/coping/quoins/drip trims, `masonry-coping` and its height
and wear channels provide four UV bands, each `v=[i/4,(i+1)/4]`. Inset each band by
8 output texels for baking, keep longitudinal UV in meters, and author the actual
profiles in the editable Blender master. `decal-stencil` provides sixteen cells,
each 0.25 UV wide/high; use 8-pixel inset gutters. Role bindings include oxide,
damp-watermark, paint-chip, calibration-paint, glass-grime, calcite/barnacle,
cosmetic seawater and fern alpha. These are role suggestions for the listed masks,
not claims that each role received an independent remote job.

Keep team red/blue and objective emissive markings on separate authored layers.
No base palette reserves team colors, and these resources contain no emissive
channel. Opaque shopfront/optical variants must remain opaque. Foundry integration
must actually bind/embed the delivered images in the next-stage model/material
export; a function name or material label alone is not evidence of using Moth.

## Provenance and generation

Authored 128² periodic seeds and masks are under `seeds/`; their lossless source
PNGs are in the candidate's `sources/`. No old game resource was sampled.
The real engine is `blur-core-v1`, a scalar quantum transformation rather than
text-to-image. Current authenticated catalog and definition returned HTTP 200.
OpenAPI version `v0.41.0`, exact schema SHA-256:
`3c9c7271133225d42739c0a9c45d04805b9f2e2335b85ab98f9d2c10bf13f2d3`.

The saved schema and sanitized engine contract are in `contracts/`. Seeds, exact
params, job IDs, generation fingerprints, provider result hashes and tool commits
are linked per material. `provider/raw/` preserves mothbake's canonical inline
archives; `provider/http/` additionally preserves the exact HTTP response bytes
from explicit GETs of completed results, verified against the canonical grids.
There are no presigned result URLs for this inline-result workflow. Provider
engine revision/backend and actual charged credits are not exposed; they remain
unknown, with no hardware-execution claim.

Generic mothbake: `6de1880b898ead5f4b110ece2a7d4e834feaab4f`.
Initial generation runner: `93e182557c7c47b75c556477127fb27686fea20d`.
Refinements and offline bakes use the new pinned tool. Node used: `v22.23.1`.
The rejected first-pass manifest was written before Node verification and its
`tool.node` field is stale; this document and selected manifest give the measured
version. Python's stock urllib received one public-schema HTTP 403; Node fetch
then retrieved it successfully. This was not an authentication failure.

## Offline rebuild (zero API calls)

```sh
export MOTHBAKE_ROOT=/path/to/mothbake-at-6de1880
node assets/moth/map-variety-20261003/bake.mjs /tmp/opencode/map-variety-rebake
node assets/moth/map-variety-20261003/verify.mjs \
  assets/moth/map-variety-20261003/candidate-v2 /tmp/opencode/map-variety-rebake
node assets/moth/map-variety-20261003/contact.mjs
```

The tool pin is checked before import, as is a clean tracked `src/`. Raw hashes,
source/params agreement and exact/canonical response agreement are checked before
baking. No key is needed. Existing output-byte conflicts fail instead of silently
overwriting a candidate. The manifest is written atomically after all channels.
`prepare.mjs`, `refine.mjs` and `archive-response.mjs` are authoring/retrieval
utilities, **not part of offline rebuild**. Existing job IDs must be reused on
resume; a fresh POST is never an archive-recovery strategy.

## Verification and review boundary

`quality.json` measures edge/interior gradients at base and downsampled mip sizes,
normal unit-length error, channel ranges and numerical provider/source changes.
The explicit local seam stage normalizes scalar range, removes boundary ramps,
applies a four-source-sample C1 transition and periodic Catmull-Rom interpolation.
This is recorded local synthesis, not a claim that API output itself tiled.
Mip diagnostics use box filtering and normal renormalization, not a claim of
Godot/Blender's eventual import filter. Coarse structural-joint ratios over 3 are
reported as review warnings rather than hidden or called aesthetic passes.

`verification.json` records decoded PNG/hash/channel checks and byte-identical
fresh offline rebake comparisons. The generic tool's 367 Node tests, three Python
backend tests, syntax checks, example run, `git diff --check` and `npm pack
--dry-run` passed. All review images are small CPU-generated PNGs:
`contact-albedo.png`, `contact-normal.png`, `contact-masks.png`, `contact-tiled.png`.

Measured selected-pack checks: **181/181 decoded and hash-verified**, **181/181
PNG byte-identical** in a fresh zero-network rebake, and byte-identical manifest
and quality report. Maximum base seam/interior gradient ratio **1.566842** (gate
≤3); maximum quantized normal length error **0.006094** (gate ≤0.015).
There are **27 coarse-mip diagnostic warnings**, retained with material/channel
and mip size in `verification.json`; most concern deliberate repetitive
structural joints, not failed base-level seams. Review them at actual world scale
before selecting distant-map LOD texture strength. This is not a runtime visual
approval. The fern coverage mask is an extra channel; all five required base
channels pass their channel checks.

Blender editable masters, GLB material/image embedding, actual import behavior,
grazing-light appearance and in-map objective readability remain the mandatory
next authorized stage. No Blender/Godot render or map geometry work was performed
for this resource delivery. Publish into the full registry only after parent
review using a merge-safe adapter; do not replace the full registry with this
partial candidate manifest.
