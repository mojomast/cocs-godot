# Engine-selection correction and controlled comparison

## Why the first pack used only blur-core-v1

This was the resource agent's implementation choice: one scalar transform fed
the easiest shared height/normal/roughness/mask pipeline. The agent fetched the
full authenticated catalog initially but inspected only blur-core's detailed
contract and did not run a cross-engine comparison. Neither the user nor parent
required this restriction. Unlimited useful remote requests were authorized;
cost was not the reason. The first pack does **not** establish blur-core as the
best engine for thirty different material families.

## Current complete discovery

The follow-up fetched `GET /api/v1/engines` and **all 32 detailed definitions**.
All 33 requests returned HTTP 200. Sanitized names, descriptions, prices, enabled
flags, exact parameter schemas, input/output slots and run policies are archived
under `assets/moth/map-variety-20261003/engine-review/`.

Enabled/readable is not proof a worker accepts a particular request. The saved
contracts distinguish catalog capability from the actual trials below.

| Engines | Documented capability and selection decision |
|---|---|
| `blur-core-v1` | Scalar grid transform; retained as existing baseline, useful for coherent relief |
| `blur-v1` | RGB image blur with soft masks and rx/ry settings; selected for structure-preserving color/weathering trials |
| `blur-v0` | Older image-blur registration; no declared output-file slot, while v1 has a versioned current output contract; deferred, not claimed unavailable |
| `deep-fryer-v1` | Per-tile quantum RGB kernel, gate intensities and masks; selected for patina/granular/coating trials at restrained intensities |
| `telablur-v1` | Two-image morph with directional processing and masks; selected for authored dry→weathered material transitions |
| `tessa-image-v1` | Color-sphere or palette round trip; selected for palette retention and calibrated-noise variation. Simulator image limit is 64², positive distortion is explicitly unsupported without real hardware |
| `tessa-image-v1-test` | Alternative test registration with provider/mode/mitigation controls; deferred in favor of production-named Tessa, not claimed unavailable |
| `qpixl-v1` | Scalar-array quantum encode/readout, quantization/range controls; selected for mask reconstruction, emu/aer 4096 shots |
| `entanglement-shader-v1` | Angle/phase reflectance/transmission LUTs and shader ZIP; selected for restrained instrument-coating complements, not a surface-height replacement |
| `entanglement-shader-v0` | Older registration without declared output slot; v1 selected for current archive semantics |
| `qrc-image-v1`, `qrc-train-v2`, `qrc-gen-v2` | Image-sequence reservoir/model training and generation; relevant to animation, deferred for this stationary material comparison, not unavailable |
| `blur-midi-v1`, `qrc-midi-v1`, `qrc-audio-v1`, `retrocausal-echo-v1`, `otoc-echo-v1` | MIDI/audio/echo trajectories; unsuitable for this surface-material comparison without an artificial cross-domain mapping |
| `graph-v1`, `labyrinth-v1` | Graph/topology generation; belongs to layout/structure authority rather than this finish-only ownership |
| `qdrive-api-v1`, `tomography-api-v2` | Circuit synthesis and tomography; no direct image/material output contract |
| `coin-toss-v1`, `comet-qrng-v1` | Entropy sources; additional seeds are not themselves richer surface transforms |
| `tamagotchi-v0`, `tamagotchi-v1` | Quantum logical-state/action experiments; no material image contract |
| `demo-callback-v1`, `test-binary-v1`, `test-engine-error-v1`, `test-engine-fail-v1`, `test-engine-submission-v1`, `test-engine-v1` | Demo, echo and failure/testing registrations; excluded from real-resource generation claims |

No QPU availability claim is made. Tessa `aer` and `fake_fez` are explicitly
requested simulator modes; Qpixl requests `mode: emu, machine: aer`. A requested
mode is recorded separately from any actually exposed backend metadata.

## Controlled inputs and useful parameter variants

Five targets: copper patina, terracotta joints, prismatic instrument etch, quay
waterline and botanical moss. All image methods for a target use the **same exact
64×64 source PNG**, downsampled from that target's authored 128² seed, not from an
old game asset. 64² is required by the documented Tessa simulation cap. Source
RGB is display-sRGB; alpha is opaque. Masks are scalar PNGs; Teleblur's second
input is a separately recorded authored weathering endpoint.

The initial matrix has 20 jobs (five roles × four image engines), four targeted
parameter variants, two Qpixl mask trials and two shader-LUT styles: 28 jobs of
fresh intent, not a claim that all submitted successfully. Current catalogs
estimate one credit per job. Inputs, plans, upload/job failures, IDs and immutable
raw archives are kept. Legacy candidate-v2 remains the scalar baseline.

Parameter comparisons include image rx vs ry, kernel intensity .10 vs .30,
Teleblur vertical vs horizontal, Tessa fixed-palette noiseless vs continuous
calibrated-noise readout, and shader `3-body` vs `frustrated` at otherwise matched
parameters. The comparison must assess structure and readable detail, rather
than equate a different hash with a useful variation.

## Observed input-service blocker

Four masked copper trials failed **before job submission**: upload completion
of `copper-patina-mask.png` returned HTTP 422. Read-only asset inspections returned
HTTP 200 and `status: rejected` for each of the three asset IDs; metadata contained
no reason. The same PNG decodes locally as 64² RGB, but local decoding does not
prove the service's scanner will accept it. Copper's source image was accepted
by Tessa; terracotta's image and mask were accepted by the other image engines.
This is an observed input-specific rejection, not evidence those engines are
unavailable. The rejected uploads and original attempts are preserved. Subsequent
explicit unmasked copper trials are separately named intent, not silent retries.

## Completed comparison results

The original 28-intent matrix, six useful concurrency trials and one unmasked
kernel-intensity follow-up total **35 intents**. **31 jobs were accepted and all
31 completed remotely** across six engines. The four failures above occurred
before any job POST. Catalog estimate for the 31 accepted jobs is **31 credits**;
actual charged credits are not exposed. Together with the original pack there
are **76 accepted/completed jobs**, with 76 estimated credits, not claimed billing.
See `engine-trials/receipt.json` for the per-engine counts and exact IDs.

| Engine | Accepted/completed | Observed use |
|---|---|---|
| `blur-v1` | 7/7 | Image rx preserves structures better than ry on brick; nonlocal etch blur loses useful lines |
| `deep-fryer-v1` | 7/7 | Restrained RGB kernel produces useful coating/oxide variants; stronger .30 flips the patina/lightness relationship |
| `telablur-v1` | 7/7 | Horizontal waterline morph is useful; vertical/strong alternatives smear or multiply meaningful bands |
| `tessa-image-v1` | 6/6 | Palette mode best preserves brick features; calibrated-noise case reduces 64² input to 21² and loses fine patina detail |
| `qpixl-v1` | 2/2 | Actual output is a flat 4096-value vector, not a 2D grid; explicitly reshaped offline, no resubmission |
| `entanglement-shader-v1` | 2/2 | Genuine HDR/EXR R/T LUTs and shader masters; usable review companions for view-dependent coatings |

The serial runner exited 1 because it reported four upload failures and two
**local** Qpixl bake-shape failures. These were not six failed remote jobs. The
Qpixl raw responses had already been archived successfully. Generic `raw-grid`
now accepts an explicit bounded shape; an actual zero-network `mothbake repair`
rebuilt both measured fields with width/height 64. Results also report backend
`aer` and `qpu_seconds: 0`, so those two simulator identities are observed, not
merely requested. Exact scalar HTTP response bytes were separately captured.

### Role-specific selection, rather than engine-count quotas

The **small `candidate-v3` overlay** adds four image-derived finishes to the
unchanged `candidate-v2` base. Actual provider RGB is preserved in linear light;
relief explicitly mixes 90% authored structure and 10% provider luminance.

| Selected resource | Source trial | Evidence and intended use |
|---|---|---|
| `copper-heat-oxide` | Deep Fryer, global rx .10 | Warm oxide/green coating; source luminance correlation .969, gradient-feature correlation .816 |
| `etched-coating-haze` | Deep Fryer, masked rx .10 | Restrained coating haze preserves etched-line feature correlation .922; useful Parallax/Helix instrument accent |
| `quay-damp-horizontal` | Teleblur, horizontal .30 | Damp transition with gradient-feature correlation .839; preserves meaningful waterline orientation |
| `moss-warm-weather` | Deep Fryer, masked rx .10 | Botanical/shore growth variation; luminance correlation .978, gradient correlation .902, no saturated pixels |

The two copper kernel tile sizes returned **byte-identical PNGs**; only one is
selected. Tessa palette retains brick features well (.986 gradient correlation)
but its mean linear RGB change is only .0004. It is not automatically a better
extra asset than the existing readable brick baseline. The noisy Tessa result's
native 21² resolution is recorded; comparison metrics explicitly resample it for
matching coordinates, rather than claiming native 64² detail. Its gradient
correlation is only .027. Stronger copper kernel .30 has negative luminance
correlation (-.677), so the restrained .10 variant was preferred.

Two **optional measured coverage masks** are exported under v3 auxiliary resources:
Qpixl moss retains .980 threshold-.5 intersection-over-union with the authored
mask; waterline retains .998. They add small measured boundary perturbations,
not a radically new surface or collision field. Both are real API outputs and
have explicit numerical provenance. The original masks remain available.

Two **LUT review companion sets** include exact provider HDR, EXR, GLSL, OSL and
MaterialX master bytes. These are angle/phase data, not direct albedo/roughness.
The 3-body reflectance master reaches 1.234375; its HDR values are preserved,
not clamped and falsely called energy-conserving PBR. Parameter-space previews
use fixed Reinhard display mapping and the provider's wavelength/phase equations.
Blender material interpretation, grazing-light review and runtime compatibility
remain next-stage work.

### Comparison artifacts and checks

Under `engine-trials/comparison/`:

- `comparison-raw.png`: same-role source, scalar baseline and actual image outputs.
- `comparison-repaired.png`, `all-variants.png`, `all-variants-tiled.png`: explicit
  local seam reconstruction and tiled usefulness review.
- `metrics.json`: linear RGB changes, luminance/gradient preservation, directional
  gradients, checker alternation, raw/repaired seams and normal angular changes.
- `mask-comparison.png`, `fields-luts.json`: measured mask stability and ranges.
- `lut-comparison.png`: angle/thickness parameter diagnostics, not a rendered scene.

No single correlation metric is an aesthetic pass: image contacts were inspected
alongside metrics. Candidate-v3 has only 20 new material PNGs (~2.67 MB), two
coverage masks and small LUT master files; it does not duplicate the old pack.
All 20 PNGs and the manifest/contacts reproduce byte-for-byte offline. Sixteen
auxiliary files (two masks and fourteen LUT/shader masters) are hash-verified and
byte-identical on fresh reconstruction. Base seam ratio max .593409, quantized
normal-length error max .005170; one coarse-mip diagnostic remains visible.

## User-requested real job concurrency experiment

`concurrency-trials.mjs` submits useful unmasked copper image/kernel trials using
genuine `Promise.all` overlapping POSTs. Only if both are accepted and completed
does it submit four further useful image/kernel/Teleblur parameter trials together.
Each request records monotonic start/end, HTTP status and immediately persisted
job ID. A central poll loop has at most two outstanding GET operations and
adaptive 1.5–5 s waits. Definite 429 responses honor Retry-After; ambiguous POST
outcomes never resubmit automatically. Reports distinguish HTTP overlap,
accepted jobs, completed archives and provider execution observations.

### Completed concurrency result

| Batch | Accepted/completed | Simultaneous POST overlap | POST durations | Complete-and-archive wall time | 429 |
|---|---|---|---|---|---|
| 2 | 2/2 | 1.532 s | 1.533, 1.944 s | 121.017 s | 0 |
| 4 | 4/4 | 1.578 s across all four | 2.400, 1.579, 2.897, 1.974 s | 63.870 s | 0 |

All six submitted jobs have immutable raw PNG archives. The first batch compares
unmasked image Blur and Deep Fryer on copper. The second compares copper Teleblur,
four-qubit-side kernel, stronger horizontal waterline Teleblur and nonlocal etch
blur. These are useful named comparison cases, not disposable stress-test jobs.

Evidence: `engine-trials/concurrency/report.json`, six per-job journals with
monotonic start/end times and HTTP statuses, and `job-history-times.json`.
The two-job IDs are `2bba80b9-3060-41cd-b65d-b8463f0e2cc6` and
`f8a88453-7580-4384-8671-00eb9679231d`. The four-job IDs are in the report.

**Proven:** simultaneous HTTP requests are accepted and multiple remote jobs can
be outstanding and complete. **Not proven:** simultaneous worker execution or a
particular queue concurrency limit. The history endpoint exposes `created_at`
and `updated_at`, not worker-start timestamps; status responses likewise provided
no `started_at`. Some jobs were observed processing, but observations alone do not
establish a reliable shared execution interval. Do not call these timings a
throughput benchmark or conclude the service serializes all work.

The final generic mothbake pin is
`69c62d7c4bd754340623a4a7fa93bfa970e5ab73`, extending the image-adapter commit
`64b5f90eebfdec575cbe0797bb297c10fb609428` and original `6de1880`.
It preserves actual provider RGB in linear light and offers explicit authored
structure mixing; it does not replace all image outputs with recolored scalar
noise. The original generic checkout remains pinned for candidate-v2 rebuilds.
The final generic suite passed **372 Node tests**, **three Python tests**, syntax
checks, offline examples, whitespace checks and package dry-run. No Blender,
Godot or other local engine/render process was used for this comparison.
