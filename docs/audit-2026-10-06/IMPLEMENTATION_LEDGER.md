# Implementation ledger — audit 2026-10-06

**Starting state:** branch `feature/relay-campaign` @ `9b497d53c95b36198d5a0239ce578469b1acf358`
(= the audited baseline; **no changes since the audit**). Integration branch:
`audit/2026-10-06-implementation`.

**Rules of engagement (from the audit + owner directive):** provenance and
source gameplay remain authoritative; experiments are measured before
promotion; workers edit only their owned files and propose changes to shared
roots/schemas through the orchestrator; authors never approve their own work;
hardware/visual/audio/human gates are never claimed from unperformed checks.

| ID | Task | Owner | Status | Evidence / notes |
|---|---|---|---|---|
| T1 | F01 active source descriptor + current-vs-historical provenance scope | orchestrator | done | `port/contracts/active-source.json` + `ACTIVE_SOURCE.md` + `tools/godot-dev/active_source.mjs`; dev/package/verify/CI/export resolve the descriptor; historical lattice/movement manifests untouched; `core-provenance.test.mjs` now scopes the movement claim to its frozen commits and verifies current bytes through the reviewed chain. Checks: 4/4 test pass (was 3 pass/1 fail), semantic export exit 0, descriptor sha resolves, modified-byte negative control rejects. Pending: full aggregate run in T10. |
| T2 | F03 decode-once protocol path (validation, epochs, ACKs, ordering, coalescing preserved) | Flash (`worker-flash`, `deepseek/deepseek-flash`) | in_progress | worktree `cocs-audit-protocol-20261006`, branch `audit/w1-protocol-decode-once`; contract `docs/audit-2026-10-06/contracts/DECODE_ONCE.md`; base hook committed; reviewed by Space Bunny |
| T3 | F05 weapon presentation profile + sampled-animation pilot (rig compositor preserved) | Space Bunny (`general` @ `opencode/space-bunny-free#max`) | in_progress | worktree `cocs-audit-weapons-20261006`, branch `audit/w2-weapon-profile`; contract `docs/audit-2026-10-06/contracts/WEAPON_PRESENTATION_PROFILE.md`; reviewed by Flash |
| T4 | F12 menu disclosure (dev destinations behind explicit flag, stale route count/description) | orchestrator | todo | no supervisor/process-ownership changes |
| T5 | F11 checkpoint reward continuity (versioned carry policy) | worker | todo | after T2/T3 slots release; real death/Retry journey |
| T6 | F08 truthful shot/contact/weapon attribution (bounded, no prediction) | orchestrator + worker | todo | serialized behind protocol work (T2) |
| T7 | F07 fire-cadence characterization (all ten weapons, measured) | worker | todo | measurement only; no balance change without review |
| T8 | F17 material-role corrections (nonmetal rubber/ceramic/soil; wet nonmetal identity) | worker | todo | owning exporter only; matched captures |
| T9 | F15 bounded gate/tier record (current vs historical, executed vs unrun) | orchestrator | todo | no unrun-as-pass |
| T10 | Integration verification + real player journeys | orchestrator | todo | package + campaign journey; regressions separated from baselines |
| T11 | PR + binary-inclusive patch + final report | orchestrator | todo | base `main` @ `9b497d53` |

Status values: `todo` · `in_progress` · `review` (independent check running) ·
`done` · `blocked` (with reason).
