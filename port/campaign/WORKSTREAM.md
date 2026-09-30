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

## Integration preparation

The source semantic export completed on the integration checkout. The first
pinned-editor import completed its asset scan/import work but crashed on editor
shutdown (signal 11). An incremental retry with `LP_NUM_THREADS=1` exited zero.
Both logs are retained under
`/home/mojo/.tmp-on-disk/cocs-campaign-evidence-20260930/`; this baseline failure
preceded integration of any campaign runtime code.

An independent Astra interface review identified and clarified feet-vs-centre
coordinates, visual-vs-hitbox scaling, base Match respawn/timeout behavior,
NativeClient chapter validation/input-reset behavior, actor-ID model reuse and
mandatory-route versus drawn-polyline distance. These clarifications were sent
to the relevant implementation lanes before integration.

The robot lane has the first exclusive engine/testing slot. Other lanes remain
on code generation and lightweight checks until that slot is released.
