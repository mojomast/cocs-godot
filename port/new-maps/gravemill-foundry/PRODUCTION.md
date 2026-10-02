# Gravemill production proof

Follow-up to source-ready commit `32cbf30f`, after explicitly granted exclusive engine/Blender access. Verified runtime `e731fd536d31d16a7014402afe6670fca644f9c1` was merged before engine work. No frozen game/server implementation was changed.

## Reviewed geometry revision

The first Blender and production-native inspection revealed an overbright mineral treatment and sparse, flat-topped process forms. Revision two adds tapered furnace/silo crowns, six radial filter banks, ore hoppers, angular geological buttresses with sediment seams, conveyor bracing, ground-conforming freight paving/rails and interior inspection details. Solid foundations now extend to their footprint's lowest terrain support so sloped terrain cannot leave unintended entry gaps beneath machinery. Every recipe change is regenerated and source-verified.

Accepted geometry:

```text
recipe  8c065b4f47c5fa67937338367cf030e4e0ff95fdc6a743483cc9127aa5ca1678
arena   357e2ef998a52135d273a30e2638392a8dececf1fa15f0b17f33c612976d853e
```

309 terrain surfaces, 2,020 individually triangulated terrain walls, and the same 908 authored route samples/native probe locations. Revised source movement and all six controlled source full-round fixtures pass. The envelope uses the existing `art/worlds/gravemill-foundry.glb` and `arena.art.ground` surface-coverage convention; no special-case production map renderer is needed.

## Autonomous bots — separate bounded observation

`bot-check.mjs` runs six ordinary source bots and a stationary human seat, without bot input override, at most 120 simulated seconds per mode. Domination ends at 63 s with a captured zone and a 50-point blue victory. Payload bots advance the cart 144.41 m, reach checkpoint one and record eight combat kills in 120 s; the round does **not** finish within the observation window. Respawn jumps are excluded from bot travel distance. This proves bounded autonomous objective participation, not competitive balance or autonomous full-map delivery.

## Evidence preservation

Root: `/home/mojo/.tmp-on-disk/cocs-new-map-foundry-evidence-20261002/`.

* `blender/` and `native-before/`: inspected first-pass architecture and production-native views.
* `blender-final/`: revised CPU review images and measured exporter/render report.
* `revision-02/`: final-revision hash-bearing source checks, six round fixtures and bounded bot receipt.
* `import-attempt-01.log`: initial complete asset import followed by an engine shutdown `double free or corruption` abort; retained as failed, never presented as clean import success.

## Blender and production colliders

Blender 4.5.14 generated the editable master and GLB, then reopened the saved master and verified the geometry hash. Final master: 6,458 total objects (including eight export batches, eight cameras and one light), 6,441 editable architectural/source components; nine material datablocks including the unused default, **eight used/exported materials**. Runtime GLB: **66,284 triangles**, **eight mesh batches**, 3,556,916 bytes. Editable master: 37,091,764 bytes.

The intermediate detailed-art build's eight 1440×900 CPU reviews took 387.11 seconds and were all inspected. Production-native review then exposed pavement shimmer. The final exporter splits original terrain planes into disjoint material regions rather than raising coplanar road/rail decals: collision coordinates and arena hash remain identical, and native road shimmer is removed. Final generation/export took **1.24 s**; four final-build CPU Cycles reviews took **190.04 s total**, 32.26–79.57 s individually, one thread / 16 samples. All four were inspected; the master retains all eight cameras. These are software/CPU costs, not GPU frame-rate measurements.

Pinned Godot 4.5.2 re-imports succeeded cleanly on attempts two and three. The actual production `multiplayer_worlds/map.gd` binder passes **908 floor support rays**, **908 standing capsules**, eight gallery/window/ceiling shot checks, **160 continuous capsule wall-contact motions**, and the 13 m conveyor underside ray. It reports **2,808 authoritative collision triangles** and geometry hash `357e2ef9…`. The moving capsule stops at X = −78.409935 on the mineral face. Physics evidence is `physics-attempt-01.log`; final master reopen evidence is `blender-inlay-reopen.log`.

## Hosted native rounds and inspection

All six requested modes pass two-peer production-native full rounds; see the outcome table in `ACCEPTANCE.md` and `native-validation.json`. Native clients serialize every control, including Puma entry, steering and exit. Passive/retreating opposition and setup frag/time limits are explicitly controlled. No simulation-state injection occurs.

Final default-lighting 1280×800 production views are in `native-reviewed/`: overview, reverse geology, crusher eye, cooling eye, assay eye, crown eye and furnace eye. Static native scene: **4,914 nodes**, including production per-face colliders; **8 base art draws**, 38–40 draws in shadowed eye views (up to 331,420 submitted primitives including shadow passes). Seven view captures plus construction finished within **4.26 s** in the logged process. This is a capture workload, not an interactive FPS benchmark.

The normal-input walkthrough visits the crusher approach, cooling entry/interior, assay interior, crown gantry and furnace apron. Its 1280×800 screenshots show intact help text, source HUD, ability card, advancing acknowledgements and pickup changes. The software capture preset disables sun shadows and uses 0.75 3D scale while retaining full-resolution UI; default-lighting architectural stills are separate.

`native-visual-final/walkthrough.mp4`: **43 captured frames over 4.46 s**, measured **9.42 captured frames/s**, resampled with timestamp durations to a 15 fps MP4. This improves on the retained first attempt's 4.39 captured frames/s, but **does not claim native 15 fps capture**. The single-thread software capture did not reach that ideal. Capture metrics are in `walkthrough-clip.json`; no GPU-performance or human-playtest claim is made.

The additional final-art rendered payload round also completed with both native result receipts. `native-payload-visual-final/payload.mp4` contains **39 captured frames over 3.891 s**, measured **9.77 captured frames/s**, timestamp-resampled to 15 fps. Full-resolution payload HUD and both clips' decoded contact sheets were inspected. `visual-validation.json` records view metrics, screenshot hashes, walkthrough stages and both clip receipts.

## Slot release

**EXPLICIT ENGINE/BLENDER SLOT RELEASED.** All Foundry Blender, Godot, native journey/server and encoding jobs completed and stopped. Process inspection found no remaining Blender/Godot/Foundry journey/encoder process. Unrelated shared browser/display processes were left alone. Parallax may acquire the next heavy slot.
