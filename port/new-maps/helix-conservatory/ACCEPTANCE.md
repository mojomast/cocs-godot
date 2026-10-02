# Acceptance — revision 2 ready for second Blender pass

**Parent accepted the old functional milestone, not final art.** See [revision-2/DESIGN.md](revision-2/DESIGN.md) for the new district architecture and passing source checks. New geometry has no native acceptance yet. The native results below and in PRODUCTION.md apply only to the preserved functional checkpoint.

**Current production evidence and exact remaining gates: [PRODUCTION.md](PRODUCTION.md).** The sections below preserve the historical pre-engine checkpoints, hashes and initially pending work; their READY FOR BLENDER status is superseded by the 2026-10-02 production pass. Five native modes are accepted; Arsenal/Juggernaut remain source-only.

## Lightweight verification

Run `node --test tools/godot-multiplayer/new-maps/helix-conservatory/acceptance.test.mjs`.

Tests exercise real frozen-source `terrainSupportAt`, `floorAt`, `walkEdge`, `obstructed`, `moveActor`, `rayWorld`, and `navigation`. Movement uses 60 Hz steering from each route's start to successive waypoints, with no waypoint teleportation. Route starts are independent test fixture initialization. Bot graph searches begin at every spawn and target every flag, zone and pickup. Schema, determinism, art/surface parity, glass/portal openness, wall blocking and non-walkable ceiling support are checked.

Evidence directory: `/home/mojo/.tmp-on-disk/cocs-new-map-conservatory-evidence-20261002/`. Failed attempts are retained. These are scripted Node checks, not human play or full GPU evidence.

Final lightweight result (`source-attempt-05.tap`): **5/5 passed**, 27,544 real movement ticks across fifteen routes; 2,554 source graph nodes and 24,380 directed edges. Every spawn reaches every required socket. Recipe budget: 1,338 authored parts, 5,034 triangles, six materials; actual exported draw surfaces remain pending Blender. Attempts 02–04 retain complete TAP failures; attempt 01 is summarized separately because it initially ran to terminal output.

## Controlled source full-round fixtures

Run `node --test tools/godot-multiplayer/new-maps/helix-conservatory/source-rounds.test.mjs` with Node 22.23.1 or compatible `node:module.registerHooks`. Set `HELIX_WRITE_SOURCE_REPORT=1` to refresh the checked-in `source-validation.json` only after all seven tests succeed.

The harness extends only `getMap` lookup through a temporary process-local module load hook, then deregisters the hook. No source files, frozen templates or shared registries are edited. Actual Match constructor, source navigation, `Match.step`, movement, weapon damage, respawn, flag rules and zone rules execute. The recipe is the exact checkpoint authority. Two controlled human seats receive synthetic inputs; this is neither autonomous bot gameplay nor hosted/human acceptance.

After initial fixture placement, the harness never writes actor positions, health, score, flag state, objective progress or match time. Source natural respawns are allowed. Pathfinding uses the source graph; every waypoint is reached through 60 Hz directional inputs. Every live frame checks finite position, bounded displacement and zero map falls. The report records complete normalized configurations, event counts, objective milestone positions, per-frame input/position trajectory hashes, distance and completion reason.

| Exact source mode | Controlled completion | Frames | Simulated seconds | Walked metres, both seats |
| --- | --- | ---: | ---: | ---: |
| `ctf` | Enemy physically steals and interact-drops home flag; defender walks its return; three physically carried captures, 3–0 | 13,325 | 222.083 | 1,575.535 |
| `deathmatch` | Five input-fired kills; four natural respawns and walked returns to duel | 4,405 | 73.417 | 377.186 |
| `teamdeathmatch` | Five input-fired kills, 5–0; four natural respawns and walked returns | 4,190 | 69.833 | 374.521 |
| `arsenal` | Native all-weapons/infinite-ammo loadout, input weapon selection, five kills | 4,385 | 73.083 | 377.186 |
| `juggernaut` | Input-fired role transfer, walk to lightwell, hold role to 15 points | 1,201 | 20.017 | 13.752 |
| `domination` | Walk from 16 m canopy spawn to lightwell; actual capture and occupancy to five points | 1,314 | 21.900 | 98.678 |
| `koth` | Walk from 16 m canopy spawn to opening lightwell hill; actual capture and occupancy to five points | 1,314 | 21.900 | 98.678 |

All rounds terminate through source scoring (`capture`, `frag`, `objective`), not timeout or direct `endMatch` calls. Combat fixtures use permitted rail-start/unlimited-ammo configuration; limits are shortened to five kills or five zone points and fifteen Juggernaut points. CTF uses the standard three-capture target. These tests do not establish default-length balance, KOTH rotation, simultaneous three-zone control, hostile bot pursuit, spawn safety under live opposition or native mode capability. Those remain later integration/playtest coverage.

Failed full-round attempts are preserved: attempt 01 caught harness syntax; attempt 02 completed journeys but incorrectly expected a `match-end` event the source does not emit. The corrected assertion requires actual `match.over` and source `overReason`. Attempts 03 and 04 are passing runs; attempt 04 adds trajectory hashes, normalized config and milestone evidence. `validatedSourceModes` lives in `source-validation.json`; public `modeBindings` remains empty and geometry hashes are unchanged.

## Source wall-perimeter regression review

Cross-map review after Gravemill `32cbf30f`: **Helix already emits all 712 wall polygons as individual triangles** in `recipe.mjs`'s `mesh(..., collision='wall')` branch. Each triangle's projected perimeter includes a full-height diagonal, satisfying the locked `terrainWallSegments`/`terrainObstructed` contract. No recipe, art, collision, mode fixture, or geometry hash changed during this review.

Run `node --test tools/godot-multiplayer/new-maps/helix-conservatory/wall-contacts.test.mjs`. Set `HELIX_WRITE_CONTACT_REPORT=1` to save `wall-contact-validation.json`. **4/4 tests passed**; evidence: `wall-contacts-attempt-01.tap` in the evidence directory. Checks include:

- Every production wall has exactly three vertices and a projected full-height segment.
- Twelve continuous-input contacts: both sides of ground aqueduct pier, archive wall, 1.4 m low planter/parapets at 0/8/16 m, and crown rib foot at 24 m. Each contact holds directional input for **720 frames / 12 seconds**. Every stopping gap is **0.426150481 m**, above the source actor radius of 0.42 m, and additional pressure leaves the actor stopped.
- Ramp-to-wall contacts climb from **7.633142309 to 8 m** at the laboratory and descend from **16.728759030 to 16 m** at a canopy planter. Both settle on actual terrain support without penetrating.
- Both directions through the archive portals and beneath the aqueduct remain traversable using continuous source movement.
- A **test-only merged-quad negative control** reproduces the reported bug on the same ground pier. Starting at `(10,0,16)` with +X input for 120 frames: merged quads let the actor reach **X=23.618293963**, through the pier at X=13.35–14.65; the unchanged production triangles stop at **X=12.923849519**, gap **0.426150481 m**. Both representations still stop the source ray at **3.35 m**, demonstrating why shot tests alone were insufficient.

Before/after production measurements are identical: 712 triangles and geometry hash `0f089e1cc6f741b08a842b0225560cb261dcbdf7d5e7031829945499f29b0553`. This is a verification-only follow-up. Existing route graph and seven controlled source rounds retain their unchanged geometry provenance. No locked-source, registry, Blender or native work was performed.

## Explicit native art coverage contract — parent-owned integration

This map's recipe contains `arena.art = {meshes, palette}`, with **no `art.ground` array**. The older native `map.gd` path uses `art.ground` to decide whether to suppress fallback terrain rendering. Parent must explicitly mark this GLB as complete terrain visual coverage, so loading it does not also draw duplicate generated ground. Collision still comes from the reviewed terrain recipe. Do not infer coverage from the legacy field or use a generic whole-mesh collider.

The new GLB path is **`res://multiplayer_worlds/art/helix-conservatory/helix-conservatory.glb`**, not legacy `res://multiplayer_worlds/art/worlds/helix-conservatory.glb`. Parent owns the explicit art-path resolver and complete-coverage integration, plus scene/manifest packaging. Verify this path and coverage behavior during actual native import and image inspection before altering art design.

## Required heavy-slot continuation

1. Obtain explicit parent grant; verify `/home/mojo/.tmp-on-disk/cocs-blender-toolchain/blender-4.5.14-linux-x64/blender` exists. Run the author script serially with `LP_NUM_THREADS=1`, `--background --threads 1`, passing this worktree after `--`.
2. Inspect exported GLB mesh counts, bounds and coordinates against recipe and save actual artifact hashes. Confirm Blender master opens and mesh parts remain editable.
3. Parent integrates native scene and registry. Import serially with pinned Godot 4.5.2 at `/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64`, `LP_NUM_THREADS=1`.
4. Capture and actually inspect overview plus eye-level views of both rooms, all elevation bands, spawns, objective and aqueduct underside. Add high-contrast route signage and tune art only against inspected renders. Record GPU/device, mesh/material/draw counts and frame timings for this map.
5. Compare native triangle collision and visual mesh transforms/hashes. Walk all ramp/ring connections with native movement, shoot portals/glass/walls and check ceilings from below.
6. Controlled source full-round fixtures have passed for all seven candidates. Still run actual bots pursuing objectives and hosted source/native DM, CTF capture-return, and one-zone capture journeys. Publish only native-proven mode IDs.
7. Save footage, screenshots, fixture logs, hosted URLs and package verifier results; update hashes after any reviewed geometry change. Preserve old evidence and releases.
8. Explicitly release ENGINE/BLENDER slot after the granted serial work is stopped.

## Current limits

No Blender/Godot execution, import, bake, GLB, `.blend`, GPU screenshots, footage, native scene or hosted journey exists yet: heavy resources are exclusively assigned elsewhere. No FPS claim. Playable overlapping balconies cannot be represented by the locked highest-floor support function; this design instead provides four non-overlapping usable elevation bands. Art quality, combat sightline balance, objective readability, autonomous bot objective behavior and native full-round behavior remain unaccepted until the continuation above completes.
