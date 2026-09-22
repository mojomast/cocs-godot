# Subagent prompt — COCS visual-identity map trilogy

Copy the prompt below into a new implementation/orchestration subagent. Research
references were checked on 2026-09-22 against the Godot 4.5 documentation.

---

You are the environment-art and level-design implementation lead for
**COCS: DESTINATIONS**. Build three original, visually distinctive Godot maps for
**three different combat modes: Deathmatch, Domination and Horde**. Deliver actual
playable environments, reusable assets, evidence and an integration handoff—not
just concept documents, screenshots or empty exploration scenes.
Do not create racing or soccer maps. Campaign remains outside this assignment.

## Context and ownership

- Repository: https://github.com/mojomast/cocs-godot
- Primary workspace:
  `/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port`
- Integration branch: `port/godot-destinations`; publication remote: `godot/main`.
  Preserve `origin`. Inspect the actual branch/HEAD/status; the checkout is active.
- Godot pin: `4.5.2.stable.official.6ce3de25a`.
- Linux binary:
  `/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64`
- Compatibility is the production renderer. Node owns authoritative gameplay;
  Godot owns rendering, input, presentation and audio.
- First read `port/handoffs/ACTIVE_LANES.md`, `port/RELEASE_MATRIX.md`,
  `port/combat-expansion/README.md`, `port/graphics-batch/README.md`, the source-lock
  and map-selection contracts, and applicable `AGENTS.md` instructions.
- Inspect existing native maps, `godot/native_arenas/`, `port/native-arenas/`,
  `tools/godot-native-arenas/`, `godot/zone_modes/`, `godot/horde/`,
  `port/native-horde/`, and launch/package options. Some of these are being
  implemented concurrently. Do not assume a proposed API is already delivered.
- Proposed exclusive new paths: `godot/identity_maps/`,
  `godot/tests/identity_maps/`, `tools/godot-identity-maps/`,
  `port/native-identity-maps/`. Agree ownership with the parent before edits.
  Shared launcher/authority/package changes belong to the parent until released;
  supply precise integration patches/contracts rather than racing another agent.
- Preserve all existing maps and modes, current releases, user work, and the
  untracked `port/handoffs/procedural-model-generation-llm-research.md`. Preserve
  reserved external weapon assets and shared services, including port 4332 and
  `http://100.125.104.79:43595/`. Use private ephemeral services for tests.

## Creative goal

The owner wants to discover the game's visual identity. Produce three strong art
directions with different silhouettes, architecture, materials, lighting and
spatial rhythms. A different sky color or palette on the same industrial kit is
not sufficient. Avoid another reactor foundry, polar observatory or lava facility;
Prism Foundry, Aurora Basin and Cinder Array already cover those territories.

Use this common COCS design language to make them belong to one game:

- Monumental, legible silhouettes; crafted ceramic/mineral shells; exposed
  functional machinery where structures join; restrained luminous inlays.
- Three scales of detail: strong large forms, readable functional assemblies,
  selective close-range surface detail. Quiet combat backgrounds are intentional.
- Shared symbols, interaction affordances, believable scale and material response.
  Shape and value must distinguish team/objective signals, not color alone.
- Energy effects indicate function and state. Decorative lights cannot resemble
  pickups, hostile projectiles, capture indicators or walkable doors.
- Original environmental storytelling and architecture. Build new combinations,
  not replicas of recognizable maps, franchises or artists' signature designs.

### 1. LACUNA COURT — Deathmatch

**Direction: sunlit mineral precision.** An abandoned acoustic exchange carved
into pale stratified stone. Huge off-center listening dishes and concave stone
walls surround a dry resonance court; indigo enamel machinery fits into the cuts.
Fine copper seamwork, chalk-white dust and a slowly turning distant acoustic sail
give it a distinctive identity. The sail is scenery, not moving combat cover.

- Shape language: offset circles, carved crescents, thick slotted walls, narrow
  copper joins. Palette: warm chalk, deep indigo, restrained copper light.
- Landmark: a split circular resonator visible from several route entrances.
- Default design load: 4–8 combatants, configurable through existing authority.
- Compact intersecting loops, at least two exits from principal combat spaces,
  short/medium engagements, deliberate longer sightline with flank access.
- Multiple protected spawn pockets; no direct spawn-to-spawn sightline. Distribute
  power weapons and recovery pickups to encourage circulation, not one bunker.
- Elevation comes from source-compatible ramps and terraces, with cover that
  interrupts long views. No mandatory jumps or decorative ledges that look usable.
- Signature effect: a restrained vibration travelling along embedded seamwork,
  with localized windblown dust outside the central aiming space.

### 2. VERMILION FOLD — Domination

**Direction: tensile civic futurism.** A terraced public signal garden grown
around enormous folded structural ribbons. Vermilion ceramic panels, jade enamel
channels and matte ivory tension members form three distinct civic pavilions.
Engineered pleats and curved retaining walls define routes; this is neither a
generic neon city nor a reskinned industrial base.

- Shape language: folds, fans, pleated shells, broad curved retaining walls.
- Palette: vermilion, ivory, deep jade; objective/team colors remain unambiguous.
- Landmark: a fixed, crown-like folded canopy; slight decorative edge motion
  must not alter visibility of enemies or authoritative collision.
- Default design load: 3v3 or 4v4, subject to supported native authority capacity.
- Three actual capture sites with unique silhouettes and callout names. Each
  objective has multiple approaches; avoid a single position watching all three.
- Measure spawn-to-objective travel times in both directions, rotation times and
  spawn safety with the actual movement controller. Geometry may be asymmetric,
  but repeated travel-time measurements should support fair starts.
- Distinguish contested ground from a safer rotation route. Keep capture volumes,
  HUD bearings and physical objective locations in agreement.
- Signature effect: small sheets of light moving inside opaque structural ribs;
  objective-state effects must read source ownership/contestation.

### 3. NACRE ENGINE — Horde

**Direction: abyssal biomechanical antiquity.** A dry, pressure-sealed chamber in
a deep-sea computation organism. Giant shell-like pressure arches, ribbed mineral
vaults and layered nacre housings surround an old mechanical memory engine.
Deep ultramarine recesses contrast with warm pearl combat surfaces and sparse
amber bioluminescent service organs. Water is beyond sealed viewports, not a
screen-filling transparent volume through the fighting space.

- Shape language: nested shells, ribs, growth rings, thick elliptical apertures.
- Palette: pearl, ultramarine, muted amber; enemies remain easy to identify.
- Landmark: a massive static nacre memory drum with bounded internal animation.
- Use the supported Horde player count; current single-human play must work.
  Architecture can allow future co-op, but do not advertise unimplemented co-op.
- Several readable enemy approaches; reserve sufficient source-agent clearance
  for the largest supported enemy/boss. Spawn areas cannot strand enemies.
- Connected retreat loops and useful recovery pockets; no permanently invulnerable
  camp spot, unavoidable spawn trap or narrow chokepoint that stalls whole waves.
- Integrate real wave spawning, combat, recovery/upgrade opportunities where
  supported, player defeat and restart. If the source mode supports a boss/endless
  transition, include space and explicit verification for it.
- Signature effect: bounded pressure pulses behind the shell housings and sparse
  suspended motes. The environment must remain readable during peak wave FX.

## Phase 1 — parallel discovery and research

Launch three independent read-only research subagents. Do not implement until
all three return and their findings have been synthesized.

1. **Engine/performance:** check the exact Godot 4.5.2 renderer, resource pipeline,
   lighting, instancing, LOD, shader and profiling constraints. Read the official
   sources below; return supported techniques, version caveats and concrete tests.
2. **Gameplay/authority:** inspect native arena, Domination and Horde adapters;
   establish map schema, actor clearance, collision/raycast semantics, spawn/nav
   requirements and real round lifecycle. Identify any missing custom-map seam.
3. **Art/level design:** inspect existing screenshots/assets, assess the proposed
   three directions and produce topology sketches, material boards and landmark
   plans. Return a clear comparison explaining why each map looks and plays
   differently, and what connects them to COCS.

Each returns exact file/line findings, sources, risks that actually affect this
project, recommended owned paths, and an actionable implementation plan.

## Research-backed technical requirements

- **Build for Compatibility first.** Do not rely on SSAO, SSR, volumetric fog,
  VoxelGI, SDFGI, screen-space normal textures, Decal nodes or automatic mesh
  instancing. Their availability differs by renderer. Use supported material
  detail, vertex/texture AO, carefully placed mesh markings and ordinary fog.
- Godot 4.5's renderer comparison lists **Compatibility glow as supported**.
  Verify its actual appearance/cost on the pinned build instead of assuming
  either universal support or universal absence. Core art must read without it.
- **LightmapGI can render baked lightmaps in Compatibility**, but baking needs
  RenderingDevice-capable hardware. Test the available bake environment first.
  Bake static map geometry offline into persistent resources with valid UV2;
  runtime-generated geometry does not acquire baked lighting automatically.
  If baking is unavailable, implement and label a genuine vertex/texture-baked
  lighting/AO alternative rather than pretending a lightmap bake succeeded.
- Prefer static lighting and bounded real-time shadows. Start with one shadowed
  key light and a small measured local-light budget. Separate emission appearance
  from actual light sources; every luminous trim does not need an OmniLight.
  Static or update-once reflection probes are preferable to continuous captures.
- Reuse a small material/trim-sheet library, consistent texel density and texture
  mipmaps/compression. Favor 1K/2K reusable textures; justify larger assets with
  measured screen coverage and memory. Bake tiny bevel/fastener detail into normals
  where it cannot affect the silhouette. Use triplanar selectively, not by default
  on every surface; measure texture sample cost.
- Batch static geometry by material **within spatial cells**. Do not merge the
  entire map into one giant mesh whose bounds defeat culling. For repeated meshes,
  use spatially partitioned MultiMeshes: one map-wide MultiMesh has all-or-none
  culling and shared LOD selection, not individual instance culling.
- Imported GLB scenes can generate automatic mesh LOD. Runtime ArrayMesh creation
  is not the same import pipeline; supply explicit LOD data or authored substitutes
  when needed. Use visibility ranges/HLOD for distant props and expensive FX.
- Design opaque route bends and architectural masses for occlusion. Use simplified
  static occluders and measure the same camera paths with culling on/off. Open
  vistas may not benefit enough to justify CPU cost. Occluders must never conceal
  visible enemies through windows or doors. MultiMeshes/particles are not included
  in automatic occluder baking; place appropriate simple proxies when necessary.
- Opaque surfaces first. Separate transparent portions, keep blended screen
  coverage low, and avoid stacked full-screen fog/water/glass sheets. Optimize
  particles by coverage, shader cost and draw submissions as well as count.
- Decorative GPU particles use shared bounded budgets, distance gating and correct
  visibility bounds. The owner reports smooth million-particle lab performance;
  that is not permission to reserve a million particles independently per map
  emitter. Reuse the combat quality manager if delivered; preserve Low/High options.
- Avoid per-prop `_process`, per-frame mesh construction and repeated material
  duplication. Prebuild/cache static assets; release map-owned resources on exit.
- Use simplified collision geometry. Godot supports static concave level meshes,
  but **the Node authoritative mover is the gameplay constraint here**. Match
  Godot presentation/query collision to source floor, wall, ray and nav semantics.

### Critical source-physics constraint

The locked source mover/navigation presently chooses the highest floor at each
XZ position. Walk-under/walk-over layouts do not work just because Godot collision
supports them. Navigation also derives Y from source floor queries. Inspect whether
this constraint still holds; if so, design ramps/terraces with no overlapping
accessible floors. Close unsupported lower spaces with matching visible
architecture. Preserve eye→muzzle and muzzle→target authoritative ray behavior.

Native DM's current adapter is deathmatch-only. Do not claim that changing a map's
mode label implements Domination or Horde. Extend only the appropriate port-owned
mode adapter, through parent-approved integration, and prove real capture/wave
behavior. Do not modify locked source simulation or the nine-map catalog.

## Phase 2 — synthesis and measured budgets

Write `port/native-identity-maps/DESIGN.md` and `RESEARCH.md` before art production:

- Three top-down route plans, dimensions, cover/clearance rules, spawns/objectives,
  skyline/landmark sketches, palette/material sheets and fixed review cameras.
- Actual mode integration contracts and expected file changes/ownership.
- A renderer-specific feature matrix with source links and tested decisions.
- Proposed budgets for visible surfaces/draw calls, triangles, texture/lightmap
  memory, shadowed/unshadowed lights, particles, physics/nav cost and load time.
- Capture an existing playable-map baseline on the same machine/settings. Compare
  graybox and final art along the same routes. Treat budget numbers as project
  hypotheses to verify—not universal Godot limits or invented measurements.
- Target stable 60 FPS at 1920×1080 on an identified representative desktop GPU,
  leaving headroom for actors, HUD and combat. Report CPU/GPU and p95 frame times
  where measurable. A llvmpipe run is useful comparative evidence, not hardware
  acceptance; label absent hardware testing explicitly.

## Phase 3 — sequential implementation subagents

After synthesis, run implementation units one at a time so later units use
verified contracts. Each returns its exact changed files, rationale and checks.

1. Shared identity-map resources, deterministic geometry/data export and minimal
   presentation/authority contracts. Prefer existing working helpers.
2. Lacuna Court: graybox source traversal/spawns/bot loop first, then final art.
3. Vermilion Fold: real capture/rotation prototype first, then final art.
4. Nacre Engine: enemy navigation/wave/defeat prototype first, then final art.
5. Mode/launcher/package integration with the parent, performance tuning and docs.
6. Independent final gameplay/visual review; only minimal targeted corrections.

Keep graybox and final visual/collision provenance. Assets must be reproducible
from committed source/resources, not dependent on a private editor cache. Provide
map-only scenes/builders usable by production sessions and a separate inspection
scene. Reuse the existing player, weapons, ADS and effects; do not invent another
combat controller, local damage model or authoritative bot simulation.

## Phase 4 — verification and evidence

Use real tests where they prove behavior, not tests mirroring implementation.
Retain failures with fixes and reproducible commands. Required evidence:

- Every spawn and pickup stands on source-confirmed accessible floor with actor
  and boss clearance as applicable. Source ray occlusion matches visible cover.
- Full route traversals using production movement; ramps, crests, corners, drops,
  boundary recovery and navigation connectivity. No invisible walls or resets
  concealing broken traversal. Bots reach the relevant fight/objectives.
- Deathmatch: real weapon hit, damage, scored kill, death/respawn, results/restart.
- Domination: actual capture/contest/score updates, both teams' approach timings,
  result/restart; include recovery from losing objectives.
- Horde: multiple real waves and recovery phase, player defeat/restart and at
  least one sustained representative peak-load run; explicitly state which full
  boss/endless/wave-completion paths were tested or remain open.
- Rendered 960×640, 1280×800 and 1920×1080 captures: entrance, landmark, combat,
  objective and worst visible sector. Review actual images, not just capture logs.
  Include readable operators at 10m/25m and ADS sightlines with effects active.
- Record fixed-camera/path median/p95 frame cadence after warm-up, cold load and
  shader stutter separately, draw/primitive counts, available memory counters and
  actual concurrent actors/particles. Show Low/High and culling/LOD comparisons.
- Repeat map load→play→results/defeat→restart→unload at least three times; inspect
  live resources/nodes, input freshness, restored camera and listener cleanup.
- Use normal-rate authority; separate injected fixtures from live input/play.
  No FPS claims from headless execution. Never equate source triangle counts with
  measured GPU speed or convert software-renderer timings into hardware promises.

Commands (resolve the repository's delivered map-specific commands in discovery):

```bash
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
"$GODOT_BIN" --headless --path godot --editor --import
PORT=0 TMPDIR=/tmp/opencode python3 tools/godot-dev/verify.py
git diff --check
git status --short
```

Run the new geometry, mode, rendered and resource checks as well. An active
checkout's unrelated failures must be diagnosed and reported, not edited away.

## Phase 5 — documentation, commits and release handoff

- Deliver `DESIGN.md`, `RESEARCH.md`, `PERFORMANCE.md`, `PLAY.md` and an integration
  handoff under `port/native-identity-maps/`, with exact commands and evidence.
- Document how each art direction advances COCS identity, actual technical budgets,
  mode acceptance, controls, limitations and known failures.
- Commit only owned paths. Preserve unrelated edits/staging and historical evidence.
  Return commit hashes; let the parent integrate/push to `godot/main` and publish
  after combined verification. Do not independently replace the current release.
- Coordinate an integrated Windows rebuild after the parent applies shared hooks:

```bash
python3 tools/godot-package/build.py --target windows \
  --state /tmp/opencode/cocs-identity-maps-package \
  --archive-directory /home/mojo/.hermes-instances/fresh/workspace/godot-toolchain
```

- Re-read builder options: use the parent-approved operator setting if the imported
  roster has landed. Keep generated executable archives outside Git.
- Restart only owned test processes. Start a fresh owned ephemeral authority per
  route; verify its documented HTTP health response with `curl --fail`, then launch
  the actual production client. Leave shared services untouched.
- Verify the detached exported package finds all maps/materials/baked resources
  without the source checkout or editor cache. Test menu routes, quit cleanup and
  all three mode flows. Windows headless validation is not graphical/audio approval.
- Provide exact launch commands and verified downloadable/test links when a build
  exists; otherwise identify the concrete artifact path and outstanding parent
  publication step. Never invent a live link or report a stale binary as current.

## Final response

Summarize the three maps/modes, show representative images, explain the shared
visual identity and their differences, report measurements with hardware/renderer
and resolution, list passed gameplay/build checks and remaining manual checks,
provide commits and launch/test links, and name any concrete integration blocker.

## Official references to verify and cite

1. Renderer feature comparison:
   https://docs.godotengine.org/en/4.5/tutorials/rendering/renderers.html
2. 3D performance, transparency, instancing, lighting:
   https://docs.godotengine.org/en/4.5/tutorials/performance/optimizing_3d_performance.html
3. Occlusion design, simplified occluders and CPU tradeoffs:
   https://docs.godotengine.org/en/4.5/tutorials/3d/occlusion_culling.html
4. Mesh LOD, import behavior and MultiMesh selection:
   https://docs.godotengine.org/en/4.5/tutorials/3d/mesh_lod.html
5. MultiMesh spatial partitioning (page carries an update warning; cross-check
   against the class reference and exact engine behavior):
   https://docs.godotengine.org/en/4.5/tutorials/performance/using_multimesh.html
6. Static lighting, UV2, bake modes and moving actors:
   https://docs.godotengine.org/en/4.5/tutorials/3d/global_illumination/using_lightmap_gi.html
7. Collision geometry and broad-phase considerations:
   https://docs.godotengine.org/en/4.5/tutorials/physics/collision_shapes_3d.html
