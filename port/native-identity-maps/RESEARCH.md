# Identity trilogy: direct research synthesis

Status: discovery complete for prototype production; release acceptance is NOT complete. User explicitly authorized direct execution of all three research tracks after delegation authentication failed. These are three direct audits, not independent reviewers. Owned paths approved in that conversation: godot/identity_maps/, godot/tests/identity_maps/, tools/godot-identity-maps/, port/native-identity-maps/. Baseline 642acb0a5ddd7d5419c71000ad6e9dce97942be7, external/visual-identity-three-maps, /tmp/opencode/cocs-identity-maps. Primary has concurrent staged/untracked work and is untouched.

## Engine / performance track

Pinned binary actually returned 4.5.2.stable.official.6ce3de25a. No /dev/dri devices are available in this execution environment. Graphical results must identify the actual driver, not imply owner-GPU acceptance. WebXNG/SearXNG searches returned empty; web_extract is unsupported by this search backend and direct docs HTTP returned 403. Successfully retrieved seven official 4.5 branch .rst documents from https://raw.githubusercontent.com/godotengine/godot-docs/4.5/tutorials/ . Local raw research cache: /tmp/opencode/cocs-identity-discovery/docs/.

Feature decisions, based on official 4.5 sources:

| Feature | Source / finding | Prototype decision / required test |
|---|---|---|
| Glow | rendering/renderers.rst:274: Compatibility supported | Off by default; optional measured A/B, core composition independent of glow |
| LightmapGI | renderers.rst:231–235: render supported, bake requires RenderingDevice | Do not claim baked lightmaps; probe RenderingDevice and bake before adopting |
| SSAO/SSR/SDFGI/volumetric fog | renderers.rst:237–272: unsupported in Compatibility | None used |
| Automatic instancing | performance/optimizing_3d_performance.rst:107–119: Forward+ only | Explicit spatial-cell material batching |
| MultiMesh | performance/using_multimesh.rst:19–29: all-or-none visibility; page marked outdated | Use only bounded spatial batches if needed; verify class/current engine before adopting |
| Mesh LOD | 3d/mesh_lod.rst:70 onward: imported scene pipeline | Runtime ArrayMesh gets no claimed automatic LOD; optional prop ranges, never missing structural cover |
| Occlusion | 3d/occlusion_culling.rst:109–130: simplified occluders, exclusions for MultiMesh/particles | Opaque architectural blockers; test culling A/B before enabling proxies |
| Transparent effects | performance/optimizing_3d_performance.rst:46–55 | Opaque surfaces first; no full-screen water/glass/fog sheets |
| Collision | physics/collision_shapes_3d.rst | Simple static geometry, but source movement/rays remain authoritative |

Persistent offline vertex AO is the proposed fallback if lightmap baking cannot be established: hemisphere ray visibility against authored architecture, recorded sampling parameters, stored vertex colors. A hand-painted gradient is not a measured AO bake. No lightmap or AO bake is claimed at this stage.

Sources for orchestrator verification:
https://docs.godotengine.org/en/4.5/tutorials/rendering/renderers.html
https://docs.godotengine.org/en/4.5/tutorials/performance/optimizing_3d_performance.html
https://docs.godotengine.org/en/4.5/tutorials/3d/occlusion_culling.html
https://docs.godotengine.org/en/4.5/tutorials/3d/mesh_lod.html
https://docs.godotengine.org/en/4.5/tutorials/performance/using_multimesh.html
https://docs.godotengine.org/en/4.5/tutorials/3d/global_illumination/using_lightmap_gi.html
https://docs.godotengine.org/en/4.5/tutorials/physics/collision_shapes_3d.html

## Gameplay / authority track

Read source-lock and map-selection contracts, ACTIVE_LANES, RELEASE_MATRIX, combat-expansion and graphics-batch records. No tracked AGENTS.md or applicable ancestor AGENTS.md found. Locked source is 51289b79c627a26a381ba556b92bab71f93f3732; nine-map registry is not editable by this lane.

Exact inspected seams at baseline:
- game/core.mjs:107–108 highest-XZ floor/support; :195–301 actual moveActor; :376 walkEdge samples at .2 m and refuses >6.5 m links; :399–406 nav adds a 3 m grid and authored points, refuses .65 m obstruction. Do NOT author walk-under/walk-over floors.
- game/core.mjs:453 assigns arena before constructing nav, spawns, pickups; :454–455 accepts teamSpawns; :471–473 constructs source objective state and can snap objectives if nav farther than 2.5 m. Test physical marker agreement after construction.
- port/native-arenas/match.mjs:9–18 only deathmatch accepted. :25–48 provides a scoped constructor accessor rather than transplanting an already-constructed Match.
- port/native-arenas/schema.mjs:70–85 whitelist tied to three existing map IDs. :83–84 excludes teamSpawns/objectiveZones. Therefore no schema-compatible claim for this trilogy under existing native adapter.
- game/mode-data.mjs:73–89 supports arena.objectiveZones for unknown custom IDs; :113–121 builds actual Domination zones. Supply three zones, not local scoring.
- godot/zone_modes/demo.gd:12–13,60–65 requires locked catalog IDs. Reuse renderer/HUD after approved custom-world/session seam; do not change locked catalog.
- port/native-horde/authority.mjs:8–15 validates only three old maps; :98 constructs Match directly; :124–145 uses normal-rate 1/60 stepping and explicit lifecycle. Shared adapter remains parent-owned.
- game/singleplayer.mjs:331–346 forcibly retains one human, three Horde lives, opt-in endless, normal wave target; :388–408 spawns source wave composition/NPCs. No co-op claim. Existing local transport does not expose upgrade selection; source wave progression itself does not wait for an upgrade.
- game/enemy-types.mjs:30–43 Warden display scale 1.6; this is not automatically a larger authoritative collision capsule. Inspect source actor collision, then test both actual radius and conservative visual clearance. Reserve >=4 m ordinary corridors and >=6 m wave approaches.

Implementation: lane-local trusted in-process match factory reuses unchanged Match construction with approved arena accessor pattern. This proves data viability, not network integration. Supply strict lane-local catalog and immutable generated arena data. Public network frames must never load arbitrary paths or JSON geometry. Parent integrates explicit factory/config/catalog hooks into appropriate adapters and packages. Until then report prototype source tests separately from playable release.

## Art / level-design track

Existing code and reports show Prism's reactor/turbine/coolant decks, Aurora's lake/observatory/skywalk, Cinder's volcanic circuit. Avoid those architectural families, not just their colors. Existing rendered-image visual review remains a distinct gate; code/report inspection is not pixel inspection.

Lacuna uses horizontal carved crescents and an off-axis split resonator; Vermilion uses angular overhead fans and three pavilion shapes; Nacre uses serial elliptical ribs and a solid memory-drum mass. Common mineral shells, dark enamel functional joins, thin metallic inlays, three detail scales. Quiet pearl/chalk surfaces behind combat silhouettes. No decorative shape copies gameplay pickup or capture symbols.

Large opaque solids determine routes; detail never changes source collision. Skyline landmarks are static and outside movement clearances. Team/objective state comes from snapshots and uses shape/labels, not decorative palette. See DESIGN.md for route/camera/material plans.

## Resolution note (this pass)

The engine track's "Collision: simple static geometry, but source movement/rays remain
authoritative" line and the handoff's blocking finding — exact high-detail triangles through the
source wall-segment mover costing 6.1 / 3.0 / 14.8 s cold — are now closed by an authored collision
representation, not by a source edit. The proven pattern came from this repo: the native DM arenas
use source `nextGen` spatial navigation plus deliberately simple walls. Measurement, parity method
and residual bounds are in PERFORMANCE.md sections 1–2; the primitives and the per-form rationale
are in DESIGN.md and in each recipe's `artNotes[]`. The prototype's own numbers stay in the
historical evidence rather than being deleted.

## Synthesis / order

1. Deterministic declarative geometry and source-data compiler, lane-local factory, geometry/navigation/movement tests.
2. Validate each graybox with source movement before final decorative art.
3. Shared materials and distinct landmark meshes, bounded scene resources, inspection-only camera scene.
4. Explicit parent integration contract for DM/Domination/Horde; retain adapters' security and input epochs.
5. Normal-rate production gameplay, render/performance matrix, package and independent human review. Do not report these as passed from graybox tests.
