# Three new Blender-authored complex multiplayer maps

Owner requests another explicit Astra fan-out to design and build **brand-new,
very complex and unique maps using Blender**. Three `openai/gpt-6-astra` agents
start from `4ae4e5b7` in isolated worktrees. This map workstream runs alongside
the [source-feature pass](../next-port/WORKSTREAM.md); the owner's authorized
second feature pass starts after that first pass's verified release.

## Map briefs and ownership

| Map | Spatial and visual identity | Target modes, subject to acceptance | Agent |
|---|---|---|---|
| **Helix Conservatory** (`helix-conservatory`) | Terraced botanical arcology; open lightwell, spiral garden ramps, split ring balconies, seed archives and irrigation passages | DM, TDM, Arsenal, Juggernaut, CTF, Domination, KOTH | `ses_f055b8ad4ffeGterKBoxtnk2Q3` |
| **Gravemill Foundry** (`gravemill-foundry`) | Canyon-scale ore refinery; crusher drums, furnace towers, rail gantries, cooling galleries and a ground vehicle/service loop | DM, TDM, Payload, Assault, Combined Arms, Domination | `ses_f055b00c7ffe1uQyo7QsXqA0gC` |
| **Parallax Observatory** (`parallax-observatory`) | Coastal cliff astronomy institute; folded telescope dishes, calibration courts, instrument vaults, arc bridges and a cistern route | DM, TDM, CTF, KOTH, Uplink, Holdout | `ses_f055a6b41ffe42yCL8AxbOL676` |

These are design targets, not shipped mode capabilities. Agents must prove source
support and complete player journeys before a pair is advertised.

Worktrees under `/home/mojo/.tmp-on-disk/`:

- `cocs-new-map-conservatory-20261002` / `maps/conservatory-20261002`
- `cocs-new-map-foundry-20261002` / `maps/foundry-20261002`
- `cocs-new-map-observatory-20261002` / `maps/observatory-20261002`

Evidence uses the corresponding `cocs-new-map-<lane>-evidence-20261002/` directory.
Each map owns `port/new-maps/<map-id>/{DESIGN,ACCEPTANCE}.md`, its named recipe,
Blender authoring scripts, editable master, GLB, native data and focused tests.

## Design and implementation requirements

- Distinct architecture, materials and silhouettes, with at least three macro
  routes, connected elevation bands, interior districts and useful crosslinks.
- Complex traversal must remain readable: safe spawn exits, recognizable
  landmarks, flank routes and counters to elevated firing positions.
- Blender authors the final geometry. Retain the `.blend` master, exported GLB,
  reproducible scripts/seed and provenance.
- One reviewed recipe drives authoritative geometry and native presentation.
  Validate floor/ceiling support and underpasses against actual source movement;
  visible openings must not hide enclosing shot-blocking boxes.
- Preserve the frozen source lock and reviewed derivative. Existing source rules
  own combat, vehicles and objectives.
- Parent owns final shared map/mode catalogs, generators, selectors, package
  closure and verification inventories. Shared hooks from agents must be separate
  integration commits; map assets/tests remain isolated by map ID.

## Verification and resource queue

**Current map state: design, code and Node checks only.** World-weather acceptance
has released the slot; Modes now owns it, followed by Experience and parent
combined verification/exports before the map queue.
Map agents must return `READY FOR BLENDER` and receive an explicit parent grant
before Blender, import, bake, rendering or Godot runs. Use serial heavy processes
and `LP_NUM_THREADS=1`; no nested agents.

Acceptance requires source movement along actual routes, spawn/objective/nav
connectivity, cover/opening checks, mode-specific source outcomes, native geometry
agreement, real-input connected journeys and inspected overview/eye-level images
plus walkthrough footage. Record asset budgets and observed timings. Separate
controlled fixtures from natural play balance and real-GPU performance. Preserve
failed attempts and earlier releases.

## Design/source checkpoints

- **Helix Conservatory — `0eb5401b`, ready for Blender.** Deterministic 240 m
  radial plan, elevations 0/8/16/24 m and fifteen authored routes. Five source
  tests passed, including 27,544 real movement ticks, open/blocked shot and
  ceiling checks, and a connected 2,554-node navigation graph. Authoring script
  is prepared; no `.blend`, GLB, native rendering or hosted mode acceptance yet.
  Art starts from 1,338 explicit parts / 5,034 triangles / six materials.
- Source movement selects the highest walkable surface at each X/Z. Helix uses
  non-overlapping terraces, with non-walkable aqueducts and ceilings, to provide
  vertical routes without incorrectly claiming overlapping playable decks.
- Helix remains on its isolated map branch until Blender/native verification;
  its advertised `modeBindings` remains empty pending actual mode journeys.
- **Parallax Observatory — `408ed002`, ready for Blender.** Three major routes
  and three crosslinks over 0/12/24 m tiers, two through-interiors and a real
  water void. All 689 navigation nodes and 21 gameplay targets are connected;
  six routes passed source movement in both directions with zero measured
  floor-height error. Physical CTF journeys and a three-capture round passed,
  alongside controlled DM/TDM/KOTH/Uplink/Holdout fixtures. Blender/native art,
  screenshots, footage and hosted native acceptance remain pending.
- Parent is reviewing the shared [integration requirements](INTEGRATION.md).
- **Helix objective follow-up — `3549c4a1`: seven source rounds passed.** DM,
  TDM, Arsenal, Juggernaut, CTF, Domination and KOTH ended through source scoring.
  After initial controlled setup, the fixtures use inputs without actor/score
  writes: 30,134 source frames, 2,915.536 m walked and zero falls. CTF includes
  interact-drop/return and three physically carried captures. Combat uses explicit
  rail-start/unlimited-ammunition settings and shortened targets. These are
  scripted source fixtures; native, autonomous-bot and human acceptance remain
  pending. Geometry is unchanged and `modeBindings` is still pending.
- **Gravemill Foundry — `32cbf30f`, ready for Blender.** All eight routes passed
  movement in both directions; 3,711 navigation nodes connect 22 gameplay
  targets. A mounted Puma completed a 767.64 m service loop with zero observed
  collisions. Payload traversed 363.60 m through three checkpoints and delivery;
  all six controlled source rounds passed, including mount/drive/dismount/zone
  capture in Combined Arms. Blender assets and native checks remain pending.
- **Cross-map collision follow-up:** Foundry proved that untriangulated vertical
  wall quads can fail standing-player movement collision in the frozen source,
  despite blocking weapon rays. It emits individual wall triangles. Helix and
  Parallax agents are now checking actual movement contacts and updating their
  recipes/hashes where necessary before Blender production.

No finished Blender asset or native map acceptance is claimed at this checkpoint.
