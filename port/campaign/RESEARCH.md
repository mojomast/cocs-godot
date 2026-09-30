# Campaign design research — Flash discovery

Research conducted by DeepSeek V4.1 Flash before Astra implementation. This
memo records actionable findings rather than treating design targets as tests.

## Current content and scale

Canopy Divide and Basalt Reach are 96 × 80 m (7,680 m²), each with 3,840 terrain
triangles and approximately 554 m of combined arena routes. That network length
is not an ordered campaign critical path. Existing source movement is 8 m/s
walking and 11 m/s sprinting; a 96 m crossing takes only 9–12 seconds.

The existing biome renderer hardcodes its bounds, two map IDs, scatter loops,
height indexing and horizon placement. Simply increasing dimensions would
produce incorrect placement or excessive work. Campaign geometry needs explicit
bounds, height/collision agreement, spatially bounded scenery and authored routes.

Source singleplayer already has enter-zone, group-dead, boss-dead, timer and
hold steps, authored anchors, checkpoints and progression. Its default 300-second
match clock is unsuitable for 5–10 minute missions. Its per-checkpoint elapsed
counter is not total mission duration.

## Principles selected for implementation

- Alternate explore, combat, story and interaction beats. Teach a mechanic in a
  simple context, test it, then combine it with established mechanics.
- Introduce no more than one enemy role at once; use two complementary roles
  in ordinary encounters and roughly three in complex encounters.
- Give the player a readable entry foothold, cover, flanking choice and a
  visible destination. Avoid fighting every encounter from the previous doorway.
- Build an ordered 700–2,000 m critical path depending on duration and movement
  speed. Most travel legs should end at a landmark or beat within 60–150 m.
- Put checkpoints before difficult fights; replaying solved corridors is not
  challenge. Preserve objective progress correctly across retries.
- Use shared geometry for floor placement/collision. Batch static props, use
  bounded foliage density and visibility ranges, and chunk larger terrain.
- A few hundred metres does not require double-precision world coordinates.
- Measure rendered compatibility separately from real hardware performance.
- Target 300–600 seconds per level; human first-playthrough timing is needed to
  establish that target. Automated completion proves sequencing, not fun or pace.

## Sources

- Level Design Book, pacing:
  https://book.leveldesignbook.com/process/preproduction/pacing
- Level Design Book, encounter structure:
  https://book.leveldesignbook.com/process/combat/encounter
- Level Design Book, metrics:
  https://book.leveldesignbook.com/process/blockout/metrics
- Level Design Book, critical path:
  https://book.leveldesignbook.com/process/layout/criticalpath
- Valve/GDC workshop, pacing:
  https://media.gdcvault.com/gdcchina14/presentations/833762_JoelBurgess_MattScott_LeePerry_3_Pacing_EN.pdf
- Andrew Yoder, combat doorway design:
  https://andrewyoderdesign.blog/2019/08/04/the-door-problem-of-combat-design/
- Michael Barclay, level design guidelines:
  https://mikebarclay.co.uk/my-level-design-guidelines
- Hullett/Whitehead, FPS design patterns:
  https://users.soe.ucsc.edu/~ejw/papers/hullett-fps-fdg2010.pdf
- Godot visibility ranges:
  https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html
- Godot 3D performance:
  https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html
- Godot MultiMesh:
  https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html
- Godot coordinate precision:
  https://docs.godotengine.org/en/stable/tutorials/physics/large_world_coordinates.html
- Yacht Club Games, checkpoint design:
  https://www.yachtclubgames.com/blog/check-point-design

## Acceptance evidence to collect

Per-map footprint and ordered route length; route reachability and grade;
required anchors and enemy encounter deployment; objective gating without
skipping required fights; checkpoint/death/retry; continuity through all four
levels and ending; distinct enemy silhouettes and telegraphs; export resource
closure; both platform launch acceptance. Record real human timings separately
when available, including deaths and checkpoint attempts.

## Enemy and integration research — second Flash lane

The source already exposes suitable Match method seams, terrain support, bot
brains and enemy-role updates. A separate port-owned loopback campaign adapter
can reuse movement/weapons/AI while owning the new mission definitions. Custom
mission IDs must not pass through the source `missionFor()` fallback, which
would load an old mission. Known `npcType` brain aliases remain authoritative;
an additive `npcModel` field selects the new robot geometry on the native client.

Six visual roles were selected: quadruped scrapper, narrow skirmisher, tripod
sentinel, mortar walker, shield bulwark and multi-legged Warden. Their shapes,
attack cues and counterplay should be recognisable independently of colour.
Use anticipation, attack and recovery phases driven by actual role state.
Introduce the roster gradually rather than putting all six types in one fight.

Procedural meshes do not automatically receive imported-mesh LOD. Use explicit
near/mid/far geometry and count every overlay in rendering-cost metrics. The
earlier operator armor accounting gap must not recur in the new enemy models.

Additional sources:

- Enemy design: https://book.leveldesignbook.com/process/combat/enemy
- Attack anatomy: https://gdkeys.com/keys-to-combat-design-1-anatomy-of-an-attack/
- Believable enemies: https://gdkeys.com/ai-keys-to-believable-enemies/
- Valve art/readability:
  https://cdn.cloudflare.steamstatic.com/apps/valve/2008/GameFest08_ArtInSource.pdf
- Fullbright encounter design:
  http://www.fullbrightdesign.com/2009/02/basics-of-effective-fps-encounter.html
- Orthogonal choice in enemies: http://www.worch.com/2014/03/23/decisions-that-matter/
- Godot mesh LOD: https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html

The original campaign was explicitly deferred in the native release matrix.
This user request activates a new researched campaign; the old source campaign
is a technical reference, not the new story specification.
