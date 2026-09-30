# Four-level biome campaign workstream

## User requirements

- Four connected single-player campaign levels in the visual family of Canopy
  Divide and Basalt Reach, substantially larger than those 96 × 80 m arenas.
- Target 5–10 minutes of first-playthrough gameplay per level.
- A continuous story, authored pacing and varied gameplay objectives.
- Multiple recognizably different robot-style enemy models and combat roles.
- Flash subagents research best practice first; Astra subagents implement.

## Delivery constraints

- Keep established multiplayer and other native modes working. New campaign
  content is explicitly port-owned; original locked authoritative source bytes
  stay unchanged.
- Integration branch `feature/relay-campaign` starts at `5db21753`.
- Isolated Astra worktrees: `campaign/worlds`, `campaign/runtime`,
  `campaign/robots`, `campaign/client`, `campaign/packaging`.
  Commit scoped changes for integration.
- Serialize engine imports, rendering, heavyweight verification and exports.
- Preserve unrelated untracked files and the existing published biome preview.
- Validate real campaign transitions, player death/retry, checkpoint state,
  objectives, encounters and final ending. Scripted timing or route budgets are
  not evidence of observed human 5–10 minute playthroughs.
- Build both platform artifacts from the same pinned revision; publish actual
  export screenshots and record package acceptance honestly.

Flash research completed before the five Astra implementation lanes launched.
See [research](RESEARCH.md) and the [shared implementation contract](CONTRACT.md).
Packaging/route integration ownership is delegated to `campaign/packaging`;
the orchestrator owns integration verification, evidence and final exports.
