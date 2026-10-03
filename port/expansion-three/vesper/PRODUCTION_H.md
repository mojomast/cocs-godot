# Vesper production H — 2026-10-03

Explicit exclusive local grant: `VESPER-ASSET-PRODUCTION-20261003-H`.
Canonical `27f3afc3` merged into original source checkout as `529f7e68`.
Public admission remains closed pending all six hosted proofs and parent visual
approval. The queue's historical F/G metadata does not override the explicit H
grant. The remote Windows Helix diagnostic is on a separate host.

## Retained progression

Evidence root:
`/home/mojo/.tmp-on-disk/cocs-expansion-three-vesper-evidence-20261002/production-h/`.

1. Initial preflight caught absent local `ws`; reused the parent's `node_modules`
   through an ignored symlink. No dependency installation or cache copying.
2. Ten candidate/consolidation contracts, five material-helper tests and all six
   controlled source rounds passed before production.
3. First real Blender build, Godot import and three native representative images
   completed. First native launch had no display; retained its log and switched
   to a private Xvfb inside the bounded stage's owned process group.
4. First images exposed overly bright brick (sRGB bytes incorrectly interpreted
   as linear Principled input) and insufficient architectural detail. The initial
   master/GLB and images are preserved in `first-representative-assets/` and
   `20261003T035449.139011Z-representative/`.
5. Vesper-only revision corrects color conversion, adds window reveals, stone
   jambs/capitals, facade piers, steel roof trusses, clock belt courses, stair
   handrails and district counters. Thirty existing row houses have deeper
   footprints on the slopes; four central solid buildings close the empty city
   center. Counter bodies are actual source walls, with central-gallery cross
   street counters explicitly omitted. Shared material helper is unchanged.
6. Revised source support is still disjoint: 19 routes both ways, 29,276 movement
   ticks, 591 authored nodes and 2,031 connected source-generated nav nodes. All
   six controlled source rounds still pass, with unchanged bounds/spawns/flags/
   objectives/routes. Native route comparison now samples 759 floor positions.
7. An outer tool's 120-second deadline interrupted the second build wrapper. Its
   observed orphan group 1295440 was explicitly killed and recorded in
   `interrupted-build-wrapper.json`. Retry uses background execution with an
   outer bound longer than the canonical 900-second build deadline.

## Preservation

`godot/tests/new_maps/vesper_viaduct/preservation.mjs` compares frozen authority,
Foundry/Parallax dressing, both public catalogs, robot/vehicle/scenery resources,
the shared finishing helper and existing producer receipts against `27f3afc3`.
Its current report is `production-h/preservation.json`; all protected diffs are
empty. Actual frozen core SHA is unchanged. No other asset unit is rebuilt.

Mechanical production is complete. Parent visual approval and package promotion
remain pending; the producer receipt deliberately does not claim those gates.

## Produced asset and mechanical acceptance

Asset commit `7e208359` contains the separately editable master, real GLB and
Godot-extracted texture resources. Final authority has 1,910 wall triangles,
253 surface records, 19 routes and seven three-room buildings. Godot constructs
2,412 gameplay triangles. Export geometry: **54,804 triangles, 11 mesh/material
batches, 3,647,280 GLB bytes**; independent reopen found 4,556 master meshes.
Eight textured material roles carry valid base/normal UV streams and tangents;
glass, water and lettering preserve their authored treatment.

| Identity | SHA-256 |
|---|---|
| Authority geometry | `27c71cc8895eab2ca3a0b5cae3c2b8f96ed9afd75db3deec4a5c96bd2f395ea7` |
| Recipe | `84aa9e5e7dd415fe9681a35c4bb03403e7b6b23b4713936039936af0cfa7c89f` |
| Master | `e9068c9c7226a231d379359157aa4c1b5fe57d81406d87e90abbb096c474548b` |
| GLB | `6afe34c82d45f06c30dedc780f59ac6afa5200835b487d41705902d771fc0bfd` |
| Builder/helper source fingerprint | `1fbf980f118a179747e057d6dbb9661ddf6fcaa7cd17a7ef61012234bbfc15dd` |

Native collision passed 13 rays, 759 route support samples, 271 sustained wall
impacts, 107 ceiling impacts and a 14.4 m collision-free doorway body journey.
All six hosted cases passed using two native clients, real GLB, production
transport and ordinary inputs. Each includes a real death and source respawn;
no pose/score/health/objective writes are used. Exact outcomes, trace coordinates,
closed-peer receipts and capture timings are in `evidence/production-h/`.

Seventeen native architectural images include every interior, civic frontage,
stair landing, canal bridge, arcade front and warehouse sign. Inspection used
Godot 4.5.2 / OpenGL3 **llvmpipe (LLVM 20.1.8, 256 bits)**, not a GPU performance
claim. Hosted capture uses the canonical reduced-raster/no-shadow preset;
architectural inspection uses full raster with shadows. Vesper has no runtime
dressing/detail/wetness profile (`ineligible`), so there are no applicable
full/reduced/off dressing switches to exercise. Captured PNG cadence is measured
from native timestamps, not inferred from an encoding rate.

## Real failures and scoped fixes

- The detached private authority could not resolve bare `ws` from an evidence
  directory outside the checkout. `candidate-admission.mjs` now resolves that
  unchanged dependency at its original location; frozen production module bodies
  remain intact apart from allowed import edges.
- Compact CTF encountered negative safe-region rectangles in damage-number
  drawing for the headless peer's tiny viewport. `cbde55eb` adds an early empty
  result and three regression cases; the engine regression and CTF then passed.
- Compact CTF imagery exposed clipped instructions. `cbde55eb` applies the
  existing Foundry responsive layout to Vesper only. The fixture's clip counter
  now observes actual canvas-scaled bounds. Failed/pre-fix runs remain retained.
- Initial DM/TDM capture timing predates the corrected respawn-trigger check;
  objective-mode captures record post-respawn movement. These are documented
  fixture differences, not additional gameplay outcomes.

## Parent integration and receipt status

`tools/godot-package/production_receipts/vesper-viaduct.json` is a real converted
producer receipt with **accepted:false**. It pins the current asset and package
inputs. Parent owns visual approval, promotion and package closure. Public
catalogs remain byte-identical to `27f3afc3` in the production branch.

Supporting input changes requiring parent reconciliation are exactly:
`tools/asset-production/candidate-admission.mjs`,
`tools/asset-production/candidate-hosted.mjs`,
`tools/asset-production/consolidation.test.mjs`,
`godot/multiplayer_worlds/demo.gd`, `godot/world/damage_numbers.gd`, and
`godot/tests/protocol/damage_numbers.gd`, plus the new Vesper-only fixtures.
The shared Moth helper, Foundry lights, Parallax assets and existing promoted
robot/vehicle/scenery producer receipts have no edits.

## Final hosted results

| Mode | Actual outcome | Source seconds | Captured PNG cadence |
|---|---|---:|---:|
| DM | 5 frags, frag-limit leader Godot | 168.93 | 6.90 fps |
| TDM | 5–1, team 0 frag-limit win | 83.83 | 5.92 fps |
| CTF compact | 1 capture, team 0 win | 91.40 | 9.23 fps |
| Domination | 1 capture + 1 scored objective second, team 0 win | 41.30 | 5.42 fps |
| KOTH | 1 capture + 1 scored objective second, team 0 win | 88.50 | 7.29 fps |
| Uplink | all 3 sequential stages, team 0 win | 69.12 | 5.63 fps |

Every row has two closed native peers with exit 0, no forced teardown, and a
closed owned server. Final HUD clip counters are zero. CTF's physical capture is
760×520 at UI150 (logical viewport 506.67×346.67); the others are 1280×800/UI100.
Reported cadence includes real stalls: retained TDM/domination/uplink sequences
contain maximum gaps of 4.508/3.432/3.178 s. These are software-rendered capture
observations, not a smooth-performance acceptance claim. The CTF clip
[`ordinary-input.mp4`](evidence/production-h/ctf/ordinary-input.mp4) uses recorded
frame durations and variable-frame-rate encoding.

Main review links: [overview](evidence/production-h/overview.png),
[civic](evidence/production-h/civic.png),
[arcade](evidence/production-h/arcade-front.png),
[concourse interior](evidence/production-h/ticket-concourse-interior.png),
[stair](evidence/production-h/civic-stair.png),
[compact result](evidence/production-h/ctf/results.png),
[wide result](evidence/production-h/deathmatch/results.png).

Failed startup/display/build and pre-fix compact runs are preserved alongside
the successful runs. The final `release-h.json` records empty owned process
groups and release of **VESPER-ASSET-PRODUCTION-20261003-H**. No heavy job remains.
