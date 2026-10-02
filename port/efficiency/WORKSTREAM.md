# Flash efficiency review

The owner requested an additional Flash research fan-out to make development as
efficient as possible. Three independent `deepseek/deepseek-flash` reviewers are
running in the background from `10a90fd0`. Implementation continues alongside them.

| Review | Session | Branch | Deliverable |
|---|---|---|---|
| Workflow and critical path | `ses_f025bfaeeffer9G4Iyy8ALX3Yh` | `efficiency/workflow-20261002` | `WORKFLOW.md`: queue priorities, vertical slices, incremental verification, branch/integration overhead and resource scheduling |
| Fighting architecture/data/tests | `ses_f025b6921ffeFA4GjVeGABRNYH` | `efficiency/architecture-20261002` | `ARCHITECTURE.md`: interface ambiguities, reusable mechanics, authoritative data, deterministic simulation and focused testing |
| Animation and asset production | `ses_f025af9f6ffeKD6VrrcnaXI4Md` | `efficiency/animation-20261002` | `ANIMATION_PIPELINE.md`: motion reuse with real character distinction, retargeting, paired throws, import/export and asset iteration |

Worktrees: `/home/mojo/.tmp-on-disk/cocs-efficiency-<lane>-20261002`.
Each reviewer owns only its report, has no nested agents or heavy-tool grant, and
must use actual committed code/design evidence plus verified primary sources.
They must not poll or modify the active implementation workers' files.

## Required outcome

Each report returns ranked concrete recommendations with:

- Observed bottleneck or risk, with file/code or documentation evidence.
- Specific change, current implementation owner and adoption priority.
- Expected benefit described honestly; no invented speedup measurements.
- Verification required and any tradeoff to functionality or motion quality.
- Three actions the parent can apply immediately without spawning another
  implementation workstream or restarting already-correct work.

Parent will reconcile findings, record adopted/deferred decisions and send scoped
steering to existing Sol/Astra owners. Preserve the full nine-character roster,
unique authored animations/effects, meaningful native acceptance, source identity
and existing releases. Efficient reuse does not mean tint-only characters or
counting source checks as rendered quality.

Current heavy-tool owner remains **Foundry revision 3**. Research is lightweight;
no Godot, Blender, import, render, audio capture or encoding is authorized here.

All three reports are complete and merged. Parent decisions, factual corrections
and assigned follow-ups are in [DECISIONS.md](DECISIONS.md). Existing Sol/Astra
owners received the actionable changes; no extra implementation workstream or
heavy grant was launched. Native performance improvements remain unmeasured.
