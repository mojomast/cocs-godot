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

**Initial state: design, code and Node checks only.** World-weather acceptance
currently owns the exclusive Godot/heavy slot; Modes and Experience follow.
Map agents must return `READY FOR BLENDER` and receive an explicit parent grant
before Blender, import, bake, rendering or Godot runs. Use serial heavy processes
and `LP_NUM_THREADS=1`; no nested agents.

Acceptance requires source movement along actual routes, spawn/objective/nav
connectivity, cover/opening checks, mode-specific source outcomes, native geometry
agreement, real-input connected journeys and inspected overview/eye-level images
plus walkthrough footage. Record asset budgets and observed timings. Separate
controlled fixtures from natural play balance and real-GPU performance. Preserve
failed attempts and earlier releases.

No map asset or native acceptance is complete at this launch checkpoint.
