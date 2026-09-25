# L2 guidance handoff

Status: implementation delivered; focused GDScript fixture authored but **not run** (engine/import slot is reserved). Base is the L1 handoff's `d23d02a56ba622defffc94c249a08af9b32350c6` plus accepted L1 files in this working tree; do not infer acceptance from static checks.

## Owned implementation

- `godot/lattice/world_target.gd`: pure advisory selector consuming recipient projection, `topology.model(...)`, local planar pose, previous target and optional explicit selection. Returns `target_id`, `intent`, `reason_code`, text, `capture_legal`, supply, source sequence/context. It sends no frames and does not simulate movement/capture or source attribution.
- `godot/lattice/world_hud.gd`: topology map-binding seam `bind_authored_map(map_id, source_map)`, topology-derived marker facts and target guidance. Text preserves separate owner, live/contest, capture legality, supply and own progress labels; marker color is redundant to symbols/text. Existing `approach_node` remains legacy-only and is not the recommendation path.
- `godot/lattice/topology.gd`: missing owner is now distinct from explicit JSON null (known neutral). Completeness requires all authored nodes and known owner fields. Unknown target ownership cannot certify capture or supply; adjacency may still be known independently. HQ connectivity/cut remains certified only from complete view + visible owned home + received cuts. Adjacency is not income/supply.
- `godot/tests/lattice/flagship_l2_contract.gd`: synthetic geometry exercises a closer illegal enemy alongside legal frontiers, a disconnected frontier next to an own cut, incomplete ownership, opponent dominance with a neutral legal prerequisite, absent/null dominance and missing `breakCount`.

## Required composition request to Sol

`world_demo.gd` is outside L2 ownership and is deliberately unmodified here. At map identity selection/start, call `lattice_hud.bind_authored_map(current_id, catalog.resolve_map(current_id))` (check the catalog accessor's exact return type); stop/rebind on map changes. Existing `apply_projection` and `text` then consume the projection automatically. If `resolve_map` returns a wrapper rather than the authored dictionary, pass its authored map dictionary. A map-bind failure must leave target/supply unknown, not fall back to a guessed graph. Consider exposing an explicit selection ID to the HUD after board-selection integration; no such selection is currently wired by this lane.

## Verification/evidence

- Read `FLAGSHIP_PLAN.md`, `FLAGSHIP_SPEC.md`, and the full L1 handoff/API schema. Inspected existing topology and world HUD plus world-demo call sites.
- `git diff --check`: passed after L2 edits.
- Engine fixture command: `godot --headless --path godot --script res://tests/lattice/flagship_l2_contract.gd` — **not run**, per no-engine marker. No import, server, round, multi-client, or package task run.
- Fixture is synthetic contract evidence only; it does not prove GDScript parses, rendered readability, authored map binding, map-specific routes, natural source outcomes, legal-target UX, or MVP-A/B/C acceptance. The 3-/4-node examples use explicit source `breakCount` values 1/2; absent source count is reported as unknown.

## Blockers / review notes

- Lead must wire the composition call described above and run the scheduled engine contract. Actual pixels at 960x640 and 1280x800 and both-map waypoint correlation remain pending.
- Opponent dominance urgency comes from the published dominance team; flip wording uses only published `breakCount`. Missing/malformed/null dominance or a missing break count is unknown (no locally invented threshold or reconstructed count). If no enemy target is directly legal but a neutral frontier is legal, that frontier is returned as a legal prerequisite; otherwise prerequisite guidance has no fabricated target.
- Explicit selection is accepted only for a legal target in the active urgency class. Previous-target stability does not carry an obsolete intent across urgency changes. Round clearing resets both cached topology and target projections; authored static topology is retained until map identity changes.
- Known links and planar bearing are not a traversable route. No doorway pathfinding, guessed attribution, action authorization or purchase behavior is implemented.
