# Gravemill Foundry — source and native acceptance

**Accepted map/mode pairs:** `gravemill-foundry` × `deathmatch`, `teamdeathmatch`, `domination`, `assault`, `payload`, `combined-arms`. Shared package/manifest closure remains the parent's integration responsibility.

## Identity and assets

```text
recipe SHA-256  8c065b4f47c5fa67937338367cf030e4e0ff95fdc6a743483cc9127aa5ca1678
geometry hash  357e2ef998a52135d273a30e2638392a8dececf1fa15f0b17f33c612976d853e
seed           0x47524156
```

* Recipe: `tools/godot-multiplayer/new-maps/gravemill-foundry/recipe.mjs`.
* Source JSON: `port/native-multiplayer-worlds/worlds/gravemill-foundry.json`.
* Complete derived authority: `godot/multiplayer_worlds/generated/gravemill-foundry.json`.
* Native source-contact probes: `godot/multiplayer_worlds/generated/gravemill-foundry-probes.json`.
* Editable reopened master: `tools/godot-multiplayer/new-maps/gravemill-foundry/gravemill-foundry.blend`.
* Runtime art: `godot/multiplayer_worlds/art/worlds/gravemill-foundry.glb`.
* Receipts: `source-validation.json`, `native-validation.json`, `bot-validation.json`, `provenance.json`, `capabilities.json` in this directory; exact artifact digests are in provenance.

The verified runtime `e731fd536d31d16a7014402afe6670fca644f9c1` was merged before engine work. Frozen game/server implementations are unmodified; `game/core.mjs` remains SHA-256 `58ff1b9c7467a53da00638f16edfd3df2e1e6fd06480ff081ad13c88fb64bdb9`.

## Actual source and production-native checks

* 384×288 m, 35 m terrain relief; 309 terrain surfaces, 2,020 wall triangles; **3,626 connected source navigation nodes**, including all 22 mandatory markers.
* All eight authored routes traverse both directions with real source movement. Terrain support error is zero in the route followers. Source wall triangles block continuous movement; vaults, headers and conveyors stop shots while portals/windows remain open.
* Actual Puma physics completes a **767.64 m / 13-segment service loop** with zero wall contacts and seat release.
* Payload source path is **363.60 m**, all nine authored anchors included, three source-native checkpoint thirds and movement-driven delivery.
* Production `multiplayer_worlds/map.gd` passes **908 support rays + 908 standing capsules**, eight gallery/window/ceiling shot probes, **160 wall-contact moves**, and the 13 m conveyor underside. **2,808 collision triangles**, matching geometry hash.

### Hosted native full rounds

Two production-native clients participate in each fixture. A scoped test controller supplies directional/action stimuli to the native clients; their normal client serializer sends ordinary input over the source server's wire. Node reads authority telemetry for steering/assertions. No actor position, health, objective, score, clock or physics state is injected. Opponent behavior is deliberately passive/retreating. These are **controlled native outcome proofs**, not competitive-balance trials.

| Mode | Actual native/source outcome | Simulation time | Input updates |
|---|---|---:|---:|
| Payload | Delivered, three checkpoints, 3–0 | 150.000 s | 2,856 |
| Combined arms | Puma mount, **76.88 m drive with bend**, dismount, zone capture, 50-point win | 71.733 s | 1,349 |
| Deathmatch | Five source kills, round ended | 132.217 s | 2,514 |
| Assault | All three sectors, attacker win | 66.700 s | 1,251 |
| Domination | Capture and 10-point victory | 26.200 s | 471 |
| Team deathmatch | Five source kills, 5–0 victory | 67.833 s | 1,273 |

Both native peers receive matching-hash result receipts for every row. `native-validation.json` contains the compact records; the evidence directory retains complete logs and authority route samples.

### Autonomous bots, separately labeled

Six unmodified source bots with a stationary human seat: domination completed at 63 s with one captured zone and a blue 50-point victory. In 120 s, payload bots advanced **144.41 m**, reached checkpoint one, and recorded eight kills. The bounded autonomous payload round **did not complete**. There is no claim of balanced natural full rounds or universal bot delivery.

## Visual acceptance and measured budgets

The first Blender/native views prompted an architectural/material refinement. A later compatibility-renderer review found pavement shimmer; final art partitions the original planar terrain into disjoint material inlays, removing raised/coplananr pavement overlays **without changing authority geometry or hash**.

Final asset: **66,284 triangles, eight mesh/material batches, 6,441 editable components**; GLB **3,556,916 bytes**; master **37,091,764 bytes**. Eight authored cameras are retained. Four final-build 1440×900 CPU renders were inspected (overview, crusher, cooling interior, furnace), after all eight prior-revision views had been inspected. Seven final default-lighting native views include both interiors and upper gantry. Master reopened successfully with the same hash.

Final generation/export: **1.24 s** inside Blender. Four CPU Cycles views: **190.04 s total**, 32.26–79.57 s per view, one thread / 16 samples. Source checks: 11.85 s; six source round fixtures: 12.97 s; autonomous bot observations: 15.64 s. Software-native static inspection and capture costs are recorded in `PRODUCTION.md`; these are not GPU or human-playtesting measurements.

## Evidence and reproducible commands

Evidence root: `/home/mojo/.tmp-on-disk/cocs-new-map-foundry-evidence-20261002/`.

* `revision-02/`: final authority source and autonomous-bot receipts.
* `blender-inlay-final/`: final Blender imagery and exporter budget.
* `native-final/`: all six hosted native round receipts.
* `native-reviewed/`: final production overview and six architectural eye/reverse views.
* `native-visual-final/`: normal-input multi-district walkthrough and clip evidence.
* Initial/failed attempts are preserved, including the first import's shutdown abort, the wall-quad movement discovery, initial spawn sightline and baffle failures, and superseded pavement captures. Subsequent imports pass cleanly.

```sh
node tools/godot-multiplayer/new-maps/gravemill-foundry/build.mjs --check
node port/new-maps/gravemill-foundry/source-check.mjs
node port/new-maps/gravemill-foundry/round-check.mjs
node port/new-maps/gravemill-foundry/bot-check.mjs
```

Engine/Blender repro requires ownership of the exclusive heavy slot:

```sh
LP_NUM_THREADS=1 OMP_NUM_THREADS=1 /home/mojo/.tmp-on-disk/cocs-blender-toolchain/blender-4.5.14-linux-x64/blender -b -t 1 --python tools/godot-multiplayer/new-maps/gravemill-foundry/blender.py -- --render
LP_NUM_THREADS=1 /home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 --headless --path godot --editor --import
LP_NUM_THREADS=1 /home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 --headless --path godot --script /home/mojo/.tmp-on-disk/cocs-new-map-foundry-20261002/tools/godot-multiplayer/new-maps/gravemill-foundry/physics_probe.gd
node port/new-maps/gravemill-foundry/native-suite.mjs
LP_NUM_THREADS=1 LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a node port/new-maps/gravemill-foundry/native-journey.mjs walkthrough
```

## Parent integration contract

The asset/proof commit and minimal shared map-bindings commit are separate. Shared changes are limited to Node `WORLDS`, native `MODES`, launch/package options, route metadata and generated route JSON. No shared package allowlist or manifest verifier is edited. The existing production art-path/surface-coverage convention already supports this asset; no `map.gd` change is required.

Invoke the scoped standalone generator for reproducibility. Its JSON already contains all overhead geometry; `overhead` is empty, so there is no second expansion pass to apply. Integrate alongside Helix/Parallax without dropping their catalog entries. Parent owns combined package closure, route counts/descriptions and released Windows/Linux matrix expansion.
