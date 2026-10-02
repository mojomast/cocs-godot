# Gravemill Foundry — source-ready, Blender/native pending

**Status: READY FOR BLENDER. Not yet native-accepted or registered as playable.**

Parent permission is required before Blender, Godot, import, rendering, or baking. No heavy process has been started. No heavy slot is held by this workstream.

## Current authority

* Recipe SHA-256: `cd1d5a678cb2fb711693f6fc2287c9f23b47efa28545227ab71023ed16bdd45d`
* Gameplay geometry SHA-256: `cabd8f2cd7c3e4bf2bda9c7aafdcbfaf4c7154d79660fe7869857859c6009ccd`
* Seed: `0x47524156`; 300 surfaces; 1,272 wall triangles; 908 explicit route nav samples.
* Source JSON: `port/native-multiplayer-worlds/worlds/gravemill-foundry.json`.
* Derived authority: `godot/multiplayer_worlds/generated/gravemill-foundry.json`.
* Mirror recipe: `godot/multiplayer_worlds/generated/worlds/gravemill-foundry.json`.
* Source-derived native probes: `godot/multiplayer_worlds/generated/gravemill-foundry-probes.json`.

No locked game/server modules or shared registries were edited. The recipe has no `overhead` descriptors requiring conversion: its exact ceiling/top/side triangles are already complete. Existing catalog builder processing should reproduce the same derived authority when the parent adds this ID.

## Actual Node evidence

Evidence directory: `/home/mojo/.tmp-on-disk/cocs-new-map-foundry-evidence-20261002/`.

`source-check.mjs` passes schema and 22 spawn/pickup/objective/vehicle markers; all eight routes in both directions via real `moveActor` input; 3,711 connected source nav nodes; ground support at every marker; window/header/roof shot probes; unobstructed gallery portals; continuous wall-contact input; blocked opposing-spawn sightline; a mounted source Puma's 767.64 m, 13-segment service lap with zero wall contacts and seat release; and 363.60 m payload support, all anchors, three checkpoints and movement-driven delivery.

`round-check.mjs` uses the same arena-assignment subclass seam as `worldMatchClass`, with the existing source derivative. Two seats receive normal controls; the opposing seat retreats for objectives and remains passive for combat. No actor positions, health, score, objective state, clocks or physics are injected. These are **source full-round fixtures**, not native journeys or competitive balance proofs.

| Mode | Actual source outcome | Simulated duration | Native |
|---|---|---:|---|
| Payload | Cart delivered, all 3 checkpoints, 3–0 | 152.675 s | Pending |
| Assault | All 3 sectors, attacker win | 65.200 s | Pending |
| Domination | Zone capture and 10-point victory | 27.475 s | Pending |
| Combined arms | Normal-input Puma mount, 77.29 m drive through bend, exit, zone capture, 50-point victory | 70.075 s | Pending |
| Deathmatch | 5 actual kills and source round ending | 180.900 s | Pending |
| Team deathmatch | 5 actual kills, 5–0 source round ending | 75.425 s | Pending |

Measured initial final-geometry runs: source checks 7.68 s wall time, all six round fixtures 8.70 s wall time. Reproducible hash-bearing receipts accompany this work. Earlier attempts are retained: exposed spawn sightline; non-retreating endpoint defender contest; wall probe failure revealing quad-edge movement leakage; and a service-lane baffle encroachment exposed by the corrected colliders. Final triangulated geometry and moved baffles pass.

## Parent integration contract

Parent owns shared integration. Add `gravemill-foundry`, name `Gravemill Foundry`, to Node and Godot catalogs/options/routes/build-world-catalog/package verification only after the required acceptance gates. Candidate modes are exactly `payload`, `assault`, `combined-arms`, `deathmatch`, `teamdeathmatch`, `domination`; source results above do not replace native mode verification.

Expected art path: `res://multiplayer_worlds/art/worlds/gravemill-foundry.glb`. This GLB includes all authored terrain (`arena.art.ground` exists), matching the production binder's existing art-covers-surfaces contract. Master output: `tools/godot-multiplayer/new-maps/gravemill-foundry/gravemill-foundry.blend`. Source/server movement stays authoritative; no vehicle lifts, moving collision or new physics.

No shared integration commit is necessary from this workstream. Existing `worlds-live.mjs` writes to old world evidence paths; create/use a Foundry-scoped fixture output location for native journeys rather than overwrite that evidence.

## Commands

Cheap, runnable now from the Foundry worktree:

```sh
node tools/godot-multiplayer/new-maps/gravemill-foundry/build.mjs --check
FOUNDRY_EVIDENCE=/home/mojo/.tmp-on-disk/cocs-new-map-foundry-evidence-20261002 node port/new-maps/gravemill-foundry/source-check.mjs
FOUNDRY_EVIDENCE=/home/mojo/.tmp-on-disk/cocs-new-map-foundry-evidence-20261002 node port/new-maps/gravemill-foundry/round-check.mjs
```

After **explicit parent grant**, run serially. Binary paths have been checked for existence, not executed:

```sh
LP_NUM_THREADS=1 OMP_NUM_THREADS=1 /home/mojo/.tmp-on-disk/cocs-blender-toolchain/blender-4.5.14-linux-x64/blender -b -t 1 --python tools/godot-multiplayer/new-maps/gravemill-foundry/blender.py -- --render --evidence=/home/mojo/.tmp-on-disk/cocs-new-map-foundry-evidence-20261002/blender
LP_NUM_THREADS=1 /home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 --headless --path godot --editor --import
LP_NUM_THREADS=1 /home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 --headless --path godot --script /home/mojo/.tmp-on-disk/cocs-new-map-foundry-20261002/tools/godot-multiplayer/new-maps/gravemill-foundry/physics_probe.gd
```

Then inspect all eight Blender views, native production colliders and shots; run normal-input native walks through crusher district, both interiors and upper gantry; complete native DM, payload and vehicle/zone journeys using integrated catalogs; capture overview, eye-level evidence and a short clip; inspect the images; record material/node/triangle/import/render budgets and native hash receipts; commit generated art/master and acceptance updates. The scoped Godot probe is prepared but unexecuted, and still requires its first parser/runtime validation.

**Pending outputs:** editable `.blend`, GLB, all screenshots/clip, measured art budgets and generation/render/import timings, production Godot probe, integrated native journeys, shared registry/package inclusion. Final acceptance requires these outputs and an explicit heavy-slot release when finished.
