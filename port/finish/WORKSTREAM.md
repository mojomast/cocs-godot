# Finish prepared expansion work

The owner requested Astra subagents to **finish up**. This workstream consolidates
the prepared features, completes queued production, and carries accepted content
through native and package verification to a new release.

## Active ownership

| Agent | Session | Branch/worktree | Deliverable |
|---|---|---|---|
| Feature integration | `ses_f0294303bffed6Fb8UJLKe4ZDz` | `finish/integration-20261002`, `cocs-finish-integration-20261002` | Merge prepared gameplay, progression, weather, spectator, Horde, audio, LATTICE, controls and replay; resolve shared hooks; add authority-free Home Replays entry |
| Package closure | `ses_f02938d29ffe6I9QBl4ledVW0a` | `finish/packaging-20261002`, `cocs-finish-packaging-20261002` | Native data/resource dependencies, external replay runtime, launch and manifest closure, extracted-package checks |
| Combined acceptance | `ses_f0292f089ffeq9MnxeAHN0yrKb` | `finish/acceptance-20261002`, `cocs-finish-acceptance-20261002` | Canonical gate registration and bounded serial full-feature acceptance orchestration with truthful evidence and pending states |
| Parallax production completion | `ses_f055a6b41ffe42yCL8AxbOL676` | Existing observatory worktree/branch | Finish current art/capture task, native and architectural evidence, final commits and explicit process/slot release |

All finishing agents use `openai/gpt-6-astra`; no nested agents. The three new
worktrees start at `6cefd9eb` and live under `/home/mojo/.tmp-on-disk/`.

## Heavy-tool ownership and completion sequence

**Helix revision 2 now owns the exclusive heavy slot.** Parallax explicitly
released all owned processes after its final production checkpoint, and the parent
granted Helix its second Blender/native pass. Integration, packaging and acceptance
agents have only source/static/Node permission until a later explicit grant.

Parallax checkpoint: assets/tests `9a6372b4`, isolated bindings `277f379e`, geometry
`906be2ae3df33f54f779df3963a5985376ac96bb75bda94578ca4d3deb6d4554`.
Six hosted modes passed: DM/TDM/CTF/KOTH/Uplink/Holdout. Parent inspected overview,
archive, pump and polar-hall images: overall silhouette and polar hall are distinct;
archive/pump interiors still share too much structure. Parallax has a bounded
**source-only** differentiation task, preserving this checkpoint. No new heavy
grant was issued to Parallax. Foundry revision 3 follows Helix's explicit release.

1. Inspect final Parallax architectural and gameplay images and record the actual
   asset identity and proven pairs. Receive explicit slot release.
2. Grant Helix revision 2, then Foundry revision 3, their queued Blender/native
   passes. Revalidate changed geometry; retain historical prototype evidence.
3. Consolidate the finishing branches and run combined native acceptance under
   the next explicit grant. Fix failures without confusing grammar/source tests
   with native execution. Inspect Horde chain before the full victory attempt.
4. Advance remaining prepared map and asset production serially; reconcile final
   accepted catalogs and source/runtime resource identities. Review actual art.
5. Render the refreshed cinematic and inspect its live-menu candidate against
   accepted runtime assets, recording offline capture provenance and cadence.
6. Build Windows/Linux from one clean accepted runtime anchor, verify extracted
   artifacts and graphical journeys, publish checksums/downloads/evidence while
   preserving previous releases.

Prepared code or recipes are not release acceptance. Unrun critical gates must
remain pending, not passed. Human feel, natural balance/completion timing, audio
listening, assistive-technology behavior and real-GPU performance retain their
distinct evidence requirements.

## Integration boundaries

### Combined candidate merged

Acceptance branch `ed404fa6` is now merged as well: 24 canonical additions
produce **383 planned gates**, and a separate 96-job matrix has strict incomplete
reporting, bounded serial execution and explicit grants. Its 20 source jobs and
30 Python runner/registration/report/watchdog checks passed on the worker branch.
No native jobs ran. See `ACCEPTANCE_PLAN.md`; Helix remains the heavy-slot owner.

Integrator final `34726217` is merged into the parent at **`5a4bc82d`**. All 24
prepared feature commits, both packaging commits and reconciled shared hooks are
now present on `feature/relay-campaign`. The exported Replay fallback fix is
implemented; native rejection/entry/caption contracts remain queued. The recorded
source closure is 86 modules/39 adapters/166 feature resources (160 WAVs), seven
original worlds and four separate replay-runtime files. Frozen game/server bytes
are unchanged and new public map assets are not yet included.

The parent verified runtime/package files match the integrator exactly and ran
five closure/manifest tests successfully (`/tmp/opencode/finish-parent-merge-checks.tap`).
Integrator evidence includes 640 distinct passing Node tests across retained runs,
93-file grammar parsing, source/wire oracles and subsequent package checks; see
`INTEGRATION.md` for exact failures, repairs and run boundaries. No native result
or release acceptance follows from this merge. The acceptance worker received the
actual merged anchor and the three additional integration gate paths.

### Packaging checkpoint

Packaging returned `8522dcde` + `1466c861`, ready for integrated checks. The
integration agent has been instructed to merge both commits after feature changes
and preserve the challenge-authority discovery hooks. Explicit closure includes
the four-file replay runtime, controls/spectator catalogs and 160 telegraph WAVs.
Only registered map/mode pairs extend the original seven worlds/43 pairs.

Actual results: 221 non-engine package tests, four final integrity/catalog tests,
fifteen replay adapter tests, and a real extracted helper running from a fresh CWD
with spaces passed. Missing/corrupt helper copies were rejected; 160 audio files
reproduced deterministically. Recorded-commit discovery found 85 source modules,
38 adapters and seven worlds. These are isolated-branch results, not integrated
PCK or platform acceptance. Initial failures remain in the evidence directory.

Required production fix assigned to the integrator: replay bridge development
fallback must be editor-only. Exports use their own `replay-runtime`, verify its
exact four file hashes before launch, and show an error for absent/corrupt helpers.
Windows uses bundled Node; Home Replays remains authority-free. The integrator
also owns reviewing stale seven-bot factory tests against the current 24-bot
contract, retaining meaningful boundary tests. Heavy-slot ownership remains Helix.

- Feature integrator owns production hook reconciliation and Home Replays.
- Packaging agent owns `tools/godot-package/` closure and extracted checks.
- Acceptance agent owns canonical registration and its new serial runner.
- Existing map/asset agents own their geometry, masters, imports and native art
  acceptance. Source-ready empty asset hooks are not blindly activated.
- Parent owns final branch consolidation, grants, visual review and publication.
- Frozen source and reviewed derivative identities remain as recorded in earlier
  workstreams. Existing releases are preserved; published runtime is `e731fd53`
  until a newly verified release is actually published.
