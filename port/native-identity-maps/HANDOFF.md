# Orchestrator handoff — identity trilogy prototype milestone

NOT a final playable-map delivery. Direct research and initial source-tested/renderable prototypes are delivered. Shared production integration, final art, visual acceptance and release gates remain open. Do not publish these as completed maps.

## Ownership and baseline

Owner approved direct research instead of unavailable subagents and the four proposed new directories in chat. Isolated worktree /tmp/opencode/cocs-identity-maps; branch external/visual-identity-three-maps; baseline 642acb0a5ddd7d5419c71000ad6e9dce97942be7. Primary checkout and its concurrent staged/untracked files were not edited. No source game modules, nine-map catalog, shared authority, launchers, packages, credentials, shared services or reserved external weapon assets changed.

Read RESEARCH.md (three direct tracks with exact source references and renderer caveats), DESIGN.md (plans/material boards/budgets), PERFORMANCE.md (actual counters and serious load-time issue), PLAY.md (actual commands).

## Implemented owned artifacts

- tools/godot-identity-maps/compile.mjs: deterministic native recipe/compiler; source floors/blocks, spawns, pickups, authored objectives, route plans and fixed cameras.
- tools/godot-identity-maps/art.mjs: original carved split resonators, folded fans/crown/pleats, elliptical shell vault and layered memory drum. These are first-pass silhouettes, not finished environment art.
- godot/identity_maps/generated/: three reproducible JSON recipe artifacts with canonical geometryHash and earlier grayboxHash. Every architectural triangle is exported for source rays; overhead forms are nonwalkable.
- godot/identity_maps/map.gd: map-only builder, exact source-aligned static physics, five cached materials, material/spatial-cell mesh batching, idempotent build. No bespoke movement/combat simulation.
- godot/identity_maps/inspection.{gd,tscn}: labelled fixed-camera inspector. Tab maps / 1–5 views / Esc exit. Headless startup verified; human input/pixel review pending.
- port/native-identity-maps/match.mjs: trusted in-process source Match factory using scoped arena accessor before source nav/spawn/objective construction. Static allowlist, mode-specific defaults, no arbitrary JSON/path network input.
- graybox.test.mjs: actual source movement in both directions, nav connectivity, clearance, no direct DM spawn sightlines, objective position agreement.
- ray-oracle.mjs + Godot rays.gd: independently computed source rayWorld distances compared with actual Godot physics.
- normal-rate.mjs: bounded wall-clock source-mode exercise with ordinary controls and no state injection; exact recipe/snapshots/events archived. NOT a WebSocket/native-client test.
- lifecycle.gd and capture.py/capture.gd: bounded cleanup/capture evidence, private owned Xvfb, explicit software-renderer counters.

## Verified current geometry

Final route suite: 35,714 checks pass (mostly per-frame floor/penetration checks); connected nav for all maps, full declared routes both directions, Lacuna 1.5 m terrace ascent/descent, six protected DM spawn pair sightline checks, source-confirmed pickups/spawns, conservative Horde spawn visual clearance and exact three Domination points.

Final source/Godot ray comparison: 108 checks pass. This is static geometry parity for sampled cover/architecture/infill, not complete weapon eye→muzzle→target acceptance.

Final headless lifecycle: 251,652 checks pass (mostly finite vertices); three full build/free cycles each return to one root node/two resources/zero orphans. No claim that this proves production match/audio/input lifecycle.

Two independent final recipe rebuilds were compared against all three persisted artifacts successfully after the infill correction. Generated JSON was then serialized compactly without semantic geometry changes. Final geometry hashes are authoritative in generated JSON and capture reports.

Final source-mode evidence: evidence/normal-rate-1790081542205/ includes compressed exact recipes, snapshots and events. Lacuna: 2,265 snapshots, 1 result at source60.017s, restart observed; second round incomplete at wall130s deadline. Vermilion: 1,058 snapshots, 7 capture events, 55 zone-score events, 2 objective wins with a restart. Nacre: 1,576 snapshots, six wave clears/resupplies across two actual three-wave source wins and restart. No injected kills/poses/time. These are bounded in-process source runs with concurrent scheduling and capped backlog, not real-time performance or network-client acceptance. Defeat/boss/endless and full ten-wave Horde were NOT proved.

45 final PNGs: evidence/render-1790081900090569141/{960x640,1280x800,1920x1080}/. Five views per map per resolution. No actors/FX; combat/objective are camera names, not live gameplay claims. Browser navigation service returned HTTP500 at localhost:9377/tabs even though the owned image HTTP endpoint returned200. Images have NOT been visually reviewed.

## Retained failures and fixes

Capture resolution correction: only render-1790081900090569141 passes independent PNG dimensions at all three sizes. Earlier sets were all1280×800 despite filenames claiming other sizes. Godot reapplied the project window dimensions after _initialize; deferred sizing and output-size assertions fix it. Earlier 1080p/960 claims are invalid and preserved as failures; see evidence/README.md.

1. Lacuna graybox nav initially disconnected (5/253 reached): widened spawn pocket openings and explicitly sampled narrow perimeter paths. Connected result retained.
2. First art export assumed source walls honored triangle indices. game/terrain.mjs:51–61 ignores those indices and fans vertices, producing degenerate/unintended walls. Changed to one source wall per actual triangle. This fixes correctness but exposes wall-scan cost.
3. First Godot capture failed on GDScript type inference for dictionary-derived material index. Explicit int corrected; initial invocation timed out180s, then bounded runner was added. Subsequent capture sets exit0 without script errors.
4. Ray oracle initially started one ray inside cover: source returns0 while Godot default ray behavior didn't. Enabled hit_from_inside to match source semantics. Initial failure retained in rays-first.json.
5. Ramp visual infill originally lacked matching collision. Added exact source/Godot infill. This then exposed an internal ramp/terrace endcap snag at Y1.428/Z−21.568. Removed both internal seam faces; final traversals/rays pass. Failed route log retained.

## Parent-owned integration hooks — agreement required before edits

These maps cannot enter the existing release by changing a map label:

1. port/native-arenas/catalog.mjs + schema.mjs + match.mjs currently allow only three pre-existing native maps and Deathmatch. For Lacuna, approve a lane registry or explicit allowlisted factory hook. Do not silently feed extended recipes into the old strict envelope (teamSpawns/objectiveZones are absent from its whitelist).
2. Domination: approved local adapter must construct source Match using this factory with mode=domination and arena.objectiveZones/teamSpawns BEFORE nav, actors and objectiveTemplate run. Source zones must remain the snapshot authority. godot/zone_modes/demo.gd:12–13/60–65 currently rejects IDs outside locked catalog; supply a separate custom-world loading path and reuse existing zone adapter/renderer/HUD.
3. Horde: port/native-horde/authority.mjs:8–15/98 needs an explicit reviewed static map/factory hook. Retain loopback-only transport, input epochs, event cursor, bounded messages and single-human contract. Do NOT enable Horde in public Room. Upgrade selection/boss/endless/full-defeat behavior remains separate acceptance.
4. Godot session composition: use map.gd as the environment instead of locked-map viewer geometry while preserving existing presentation, player/operator models, first-person weapons/ADS, pickups, combat events/audio/quality manager, source camera poses and round cleanup. There is no production client seam implemented in this milestone.
5. Launcher/menu/package routing stays with parent. Add only explicit three map/mode pairs to an approved registry; bundle generated JSON, builder and required source adapter closure. Test detached Linux and Windows packages after full integration, not before.

## Blocking performance/art work before integration acceptance

Exact high-detail source walls cause cold Match construction ~6.06s Lacuna /2.95s Vermilion /14.83s Nacre on this host. Simplify authored collision with explicit visual/ray provenance, not locked-source edits or invisible support. Software-rendered Nacre worst-camera p95 ~52.57ms at verified1920×1080 with ZERO actors/particles is not 60Hz acceptance. See PERFORMANCE.md.

The art pass does not yet satisfy final lighting/material/detail goals: no LightmapGI bake or genuine vertex AO, no trim textures, no bounded signature FX, no Low/High or occlusion/LOD comparison. Lacuna/Vermilion/Nacre now have different core silhouettes, but that is not final visual identity acceptance.

Remaining mandatory gates: pixel review, existing-playable-map baseline, 10m/25m operator and ADS/FX readability, real production-client weapon kills/respawn, capture/contest/loss recovery, Horde defeat/restart/boss/endless/peak load, three complete integrated lifecycle cycles, actual-controller repeated timing/fairness under live play, exported resource/menu/input/audio checks, independent final review and representative GPU performance. No merge/push/deploy/release was performed.
