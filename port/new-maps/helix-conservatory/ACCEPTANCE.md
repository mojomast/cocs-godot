# Acceptance — READY FOR BLENDER, not release-ready

## Lightweight verification

Run `node --test tools/godot-multiplayer/new-maps/helix-conservatory/acceptance.test.mjs`.

Tests exercise real frozen-source `terrainSupportAt`, `floorAt`, `walkEdge`, `obstructed`, `moveActor`, `rayWorld`, and `navigation`. Movement uses 60 Hz steering from each route's start to successive waypoints, with no waypoint teleportation. Route starts are independent test fixture initialization. Bot graph searches begin at every spawn and target every flag, zone and pickup. Schema, determinism, art/surface parity, glass/portal openness, wall blocking and non-walkable ceiling support are checked.

Evidence directory: `/home/mojo/.tmp-on-disk/cocs-new-map-conservatory-evidence-20261002/`. Failed attempts are retained. These are scripted Node checks, not human play or full GPU evidence.

Final lightweight result (`source-attempt-05.tap`): **5/5 passed**, 27,544 real movement ticks across fifteen routes; 2,554 source graph nodes and 24,380 directed edges. Every spawn reaches every required socket. Recipe budget: 1,338 authored parts, 5,034 triangles, six materials; actual exported draw surfaces remain pending Blender. Attempts 02–04 retain complete TAP failures; attempt 01 is summarized separately because it initially ran to terminal output.

## Required heavy-slot continuation

1. Obtain explicit parent grant; verify `/home/mojo/.tmp-on-disk/cocs-blender-toolchain/blender-4.5.14-linux-x64/blender` exists. Run the author script serially with `LP_NUM_THREADS=1`, `--background --threads 1`, passing this worktree after `--`.
2. Inspect exported GLB mesh counts, bounds and coordinates against recipe and save actual artifact hashes. Confirm Blender master opens and mesh parts remain editable.
3. Parent integrates native scene and registry. Import serially with pinned Godot 4.5.2 at `/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64`, `LP_NUM_THREADS=1`.
4. Capture and actually inspect overview plus eye-level views of both rooms, all elevation bands, spawns, objective and aqueduct underside. Add high-contrast route signage and tune art only against inspected renders. Record GPU/device, mesh/material/draw counts and frame timings for this map.
5. Compare native triangle collision and visual mesh transforms/hashes. Walk all ramp/ring connections with native movement, shoot portals/glass/walls and check ceilings from below.
6. Run bounded real source full-round fixtures, actual bots pursuing objectives, and hosted source/native DM, CTF capture-return, and one-zone capture journeys. Publish only proven mode IDs.
7. Save footage, screenshots, fixture logs, hosted URLs and package verifier results; update hashes after any reviewed geometry change. Preserve old evidence and releases.
8. Explicitly release ENGINE/BLENDER slot after the granted serial work is stopped.

## Current limits

No Blender/Godot execution, import, bake, GLB, `.blend`, GPU screenshots, footage, native scene or hosted journey exists yet: heavy resources are exclusively assigned elsewhere. No FPS claim. Playable overlapping balconies cannot be represented by the locked highest-floor support function; this design instead provides four non-overlapping usable elevation bands. Art quality, combat sightline balance, objective readability and full-round mode behavior remain unaccepted until the continuation above completes.
