# Parallel development ownership

Coordination snapshot after `013ad65`. This is an ownership record, not evidence
that an in-progress feature has passed acceptance. The lead integrates commits,
updates root documentation/shared verification and owns publication.

| Lane | Owner / baseline | Reserved files |
|---|---|---|
| LATTICE in-world command panel | Delivered `7439f05`, integrated `511bb8d`; independent suite PASS | World panel and tests; lead owns integration/docs |
| Native KOTH / Domination | Delivered `2b3d758` + `7238c9d`, integrated `8344544` + `c95f5ca`; independent acceptance PASS | New `godot/zone_modes/`, `godot/tests/zone_modes/`, `port/native-zone-modes/` |
| Independent zone acceptance | Delivered `60ebf1c`; both capture/scoring/results/restart runs PASS | `port/reports/zone-modes-independent/`; lead corrected helper partial-pass and provenance issues |
| LATTICE world co-op window | `ses_f38bf686ffferVSm9YSxCZ2qBP`; `8a58c97` | New `port/native-lattice-world-coop/`, new `godot/tests/lattice/world_coop_*`; existing runtime read-only |
| Native Arms Race | `ses_f38befeabfferVsmwNUVMxGkNX`; `8a58c97` | New `godot/arms_race/`, `godot/tests/arms_race/`, `port/native-arms-race/` |
| Player-facing usability audit | `ses_f38bcab6cffeceiulWP8ehkAkm`; `83e4aff`; owner-approved fifth lane | New `port/native-usability-audit/` only; graphical review and prioritized findings, no runtime edits |
| Race victory / soccer practice | Delivered `33f5257`, integrated `8a58c97`; independent race victory/local goal PASS | Sports coaching/tests; zero-bot practice blocked by source |
| Sunscar combined-arms vehicle slice | Delivered `1126a08` + `613dc92`, integrated `88cd514` + `fc5795c` | New `godot/combined_arms/`, `godot/tests/combined_arms/`, `port/native-combined-arms/` |
| Independent combined-arms acceptance | `ses_f38bb0b98ffeMGMo60aSC3YOzr`; `83e4aff` + delivery | New `port/reports/combined-arms-independent/`; independent evidence only, runtime read-only |
| Multiplayer lobby / leave / retry | Runtime delivery `3b96206` available; uncommitted acceptance/handoff path absent locally, requested committed evidence | New lobby-prefixed UI/tests, narrow `godot/world/session.gd` / scene and backward-compatible client hook if essential; `port/native-multiplayer-lobby/` |
| Independent lobby review | `ses_f38b68670ffexH4SE93QXRWRVd`; current integration runtime + `3b96206` in private worktree | New `port/reports/multiplayer-lobby-independent/` and new lobby-prefixed observers; shared runtime read-only |
| Pulse rifle preview | Existing external reservation | Preserve its preview/asset paths; no accepted delivery yet |
| Native Horde survival | External delivery `94690b6`; integration/review queued | New `godot/horde/`, `godot/tests/horde/`, `port/native-horde/`; local-only Match adapter needs separate launcher/package review, visual inspection pending |

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

## Deferred campaign

The owner wants a campaign remake, then explicitly deferred it for substantial
planning and research. **No campaign implementation is authorized by this lane
record and no campaign agent was launched.** `external-native-campaign-remake.md`
is retained only as an inactive preliminary draft; its architecture and mission
count are not agreed requirements. Schedule a dedicated planning task later.

`external-native-horde.md` is the replacement ready-to-copy development task.
Horde is an existing standalone source mode, separate from campaign design.

External tasks have complete scope/commands in
`external-native-objective-gameplay.md` and
`external-native-multiplayer-lobby.md`. They can be executed sequentially by
harnesses without subagents. No lane should change another owner's files,
silently merge shared branches, restart shared services or publish independently.

Published repository: <https://github.com/mojomast/cocs-godot>.
Screenshot gallery: <http://100.125.104.79:43595/> (Tailscale, screenshots only).
