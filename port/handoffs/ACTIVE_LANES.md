# Parallel development ownership

Coordination snapshot after `013ad65`. This is an ownership record, not evidence
that an in-progress feature has passed acceptance. The lead integrates commits,
updates root documentation/shared verification and owns publication.

| Lane | Owner / baseline | Reserved files |
|---|---|---|
| LATTICE in-world command panel | Internal follow-up; `6116f12` | New world command UI/tests, narrow world_demo/world_hud only, `port/native-lattice-world-commands/` |
| Native KOTH / Domination | Internal agent; `013ad65` | New `godot/zone_modes/`, `godot/tests/zone_modes/`, `port/native-zone-modes/` |
| Race victory / soccer practice | Internal agent; `013ad65` | Narrow `godot/sports/`, new practice tests, `port/native-sports-victory/` |
| Sunscar combined-arms vehicle slice | Internal agent; `013ad65` | New `godot/combined_arms/`, `godot/tests/combined_arms/`, `port/native-combined-arms/` |
| Multiplayer lobby / leave / retry | External handoff; `8094d41` | New lobby-prefixed UI/tests, narrow `godot/world/session.gd` / scene and backward-compatible client hook if essential; `port/native-multiplayer-lobby/` |
| Pulse rifle preview | Existing external reservation | Preserve its preview/asset paths; no accepted delivery yet |

The LATTICE command and physical-input lanes are delivered and integrated at
`658b4e7` and `aca52f5`. The projectile navigation follow-up is integrated at
`cb908db`. Their current evidence remains separate from future gameplay work.
The external objective slice is delivered as `91ce0bd` and integrated at
`d498479`; its original tools/evidence stay preserved during follow-up work.
The native CI lane is delivered as `3d6de79` and integrated at `a12d89f`.
The LATTICE tactical map is delivered as `596325d`, integrated at `c982d25` and
independently accepted through both Map and original List native-input paths.
The lead owns common launcher routing, verification, root docs and publication.
The sports progression lane is delivered as `0a07f5c` and integrated at
`e76acdb`; the lead is reproducing full-lap and round-lifecycle claims separately.
That independent sports verification passed. Objective progression is integrated
at `ffa6aac` and independently passes CTF return/capture and Payload contest/
checkpoint/results/restart. GLB-side repair at `0149cbb` / `0af3c51` independently
passes all-nine export/import and matched-camera review.
Soccer targeting is integrated at `e561f99` / `4eb0e36`; independent two-resolution
visual checks and archived source-goal audit pass. Local-driver scoring remains
unaccepted after two bounded agent attempts; seven bot/own goals are preserved.
Co-op recruitment is integrated at `642c615`; independent natural-window purchases
pass on both maps, with prior Map/List regressions intact.
Objective completion is integrated at `1228369` / `2077911` / `db0c3ee`;
independent full Payload rollback/delivery and CTF pass/settled restart pass.
World traversal is integrated at `6116f12`; both independent graphical cases
and all four common-launcher startup routes pass. Native strategy commands
within that world and an editor-free Linux prototype build are now delegated.
The Linux package lane is delivered at `0c2dc2b` / `47c0ba2`, integrated as
`7f694ce` / `1b0949b`. The lead owns independent rebuild/extraction/launch
verification and documentation; generated local artifacts remain outside git.
The independent package rebuild and fresh-directory exported startup/cleanup
passed; the exact local archive and report are recorded in
`port/reports/linux-package-independent/README.md`.

## Resumed development batch

The owner requested renewed parallel acceleration after the 63-gate status
update. Three fresh worktrees now tackle disjoint gameplay gaps alongside the
existing in-world command panel:

- KOTH/Domination: actual source-controlled zone capture/scoring and readable
  native markers/HUD, with Meridian and Verdant as the initial acceptance cases.
- Sports: genuine lap-target victory; an explicit source-valid zero-bot soccer
  practice preset and bounded attempts at an attributable local-driver goal.
  Prior failed scoring attempts remain unchanged; practice acceptance is separate.
- Combined arms: ordinary Sunscar infantry approach, mount, authoritative vehicle
  motion and dismount, with clean transitions back to infantry controls.

These lanes may propose launcher/package routes but do not edit shared session,
network, common launcher, package pipeline, verifier, locked source or contracts.
The lead reviews integration hooks, reproduces important live claims, updates
evidence and rebuilds the Linux artifact after accepted runtime changes.

External tasks have complete scope/commands in
`external-native-objective-gameplay.md` and
`external-native-multiplayer-lobby.md`. They can be executed sequentially by
harnesses without subagents. No lane should change another owner's files,
silently merge shared branches, restart shared services or publish independently.

Published repository: <https://github.com/mojomast/cocs-godot>.
Screenshot gallery: <http://100.125.104.79:43595/> (Tailscale, screenshots only).
